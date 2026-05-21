#!/bin/bash
# =============================================================================
# Nom         : web-server.sh
# Description : Serveur HTTP minimaliste en Bash pur pour l'interface web
#               Fire-UX. Aucune dépendance externe : socat (ou ncat en
#               fallback), bash, iptables, ss et coreutils standard.
# Usage       : sudo bash web-server.sh [port]
# Port défaut : 8080
# Auteur      : Fire-UX Contributors
# Version     : 1.0.0
# =============================================================================

set -euo pipefail

# ─── Configuration ────────────────────────────────────────────────────────────
WEB_PORT="${1:-8080}"
WEB_HOST="0.0.0.0"
LIB_DIR="/usr/local/lib/fire-ux"
LOG_FILE="/var/log/fire-ux.log"
VERSION="1.0.0"
SERVER_PID=$$

# ─── Vérification des droits root ────────────────────────────────────────────
if [ "${EUID}" -ne 0 ]; then
    echo "Erreur : web-server.sh doit être exécuté en root." >&2
    exit 1
fi

# ─── Chargement du générateur HTML ───────────────────────────────────────────
# Cherche web-ui.sh d'abord dans le répertoire du script, puis dans LIB_DIR
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "${SCRIPT_DIR}/web-ui.sh" ]; then
    # shellcheck source=web-ui.sh
    source "${SCRIPT_DIR}/web-ui.sh"
elif [ -f "${LIB_DIR}/web-ui.sh" ]; then
    # shellcheck source=/dev/null
    source "${LIB_DIR}/web-ui.sh"
else
    echo "Erreur : web-ui.sh introuvable (cherché dans ${SCRIPT_DIR} et ${LIB_DIR})." >&2
    exit 1
fi

# ─── Détection du multiplexeur réseau ────────────────────────────────────────
# Préférence : socat ; fallback : ncat
detect_netcat() {
    if command -v socat &>/dev/null; then
        echo "socat"
    elif command -v ncat &>/dev/null; then
        echo "ncat"
    elif command -v nc &>/dev/null && nc --help 2>&1 | grep -q "\-l"; then
        echo "nc"
    else
        echo ""
    fi
}

NET_TOOL=$(detect_netcat)
if [ -z "${NET_TOOL}" ]; then
    echo "Erreur : socat ou ncat requis. Installez l'un d'eux :" >&2
    echo "  apt install socat   OU   apt install ncat" >&2
    exit 1
fi

# ─── Envoi d'une réponse HTTP ─────────────────────────────────────────────────
# Paramètres : $1 = code HTTP, $2 = content-type, $3 = corps de la réponse
send_response() {
    local code="$1"
    local content_type="$2"
    local body="$3"
    local length
    length=$(printf '%s' "${body}" | wc -c)

    printf 'HTTP/1.1 %s\r\n' "${code}"
    printf 'Content-Type: %s; charset=utf-8\r\n' "${content_type}"
    printf 'Content-Length: %d\r\n' "${length}"
    printf 'Connection: close\r\n'
    printf 'Cache-Control: no-cache\r\n'
    printf 'X-Frame-Options: SAMEORIGIN\r\n'
    printf '\r\n'
    printf '%s' "${body}"
}

# ─── Réponse HTML raccourcie ──────────────────────────────────────────────────
send_html() {
    send_response "200 OK" "text/html" "$1"
}

# ─── Redirection HTTP ─────────────────────────────────────────────────────────
send_redirect() {
    local location="$1"
    printf 'HTTP/1.1 302 Found\r\n'
    printf 'Location: %s\r\n' "${location}"
    printf 'Content-Length: 0\r\n'
    printf 'Connection: close\r\n'
    printf '\r\n'
}

# ─── Réponse JSON ─────────────────────────────────────────────────────────────
send_json() {
    send_response "200 OK" "application/json" "$1"
}

# ─── Réponse 404 ─────────────────────────────────────────────────────────────
send_404() {
    local body
    body=$(html_header "404 – Page introuvable")
    body+='<div class="card"><h2>404 – Page introuvable</h2>'
    body+='<p>La route demandée n&#39;existe pas.</p>'
    body+='<a href="/" class="btn">← Retour au tableau de bord</a></div>'
    body+=$(html_footer)
    send_response "404 Not Found" "text/html" "${body}"
}

# ─── Décodage URL ─────────────────────────────────────────────────────────────
# Convertit %XX et + en caractères lisibles
urldecode() {
    local encoded="${1//+/ }"
    printf '%b' "${encoded//%/\\x}"
}

# ─── Extraction d'un paramètre POST ──────────────────────────────────────────
# parse_param "chain=INPUT&port=80" "port"  →  "80"
parse_param() {
    local body="$1"
    local key="$2"
    local val
    # Extrait la valeur entre = et & (ou fin de chaîne)
    val=$(printf '%s' "${body}" | grep -oE "${key}=[^&]*" | head -1 | cut -d= -f2-)
    urldecode "${val}"
}

# ─── Lecture de la requête HTTP ───────────────────────────────────────────────
# Lit depuis stdin et retourne : METHOD|PATH|BODY
read_request() {
    local method="" path="" line body="" content_length=0

    # Lecture de la ligne de requête
    IFS= read -r line
    line="${line%$'\r'}"
    method=$(echo "${line}" | awk '{print $1}')
    path=$(echo "${line}" | awk '{print $2}')

    # Lecture des en-têtes pour trouver Content-Length
    while IFS= read -r line; do
        line="${line%$'\r'}"
        [ -z "${line}" ] && break
        if echo "${line}" | grep -qi "^content-length:"; then
            content_length=$(echo "${line}" | awk -F': ' '{print $2}' | tr -d '[:space:]')
        fi
    done

    # Lecture du corps si POST
    if [ "${method}" = "POST" ] && [ "${content_length}" -gt 0 ]; then
        body=$(dd bs=1 count="${content_length}" 2>/dev/null)
    fi

    printf '%s|%s|%s' "${method}" "${path}" "${body}"
}

# ─── Route : GET / ────────────────────────────────────────────────────────────
handle_dashboard() {
    send_html "$(page_dashboard)"
}

# ─── Route : GET /rules ───────────────────────────────────────────────────────
handle_rules() {
    send_html "$(page_rules)"
}

# ─── Route : GET /logs ────────────────────────────────────────────────────────
handle_logs() {
    send_html "$(page_logs)"
}

# ─── Route : GET /profiles ───────────────────────────────────────────────────
handle_profiles() {
    send_html "$(page_profiles)"
}

# ─── Route : GET /status (JSON) ───────────────────────────────────────────────
handle_status() {
    local cnt_in cnt_out cnt_fwd ipv6_status uptime_val
    cnt_in=$(iptables  -L INPUT   --line-numbers -n 2>/dev/null | tail -n +3 | grep -c "." || true)
    cnt_out=$(iptables -L OUTPUT  --line-numbers -n 2>/dev/null | tail -n +3 | grep -c "." || true)
    cnt_fwd=$(iptables -L FORWARD --line-numbers -n 2>/dev/null | tail -n +3 | grep -c "." || true)

    if command -v ip6tables &>/dev/null && ip6tables -L INPUT -n &>/dev/null 2>&1; then
        ipv6_status="true"
    else
        ipv6_status="false"
    fi

    uptime_val=$(uptime -p 2>/dev/null || uptime | sed 's/.*up //' | sed 's/,.*//')

    local json
    json=$(printf '{"rules_input":%d,"rules_output":%d,"rules_forward":%d,"ipv6":%s,"uptime":"%s","server_pid":%d}' \
        "${cnt_in}" "${cnt_out}" "${cnt_fwd}" "${ipv6_status}" "${uptime_val}" "${SERVER_PID}")
    send_json "${json}"
}

# ─── Route : POST /apply-preset ──────────────────────────────────────────────
handle_apply_preset() {
    local body="$1"
    local preset
    preset=$(parse_param "${body}" "preset")

    local fire_ux
    if [ -f "${SCRIPT_DIR}/fire-ux.sh" ]; then
        fire_ux="${SCRIPT_DIR}/fire-ux.sh"
    elif [ -f "/usr/local/bin/fire-ux" ]; then
        fire_ux="/usr/local/bin/fire-ux"
    else
        send_redirect "/?msg=error_fireuxnotfound"
        return
    fi

    case "${preset}" in
        web)
            iptables -F; iptables -X
            iptables -P INPUT DROP; iptables -P FORWARD DROP; iptables -P OUTPUT ACCEPT
            iptables -A INPUT -i lo -j ACCEPT
            iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
            iptables -A INPUT -p tcp --dport 22  -j ACCEPT
            iptables -A INPUT -p tcp --dport 80  -j ACCEPT
            iptables -A INPUT -p tcp --dport 443 -j ACCEPT
            iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
            echo "$(date '+%Y-%m-%d %H:%M:%S') - Preset appliqué via interface web : web" >> "${LOG_FILE}"
            ;;
        ssh)
            iptables -F; iptables -X
            iptables -P INPUT DROP; iptables -P FORWARD DROP; iptables -P OUTPUT ACCEPT
            iptables -A INPUT -i lo -j ACCEPT
            iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
            iptables -A INPUT -p tcp --dport 22  -j ACCEPT
            iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
            echo "$(date '+%Y-%m-%d %H:%M:%S') - Preset appliqué via interface web : ssh" >> "${LOG_FILE}"
            ;;
        panic)
            iptables -F; iptables -X
            iptables -P INPUT DROP; iptables -P FORWARD DROP; iptables -P OUTPUT DROP
            iptables -A INPUT  -i lo -j ACCEPT
            iptables -A OUTPUT -o lo -j ACCEPT
            echo "$(date '+%Y-%m-%d %H:%M:%S') - Mode panique activé via interface web" >> "${LOG_FILE}"
            ;;
        flush_all)
            iptables -F; iptables -X
            iptables -P INPUT ACCEPT; iptables -P FORWARD ACCEPT; iptables -P OUTPUT ACCEPT
            echo "$(date '+%Y-%m-%d %H:%M:%S') - Flush total via interface web" >> "${LOG_FILE}"
            ;;
        *)
            send_redirect "/?msg=error_unknown_preset"
            return
            ;;
    esac

    send_redirect "/?msg=preset_applied"
}

# ─── Route : POST /add-rule ───────────────────────────────────────────────────
handle_add_rule() {
    local body="$1"
    local chain port proto action src

    chain=$(parse_param "${body}" "chain")
    port=$(parse_param  "${body}" "port")
    proto=$(parse_param "${body}" "proto")
    action=$(parse_param "${body}" "action")
    src=$(parse_param   "${body}" "src")

    # Validation basique des entrées
    case "${chain}" in INPUT|OUTPUT|FORWARD) ;; *)
        send_redirect "/rules?msg=error_invalid_chain"; return ;;
    esac
    case "${action}" in ACCEPT|DROP|REJECT) ;; *)
        send_redirect "/rules?msg=error_invalid_action"; return ;;
    esac
    case "${proto}" in tcp|udp|icmp|all) ;; *)
        send_redirect "/rules?msg=error_invalid_proto"; return ;;
    esac
    if [ -n "${port}" ] && ! echo "${port}" | grep -qE '^[0-9]{1,5}(:[0-9]{1,5})?$'; then
        send_redirect "/rules?msg=error_invalid_port"; return
    fi
    if [ -n "${src}" ] && ! echo "${src}" | grep -qE '^[0-9]{1,3}(\.[0-9]{1,3}){3}(/[0-9]{1,2})?$'; then
        send_redirect "/rules?msg=error_invalid_src"; return
    fi

    # Construction de la commande iptables
    local cmd="iptables -A ${chain}"
    [ "${proto}" != "all" ] && cmd="${cmd} -p ${proto}"
    if [ -n "${port}" ] && [ "${proto}" != "icmp" ] && [ "${proto}" != "all" ]; then
        cmd="${cmd} --dport ${port}"
    fi
    [ -n "${src}" ] && cmd="${cmd} -s ${src}"
    cmd="${cmd} -j ${action}"

    if eval "${cmd}" 2>/dev/null; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Règle ajoutée via interface web : ${cmd}" >> "${LOG_FILE}"
        send_redirect "/rules?msg=rule_added"
    else
        send_redirect "/rules?msg=error_add_failed"
    fi
}

# ─── Route : POST /delete-rule ───────────────────────────────────────────────
handle_delete_rule() {
    local body="$1"
    local num chain

    num=$(parse_param   "${body}" "num")
    chain=$(parse_param "${body}" "chain")

    case "${chain}" in INPUT|OUTPUT|FORWARD) ;; *)
        send_redirect "/rules?msg=error_invalid_chain"; return ;;
    esac
    if ! echo "${num}" | grep -qE '^[0-9]+$'; then
        send_redirect "/rules?msg=error_invalid_num"; return
    fi

    if iptables -D "${chain}" "${num}" 2>/dev/null; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Règle #${num} supprimée de ${chain} via interface web" >> "${LOG_FILE}"
        send_redirect "/rules?msg=rule_deleted"
    else
        send_redirect "/rules?msg=error_delete_failed"
    fi
}

# ─── Route : POST /flush ──────────────────────────────────────────────────────
handle_flush() {
    local body="$1"
    local chain
    chain=$(parse_param "${body}" "chain")

    case "${chain}" in
        INPUT|OUTPUT|FORWARD)
            iptables -F "${chain}" 2>/dev/null
            echo "$(date '+%Y-%m-%d %H:%M:%S') - Chaîne ${chain} vidée via interface web" >> "${LOG_FILE}"
            send_redirect "/rules?msg=chain_flushed"
            ;;
        all)
            iptables -F 2>/dev/null
            echo "$(date '+%Y-%m-%d %H:%M:%S') - Toutes les chaînes vidées via interface web" >> "${LOG_FILE}"
            send_redirect "/rules?msg=all_flushed"
            ;;
        *)
            send_redirect "/rules?msg=error_invalid_chain"
            ;;
    esac
}

# ─── Route : POST /save-snapshot ─────────────────────────────────────────────
handle_save_snapshot() {
    local profiles_dir="/etc/fire-ux/profiles"
    mkdir -p "${profiles_dir}"
    local ts
    ts=$(date +%Y%m%d%H%M%S)
    local snap_file="${profiles_dir}/snapshot_web_${ts}"

    if iptables-save > "${snap_file}" 2>/dev/null; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Snapshot créé via interface web : snapshot_web_${ts}" >> "${LOG_FILE}"
        send_redirect "/profiles?msg=snapshot_saved"
    else
        send_redirect "/profiles?msg=error_snapshot_failed"
    fi
}

# ─── Route : POST /apply-profile ─────────────────────────────────────────────
handle_apply_profile() {
    local body="$1"
    local name
    name=$(parse_param "${body}" "name")

    # Sécurisation : uniquement alphanumériques, tirets, underscores, points
    name=$(printf '%s' "${name}" | tr -cd '[:alnum:]._-')
    local pf="/etc/fire-ux/profiles/${name}"

    if [ ! -f "${pf}" ]; then
        send_redirect "/profiles?msg=error_profile_not_found"
        return
    fi

    if iptables-restore < "${pf}" 2>/dev/null; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Profil appliqué via interface web : ${name}" >> "${LOG_FILE}"
        send_redirect "/profiles?msg=profile_applied"
    else
        send_redirect "/profiles?msg=error_restore_failed"
    fi
}

# ─── Routeur principal ────────────────────────────────────────────────────────
# Dispatche chaque requête vers le handler approprié
route_request() {
    local raw_request
    raw_request=$(read_request)

    local method path body
    method=$(printf '%s' "${raw_request}" | cut -d'|' -f1)
    path=$(printf '%s'   "${raw_request}" | cut -d'|' -f2)
    body=$(printf '%s'   "${raw_request}" | cut -d'|' -f3-)

    # Normalisation du chemin (suppression du query string pour le routage)
    local clean_path
    clean_path=$(printf '%s' "${path}" | cut -d'?' -f1)

    case "${method}|${clean_path}" in
        "GET|/")               handle_dashboard ;;
        "GET|/rules")          handle_rules ;;
        "GET|/logs")           handle_logs ;;
        "GET|/profiles")       handle_profiles ;;
        "GET|/status")         handle_status ;;
        "POST|/apply-preset")  handle_apply_preset  "${body}" ;;
        "POST|/add-rule")      handle_add_rule       "${body}" ;;
        "POST|/delete-rule")   handle_delete_rule    "${body}" ;;
        "POST|/flush")         handle_flush          "${body}" ;;
        "POST|/save-snapshot") handle_save_snapshot ;;
        "POST|/apply-profile") handle_apply_profile  "${body}" ;;
        *)                     send_404 ;;
    esac
}

# ─── Boucle serveur socat ─────────────────────────────────────────────────────
run_with_socat() {
    echo "Serveur Fire-UX démarré sur http://${WEB_HOST}:${WEB_PORT} (socat)" >&2
    socat TCP-LISTEN:"${WEB_PORT}",reuseaddr,fork,bind="${WEB_HOST}" \
        SYSTEM:'bash -c "source \"'"${SCRIPT_DIR}/web-ui.sh"'\" 2>/dev/null || source \"'"${LIB_DIR}/web-ui.sh"'\"; source \"'"$0"'\"; route_request"' 2>/dev/null
}

# ─── Boucle serveur ncat ──────────────────────────────────────────────────────
run_with_ncat() {
    echo "Serveur Fire-UX démarré sur http://${WEB_HOST}:${WEB_PORT} (ncat)" >&2
    ncat --listen "${WEB_HOST}" "${WEB_PORT}" --keep-open \
        --sh-exec 'bash -c "source \"'"${SCRIPT_DIR}/web-ui.sh"'\" 2>/dev/null || source \"'"${LIB_DIR}/web-ui.sh"'\"; source \"'"$0"'\"; route_request"' 2>/dev/null
}

# ─── Boucle serveur nc (fallback basique) ────────────────────────────────────
# nc classique ne supporte pas --keep-open ni --sh-exec de façon portable ;
# on utilise une boucle while pour simuler l'accept.
run_with_nc() {
    echo "Serveur Fire-UX démarré sur http://${WEB_HOST}:${WEB_PORT} (nc)" >&2
    while true; do
        nc -l -p "${WEB_PORT}" -q 1 2>/dev/null < <(route_request) || true
    done
}

# ─── Démarrage du serveur ─────────────────────────────────────────────────────
echo "Fire-UX Web Interface v${VERSION} — PID $$" >&2
echo "Outil réseau sélectionné : ${NET_TOOL}" >&2

# Écriture du PID dans un fichier pour le service systemd
echo $$ > /run/fire-ux-web.pid

case "${NET_TOOL}" in
    socat) run_with_socat ;;
    ncat)  run_with_ncat ;;
    nc)    run_with_nc ;;
esac
