#!/bin/bash
# =============================================================================
# Nom         : web-ui.sh
# Description : Générateur HTML pour l'interface web Fire-UX.
#               Toutes les fonctions produisent du HTML sur stdout.
#               Ce fichier est sourcé par web-server.sh, pas exécuté
#               directement.
# Auteur      : Fire-UX Contributors
# Version     : 1.0.0
# =============================================================================

# ─── Constantes partagées ────────────────────────────────────────────────────
_LOG_FILE="/var/log/fire-ux.log"
_PROFILES_DIR="/etc/fire-ux/profiles"
_VERSION="1.0.0"

# =============================================================================
# html_header — Génère le <head> complet avec CSS embarqué et barre de nav
# Paramètre $1 : titre de la page
# =============================================================================
html_header() {
    local title="${1:-Fire-UX Web}"
    local now
    now=$(date '+%Y-%m-%d %H:%M:%S')

    cat <<HTML
<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta http-equiv="refresh" content="30">
<title>${title} — Fire-UX</title>
<style>
/* ── Variables globales ──────────────────────────────────────────────────── */
:root {
  --bg:        #0d1117;
  --bg2:       #161b22;
  --bg3:       #21262d;
  --border:    #30363d;
  --text:      #e6edf3;
  --muted:     #8b949e;
  --accent:    #f78166;
  --accent2:   #ffa657;
  --green:     #3fb950;
  --red:       #f85149;
  --yellow:    #d29922;
  --blue:      #58a6ff;
  --radius:    6px;
  --font-mono: 'SFMono-Regular', Consolas, 'Liberation Mono', Menlo, monospace;
  --font-sans: -apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif;
}

/* ── Reset & base ────────────────────────────────────────────────────────── */
*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
html { font-size: 15px; }
body {
  background: var(--bg);
  color: var(--text);
  font-family: var(--font-sans);
  line-height: 1.6;
  min-height: 100vh;
  display: flex;
  flex-direction: column;
}

/* ── Barre de navigation ─────────────────────────────────────────────────── */
nav {
  background: var(--bg2);
  border-bottom: 1px solid var(--border);
  padding: 0 1.5rem;
  display: flex;
  align-items: center;
  gap: 1rem;
  flex-wrap: wrap;
  position: sticky;
  top: 0;
  z-index: 100;
}
.nav-logo {
  font-family: var(--font-mono);
  font-weight: 700;
  font-size: 1.1rem;
  color: var(--accent);
  padding: 0.75rem 0;
  text-decoration: none;
  letter-spacing: 0.05em;
}
.nav-logo span { color: var(--accent2); }
.nav-links {
  display: flex;
  gap: 0.25rem;
  flex: 1;
  flex-wrap: wrap;
}
.nav-links a {
  color: var(--muted);
  text-decoration: none;
  padding: 0.5rem 0.75rem;
  border-radius: var(--radius);
  font-size: 0.9rem;
  transition: color 0.15s, background 0.15s;
}
.nav-links a:hover, .nav-links a.active {
  color: var(--text);
  background: var(--bg3);
}
.nav-time {
  font-family: var(--font-mono);
  font-size: 0.78rem;
  color: var(--muted);
  padding: 0.5rem 0;
}

/* ── Contenu principal ───────────────────────────────────────────────────── */
main {
  flex: 1;
  padding: 1.5rem;
  max-width: 1200px;
  width: 100%;
  margin: 0 auto;
}

/* ── Cartes ──────────────────────────────────────────────────────────────── */
.card {
  background: var(--bg2);
  border: 1px solid var(--border);
  border-radius: var(--radius);
  padding: 1.25rem 1.5rem;
  margin-bottom: 1rem;
}
.card h2 {
  font-size: 1rem;
  font-weight: 600;
  color: var(--text);
  margin-bottom: 1rem;
  padding-bottom: 0.5rem;
  border-bottom: 1px solid var(--border);
}
.card h3 {
  font-size: 0.9rem;
  font-weight: 600;
  color: var(--accent2);
  margin: 1rem 0 0.5rem;
}

/* ── Grille de cartes ────────────────────────────────────────────────────── */
.grid-2 {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
  gap: 1rem;
}

/* ── Statistiques ────────────────────────────────────────────────────────── */
.stat-row {
  display: flex;
  gap: 1rem;
  flex-wrap: wrap;
  margin-bottom: 0.75rem;
}
.stat-item {
  display: flex;
  flex-direction: column;
  gap: 0.2rem;
}
.stat-label {
  font-size: 0.75rem;
  color: var(--muted);
  text-transform: uppercase;
  letter-spacing: 0.05em;
}
.stat-value {
  font-family: var(--font-mono);
  font-size: 1.4rem;
  font-weight: 700;
  color: var(--accent);
}
.stat-value.green { color: var(--green); }
.stat-value.red   { color: var(--red); }
.stat-value.blue  { color: var(--blue); }

/* ── Tableaux ────────────────────────────────────────────────────────────── */
.table-wrap { overflow-x: auto; }
table {
  width: 100%;
  border-collapse: collapse;
  font-size: 0.85rem;
  font-family: var(--font-mono);
}
thead tr {
  background: var(--bg3);
  border-bottom: 2px solid var(--border);
}
th {
  text-align: left;
  padding: 0.5rem 0.75rem;
  color: var(--muted);
  font-weight: 600;
  font-size: 0.78rem;
  text-transform: uppercase;
  letter-spacing: 0.05em;
}
tbody tr {
  border-bottom: 1px solid var(--border);
  transition: background 0.1s;
}
tbody tr:hover { background: var(--bg3); }
td { padding: 0.5rem 0.75rem; vertical-align: top; word-break: break-all; }

/* ── Badges de statut ────────────────────────────────────────────────────── */
.badge {
  display: inline-block;
  padding: 0.15em 0.55em;
  border-radius: 3px;
  font-size: 0.75rem;
  font-weight: 600;
  letter-spacing: 0.03em;
  font-family: var(--font-mono);
}
.badge-green  { background: rgba(63,185,80,.18); color: var(--green); }
.badge-red    { background: rgba(248,81,73,.18);  color: var(--red); }
.badge-yellow { background: rgba(210,153,34,.18); color: var(--yellow); }
.badge-blue   { background: rgba(88,166,255,.18); color: var(--blue); }
.badge-gray   { background: var(--bg3); color: var(--muted); }

/* ── Boutons ─────────────────────────────────────────────────────────────── */
.btn {
  display: inline-block;
  padding: 0.4rem 0.9rem;
  border-radius: var(--radius);
  font-size: 0.85rem;
  font-weight: 500;
  cursor: pointer;
  text-decoration: none;
  border: 1px solid transparent;
  transition: opacity 0.15s, transform 0.1s;
}
.btn:hover { opacity: 0.85; transform: translateY(-1px); }
.btn:active { transform: translateY(0); }
.btn-primary   { background: var(--accent);  color: #0d1117; border-color: var(--accent); }
.btn-secondary { background: var(--bg3);     color: var(--text); border-color: var(--border); }
.btn-danger    { background: rgba(248,81,73,.2); color: var(--red); border-color: var(--red); }
.btn-warning   { background: rgba(210,153,34,.2); color: var(--yellow); border-color: var(--yellow); }
.btn-success   { background: rgba(63,185,80,.2); color: var(--green); border-color: var(--green); }
.btn-sm { padding: 0.25rem 0.6rem; font-size: 0.78rem; }

/* ── Groupe de boutons d'action rapide ───────────────────────────────────── */
.action-bar {
  display: flex;
  gap: 0.5rem;
  flex-wrap: wrap;
  margin-top: 1rem;
}

/* ── Formulaires ─────────────────────────────────────────────────────────── */
.form-row {
  display: flex;
  gap: 0.75rem;
  flex-wrap: wrap;
  align-items: flex-end;
  margin-bottom: 0.75rem;
}
.form-group {
  display: flex;
  flex-direction: column;
  gap: 0.3rem;
}
label {
  font-size: 0.78rem;
  color: var(--muted);
  text-transform: uppercase;
  letter-spacing: 0.04em;
}
input[type="text"], input[type="number"], select {
  background: var(--bg3);
  border: 1px solid var(--border);
  border-radius: var(--radius);
  color: var(--text);
  padding: 0.4rem 0.65rem;
  font-family: var(--font-mono);
  font-size: 0.85rem;
  outline: none;
  transition: border-color 0.15s;
  min-width: 100px;
}
input:focus, select:focus { border-color: var(--accent); }
select option { background: var(--bg2); }

/* ── Bloc de log ─────────────────────────────────────────────────────────── */
.log-block {
  background: var(--bg);
  border: 1px solid var(--border);
  border-radius: var(--radius);
  padding: 1rem;
  font-family: var(--font-mono);
  font-size: 0.8rem;
  overflow-x: auto;
  max-height: 600px;
  overflow-y: auto;
}
.log-line { padding: 0.1rem 0; border-bottom: 1px solid rgba(48,54,61,.4); }
.log-line:last-child { border-bottom: none; }
.log-accept { color: var(--green); }
.log-drop   { color: var(--red); }
.log-error  { color: var(--yellow); }
.log-info   { color: var(--muted); }

/* ── Ports en écoute ─────────────────────────────────────────────────────── */
.port-list { display: flex; flex-wrap: wrap; gap: 0.4rem; margin-top: 0.5rem; }
.port-item {
  font-family: var(--font-mono);
  font-size: 0.8rem;
  padding: 0.2rem 0.5rem;
  border-radius: 3px;
  border: 1px solid var(--border);
}
.port-open   { border-color: var(--green); color: var(--green); }
.port-closed { border-color: var(--border); color: var(--muted); }

/* ── Barre de statut pied de page ────────────────────────────────────────── */
footer {
  background: var(--bg2);
  border-top: 1px solid var(--border);
  padding: 0.5rem 1.5rem;
  display: flex;
  justify-content: space-between;
  align-items: center;
  font-size: 0.75rem;
  color: var(--muted);
  font-family: var(--font-mono);
  flex-wrap: wrap;
  gap: 0.5rem;
}
footer span { display: flex; align-items: center; gap: 0.5rem; }
.dot {
  width: 6px; height: 6px;
  border-radius: 50%;
  background: var(--green);
  display: inline-block;
}

/* ── Bannière de message flash ───────────────────────────────────────────── */
.flash {
  padding: 0.6rem 1rem;
  border-radius: var(--radius);
  margin-bottom: 1rem;
  font-size: 0.85rem;
}
.flash-ok  { background: rgba(63,185,80,.15); border: 1px solid var(--green); color: var(--green); }
.flash-err { background: rgba(248,81,73,.15); border: 1px solid var(--red);   color: var(--red); }

/* ── Responsive ──────────────────────────────────────────────────────────── */
@media (max-width: 640px) {
  main { padding: 1rem 0.75rem; }
  .stat-value { font-size: 1.1rem; }
  nav { padding: 0 0.75rem; }
  table { font-size: 0.75rem; }
}
</style>
</head>
<body>
<nav>
  <a class="nav-logo" href="/"><span>&#x1F525;</span> Fire-UX</a>
  <div class="nav-links">
    <a href="/">Tableau de bord</a>
    <a href="/rules">Règles</a>
    <a href="/logs">Journaux</a>
    <a href="/profiles">Profils</a>
  </div>
  <span class="nav-time">${now}</span>
</nav>
<main>
HTML
}

# =============================================================================
# html_footer — Génère le pied de page et ferme les balises HTML
# =============================================================================
html_footer() {
    local ver="${_VERSION}"
    local pid="${SERVER_PID:-—}"
    local uptime_val
    uptime_val=$(uptime -p 2>/dev/null || uptime | sed 's/.*up //' | sed 's/,.*//')

    cat <<HTML
</main>
<footer>
  <span><span class="dot"></span> Fire-UX Web Interface v${ver}</span>
  <span>PID serveur : ${pid} &nbsp;·&nbsp; Uptime : ${uptime_val}</span>
</footer>
</body>
</html>
HTML
}

# =============================================================================
# _flash_message — Génère une bannière flash selon le paramètre msg de l'URL
# Paramètre $1 : valeur brute du paramètre ?msg=
# =============================================================================
_flash_message() {
    local msg="$1"
    case "${msg}" in
        preset_applied)     printf '<div class="flash flash-ok">✓ Preset appliqué avec succès.</div>' ;;
        rule_added)         printf '<div class="flash flash-ok">✓ Règle ajoutée avec succès.</div>' ;;
        rule_deleted)       printf '<div class="flash flash-ok">✓ Règle supprimée.</div>' ;;
        chain_flushed)      printf '<div class="flash flash-ok">✓ Chaîne vidée.</div>' ;;
        all_flushed)        printf '<div class="flash flash-ok">✓ Toutes les chaînes ont été vidées.</div>' ;;
        snapshot_saved)     printf '<div class="flash flash-ok">✓ Snapshot sauvegardé dans les profils.</div>' ;;
        profile_applied)    printf '<div class="flash flash-ok">✓ Profil appliqué avec succès.</div>' ;;
        error_*)            printf '<div class="flash flash-err">✗ Erreur : %s</div>' "${msg#error_}" ;;
    esac
}

# =============================================================================
# page_dashboard — Tableau de bord principal
# =============================================================================
page_dashboard() {
    local hostname_val ip_val cnt_in cnt_out cnt_fwd pol_in pol_out pol_fwd

    hostname_val=$(hostname 2>/dev/null || echo "inconnu")
    ip_val=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "—")
    uptime_val=$(uptime -p 2>/dev/null || uptime | sed 's/.*up //' | sed 's/,.*//')

    pol_in=$(iptables  -L INPUT   2>/dev/null | head -n1 | awk '{print $4}')
    pol_out=$(iptables -L OUTPUT  2>/dev/null | head -n1 | awk '{print $4}')
    pol_fwd=$(iptables -L FORWARD 2>/dev/null | head -n1 | awk '{print $4}')

    cnt_in=$(iptables  -L INPUT   --line-numbers -n 2>/dev/null | tail -n +3 | grep -c "." 2>/dev/null || echo 0)
    cnt_out=$(iptables -L OUTPUT  --line-numbers -n 2>/dev/null | tail -n +3 | grep -c "." 2>/dev/null || echo 0)
    cnt_fwd=$(iptables -L FORWARD --line-numbers -n 2>/dev/null | tail -n +3 | grep -c "." 2>/dev/null || echo 0)

    # Couleur d'un badge de politique
    _pol_badge() {
        case "$1" in
            ACCEPT) printf '<span class="badge badge-green">%s</span>' "$1" ;;
            DROP|REJECT) printf '<span class="badge badge-red">%s</span>' "$1" ;;
            *) printf '<span class="badge badge-gray">%s</span>' "${1:-?}" ;;
        esac
    }

    html_header "Tableau de bord"

    cat <<HTML
<div class="grid-2">

  <!-- Carte : Statut système -->
  <div class="card">
    <h2>Statut système</h2>
    <div class="stat-row">
      <div class="stat-item">
        <span class="stat-label">Hôte</span>
        <span class="stat-value blue">${hostname_val}</span>
      </div>
      <div class="stat-item">
        <span class="stat-label">IP principale</span>
        <span class="stat-value">${ip_val}</span>
      </div>
    </div>
    <div class="stat-row">
      <div class="stat-item">
        <span class="stat-label">Uptime</span>
        <span class="stat-value green">${uptime_val}</span>
      </div>
    </div>
    <h3>Politiques par défaut</h3>
    <div class="stat-row">
      <div class="stat-item">
        <span class="stat-label">INPUT</span>
        $(_pol_badge "${pol_in}")
      </div>
      <div class="stat-item">
        <span class="stat-label">OUTPUT</span>
        $(_pol_badge "${pol_out}")
      </div>
      <div class="stat-item">
        <span class="stat-label">FORWARD</span>
        $(_pol_badge "${pol_fwd}")
      </div>
    </div>
    <h3>Règles actives</h3>
    <div class="stat-row">
      <div class="stat-item">
        <span class="stat-label">INPUT</span>
        <span class="stat-value">${cnt_in}</span>
      </div>
      <div class="stat-item">
        <span class="stat-label">OUTPUT</span>
        <span class="stat-value">${cnt_out}</span>
      </div>
      <div class="stat-item">
        <span class="stat-label">FORWARD</span>
        <span class="stat-value">${cnt_fwd}</span>
      </div>
    </div>
  </div>

  <!-- Carte : Services détectés -->
  <div class="card">
    <h2>Services détectés</h2>
$(
    local ports_data
    ports_data=$(ss -tlnp 2>/dev/null || netstat -tlnp 2>/dev/null || echo "")
    echo '    <div class="port-list">'
    while IFS= read -r pline; do
        local port_num proto_label
        port_num=$(echo "${pline}" | awk '{print $4}' | rev | cut -d: -f1 | rev)
        [[ "${port_num}" =~ ^[0-9]+$ ]] || continue
        local svc_name
        case "${port_num}" in
            22)    svc_name="SSH (22)" ;;
            80)    svc_name="HTTP (80)" ;;
            443)   svc_name="HTTPS (443)" ;;
            25)    svc_name="SMTP (25)" ;;
            587)   svc_name="SMTP (587)" ;;
            993)   svc_name="IMAPS (993)" ;;
            3306)  svc_name="MySQL (3306)" ;;
            5432)  svc_name="PostgreSQL (5432)" ;;
            6379)  svc_name="Redis (6379)" ;;
            8080)  svc_name="HTTP-alt (8080)" ;;
            51820) svc_name="WireGuard (51820)" ;;
            *)     svc_name="port ${port_num}" ;;
        esac
        local in_ipt
        in_ipt=$(iptables -L INPUT -n 2>/dev/null | grep "dpt:${port_num}" | grep -c "ACCEPT" 2>/dev/null || echo 0)
        if [ "${in_ipt}" -gt 0 ]; then
            printf '      <span class="port-item port-open" title="ACCEPT dans iptables">%s ✓</span>\n' "${svc_name}"
        else
            printf '      <span class="port-item port-closed" title="Aucune règle ACCEPT trouvée">%s</span>\n' "${svc_name}"
        fi
    done < <(echo "${ports_data}" | grep "LISTEN" | grep -v "^Netid" || true)
    echo '    </div>'
)
  </div>

</div>

<!-- Carte : Activité récente -->
<div class="card">
  <h2>Activité récente
    <a href="/logs" class="btn btn-secondary btn-sm" style="float:right">Voir tout →</a>
  </h2>
  <div class="log-block">
$(
    if [ -f "${_LOG_FILE}" ]; then
        tail -n 10 "${_LOG_FILE}" | while IFS= read -r logline; do
            if echo "${logline}" | grep -qi "accept"; then
                printf '    <div class="log-line log-accept">%s</div>\n' "${logline}"
            elif echo "${logline}" | grep -qi "drop\|reject\|denied"; then
                printf '    <div class="log-line log-drop">%s</div>\n' "${logline}"
            elif echo "${logline}" | grep -qi "error\|fail\|erreur"; then
                printf '    <div class="log-line log-error">%s</div>\n' "${logline}"
            else
                printf '    <div class="log-line log-info">%s</div>\n' "${logline}"
            fi
        done
    else
        echo '    <div class="log-line log-info">Aucune entrée de journal disponible.</div>'
    fi
)
  </div>
</div>

<!-- Carte : Actions rapides -->
<div class="card">
  <h2>Actions rapides</h2>
  <div class="action-bar">
    <form method="POST" action="/apply-preset" style="display:inline">
      <input type="hidden" name="preset" value="web">
      <button class="btn btn-secondary" type="submit">Preset Web (HTTP+HTTPS+SSH)</button>
    </form>
    <form method="POST" action="/apply-preset" style="display:inline">
      <input type="hidden" name="preset" value="ssh">
      <button class="btn btn-secondary" type="submit">Preset SSH uniquement</button>
    </form>
    <form method="POST" action="/apply-preset" style="display:inline" onsubmit="return confirm('Activer le mode panique ? Tout le trafic externe sera bloqué.')">
      <input type="hidden" name="preset" value="panic">
      <button class="btn btn-danger" type="submit">&#x26A0; Mode Panique</button>
    </form>
    <form method="POST" action="/apply-preset" style="display:inline" onsubmit="return confirm('Vider toutes les règles et tout accepter ?')">
      <input type="hidden" name="preset" value="flush_all">
      <button class="btn btn-warning" type="submit">Flush All + ACCEPT</button>
    </form>
    <a href="/rules" class="btn btn-primary">Gérer les règles →</a>
  </div>
</div>
HTML

    html_footer
}

# =============================================================================
# page_rules — Liste et gestion des règles iptables
# =============================================================================
page_rules() {
    # Récupération du message flash depuis la variable d'environnement QUERY_STRING
    local flash_msg="${QUERY_STRING:-}"
    flash_msg=$(printf '%s' "${flash_msg}" | grep -oE 'msg=[^&]*' | cut -d= -f2)

    html_header "Règles iptables"

    [ -n "${flash_msg}" ] && _flash_message "${flash_msg}"

    # Rendu d'un tableau de règles pour une chaîne donnée
    _chain_table() {
        local chain="$1"
        local rules_raw
        rules_raw=$(iptables -L "${chain}" --line-numbers -n 2>/dev/null || true)

        cat <<HTML
<div class="card">
  <h2>Chaîne ${chain}
    <form method="POST" action="/flush" style="display:inline;float:right">
      <input type="hidden" name="chain" value="${chain}">
      <button class="btn btn-danger btn-sm" type="submit"
        onclick="return confirm('Vider la chaîne ${chain} ?')">Vider la chaîne</button>
    </form>
  </h2>
  <div class="table-wrap">
  <table>
    <thead><tr>
      <th>#</th><th>Cible</th><th>Proto</th><th>Source</th>
      <th>Destination</th><th>Options</th><th>Action</th>
    </tr></thead>
    <tbody>
HTML
        local lineno=0
        while IFS= read -r line; do
            lineno=$((lineno + 1))
            [ "${lineno}" -le 2 ] && continue
            [ -z "${line}" ] && continue
            local num tgt proto src dst opts
            num=$(echo "${line}"  | awk '{print $1}')
            tgt=$(echo "${line}"  | awk '{print $2}')
            proto=$(echo "${line}"| awk '{print $3}')
            src=$(echo "${line}"  | awk '{print $4}')
            dst=$(echo "${line}"  | awk '{print $5}')
            opts=$(echo "${line}" | awk '{$1=$2=$3=$4=$5=""; print $0}' | sed 's/^ *//')

            local tgt_badge
            case "${tgt}" in
                ACCEPT) tgt_badge='<span class="badge badge-green">ACCEPT</span>' ;;
                DROP)   tgt_badge='<span class="badge badge-red">DROP</span>' ;;
                REJECT) tgt_badge='<span class="badge badge-red">REJECT</span>' ;;
                *)      tgt_badge="<span class=\"badge badge-gray\">${tgt}</span>" ;;
            esac

            cat <<HTML
    <tr>
      <td>${num}</td>
      <td>${tgt_badge}</td>
      <td>${proto}</td>
      <td>${src}</td>
      <td>${dst}</td>
      <td>${opts}</td>
      <td>
        <form method="POST" action="/delete-rule" style="display:inline">
          <input type="hidden" name="num"   value="${num}">
          <input type="hidden" name="chain" value="${chain}">
          <button class="btn btn-danger btn-sm" type="submit"
            onclick="return confirm('Supprimer la règle #${num} de ${chain} ?')">✕</button>
        </form>
      </td>
    </tr>
HTML
        done <<< "${rules_raw}"

        cat <<HTML
    </tbody>
  </table>
  </div>
</div>
HTML
    }

    for ch in INPUT OUTPUT FORWARD; do
        _chain_table "${ch}"
    done

    # Formulaire d'ajout de règle
    cat <<HTML
<div class="card">
  <h2>Ajouter une règle</h2>
  <form method="POST" action="/add-rule">
    <div class="form-row">
      <div class="form-group">
        <label for="r-chain">Chaîne</label>
        <select id="r-chain" name="chain">
          <option value="INPUT">INPUT</option>
          <option value="OUTPUT">OUTPUT</option>
          <option value="FORWARD">FORWARD</option>
        </select>
      </div>
      <div class="form-group">
        <label for="r-proto">Protocole</label>
        <select id="r-proto" name="proto">
          <option value="tcp">TCP</option>
          <option value="udp">UDP</option>
          <option value="icmp">ICMP</option>
          <option value="all">Tous</option>
        </select>
      </div>
      <div class="form-group">
        <label for="r-port">Port (vide = tous)</label>
        <input type="text" id="r-port" name="port" placeholder="ex: 80 ou 8000:8080" style="width:160px">
      </div>
      <div class="form-group">
        <label for="r-src">IP source (vide = toutes)</label>
        <input type="text" id="r-src" name="src" placeholder="ex: 192.168.1.0/24" style="width:180px">
      </div>
      <div class="form-group">
        <label for="r-action">Action</label>
        <select id="r-action" name="action">
          <option value="ACCEPT">ACCEPT</option>
          <option value="DROP">DROP</option>
          <option value="REJECT">REJECT</option>
        </select>
      </div>
      <div class="form-group">
        <label>&nbsp;</label>
        <button class="btn btn-primary" type="submit">Ajouter la règle</button>
      </div>
    </div>
  </form>
</div>
HTML

    html_footer
}

# =============================================================================
# page_logs — Affichage des 50 dernières lignes du journal
# =============================================================================
page_logs() {
    html_header "Journaux"

    cat <<HTML
<div class="card">
  <h2>Journal Fire-UX — 50 dernières entrées
    <a href="/logs" class="btn btn-secondary btn-sm" style="float:right">&#x21BB; Rafraîchir</a>
  </h2>
  <div class="log-block">
HTML

    if [ -f "${_LOG_FILE}" ]; then
        tail -n 50 "${_LOG_FILE}" | while IFS= read -r logline; do
            # Échappement des caractères HTML
            local safe_line
            safe_line=$(printf '%s' "${logline}" \
                | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
            if echo "${safe_line}" | grep -qi "accept"; then
                printf '    <div class="log-line log-accept">%s</div>\n' "${safe_line}"
            elif echo "${safe_line}" | grep -qi "drop\|reject\|denied"; then
                printf '    <div class="log-line log-drop">%s</div>\n' "${safe_line}"
            elif echo "${safe_line}" | grep -qi "error\|fail\|erreur"; then
                printf '    <div class="log-line log-error">%s</div>\n' "${safe_line}"
            else
                printf '    <div class="log-line log-info">%s</div>\n' "${safe_line}"
            fi
        done
    else
        echo '    <div class="log-line log-info">Fichier journal introuvable : '"${_LOG_FILE}"'</div>'
    fi

    cat <<HTML
  </div>
</div>
HTML

    html_footer
}

# =============================================================================
# page_profiles — Gestion des profils de règles sauvegardés
# =============================================================================
page_profiles() {
    local flash_msg="${QUERY_STRING:-}"
    flash_msg=$(printf '%s' "${flash_msg}" | grep -oE 'msg=[^&]*' | cut -d= -f2)

    html_header "Profils"

    [ -n "${flash_msg}" ] && _flash_message "${flash_msg}"

    cat <<HTML
<div class="card">
  <h2>Profils sauvegardés
    <form method="POST" action="/save-snapshot" style="display:inline;float:right">
      <button class="btn btn-success btn-sm" type="submit">&#x1F4BE; Snapshot actuel</button>
    </form>
  </h2>
HTML

    if [ -d "${_PROFILES_DIR}" ] && [ -n "$(ls -A "${_PROFILES_DIR}" 2>/dev/null)" ]; then
        echo '  <div class="table-wrap"><table>'
        echo '    <thead><tr><th>Nom</th><th>Date</th><th>Taille</th><th>Aperçu</th><th>Action</th></tr></thead>'
        echo '    <tbody>'

        for pf in "${_PROFILES_DIR}"/*; do
            [ -f "${pf}" ] || continue
            local pname pdate psize ppreview
            pname=$(basename "${pf}")
            pdate=$(date -r "${pf}" '+%Y-%m-%d %H:%M' 2>/dev/null || stat -c '%y' "${pf}" 2>/dev/null | cut -d. -f1)
            psize=$(du -sh "${pf}" 2>/dev/null | awk '{print $1}')
            ppreview=$(head -n 3 "${pf}" 2>/dev/null | tr '\n' ' ' \
                | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')

            cat <<HTML
    <tr>
      <td><code>${pname}</code></td>
      <td>${pdate}</td>
      <td>${psize}</td>
      <td style="max-width:300px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;font-size:0.75rem;color:var(--muted)">${ppreview}</td>
      <td>
        <form method="POST" action="/apply-profile" style="display:inline">
          <input type="hidden" name="name" value="${pname}">
          <button class="btn btn-warning btn-sm" type="submit"
            onclick="return confirm('Appliquer le profil ${pname} ? Les règles actuelles seront remplacées.')">
            Appliquer
          </button>
        </form>
      </td>
    </tr>
HTML
        done

        echo '    </tbody></table></div>'
    else
        echo '  <p style="color:var(--muted);font-size:0.9rem">Aucun profil sauvegardé. Utilisez le bouton « Snapshot actuel » pour en créer un.</p>'
    fi

    echo '</div>'

    # Aide contextuelle
    cat <<HTML
<div class="card">
  <h2>Comment utiliser les profils ?</h2>
  <ul style="color:var(--muted);font-size:0.9rem;line-height:1.8;padding-left:1.2rem">
    <li><strong style="color:var(--text)">Snapshot actuel</strong> — Sauvegarde l'état courant des règles iptables sous un nouveau profil horodaté.</li>
    <li><strong style="color:var(--text)">Appliquer</strong> — Restaure les règles iptables telles qu'elles étaient lors de la création du profil (<code>iptables-restore</code>).</li>
    <li>Les profils sont stockés dans <code>${_PROFILES_DIR}/</code>.</li>
  </ul>
</div>
HTML

    html_footer
}
