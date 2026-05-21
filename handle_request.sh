#!/bin/bash
# =============================================================================
# Nom         : handle_request.sh
# Description : Gestionnaire HTTP invoqué par socat EXEC: à chaque connexion.
#               stdin  = socket entrant  (requête HTTP du navigateur)
#               stdout = socket sortant (réponse HTTP vers le navigateur)
#
#               Script AUTONOME : aucun source avant d'avoir vidé stdin.
#               Pas de set -e — un exit prématuré produirait une réponse vide.
# Auteur      : Fire-UX Contributors
# Version     : 1.0.0
# =============================================================================

# ─── Étape 1 : lecture de stdin (requête HTTP) ────────────────────────────────
# Doit être la toute première chose exécutée.
# On parse en même temps la ligne de requête et Content-Length.

_method=""
_path="/"
_content_length=0
_first=true

while IFS= read -r -t 2 line; do
    [[ "$line" == $'\r' || -z "$line" ]] && break

    if $_first; then
        # Première ligne : "GET /chemin HTTP/1.1"
        _first=false
        line="${line%$'\r'}"
        _method="${line%% *}"
        _rest="${line#* }"
        _path="${_rest%% *}"
    elif [[ "$line" =~ ^[Cc]ontent-[Ll]ength:[[:space:]]*([0-9]+) ]]; then
        _content_length="${BASH_REMATCH[1]}"
    fi
done

# Lecture du corps POST (après les headers, toujours depuis stdin)
_post_body=""
if [[ "$_method" == "POST" && "$_content_length" -gt 0 && "$_content_length" -le 8192 ]]; then
    _post_body="$(head -c "$_content_length")"
fi

# ─── Étape 2 : chargement de web-ui.sh (stdin entièrement vidé) ──────────────
_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -f "${_dir}/web-ui.sh" ]]; then
    # shellcheck source=web-ui.sh
    source "${_dir}/web-ui.sh"
elif [[ -f "/usr/local/lib/fire-ux/web-ui.sh" ]]; then
    # shellcheck source=/dev/null
    source "/usr/local/lib/fire-ux/web-ui.sh"
else
    _b="<html><body><h1>Erreur : web-ui.sh introuvable</h1></body></html>"
    printf "HTTP/1.1 500 Internal Server Error\r\n"
    printf "Content-Type: text/html\r\n"
    printf "Content-Length: %d\r\n" "$(printf '%s' "$_b" | wc -c)"
    printf "Connection: close\r\n"
    printf "\r\n"
    printf "%s" "$_b"
    exit 1
fi

# PID du processus serveur principal, affiché par html_footer()
SERVER_PID="$(cat /run/fire-ux-web.pid 2>/dev/null || printf '—')"

# ─── Fonctions d'envoi HTTP ───────────────────────────────────────────────────

_send_html() {
    local body="$1"
    local len
    len="$(printf '%s' "$body" | wc -c)"
    printf "HTTP/1.1 200 OK\r\n"
    printf "Content-Type: text/html; charset=utf-8\r\n"
    printf "Content-Length: %d\r\n" "$len"
    printf "Connection: close\r\n"
    printf "\r\n"
    printf "%s" "$body"
}

_send_json() {
    local body="$1"
    local len
    len="$(printf '%s' "$body" | wc -c)"
    printf "HTTP/1.1 200 OK\r\n"
    printf "Content-Type: application/json; charset=utf-8\r\n"
    printf "Content-Length: %d\r\n" "$len"
    printf "Connection: close\r\n"
    printf "\r\n"
    printf "%s" "$body"
}

_send_redirect() {
    printf "HTTP/1.1 302 Found\r\n"
    printf "Location: %s\r\n" "$1"
    printf "Content-Length: 0\r\n"
    printf "Connection: close\r\n"
    printf "\r\n"
}

_send_404() {
    local body
    body="$(html_header '404 – Page introuvable')"
    body+='<div class="card">'
    body+='<h2>404 – Page introuvable</h2>'
    body+='<p style="color:var(--muted);margin:.5rem 0 1rem">La route demand&#233;e n&#39;existe pas.</p>'
    body+='<a href="/" class="btn btn-secondary">&#8592; Tableau de bord</a>'
    body+='</div>'
    body+="$(html_footer)"
    local len
    len="$(printf '%s' "$body" | wc -c)"
    printf "HTTP/1.1 404 Not Found\r\n"
    printf "Content-Type: text/html; charset=utf-8\r\n"
    printf "Content-Length: %d\r\n" "$len"
    printf "Connection: close\r\n"
    printf "\r\n"
    printf "%s" "$body"
}

# ─── Utilitaires paramètres POST ─────────────────────────────────────────────

# Décode une chaîne URL-encodée (%XX → caractère, + → espace)
_urldecode() {
    local s="${1//+/ }"
    printf '%b' "${s//%/\\x}"
}

# Extrait la valeur d'un champ depuis un body URL-encodé
# Usage : _param "chain=INPUT&port=80" "port"  →  80
_param() {
    local raw
    raw="$(printf '%s' "$1" | grep -oE "$2=[^&]*" | head -1 | cut -d= -f2-)"
    _urldecode "$raw"
}

# ─── Handlers POST ────────────────────────────────────────────────────────────

_handle_apply_preset() {
    local preset
    preset="$(_param "$_post_body" "preset")"
    case "$preset" in
        web)
            iptables -F; iptables -X
            iptables -P INPUT DROP; iptables -P FORWARD DROP; iptables -P OUTPUT ACCEPT
            iptables -A INPUT -i lo -j ACCEPT
            iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
            iptables -A INPUT -p tcp --dport 22  -j ACCEPT
            iptables -A INPUT -p tcp --dport 80  -j ACCEPT
            iptables -A INPUT -p tcp --dport 443 -j ACCEPT
            iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
            printf '%s - Preset web appliqué via interface web\n' \
                "$(date '+%Y-%m-%d %H:%M:%S')" >> /var/log/fire-ux.log
            _send_redirect "/?msg=preset_applied" ;;
        ssh)
            iptables -F; iptables -X
            iptables -P INPUT DROP; iptables -P FORWARD DROP; iptables -P OUTPUT ACCEPT
            iptables -A INPUT -i lo -j ACCEPT
            iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
            iptables -A INPUT -p tcp --dport 22 -j ACCEPT
            iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
            printf '%s - Preset ssh appliqué via interface web\n' \
                "$(date '+%Y-%m-%d %H:%M:%S')" >> /var/log/fire-ux.log
            _send_redirect "/?msg=preset_applied" ;;
        panic)
            iptables -F; iptables -X
            iptables -P INPUT DROP; iptables -P FORWARD DROP; iptables -P OUTPUT DROP
            iptables -A INPUT  -i lo -j ACCEPT
            iptables -A OUTPUT -o lo -j ACCEPT
            printf '%s - Mode panique activé via interface web\n' \
                "$(date '+%Y-%m-%d %H:%M:%S')" >> /var/log/fire-ux.log
            _send_redirect "/?msg=preset_applied" ;;
        flush_all)
            iptables -F; iptables -X
            iptables -P INPUT ACCEPT; iptables -P FORWARD ACCEPT; iptables -P OUTPUT ACCEPT
            printf '%s - Flush total via interface web\n' \
                "$(date '+%Y-%m-%d %H:%M:%S')" >> /var/log/fire-ux.log
            _send_redirect "/?msg=preset_applied" ;;
        *)
            _send_redirect "/?msg=error_unknown_preset" ;;
    esac
}

_handle_add_rule() {
    local chain proto port src action
    chain="$(_param "$_post_body" "chain")"
    proto="$(_param "$_post_body" "proto")"
    port="$(_param  "$_post_body" "port")"
    src="$(_param   "$_post_body" "src")"
    action="$(_param "$_post_body" "action")"

    case "$chain"  in INPUT|OUTPUT|FORWARD) ;;
        *) _send_redirect "/rules?msg=error_invalid_chain";  return ;;
    esac
    case "$proto"  in tcp|udp|icmp|all) ;;
        *) _send_redirect "/rules?msg=error_invalid_proto";  return ;;
    esac
    case "$action" in ACCEPT|DROP|REJECT) ;;
        *) _send_redirect "/rules?msg=error_invalid_action"; return ;;
    esac
    if [[ -n "$port" ]] && ! [[ "$port" =~ ^[0-9]{1,5}(:[0-9]{1,5})?$ ]]; then
        _send_redirect "/rules?msg=error_invalid_port"; return
    fi
    if [[ -n "$src" ]] && \
       ! [[ "$src" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}(/[0-9]{1,2})?$ ]]; then
        _send_redirect "/rules?msg=error_invalid_src"; return
    fi

    # Tableau de commande sans eval
    local -a cmd=( iptables -A "$chain" )
    [[ "$proto" != "all" ]] && cmd+=( -p "$proto" )
    if [[ -n "$port" && "$proto" != "icmp" && "$proto" != "all" ]]; then
        cmd+=( --dport "$port" )
    fi
    [[ -n "$src" ]] && cmd+=( -s "$src" )
    cmd+=( -j "$action" )

    if "${cmd[@]}" 2>/dev/null; then
        printf '%s - Règle ajoutée via interface web : %s\n' \
            "$(date '+%Y-%m-%d %H:%M:%S')" "${cmd[*]}" >> /var/log/fire-ux.log
        _send_redirect "/rules?msg=rule_added"
    else
        _send_redirect "/rules?msg=error_add_failed"
    fi
}

_handle_delete_rule() {
    local num chain
    num="$(_param   "$_post_body" "num")"
    chain="$(_param "$_post_body" "chain")"

    case "$chain" in INPUT|OUTPUT|FORWARD) ;;
        *) _send_redirect "/rules?msg=error_invalid_chain"; return ;;
    esac
    if ! [[ "$num" =~ ^[0-9]+$ ]]; then
        _send_redirect "/rules?msg=error_invalid_num"; return
    fi

    if iptables -D "$chain" "$num" 2>/dev/null; then
        printf '%s - Règle #%s supprimée de %s via interface web\n' \
            "$(date '+%Y-%m-%d %H:%M:%S')" "$num" "$chain" >> /var/log/fire-ux.log
        _send_redirect "/rules?msg=rule_deleted"
    else
        _send_redirect "/rules?msg=error_delete_failed"
    fi
}

_handle_flush() {
    local chain
    chain="$(_param "$_post_body" "chain")"
    case "$chain" in
        INPUT|OUTPUT|FORWARD)
            iptables -F "$chain" 2>/dev/null || true
            printf '%s - Chaîne %s vidée via interface web\n' \
                "$(date '+%Y-%m-%d %H:%M:%S')" "$chain" >> /var/log/fire-ux.log
            _send_redirect "/rules?msg=chain_flushed" ;;
        all)
            iptables -F 2>/dev/null || true
            printf '%s - Toutes les chaînes vidées via interface web\n' \
                "$(date '+%Y-%m-%d %H:%M:%S')" >> /var/log/fire-ux.log
            _send_redirect "/rules?msg=all_flushed" ;;
        *)
            _send_redirect "/rules?msg=error_invalid_chain" ;;
    esac
}

_handle_save_snapshot() {
    local dir="/etc/fire-ux/profiles"
    mkdir -p "$dir"
    local ts
    ts="$(date +%Y%m%d%H%M%S)"
    if iptables-save > "${dir}/snapshot_web_${ts}" 2>/dev/null; then
        printf '%s - Snapshot créé : snapshot_web_%s\n' \
            "$(date '+%Y-%m-%d %H:%M:%S')" "$ts" >> /var/log/fire-ux.log
        _send_redirect "/profiles?msg=snapshot_saved"
    else
        _send_redirect "/profiles?msg=error_snapshot_failed"
    fi
}

_handle_apply_profile() {
    local name pf
    name="$(_param "$_post_body" "name")"
    name="$(printf '%s' "$name" | tr -cd '[:alnum:]._-')"
    pf="/etc/fire-ux/profiles/${name}"
    if [[ -z "$name" || ! -f "$pf" ]]; then
        _send_redirect "/profiles?msg=error_profile_not_found"; return
    fi
    if iptables-restore < "$pf" 2>/dev/null; then
        printf '%s - Profil appliqué : %s\n' \
            "$(date '+%Y-%m-%d %H:%M:%S')" "$name" >> /var/log/fire-ux.log
        _send_redirect "/profiles?msg=profile_applied"
    else
        _send_redirect "/profiles?msg=error_restore_failed"
    fi
}

# ─── Étape 3 : extraction du query string et routing ─────────────────────────

_clean_path="${_path%%\?*}"
if [[ "$_path" == *"?"* ]]; then
    QUERY_STRING="${_path#*\?}"
else
    QUERY_STRING=""
fi

case "${_method}|${_clean_path}" in

    "GET|/")
        _send_html "$(page_dashboard)" ;;

    "GET|/rules")
        _send_html "$(page_rules)" ;;

    "GET|/logs")
        _send_html "$(page_logs)" ;;

    "GET|/profiles")
        _send_html "$(page_profiles)" ;;

    "GET|/status")
        _ci="$(iptables -L INPUT   --line-numbers -n 2>/dev/null | tail -n +3 | grep -c '.' || echo 0)"
        _co="$(iptables -L OUTPUT  --line-numbers -n 2>/dev/null | tail -n +3 | grep -c '.' || echo 0)"
        _cf="$(iptables -L FORWARD --line-numbers -n 2>/dev/null | tail -n +3 | grep -c '.' || echo 0)"
        _up="$(uptime -p 2>/dev/null || uptime | sed 's/.*up //;s/,.*//')"
        _send_json "$(printf \
            '{"rules_input":%d,"rules_output":%d,"rules_forward":%d,"server_pid":"%s","uptime":"%s"}' \
            "$_ci" "$_co" "$_cf" "$SERVER_PID" "$_up")" ;;

    "GET|/favicon.ico")
        printf "HTTP/1.1 204 No Content\r\nConnection: close\r\n\r\n" ;;

    "POST|/apply-preset")   _handle_apply_preset  ;;
    "POST|/add-rule")       _handle_add_rule       ;;
    "POST|/delete-rule")    _handle_delete_rule    ;;
    "POST|/flush")          _handle_flush          ;;
    "POST|/save-snapshot")  _handle_save_snapshot  ;;
    "POST|/apply-profile")  _handle_apply_profile  ;;

    *)
        _send_404 ;;
esac
