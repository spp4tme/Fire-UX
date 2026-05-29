#!/bin/bash
# =============================================================================
# handle_request.sh v2.1 — Gestionnaire HTTP Fire-UX
# =============================================================================

# ── Étape 1 : lecture stdin ───────────────────────────────────────────────────
_method="" _path="/" _content_length=0 _first=true

while IFS= read -r -t 2 line; do
    [[ "$line" == $'\r' || -z "$line" ]] && break
    if $_first; then
        _first=false; line="${line%$'\r'}"; _method="${line%% *}"
        _rest="${line#* }"; _path="${_rest%% *}"
    elif [[ "$line" =~ ^[Cc]ontent-[Ll]ength:[[:space:]]*([0-9]+) ]]; then
        _content_length="${BASH_REMATCH[1]}"
    fi
done

_post_body=""
if [[ "$_method" == "POST" && "$_content_length" -gt 0 && "$_content_length" -le 8192 ]]; then
    _post_body="$(head -c "$_content_length")"
fi

# ── Étape 2 : chargement web-ui.sh ───────────────────────────────────────────
_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${_dir}/web-ui.sh" ]]; then
    source "${_dir}/web-ui.sh"
elif [[ -f "/usr/local/lib/fire-ux/web-ui.sh" ]]; then
    source "/usr/local/lib/fire-ux/web-ui.sh"
else
    _b="<html><body><h1>Erreur : web-ui.sh introuvable</h1></body></html>"
    printf "HTTP/1.1 500 Internal Server Error\r\nContent-Type: text/html\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s" \
        "$(printf '%s' "$_b"|wc -c)" "$_b"
    exit 1
fi
SERVER_PID="$(cat /run/fire-ux-web.pid 2>/dev/null || printf '—')"

# ── Helpers HTTP ──────────────────────────────────────────────────────────────
_send_html() {
    local body="$1" len; len="$(printf '%s' "$body"|wc -c)"
    printf "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: %d\r\nConnection: close\r\nCache-Control: no-cache\r\n\r\n%s" "$len" "$body"
}
_send_json() {
    local body="$1" len; len="$(printf '%s' "$body"|wc -c)"
    printf "HTTP/1.1 200 OK\r\nContent-Type: application/json; charset=utf-8\r\nContent-Length: %d\r\nConnection: close\r\nAccess-Control-Allow-Origin: *\r\nCache-Control: no-cache\r\n\r\n%s" "$len" "$body"
}
_send_redirect() { printf "HTTP/1.1 302 Found\r\nLocation: %s\r\nContent-Length: 0\r\nConnection: close\r\n\r\n" "$1"; }
_send_404() {
    local body; body="$(html_header '404' '')
<div style='max-width:440px;margin:4rem auto;text-align:center'>
<div style='font-size:4rem;line-height:1;color:var(--ac);text-shadow:0 0 30px rgba(0,210,255,.4);margin-bottom:1rem'>⊘</div>
<div style='font-size:1.1rem;font-weight:700;margin-bottom:.5rem'>404 — Page introuvable</div>
<p style='color:var(--mu);font-size:.85rem;margin-bottom:1.5rem'>La route demandée n'\''existe pas.</p>
<a href='/' class='btn btn-p'>← Tableau de bord</a></div>$(html_footer)"
    local len; len="$(printf '%s' "$body"|wc -c)"
    printf "HTTP/1.1 404 Not Found\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s" "$len" "$body"
}

# ── Paramètres POST ───────────────────────────────────────────────────────────
_urldecode() { local s="${1//+/ }"; printf '%b' "${s//%/\\x}"; }
_param() {
    local raw; raw="$(printf '%s' "$1"|grep -oE "$2=[^&]*"|head -1|cut -d= -f2-)"; _urldecode "$raw"
}

# ── Handlers POST ─────────────────────────────────────────────────────────────
_handle_apply_preset() {
    local preset; preset="$(_param "$_post_body" "preset")"
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
            printf '%s - Preset web appliqué\n' "$(date '+%Y-%m-%d %H:%M:%S')" >> /var/log/fire-ux.log
            _send_redirect "/?msg=preset_applied" ;;
        ssh)
            iptables -F; iptables -X
            iptables -P INPUT DROP; iptables -P FORWARD DROP; iptables -P OUTPUT ACCEPT
            iptables -A INPUT -i lo -j ACCEPT
            iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
            iptables -A INPUT -p tcp --dport 22 -j ACCEPT
            iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
            printf '%s - Preset ssh appliqué\n' "$(date '+%Y-%m-%d %H:%M:%S')" >> /var/log/fire-ux.log
            _send_redirect "/?msg=preset_applied" ;;
        panic)
            iptables -F; iptables -X
            iptables -P INPUT DROP; iptables -P FORWARD DROP; iptables -P OUTPUT DROP
            iptables -A INPUT  -i lo -j ACCEPT
            iptables -A OUTPUT -o lo -j ACCEPT
            printf '%s - Mode panique activé\n' "$(date '+%Y-%m-%d %H:%M:%S')" >> /var/log/fire-ux.log
            _send_redirect "/?msg=preset_applied" ;;
        flush_all)
            iptables -F; iptables -X
            iptables -P INPUT ACCEPT; iptables -P FORWARD ACCEPT; iptables -P OUTPUT ACCEPT
            printf '%s - Flush total\n' "$(date '+%Y-%m-%d %H:%M:%S')" >> /var/log/fire-ux.log
            _send_redirect "/?msg=preset_applied" ;;
        *) _send_redirect "/?msg=error_unknown_preset" ;;
    esac
}

_handle_add_rule() {
    local chain proto port src action
    chain="$(_param "$_post_body" "chain")"; proto="$(_param "$_post_body" "proto")"
    port="$(_param  "$_post_body" "port")";  src="$(_param "$_post_body" "src")"
    action="$(_param "$_post_body" "action")"
    case "$chain"  in INPUT|OUTPUT|FORWARD) ;; *) _send_redirect "/rules?msg=error_invalid_chain";  return ;; esac
    case "$proto"  in tcp|udp|icmp|all)    ;; *) _send_redirect "/rules?msg=error_invalid_proto";  return ;; esac
    case "$action" in ACCEPT|DROP|REJECT)  ;; *) _send_redirect "/rules?msg=error_invalid_action"; return ;; esac
    if [[ -n "$port" ]] && ! [[ "$port" =~ ^[0-9]{1,5}(:[0-9]{1,5})?$ ]]; then
        _send_redirect "/rules?msg=error_invalid_port"; return; fi
    if [[ -n "$src" ]] && ! [[ "$src" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}(/[0-9]{1,2})?$ ]]; then
        _send_redirect "/rules?msg=error_invalid_src"; return; fi
    local -a cmd=( iptables -A "$chain" )
    [[ "$proto" != "all" ]] && cmd+=( -p "$proto" )
    [[ -n "$port" && "$proto" != "icmp" && "$proto" != "all" ]] && cmd+=( --dport "$port" )
    [[ -n "$src" ]] && cmd+=( -s "$src" )
    cmd+=( -j "$action" )
    if "${cmd[@]}" 2>/dev/null; then
        printf '%s - Règle ajoutée : %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "${cmd[*]}" >> /var/log/fire-ux.log
        _send_redirect "/rules?msg=rule_added"
    else _send_redirect "/rules?msg=error_add_failed"; fi
}

_handle_delete_rule() {
    local num chain
    num="$(_param "$_post_body" "num")"; chain="$(_param "$_post_body" "chain")"
    case "$chain" in INPUT|OUTPUT|FORWARD) ;; *) _send_redirect "/rules?msg=error_invalid_chain"; return ;; esac
    [[ "$num" =~ ^[0-9]+$ ]] || { _send_redirect "/rules?msg=error_invalid_num"; return; }
    if iptables -D "$chain" "$num" 2>/dev/null; then
        printf '%s - Règle #%s supprimée de %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$num" "$chain" >> /var/log/fire-ux.log
        _send_redirect "/rules?msg=rule_deleted"
    else _send_redirect "/rules?msg=error_delete_failed"; fi
}

_handle_move_rule() {
    local num chain dir
    num="$(_param "$_post_body" "num")"; chain="$(_param "$_post_body" "chain")"
    dir="$(_param "$_post_body" "dir")"
    case "$chain" in INPUT|OUTPUT|FORWARD) ;; *) _send_redirect "/rules?msg=error_invalid_chain"; return ;; esac
    [[ "$num" =~ ^[0-9]+$ ]] || { _send_redirect "/rules?msg=error_invalid_num"; return; }
    case "$dir" in up|down) ;; *) _send_redirect "/rules?msg=error_invalid_dir"; return ;; esac
    local total
    total=$(iptables -L "$chain" --line-numbers -n 2>/dev/null | tail -n+3 | grep -v '^$' | wc -l)
    [ "$total" -lt 2 ] && { _send_redirect "/rules?msg=error_cannot_move"; return; }
    local new_pos
    if [ "$dir" = "up" ]; then
        [ "$num" -le 1 ] && { _send_redirect "/rules?msg=error_cannot_move"; return; }
        new_pos=$((num - 1))
    else
        [ "$num" -ge "$total" ] && { _send_redirect "/rules?msg=error_cannot_move"; return; }
        new_pos=$((num + 1))
    fi
    # Get rule spec, delete it, re-insert at new position
    local spec
    spec=$(iptables -S "$chain" 2>/dev/null | tail -n+2 | sed -n "${num}p" | sed "s/^-A $chain //" )
    [ -z "$spec" ] && { _send_redirect "/rules?msg=error_delete_failed"; return; }
    if iptables -D "$chain" "$num" 2>/dev/null; then
        local -a insert_cmd
        read -ra insert_cmd <<< "iptables -I $chain $new_pos $spec"
        if "${insert_cmd[@]}" 2>/dev/null; then
            printf '%s - Règle déplacée (%s→%s) dans %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$num" "$new_pos" "$chain" >> /var/log/fire-ux.log
            _send_redirect "/rules?msg=rule_moved"
        else
            _send_redirect "/rules?msg=error_add_failed"
        fi
    else _send_redirect "/rules?msg=error_delete_failed"; fi
}

_handle_flush() {
    local chain; chain="$(_param "$_post_body" "chain")"
    case "$chain" in
        INPUT|OUTPUT|FORWARD)
            iptables -F "$chain" 2>/dev/null||true
            printf '%s - Chaîne %s vidée\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$chain" >> /var/log/fire-ux.log
            _send_redirect "/rules?msg=chain_flushed" ;;
        all)
            iptables -F 2>/dev/null||true
            printf '%s - Toutes les chaînes vidées\n' "$(date '+%Y-%m-%d %H:%M:%S')" >> /var/log/fire-ux.log
            _send_redirect "/rules?msg=all_flushed" ;;
        *) _send_redirect "/rules?msg=error_invalid_chain" ;;
    esac
}

_handle_save_snapshot() {
    local dir="/etc/fire-ux/profiles" ts; mkdir -p "$dir"; ts="$(date +%Y%m%d%H%M%S)"
    if iptables-save > "${dir}/snapshot_${ts}" 2>/dev/null; then
        printf '%s - Snapshot : snapshot_%s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$ts" >> /var/log/fire-ux.log
        _send_redirect "/profiles?msg=snapshot_saved"
    else _send_redirect "/profiles?msg=error_snapshot_failed"; fi
}

_handle_apply_profile() {
    local name pf
    name="$(printf '%s' "$(_param "$_post_body" "name")"|tr -cd '[:alnum:]._-')"
    pf="/etc/fire-ux/profiles/${name}"
    [[ -z "$name" || ! -f "$pf" ]] && { _send_redirect "/profiles?msg=error_profile_not_found"; return; }
    if iptables-restore < "$pf" 2>/dev/null; then
        printf '%s - Profil appliqué : %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$name" >> /var/log/fire-ux.log
        _send_redirect "/profiles?msg=profile_applied"
    else _send_redirect "/profiles?msg=error_restore_failed"; fi
}

_handle_delete_profile() {
    local name pf
    name="$(printf '%s' "$(_param "$_post_body" "name")"|tr -cd '[:alnum:]._-')"
    pf="/etc/fire-ux/profiles/${name}"
    [[ -z "$name" || ! -f "$pf" ]] && { _send_redirect "/profiles?msg=error_profile_not_found"; return; }
    if rm -f "$pf" 2>/dev/null; then
        printf '%s - Profil supprimé : %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$name" >> /var/log/fire-ux.log
        _send_redirect "/profiles?msg=profile_deleted"
    else _send_redirect "/profiles?msg=error_delete_failed"; fi
}

_handle_quick_ban() {
    local ip action chain
    ip="$(_param "$_post_body" "ip")"; action="$(_param "$_post_body" "action")"
    chain="$(_param "$_post_body" "chain")"
    [[ "$ip" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}(/[0-9]{1,2})?$ ]] || { _send_redirect "/?msg=error_invalid_ip"; return; }
    case "$action" in DROP|REJECT|ACCEPT) ;; *) _send_redirect "/?msg=error_invalid_action"; return ;; esac
    case "$chain" in INPUT|OUTPUT|FORWARD) ;; *) _send_redirect "/?msg=error_invalid_chain"; return ;; esac
    if iptables -I "$chain" 1 -s "$ip" -j "$action" 2>/dev/null; then
        printf '%s - Quick-ban %s/%s → %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$ip" "$chain" "$action" >> /var/log/fire-ux.log
        _send_redirect "/?msg=rule_added"
    else _send_redirect "/?msg=error_add_failed"; fi
}

# ── API : /api/stats ──────────────────────────────────────────────────────────
_api_stats() {
    local ci co cf pi po pf upv hn ip mem_t mem_f mem_used mem_pct
    local cpu_pct ncpu load conns ts

    ci=$(iptables -L INPUT   --line-numbers -n 2>/dev/null|tail -n+3|grep -v '^$'|wc -l)
    co=$(iptables -L OUTPUT  --line-numbers -n 2>/dev/null|tail -n+3|grep -v '^$'|wc -l)
    cf=$(iptables -L FORWARD --line-numbers -n 2>/dev/null|tail -n+3|grep -v '^$'|wc -l)
    pi=$(iptables -L INPUT   2>/dev/null|head -1|awk '{print $4}'|tr -d ')')
    po=$(iptables -L OUTPUT  2>/dev/null|head -1|awk '{print $4}'|tr -d ')')
    pf=$(iptables -L FORWARD 2>/dev/null|head -1|awk '{print $4}'|tr -d ')')
    upv=$(uptime -p 2>/dev/null|sed 's/up //'||uptime|sed 's/.*up //;s/,.*//')
    hn=$(hostname 2>/dev/null||echo "host")
    ip=$(hostname -I 2>/dev/null|awk '{print $1}'||echo "")
    mem_t=$(awk '/MemTotal/{print $2}'     /proc/meminfo 2>/dev/null||echo 1)
    mem_f=$(awk '/MemAvailable/{print $2}' /proc/meminfo 2>/dev/null||echo 1)
    mem_used=$((mem_t - mem_f))
    mem_pct=$(awk "BEGIN{print int($mem_used*100/$mem_t)}")
    ncpu=$(nproc 2>/dev/null||echo 1)
    load=$(awk '{print $1}' /proc/loadavg 2>/dev/null||echo "0")
    cpu_pct=$(awk "BEGIN{v=int($load*100/$ncpu);print(v>100?100:v)}")
    conns=$(ss -tn state established 2>/dev/null|tail -n+2|wc -l||echo 0)
    ts=$(date '+%Y-%m-%d %H:%M:%S')

    _send_json "$(printf '{"rules_input":%d,"rules_output":%d,"rules_forward":%d,"policy_input":"%s","policy_output":"%s","policy_forward":"%s","server_pid":"%s","uptime":"%s","hostname":"%s","ip":"%s","mem_pct":%d,"cpu_pct":%d,"connections":%d,"load":"%s","timestamp":"%s"}' \
        "$ci" "$co" "$cf" "$pi" "$po" "$pf" "${SERVER_PID:-}" "$upv" "$hn" "$ip" "$mem_pct" "$cpu_pct" "$conns" "$load" "$ts")"
}

# ── API : /api/logs ───────────────────────────────────────────────────────────
_api_logs() {
    local n=50
    [[ "$_path" == *"n="* ]] && { n="${_path##*n=}"; n="${n%%&*}"; [[ "$n" =~ ^[0-9]+$ ]]||n=50; [ "$n" -gt 500 ]&&n=500; }
    local lines_json="[" first=true
    if [ -f "${_LOG_FILE}" ]; then
        while IFS= read -r l; do
            local s; s=$(printf '%s' "$l"|sed 's/\\/\\\\/g;s/"/\\"/g;s/	/ /g')
            $first||lines_json+=","
            lines_json+="\"${s}\""
            first=false
        done < <(tail -n "${n}" "${_LOG_FILE}")
    fi
    lines_json+="]"
    _send_json "{\"lines\":${lines_json},\"count\":$([ -f "${_LOG_FILE}" ]&&wc -l<"${_LOG_FILE}"||echo 0)}"
}

# ── API : /api/health ─────────────────────────────────────────────────────────
_api_health() {
    local pi po ri has_est has_ssh warns='[]'
    pi=$(iptables -L INPUT  2>/dev/null|head -1|awk '{print $4}'|tr -d ')')
    po=$(iptables -L OUTPUT 2>/dev/null|head -1|awk '{print $4}'|tr -d ')')
    ri=$(iptables -L INPUT --line-numbers -n 2>/dev/null|tail -n+3|grep -v '^$'|wc -l)
    has_est=$(iptables -L INPUT -n 2>/dev/null|grep -c "ESTABLISHED"||echo 0)
    has_ssh=$(iptables -L INPUT -n 2>/dev/null|grep -c "dpt:22"||echo 0)

    local w=() a=()
    [ "$pi" = "ACCEPT" ] && [ "$ri" -eq 0 ] && \
        w+=('{"level":"info","msg":"Aucun filtrage INPUT actif"}')
    { [ "$pi" = "DROP" ] || [ "$pi" = "REJECT" ]; } && [ "${has_est:-0}" -eq 0 ] && \
        w+=('{"level":"danger","msg":"INPUT DROP sans règle ESTABLISHED"}')
    { [ "$pi" = "DROP" ] || [ "$pi" = "REJECT" ]; } && [ "${has_ssh:-0}" -eq 0 ] && \
        w+=('{"level":"danger","msg":"INPUT DROP sans règle SSH (port 22)"}')
    { [ "$po" = "DROP" ] || [ "$po" = "REJECT" ]; } && \
        w+=('{"level":"warning","msg":"Politique OUTPUT DROP active"}')

    local json='['; local first=true
    for ww in "${w[@]}"; do $first||json+=","; json+="$ww"; first=false; done
    json+=']'
    _send_json "{\"warnings\":${json},\"count\":${#w[@]}}"
}

# ── Export iptables-save ──────────────────────────────────────────────────────
_handle_export() {
    local ts body len
    ts=$(date '+%Y%m%d_%H%M%S')
    body=$(iptables-save 2>/dev/null || printf '# iptables-save: erreur\n')
    len=$(printf '%s' "$body"|wc -c)
    printf "HTTP/1.1 200 OK\r\n"
    printf "Content-Type: text/plain; charset=utf-8\r\n"
    printf "Content-Length: %d\r\n" "$len"
    printf "Content-Disposition: attachment; filename=\"iptables_%s.rules\"\r\n" "$ts"
    printf "Connection: close\r\n\r\n"
    printf "%s" "$body"
}

# ── Routing ───────────────────────────────────────────────────────────────────
_clean_path="${_path%%\?*}"
QUERY_STRING="$( [[ "$_path" == *"?"* ]] && printf '%s' "${_path#*\?}" || true )"

case "${_method}|${_clean_path}" in
    "GET|/")              _send_html "$(page_dashboard)" ;;
    "GET|/rules")         _send_html "$(page_rules)"     ;;
    "GET|/logs")          _send_html "$(page_logs)"      ;;
    "GET|/profiles")      _send_html "$(page_profiles)"  ;;
    "GET|/network")       _send_html "$(page_network)"   ;;
    "GET|/settings")      _send_html "$(page_settings)"  ;;
    "GET|/api/stats")     _api_stats   ;;
    "GET|/api/logs")      _api_logs    ;;
    "GET|/api/health")    _api_health  ;;
    "GET|/export")        _handle_export ;;
    "GET|/favicon.ico")   printf "HTTP/1.1 204 No Content\r\nConnection: close\r\n\r\n" ;;
    "POST|/apply-preset")   _handle_apply_preset   ;;
    "POST|/add-rule")       _handle_add_rule        ;;
    "POST|/delete-rule")    _handle_delete_rule     ;;
    "POST|/move-rule")      _handle_move_rule       ;;
    "POST|/flush")          _handle_flush           ;;
    "POST|/save-snapshot")  _handle_save_snapshot   ;;
    "POST|/apply-profile")  _handle_apply_profile   ;;
    "POST|/delete-profile") _handle_delete_profile  ;;
    "POST|/quick-ban")      _handle_quick_ban       ;;
    *)                      _send_404 ;;
esac
