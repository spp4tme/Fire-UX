#!/bin/bash
# =============================================================================
# web-ui.sh v2.1 — Fire-UX Web UI Generator
# =============================================================================

_LOG_FILE="/var/log/fire-ux.log"
_PROFILES_DIR="/etc/fire-ux/profiles"
_VERSION="2.1.0"

# ── Helpers ───────────────────────────────────────────────────────────────────
_nav_class() { [ "$1" = "$2" ] && printf ' active' || true; }

_pol_badge() {
    case "$1" in
        ACCEPT) printf '<span class="badge ba">ACCEPT</span>' ;;
        DROP)   printf '<span class="badge bd">DROP</span>'   ;;
        REJECT) printf '<span class="badge br">REJECT</span>' ;;
        *)      printf '<span class="badge bg">%s</span>' "${1:-?}" ;;
    esac
}
_tgt_badge() {
    case "$1" in
        ACCEPT) printf '<span class="badge ba">ACCEPT</span>' ;;
        DROP)   printf '<span class="badge bd">DROP</span>'   ;;
        REJECT) printf '<span class="badge br">REJECT</span>' ;;
        *)      printf '<span class="badge bg">%s</span>' "$1" ;;
    esac
}
_flash_msg() {
    case "$1" in
        preset_applied)  echo '<div class="flash ok">✓ Preset appliqué.</div>' ;;
        rule_added)      echo '<div class="flash ok">✓ Règle ajoutée.</div>' ;;
        rule_deleted)    echo '<div class="flash ok">✓ Règle supprimée.</div>' ;;
        rule_moved)      echo '<div class="flash ok">✓ Règle déplacée.</div>' ;;
        chain_flushed)   echo '<div class="flash ok">✓ Chaîne vidée.</div>' ;;
        all_flushed)     echo '<div class="flash ok">✓ Toutes les chaînes vidées.</div>' ;;
        snapshot_saved)  echo '<div class="flash ok">✓ Snapshot créé.</div>' ;;
        profile_applied) echo '<div class="flash ok">✓ Profil appliqué.</div>' ;;
        profile_deleted) echo '<div class="flash ok">✓ Profil supprimé.</div>' ;;
        logs_cleared)    echo '<div class="flash ok">✓ Journaux vidés.</div>' ;;
        chain_created)   echo '<div class="flash ok">✓ Chaîne créée.</div>' ;;
        chain_deleted)   echo '<div class="flash ok">✓ Chaîne supprimée.</div>' ;;
        settings_saved)  echo '<div class="flash ok">✓ Paramètres sauvegardés.</div>' ;;
        error_cannot_move) echo '<div class="flash err">✗ Impossible de déplacer (déjà en position limite).</div>' ;;
        error_builtin_chain) echo '<div class="flash err">✗ Impossible de modifier une chaîne intégrée.</div>' ;;
        error_chain_exists)  echo '<div class="flash err">✗ Cette chaîne existe déjà.</div>' ;;
        error_chain_in_use)  echo '<div class="flash err">✗ Chaîne encore référencée — videz-la d'\''abord.</div>' ;;
        error_*)         printf '<div class="flash err">✗ Erreur : %s</div>\n' "${1#error_}" ;;
    esac
}

# Security warnings — returns HTML for any dangerous config
_sec_warnings() {
    local pi po ri has_est has_ssh out=""
    pi=$(iptables -L INPUT  2>/dev/null|head -1|awk '{print $4}'|tr -d ')')
    po=$(iptables -L OUTPUT 2>/dev/null|head -1|awk '{print $4}'|tr -d ')')
    ri=$(iptables -L INPUT  --line-numbers -n 2>/dev/null|tail -n+3|grep -v '^$'|wc -l)
    has_est=$(iptables -L INPUT -n 2>/dev/null|grep -c "ESTABLISHED"||echo 0)
    has_ssh=$(iptables -L INPUT -n 2>/dev/null|grep -c "dpt:22"||echo 0)

    [ "$pi" = "ACCEPT" ] && [ "$ri" -eq 0 ] && \
        out+='<div class="warn wi"><span>ℹ</span><span>Aucun filtrage INPUT — tout le trafic entrant est accepté sans restriction.</span></div>'

    { [ "$pi" = "DROP" ] || [ "$pi" = "REJECT" ]; } && [ "${has_est:-0}" -eq 0 ] && \
        out+='<div class="warn wd"><span>⚠</span><div><strong>INPUT DROP sans règle ESTABLISHED/RELATED</strong> — les connexions en cours peuvent être interrompues !</div></div>'

    { [ "$pi" = "DROP" ] || [ "$pi" = "REJECT" ]; } && [ "${has_ssh:-0}" -eq 0 ] && \
        out+='<div class="warn wd"><span>⚠</span><div><strong>INPUT DROP sans règle SSH (port 22)</strong> — risque de perte d'\''accès distant !<br><form method="POST" action="/apply-preset" style="display:inline;margin-top:.3rem"><input type="hidden" name="preset" value="ssh"><button class="btn btn-sm btn-d" type="submit" style="margin-top:.28rem" onclick="return confirm('\''Appliquer le preset SSH maintenant ?'\'')">Appliquer preset SSH</button></form></div></div>'

    { [ "$po" = "DROP" ] || [ "$po" = "REJECT" ]; } && \
        out+='<div class="warn ww"><span>⚠</span><span>Politique OUTPUT DROP — le trafic sortant est bloqué par défaut.</span></div>'

    printf '%s' "$out"
}

# Circular gauge — args: value(0-100) color label sublabel
_gauge() {
    local val="${1:-0}" color="${2:-#00d2ff}" label="${3:-}" sub="${4:-}"
    local deg; deg=$(awk "BEGIN{print int($val*3.6)}")
    printf '<div style="display:flex;align-items:center;gap:.9rem;margin-bottom:.5rem">'
    printf '<div style="position:relative;width:72px;height:72px;border-radius:50%;background:conic-gradient(%s %ddeg,#162035 %ddeg 360deg);flex-shrink:0;display:grid;place-items:center">' "$color" "$deg" "$deg"
    printf '<div style="width:54px;height:54px;border-radius:50%;background:var(--b1);display:flex;flex-direction:column;align-items:center;justify-content:center;gap:.05rem">'
    printf '<span style="font-family:var(--mo);font-size:.85rem;font-weight:800;color:%s;line-height:1">%s%%</span>' "$color" "$val"
    printf '</div></div>'
    printf '<div style="display:flex;flex-direction:column;gap:.15rem">'
    printf '<span style="font-family:var(--mo);font-size:.72rem;font-weight:700;color:var(--tx);text-transform:uppercase;letter-spacing:.07em">%s</span>' "$label"
    printf '<span style="font-family:var(--mo);font-size:.67rem;color:var(--mu)">%s</span>' "$sub"
    local pct="$val" bar_color
    [ "$pct" -lt 60 ] && bar_color="var(--gr)" || { [ "$pct" -lt 80 ] && bar_color="var(--ye)" || bar_color="var(--re)"; }
    printf '<div style="height:4px;width:110px;background:var(--b3);border-radius:2px;overflow:hidden"><div style="height:100%%;width:%d%%;background:%s;border-radius:2px;transition:width .8s"></div></div>' "$pct" "$bar_color"
    printf '</div></div>'
}

# ── html_header <title> <active_page> ────────────────────────────────────────
html_header() {
    local title="${1:-Fire-UX}" active="${2:-}"
    local now hostname_val ip_val
    now=$(date '+%H:%M:%S')
    hostname_val=$(hostname 2>/dev/null||echo "host")
    ip_val=$(hostname -I 2>/dev/null|awk '{print $1}'||echo "—")

    cat << 'STATIC'
<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>
:root{
  --b0:#06080d;--b1:#0c1420;--b2:#101b2b;--b3:#162035;--b4:#1d2a42;
  --bd:rgba(0,210,255,.11);--bd2:rgba(0,210,255,.28);--bd3:rgba(0,210,255,.5);
  --tx:#d8ecff;--mu:#506a88;--mu2:#304458;
  --ac:#00d2ff;--ac2:#7c3aed;--ac3:#0099bb;
  --gr:#0fe94f;--re:#ff3355;--ye:#ffb700;--or:#ff6528;
  --r:6px;--r2:10px;
  --mo:'JetBrains Mono','Cascadia Code','Fira Code',Consolas,monospace;
  --sa:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;
  --ez:cubic-bezier(.4,0,.2,1);
}
*,*::before,*::after{box-sizing:border-box;margin:0;padding:0}
html{font-size:14px;scroll-behavior:smooth}
body{background:var(--b0);color:var(--tx);font-family:var(--sa);line-height:1.6;min-height:100vh;display:flex;overflow-x:hidden}
body::before{content:'';position:fixed;inset:0;pointer-events:none;z-index:9999;
  background:repeating-linear-gradient(0deg,transparent,transparent 2px,rgba(0,0,0,.03) 2px,rgba(0,0,0,.03) 4px)}

/* ── Sidebar ── */
.sb{width:220px;min-height:100vh;background:var(--b1);border-right:1px solid var(--bd);
  display:flex;flex-direction:column;position:fixed;left:0;top:0;bottom:0;z-index:200;
  transition:transform .25s var(--ez)}
.sb-logo{padding:1.2rem 1.2rem .85rem;border-bottom:1px solid var(--bd)}
.sb-title{font-family:var(--mo);font-size:1.1rem;font-weight:800;color:var(--ac);
  text-shadow:0 0 18px rgba(0,210,255,.3);letter-spacing:.05em;display:flex;align-items:center;gap:.4rem}
.sb-ver{font-family:var(--mo);font-size:.61rem;color:var(--mu);margin-top:.18rem;letter-spacing:.07em}
.sb-pill{margin:.65rem 1rem;padding:.45rem .7rem;background:rgba(15,233,79,.05);
  border:1px solid rgba(15,233,79,.15);border-radius:var(--r);display:flex;align-items:center;
  gap:.45rem;font-family:var(--mo);font-size:.67rem;color:var(--mu)}
.pulse{width:7px;height:7px;border-radius:50%;background:var(--gr);box-shadow:0 0 7px var(--gr);
  animation:pulse 2s infinite;flex-shrink:0}
@keyframes pulse{0%,100%{opacity:1;transform:scale(1)}50%{opacity:.45;transform:scale(.75)}}
.sb-nav{flex:1;padding:.4rem 0;overflow-y:auto}
.sb-sec{margin-bottom:.2rem}
.sb-lbl{font-size:.6rem;color:var(--mu2);font-family:var(--mo);letter-spacing:.12em;
  text-transform:uppercase;padding:.55rem 1.2rem .2rem}
.nl{display:flex;align-items:center;gap:.55rem;padding:.52rem 1.2rem;color:var(--mu);
  text-decoration:none;font-size:.845rem;transition:all .18s var(--ez);border-left:2px solid transparent}
.nl:hover{color:var(--tx);background:rgba(0,210,255,.04);border-left-color:rgba(0,210,255,.22)}
.nl.active{color:var(--ac);background:rgba(0,210,255,.07);border-left-color:var(--ac);
  text-shadow:0 0 9px rgba(0,210,255,.3)}
.ni{width:1.1rem;text-align:center;font-size:.9rem}
.nc{margin-left:auto;font-family:var(--mo);font-size:.61rem;padding:.08rem .38rem;
  background:rgba(0,210,255,.09);color:var(--ac);border-radius:3px;border:1px solid var(--bd)}
.sb-foot{padding:.7rem 1.2rem;border-top:1px solid var(--bd);font-family:var(--mo);
  font-size:.62rem;color:var(--mu2);line-height:1.7}

/* ── Main ── */
.main{margin-left:220px;flex:1;display:flex;flex-direction:column;min-height:100vh}

/* ── Topbar ── */
.topbar{background:rgba(12,20,32,.92);border-bottom:1px solid var(--bd);
  padding:.58rem 1.4rem;display:flex;align-items:center;justify-content:space-between;
  position:sticky;top:0;z-index:100;backdrop-filter:blur(14px)}
.tb-bc{display:flex;align-items:center;gap:.38rem;font-size:.76rem;color:var(--mu);font-family:var(--mo)}
.tb-bc .sep{color:var(--mu2)}
.tb-bc .cur{color:var(--tx)}
.tb-r{display:flex;align-items:center;gap:.85rem}
.tb-host{font-family:var(--mo);font-size:.73rem;color:var(--mu);display:flex;align-items:center;gap:.28rem}
.hd{width:5px;height:5px;border-radius:50%;background:var(--gr);box-shadow:0 0 5px var(--gr)}
.tb-clock{font-family:var(--mo);font-size:.79rem;color:var(--ac);
  text-shadow:0 0 8px rgba(0,210,255,.28);min-width:4.5rem;text-align:right}
.ham{display:none;background:none;border:1px solid var(--bd);cursor:pointer;padding:.28rem .5rem;
  color:var(--tx);font-size:1rem;border-radius:var(--r);line-height:1;transition:border-color .2s}
.ham:hover{border-color:var(--bd2)}

/* ── Content ── */
.ct{flex:1;padding:1.4rem;animation:fi .22s ease}
@keyframes fi{from{opacity:0;transform:translateY(5px)}to{opacity:1;transform:translateY(0)}}
.pt{font-size:1.05rem;font-weight:700;color:var(--tx);display:flex;align-items:center;
  gap:.45rem;margin-bottom:1.2rem}
.pt .ic{color:var(--ac);font-size:.95rem}

/* ── Cards ── */
.card{background:var(--b1);border:1px solid var(--bd);border-radius:var(--r2);
  padding:1.2rem;margin-bottom:.9rem;position:relative;overflow:hidden;
  transition:border-color .2s var(--ez)}
.card::before{content:'';position:absolute;inset:0;pointer-events:none;
  background:linear-gradient(135deg,rgba(0,210,255,.02),transparent 58%)}
.card:hover{border-color:rgba(0,210,255,.19)}
.card-hd{display:flex;align-items:center;justify-content:space-between;
  margin-bottom:.9rem;padding-bottom:.6rem;border-bottom:1px solid var(--bd)}
.card-t{font-size:.76rem;font-weight:700;color:var(--tx);text-transform:uppercase;
  letter-spacing:.08em;display:flex;align-items:center;gap:.38rem}
.card-t .ic{color:var(--ac)}

/* ── Stat cards ── */
.srow{display:grid;grid-template-columns:repeat(auto-fit,minmax(160px,1fr));gap:.9rem;margin-bottom:.9rem}
.sc{background:var(--b1);border:1px solid var(--bd);border-radius:var(--r2);
  padding:.95rem 1.1rem;position:relative;overflow:hidden;transition:all .22s var(--ez);cursor:default}
.sc:hover{border-color:var(--bd2);transform:translateY(-2px);box-shadow:0 8px 24px rgba(0,0,0,.45)}
.sc::after{content:'';position:absolute;bottom:0;left:0;right:0;height:2px;
  background:linear-gradient(90deg,transparent,var(--ac),transparent);opacity:0;transition:opacity .22s}
.sc:hover::after{opacity:1}
.sc.g::after{background:linear-gradient(90deg,transparent,var(--gr),transparent)}
.sc.r::after{background:linear-gradient(90deg,transparent,var(--re),transparent)}
.sc.y::after{background:linear-gradient(90deg,transparent,var(--ye),transparent)}
.sc.p::after{background:linear-gradient(90deg,transparent,var(--ac2),transparent)}
.sl{font-size:.63rem;color:var(--mu);text-transform:uppercase;letter-spacing:.1em;
  font-family:var(--mo);margin-bottom:.32rem}
.sv{font-family:var(--mo);font-size:1.95rem;font-weight:800;color:var(--ac);
  text-shadow:0 0 16px rgba(0,210,255,.35);line-height:1}
.sv.g{color:var(--gr);text-shadow:0 0 14px rgba(15,233,79,.3)}
.sv.r{color:var(--re);text-shadow:0 0 14px rgba(255,51,85,.3)}
.sv.y{color:var(--ye);text-shadow:none}
.sv.w{color:var(--tx);text-shadow:none}
.sv.p{color:var(--ac2);text-shadow:0 0 14px rgba(124,58,237,.3)}
.ss{font-size:.68rem;color:var(--mu);margin-top:.28rem;font-family:var(--mo)}
.sbg{position:absolute;top:.8rem;right:.8rem;font-size:.6rem;padding:.12rem .4rem;
  border-radius:3px;font-family:var(--mo);font-weight:700}
.sbg.a{background:rgba(15,233,79,.1);color:var(--gr);border:1px solid rgba(15,233,79,.22)}
.sbg.d{background:rgba(255,51,85,.1);color:var(--re);border:1px solid rgba(255,51,85,.22)}

/* ── Grids ── */
.g2{display:grid;grid-template-columns:repeat(auto-fit,minmax(290px,1fr));gap:.9rem}
.g3{display:grid;grid-template-columns:repeat(auto-fit,minmax(210px,1fr));gap:.9rem}
.g4{display:grid;grid-template-columns:repeat(auto-fit,minmax(170px,1fr));gap:.9rem}

/* ── Tables ── */
.tw{overflow-x:auto}
table{width:100%;border-collapse:collapse;font-size:.79rem;font-family:var(--mo)}
thead{position:sticky;top:0;z-index:10}
thead tr{background:var(--b2)}
th{text-align:left;padding:.52rem .72rem;color:var(--mu);font-weight:600;font-size:.65rem;
  text-transform:uppercase;letter-spacing:.08em;border-bottom:1px solid var(--bd);white-space:nowrap}
tbody tr{border-bottom:1px solid rgba(22,32,53,.9);transition:background .13s}
tbody tr:hover{background:rgba(0,210,255,.025)}
tbody tr.hidden{display:none}
td{padding:.48rem .72rem;vertical-align:middle;word-break:break-all}

/* ── Badges ── */
.badge{display:inline-flex;align-items:center;padding:.11em .48em;border-radius:4px;
  font-size:.69rem;font-weight:700;letter-spacing:.04em;font-family:var(--mo);white-space:nowrap}
.ba{background:rgba(15,233,79,.09);color:var(--gr);border:1px solid rgba(15,233,79,.23)}
.bd{background:rgba(255,51,85,.09);color:var(--re);border:1px solid rgba(255,51,85,.23)}
.br{background:rgba(255,101,40,.09);color:var(--or);border:1px solid rgba(255,101,40,.23)}
.bg{background:rgba(80,106,136,.08);color:var(--mu);border:1px solid rgba(80,106,136,.15)}
.bb{background:rgba(0,210,255,.08);color:var(--ac);border:1px solid rgba(0,210,255,.2)}
.by{background:rgba(255,183,0,.08);color:var(--ye);border:1px solid rgba(255,183,0,.2)}
.bp{background:rgba(124,58,237,.08);color:var(--ac2);border:1px solid rgba(124,58,237,.2)}

/* ── Buttons ── */
.btn{display:inline-flex;align-items:center;gap:.38rem;padding:.4rem .8rem;
  border-radius:var(--r);font-size:.79rem;font-weight:500;cursor:pointer;
  text-decoration:none;border:1px solid transparent;transition:all .18s var(--ez);
  background:none;white-space:nowrap;font-family:var(--sa);line-height:1}
.btn:hover{transform:translateY(-1px)}
.btn:active{transform:translateY(0)}
.btn-p{background:var(--ac);color:#000;border-color:var(--ac);font-weight:700;
  box-shadow:0 0 11px rgba(0,210,255,.18)}
.btn-p:hover{box-shadow:0 0 20px rgba(0,210,255,.38)}
.btn-s{background:var(--b3);color:var(--tx);border-color:var(--bd)}
.btn-s:hover{border-color:var(--bd2)}
.btn-d{background:rgba(255,51,85,.07);color:var(--re);border-color:rgba(255,51,85,.23)}
.btn-d:hover{background:rgba(255,51,85,.17);box-shadow:0 0 9px rgba(255,51,85,.18)}
.btn-w{background:rgba(255,183,0,.07);color:var(--ye);border-color:rgba(255,183,0,.23)}
.btn-w:hover{background:rgba(255,183,0,.17)}
.btn-g{background:rgba(15,233,79,.07);color:var(--gr);border-color:rgba(15,233,79,.23)}
.btn-g:hover{background:rgba(15,233,79,.17);box-shadow:0 0 9px rgba(15,233,79,.18)}
.btn-sm{padding:.22rem .52rem;font-size:.71rem}
.ab{display:flex;gap:.4rem;flex-wrap:wrap;margin-top:.7rem}

/* ── Warnings / alerts ── */
.warn{display:flex;align-items:flex-start;gap:.6rem;padding:.62rem .88rem;
  border-radius:var(--r);margin-bottom:.5rem;font-size:.81rem;line-height:1.5;border:1px solid}
.warn>span:first-child{flex-shrink:0;margin-top:.05rem}
.wd{background:rgba(255,51,85,.07);border-color:rgba(255,51,85,.28);color:var(--re)}
.ww{background:rgba(255,183,0,.07);border-color:rgba(255,183,0,.28);color:var(--ye)}
.wi{background:rgba(0,210,255,.07);border-color:rgba(0,210,255,.28);color:var(--ac)}
.wg{background:rgba(15,233,79,.07);border-color:rgba(15,233,79,.28);color:var(--gr)}

/* ── Forms ── */
.fg{display:flex;flex-direction:column;gap:.28rem}
label{font-size:.65rem;color:var(--mu);text-transform:uppercase;letter-spacing:.08em;font-family:var(--mo)}
input[type=text],input[type=number],input[type=search],select{
  background:var(--b3);border:1px solid var(--bd);border-radius:var(--r);
  color:var(--tx);padding:.4rem .62rem;font-family:var(--mo);font-size:.79rem;
  outline:none;transition:border-color .18s,box-shadow .18s;width:100%}
input:focus,select:focus{border-color:var(--ac);box-shadow:0 0 0 2px rgba(0,210,255,.09)}
select option{background:var(--b2)}
.fgrid{display:grid;grid-template-columns:repeat(auto-fit,minmax(138px,1fr));gap:.7rem;align-items:end}
.srch{position:relative}
.srch input{padding-left:1.85rem}
.srch::before{content:'⌕';position:absolute;left:.58rem;top:50%;transform:translateY(-50%);
  color:var(--mu);font-size:.95rem;pointer-events:none;z-index:1}

/* ── Toggle ── */
.toggle{position:relative;display:inline-block;width:40px;height:20px;flex-shrink:0}
.toggle input{opacity:0;width:0;height:0}
.slider{position:absolute;cursor:pointer;inset:0;background:var(--b3);
  border:1px solid var(--bd);border-radius:10px;transition:.22s}
.slider:before{position:absolute;content:'';height:14px;width:14px;left:2px;bottom:2px;
  background:var(--mu);border-radius:50%;transition:.22s}
input:checked+.slider{background:rgba(0,210,255,.18);border-color:var(--ac)}
input:checked+.slider:before{background:var(--ac);transform:translateX(20px);
  box-shadow:0 0 5px rgba(0,210,255,.4)}

/* ── Log viewer ── */
.logblock{background:var(--b0);border:1px solid var(--bd);border-radius:var(--r2);overflow:hidden;font-family:var(--mo);font-size:.75rem}
.logtb{display:flex;align-items:center;gap:.45rem;padding:.48rem .7rem;
  border-bottom:1px solid var(--bd);background:var(--b1);flex-wrap:wrap}
.logbody{max-height:510px;overflow-y:auto;padding:.55rem .7rem}
.logbody::-webkit-scrollbar{width:4px}
.logbody::-webkit-scrollbar-thumb{background:var(--b3);border-radius:2px}
.ll{padding:.14rem 0;border-bottom:1px solid rgba(255,255,255,.022);line-height:1.52}
.ll:last-child{border-bottom:none}
.la{color:var(--gr)}.ld{color:var(--re)}.le{color:var(--ye)}.li{color:#2d4560}
.lnew{animation:lf .55s ease}
@keyframes lf{from{background:rgba(0,210,255,.07)}to{background:transparent}}

/* ── Port chips ── */
.pgrid{display:flex;flex-wrap:wrap;gap:.32rem;margin-top:.45rem}
.pc{display:inline-flex;align-items:center;gap:.28rem;padding:.18rem .52rem;
  border-radius:4px;font-family:var(--mo);font-size:.71rem;border:1px solid;transition:all .14s}
.po{border-color:rgba(15,233,79,.28);color:var(--gr);background:rgba(15,233,79,.05)}
.po:hover{box-shadow:0 0 7px rgba(15,233,79,.18)}
.pn{border-color:var(--bd);color:var(--mu);background:var(--b3)}

/* ── Chart ── */
.chwrap{position:relative;height:155px}

/* ── Policy ── */
.prow{display:flex;gap:.45rem;flex-wrap:wrap}
.pi{display:flex;flex-direction:column;align-items:center;gap:.22rem;background:var(--b3);
  border:1px solid var(--bd);border-radius:var(--r);padding:.5rem .85rem;min-width:73px}
.pn2{font-size:.6rem;color:var(--mu);text-transform:uppercase;letter-spacing:.08em;font-family:var(--mo)}
.pv{font-family:var(--mo);font-size:.73rem;font-weight:700;padding:.1rem .38rem;border-radius:3px}
.pva{background:rgba(15,233,79,.1);color:var(--gr);border:1px solid rgba(15,233,79,.28)}
.pvd{background:rgba(255,51,85,.1);color:var(--re);border:1px solid rgba(255,51,85,.28)}
.pvr{background:rgba(255,101,40,.1);color:var(--or);border:1px solid rgba(255,101,40,.28)}
.pvo{background:var(--b3);color:var(--mu);border:1px solid var(--bd)}

/* ── Iface cards ── */
.igrid{display:grid;grid-template-columns:repeat(auto-fill,minmax(215px,1fr));gap:.7rem}
.ifc{background:var(--b3);border:1px solid var(--bd);border-radius:var(--r2);
  padding:.85rem .95rem;transition:border-color .18s}
.ifc:hover{border-color:var(--bd2)}
.ifn{font-family:var(--mo);font-size:.88rem;font-weight:700;color:var(--ac);margin-bottom:.28rem}
.ifip{font-family:var(--mo);font-size:.76rem;color:var(--tx)}
.ifm{font-family:var(--mo);font-size:.67rem;color:var(--mu);margin-top:.12rem}
.ifs{display:inline-flex;align-items:center;gap:.24rem;margin-top:.3rem;font-size:.67rem;font-family:var(--mo)}
.ud{width:5px;height:5px;border-radius:50%;background:var(--gr);box-shadow:0 0 4px var(--gr)}
.dd{width:5px;height:5px;border-radius:50%;background:var(--mu)}

/* ── Settings ── */
.set-row{display:flex;align-items:center;justify-content:space-between;gap:1rem;
  padding:.75rem 0;border-bottom:1px solid var(--bd)}
.set-row:last-child{border-bottom:none}
.set-info{flex:1}
.set-lbl{font-size:.85rem;color:var(--tx);font-weight:500}
.set-desc{font-size:.73rem;color:var(--mu);margin-top:.12rem}
.set-ctrl{flex-shrink:0;min-width:130px;text-align:right;display:flex;justify-content:flex-end;align-items:center}

/* ── Toast ── */
.tw2{position:fixed;bottom:1.4rem;right:1.4rem;display:flex;flex-direction:column;gap:.38rem;z-index:9000;pointer-events:none}
.toast{display:flex;align-items:center;gap:.52rem;padding:.58rem .88rem;border-radius:var(--r);
  font-size:.79rem;pointer-events:auto;min-width:215px;max-width:340px;backdrop-filter:blur(16px);
  border:1px solid;animation:ti .28s ease}
@keyframes ti{from{transform:translateX(110%);opacity:0}to{transform:translateX(0);opacity:1}}
@keyframes to2{from{transform:translateX(0);opacity:1}to{transform:translateX(110%);opacity:0}}
.toast.out{animation:to2 .28s ease forwards}
.t-ok{background:rgba(6,8,13,.93);border-color:rgba(15,233,79,.38);color:var(--gr)}
.t-err{background:rgba(6,8,13,.93);border-color:rgba(255,51,85,.38);color:var(--re)}
.t-info{background:rgba(6,8,13,.93);border-color:rgba(0,210,255,.38);color:var(--ac)}
.t-warn{background:rgba(6,8,13,.93);border-color:rgba(255,183,0,.38);color:var(--ye)}

/* ── Flash ── */
.flash{display:flex;align-items:center;gap:.45rem;padding:.58rem .88rem;border-radius:var(--r);margin-bottom:.9rem;font-size:.8rem}
.flash.ok{background:rgba(15,233,79,.07);border:1px solid rgba(15,233,79,.23);color:var(--gr)}
.flash.err{background:rgba(255,51,85,.07);border:1px solid rgba(255,51,85,.23);color:var(--re)}

/* ── Mobile overlay ── */
.sb-ov{display:none;position:fixed;inset:0;background:rgba(0,0,0,.5);z-index:190;backdrop-filter:blur(2px)}

/* ── Misc ── */
code{background:var(--b3);border:1px solid var(--bd);border-radius:3px;padding:.09em .33em;
  font-family:var(--mo);font-size:.81em;color:var(--ac)}
.mu{color:var(--mu)}
hr.dv{border:none;border-top:1px solid var(--bd);margin:.7rem 0}
::-webkit-scrollbar{width:5px;height:5px}
::-webkit-scrollbar-track{background:var(--b0)}
::-webkit-scrollbar-thumb{background:var(--b3);border-radius:3px}
::-webkit-scrollbar-thumb:hover{background:rgba(0,210,255,.22)}

/* ── Responsive ── */
@media(max-width:768px){
  .sb{transform:translateX(-100%)}
  .sb.open{transform:translateX(0)}
  .sb-ov.show{display:block}
  .main{margin-left:0}
  .srow{grid-template-columns:repeat(2,1fr)}
  .sv{font-size:1.5rem}
  .topbar,.ct{padding:.5rem .75rem}
  .ham{display:flex}
  .g2,.g3,.g4{grid-template-columns:1fr}
}
</style>
STATIC

    printf '<title>%s — Fire-UX</title>\n' "$title"
    printf '<script>const _PG="%s",_VER="%s";</script>\n' "$active" "${_VERSION}"
    printf '</head>\n<body>\n'
    printf '<div class="sb-ov" id="sbov" onclick="closeSb()"></div>\n'
    printf '<div class="tw2" id="tw"></div>\n'

    # ── Sidebar ──────────────────────────────────────────────────────────────
    cat << SBEOF
<aside class="sb" id="sb">
  <div class="sb-logo">
    <div class="sb-title">🔥 Fire-UX</div>
    <div class="sb-ver">v${_VERSION} · iptables manager</div>
  </div>
  <div class="sb-pill">
    <span class="pulse"></span>
    <span>online · ${ip_val}</span>
  </div>
  <nav class="sb-nav">
    <div class="sb-sec">
      <div class="sb-lbl">Navigation</div>
      <a href="/"         class="nl$(_nav_class dashboard "$active")"><span class="ni">▣</span> Tableau de bord</a>
      <a href="/rules"    class="nl$(_nav_class rules    "$active")"><span class="ni">⊟</span> Règles<span class="nc" id="sbnc">…</span></a>
      <a href="/logs"     class="nl$(_nav_class logs     "$active")"><span class="ni">≡</span> Journaux</a>
      <a href="/network"  class="nl$(_nav_class network  "$active")"><span class="ni">⊕</span> Réseau</a>
      <a href="/profiles" class="nl$(_nav_class profiles "$active")"><span class="ni">◈</span> Profils</a>
      <a href="/settings" class="nl$(_nav_class settings "$active")"><span class="ni">⚙</span> Paramètres</a>
    </div>
    <div class="sb-sec">
      <div class="sb-lbl">API</div>
      <a href="/api/stats"  class="nl" target="_blank"><span class="ni">⊙</span> /api/stats</a>
      <a href="/api/health" class="nl" target="_blank"><span class="ni">⊙</span> /api/health</a>
      <a href="/export"     class="nl" target="_blank"><span class="ni">↓</span> Exporter</a>
    </div>
  </nav>
  <div class="sb-foot">
    PID : ${SERVER_PID:-—}<br>
    Hôte : ${hostname_val}<br>
    <span style="color:var(--mu2);font-size:.58rem">1-6 nav · ? aide</span>
  </div>
</aside>
SBEOF

    cat << TBEOF
<div class="main">
<header class="topbar">
  <div class="tb-bc">
    <button class="ham" onclick="toggleSb()" title="Menu">☰</button>
    <span>fire-ux</span><span class="sep">/</span><span class="cur">${active:-home}</span>
  </div>
  <div class="tb-r">
    <div id="warnbadge" style="display:none"><span class="badge bd" style="cursor:pointer" onclick="location.href='/'">⚠ <span id="wc">0</span> alerte(s)</span></div>
    <div class="tb-host"><span class="hd"></span>${hostname_val}</div>
    <div class="tb-clock" id="clk">${now}</div>
  </div>
</header>
<div class="ct">
TBEOF
}

# ── html_footer ───────────────────────────────────────────────────────────────
html_footer() {
    cat << 'JSEOF'
</div></div>
<script>
// ── Clock ────────────────────────────────────────────────────────────────────
const _clk=document.getElementById('clk');
setInterval(()=>{if(!_clk)return;const n=new Date();_clk.textContent=[n.getHours(),n.getMinutes(),n.getSeconds()].map(v=>String(v).padStart(2,'0')).join(':')},1000);

// ── Mobile sidebar ───────────────────────────────────────────────────────────
const _sb=document.getElementById('sb');
const _ov=document.getElementById('sbov');
function toggleSb(){_sb&&_sb.classList.toggle('open');_ov&&_ov.classList.toggle('show')}
function closeSb(){_sb&&_sb.classList.remove('open');_ov&&_ov.classList.remove('show')}

// ── Animated counter ─────────────────────────────────────────────────────────
function cnt(el,v,ms=550){
  if(!el)return;const s=parseInt(el.textContent)||0;if(s===v)return;
  const r=v-s,t0=performance.now();
  const f=t=>{const p=Math.min((t-t0)/ms,1),e=1-Math.pow(1-p,3);el.textContent=Math.round(s+r*e);p<1?requestAnimationFrame(f):el.textContent=v};
  requestAnimationFrame(f);
}

// ── Toast system ─────────────────────────────────────────────────────────────
const _tw=document.getElementById('tw');
function toast(msg,type='info',dur=3400){
  if(!_tw)return;
  const t=document.createElement('div');
  t.className='toast t-'+type;
  const ic={ok:'✓',err:'✗',info:'ℹ',warn:'⚠'}[type]||'·';
  t.innerHTML=`<span>${ic}</span><span>${msg}</span>`;
  _tw.appendChild(t);
  setTimeout(()=>{t.classList.add('out');setTimeout(()=>t.remove(),300)},dur);
}

// ── URL flash → toast ─────────────────────────────────────────────────────────
(()=>{
  const p=new URLSearchParams(location.search),m=p.get('msg');
  const map={preset_applied:['Preset appliqué','ok'],rule_added:['Règle ajoutée','ok'],
    rule_deleted:['Règle supprimée','ok'],rule_moved:['Règle déplacée','ok'],
    chain_flushed:['Chaîne vidée','ok'],all_flushed:['Toutes les chaînes vidées','ok'],
    snapshot_saved:['Snapshot créé','ok'],profile_applied:['Profil appliqué','ok'],
    profile_deleted:['Profil supprimé','ok'],logs_cleared:['Journaux vidés','ok'],
    chain_created:['Chaîne créée','ok'],chain_deleted:['Chaîne supprimée','ok'],
    settings_saved:['Paramètres sauvegardés','ok']};
  if(m){const d=map[m];d?toast(...d):m.startsWith('error_')&&toast('Erreur : '+m.replace(/error_/,''),'err');
    const u=new URL(location);u.searchParams.delete('msg');history.replaceState({},'',u)}
})();

// ── Stats polling ─────────────────────────────────────────────────────────────
const _se={i:document.getElementById('si'),o:document.getElementById('so'),
  f:document.getElementById('sf'),t:document.getElementById('st'),
  nc:document.getElementById('sbnc'),cpu:document.getElementById('scpu'),
  mem:document.getElementById('smem'),conn:document.getElementById('sconn')};
let _ch=null;

async function fetchStats(){
  try{
    const r=await fetch('/api/stats');if(!r.ok)return;
    const d=await r.json();
    cnt(_se.i,d.rules_input||0);cnt(_se.o,d.rules_output||0);
    cnt(_se.f,d.rules_forward||0);
    const tot=(d.rules_input||0)+(d.rules_output||0)+(d.rules_forward||0);
    cnt(_se.t,tot);
    if(_se.nc)_se.nc.textContent=tot;
    if(_se.cpu)_se.cpu.textContent=d.cpu_pct+'%';
    if(_se.mem)_se.mem.textContent=d.mem_pct+'%';
    if(_se.conn)_se.conn.textContent=d.connections||0;
    if(_ch){_ch.data.datasets[0].data=[d.rules_input||0,d.rules_output||0,d.rules_forward||0];_ch.update('none')}
    _updateGauge('cpu-gauge',d.cpu_pct||0);
    _updateGauge('mem-gauge',d.mem_pct||0);
    const si6=document.getElementById('si6');const so6=document.getElementById('so6');
    const sf6=document.getElementById('sf6');const st6=document.getElementById('st6');
    if(si6)cnt(si6,d.rules_input6||0);if(so6)cnt(so6,d.rules_output6||0);
    if(sf6)cnt(sf6,d.rules_forward6||0);
    if(st6)cnt(st6,(d.rules_input6||0)+(d.rules_output6||0)+(d.rules_forward6||0));
  }catch(e){}
}

function _updateGauge(id,val){
  const el=document.getElementById(id);if(!el)return;
  const color=val<60?'#0fe94f':val<80?'#ffb700':'#ff3355';
  el.style.background=`conic-gradient(${color} ${val*3.6}deg,#162035 ${val*3.6}deg 360deg)`;
  const inner=el.querySelector('.gi');if(inner){inner.style.color=color;inner.textContent=val+'%'}
  const bar=el.parentElement&&el.parentElement.querySelector('.gb');
  if(bar){bar.style.width=val+'%';bar.style.background=color}
}

// ── Chart ────────────────────────────────────────────────────────────────────
function initChart(){
  const c=document.getElementById('rChart');
  if(!c||typeof Chart==='undefined')return;
  _ch=new Chart(c,{type:'bar',data:{labels:['INPUT','OUTPUT','FORWARD'],datasets:[{
    data:[0,0,0],
    backgroundColor:['rgba(0,210,255,.2)','rgba(15,233,79,.2)','rgba(255,183,0,.2)'],
    borderColor:['rgba(0,210,255,.7)','rgba(15,233,79,.7)','rgba(255,183,0,.7)'],
    borderWidth:1,borderRadius:4}]},options:{responsive:true,maintainAspectRatio:false,
    plugins:{legend:{display:false}},scales:{
      x:{grid:{color:'rgba(255,255,255,.035)'},ticks:{color:'#506a88',font:{family:'JetBrains Mono,monospace',size:11}}},
      y:{grid:{color:'rgba(255,255,255,.035)'},ticks:{color:'#506a88',font:{family:'JetBrains Mono,monospace',size:11},stepSize:1},beginAtZero:true}}}});
}

// ── Health warnings badge ─────────────────────────────────────────────────────
async function fetchHealth(){
  try{
    const r=await fetch('/api/health');if(!r.ok)return;
    const d=await r.json();
    const wb=document.getElementById('warnbadge');
    const wc=document.getElementById('wc');
    if(wb&&wc){const n=d.count||0;wb.style.display=n>0?'':'none';if(wc)wc.textContent=n}
  }catch(e){}
}

// ── Table search ─────────────────────────────────────────────────────────────
document.querySelectorAll('[data-search]').forEach(inp=>{
  const t=document.getElementById(inp.dataset.search);if(!t)return;
  inp.addEventListener('input',()=>{
    const q=inp.value.toLowerCase();
    t.querySelectorAll('tbody tr').forEach(tr=>tr.classList.toggle('hidden',!!q&&!tr.textContent.toLowerCase().includes(q)));
  });
});

// ── Log live tail ─────────────────────────────────────────────────────────────
const _lb=document.getElementById('lb');
let _lc=0,_ar=true;
async function fetchLogs(){
  if(!_lb||!_ar)return;
  try{
    const ll=parseInt(localStorage.getItem('loglines')||'100');
    const r=await fetch('/api/logs?n='+ll);if(!r.ok)return;
    const d=await r.json();if(!Array.isArray(d.lines)||d.lines.length===_lc)return;
    _lc=d.lines.length;
    const bot=_lb.scrollTop+_lb.clientHeight>=_lb.scrollHeight-25;
    _lb.innerHTML=d.lines.map(l=>{
      const cls=/accept/i.test(l)?'la':/drop|reject|deni/i.test(l)?'ld':/error|fail|erreur/i.test(l)?'le':'li';
      const s=l.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
      return `<div class="ll ${cls}">${s}</div>`;
    }).join('');
    const as2=localStorage.getItem('autoscroll')!=='false';
    if(bot&&as2)_lb.scrollTop=_lb.scrollHeight;
    const cnt2=document.getElementById('logcnt');if(cnt2)cnt2.textContent=d.count;
  }catch(e){}
}
const _arb=document.getElementById('arb');
if(_arb)_arb.addEventListener('click',()=>{
  _ar=!_ar;_arb.textContent=_ar?'⏸ Pause':'▶ Reprendre';
  _arb.className=_ar?'btn btn-sm btn-s':'btn btn-sm btn-w';
});

// ── Log search+filter ─────────────────────────────────────────────────────────
const _lsrch=document.getElementById('lsrch');
const _lflt=document.getElementById('lflt');
function applyLogFilter(){
  const q=(_lsrch?_lsrch.value:'').toLowerCase();
  const f=_lflt?_lflt.value:'';
  document.querySelectorAll('#lb .ll').forEach(el=>{
    const txt=el.textContent.toLowerCase();
    const mq=!q||txt.includes(q);
    const mf=!f||(f==='accept'&&el.classList.contains('la'))||(f==='drop'&&el.classList.contains('ld'))||(f==='error'&&el.classList.contains('le'));
    el.style.display=(mq&&mf)?'':'none';
  });
}
_lsrch&&_lsrch.addEventListener('input',applyLogFilter);
_lflt&&_lflt.addEventListener('change',applyLogFilter);

// ── Keyboard shortcuts ────────────────────────────────────────────────────────
document.addEventListener('keydown',e=>{
  if(['INPUT','SELECT','TEXTAREA'].includes(e.target.tagName))return;
  if(e.key==='1')location.href='/';
  if(e.key==='2')location.href='/rules';
  if(e.key==='3')location.href='/logs';
  if(e.key==='4')location.href='/network';
  if(e.key==='5')location.href='/profiles';
  if(e.key==='6')location.href='/settings';
  if(e.key==='e'||e.key==='E')location.href='/export';
  if(e.key==='?')toast('Raccourcis : 1-6 navigation · E export · ? aide','info',4500);
  if(e.key==='Escape')closeSb();
});

// ── Settings restore ──────────────────────────────────────────────────────────
(()=>{
  const rv=localStorage.getItem('refresh')||'4';
  const rs=document.getElementById('set-refresh');if(rs)rs.value=rv;
  const ls=document.getElementById('set-loglines');if(ls)ls.value=localStorage.getItem('loglines')||'100';
  const as=document.getElementById('set-autoscroll');if(as)as.checked=localStorage.getItem('autoscroll')!=='false';
})();

// ── Dynamic refresh interval ──────────────────────────────────────────────────
const _ri=parseInt(localStorage.getItem('refresh')||'4')*1000;
const _ril=document.getElementById('ri-lbl');if(_ril)_ril.textContent=parseInt(localStorage.getItem('refresh')||'4');

// ── Boot ──────────────────────────────────────────────────────────────────────
(async()=>{
  initChart();
  await fetchStats();await fetchHealth();
  if(_ri>0)setInterval(fetchStats,_ri);
  setInterval(fetchHealth,15000);
  if(_lb){await fetchLogs();setInterval(fetchLogs,5000)}
})();
</script>
<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js"
  onload="initChart()" onerror="console.warn('Chart.js CDN indisponible')"></script>
</body></html>
JSEOF
}

# ── page_dashboard ────────────────────────────────────────────────────────────
page_dashboard() {
    local pi po pf ci co cf ct uv hn iv
    local ncpu load cpu_pct cpu_deg cpu_color
    local mem_t mem_f mem_used mem_pct mem_deg mem_color
    local conns ci6=0 co6=0 cf6=0 ct6=0 has_ip6=0

    pi=$(iptables -L INPUT   2>/dev/null|head -1|awk '{print $4}'|tr -d ')')
    po=$(iptables -L OUTPUT  2>/dev/null|head -1|awk '{print $4}'|tr -d ')')
    pf=$(iptables -L FORWARD 2>/dev/null|head -1|awk '{print $4}'|tr -d ')')
    ci=$(iptables -L INPUT   --line-numbers -n 2>/dev/null|tail -n+3|grep -v '^$'|wc -l)
    co=$(iptables -L OUTPUT  --line-numbers -n 2>/dev/null|tail -n+3|grep -v '^$'|wc -l)
    cf=$(iptables -L FORWARD --line-numbers -n 2>/dev/null|tail -n+3|grep -v '^$'|wc -l)
    ct=$((ci+co+cf))
    if command -v ip6tables &>/dev/null; then
        has_ip6=1
        ci6=$(ip6tables -L INPUT   --line-numbers -n 2>/dev/null|tail -n+3|grep -v '^$'|wc -l||echo 0)
        co6=$(ip6tables -L OUTPUT  --line-numbers -n 2>/dev/null|tail -n+3|grep -v '^$'|wc -l||echo 0)
        cf6=$(ip6tables -L FORWARD --line-numbers -n 2>/dev/null|tail -n+3|grep -v '^$'|wc -l||echo 0)
        ct6=$((ci6+co6+cf6))
    fi
    uv=$(uptime -p 2>/dev/null|sed 's/up //'||uptime|sed 's/.*up //;s/,.*//')
    hn=$(hostname 2>/dev/null||echo "—")
    iv=$(hostname -I 2>/dev/null|awk '{print $1}'||echo "—")
    conns=$(ss -tn state established 2>/dev/null|tail -n+2|wc -l||echo 0)
    ncpu=$(nproc 2>/dev/null||echo 1)
    load=$(awk '{print $1}' /proc/loadavg 2>/dev/null||echo "0")
    cpu_pct=$(awk "BEGIN{v=int($load*100/$ncpu);print(v>100?100:v)}")
    cpu_deg=$(awk "BEGIN{print int($cpu_pct*3.6)}")
    mem_t=$(awk '/MemTotal/{print $2}'     /proc/meminfo 2>/dev/null||echo 1)
    mem_f=$(awk '/MemAvailable/{print $2}' /proc/meminfo 2>/dev/null||echo 1)
    mem_used=$((mem_t-mem_f))
    mem_pct=$(awk "BEGIN{print int($mem_used*100/$mem_t)}")
    mem_deg=$(awk "BEGIN{print int($mem_pct*3.6)}")

    # Color helpers
    _gc() { [ "$1" -lt 60 ]&&echo "#0fe94f"||{ [ "$1" -lt 80 ]&&echo "#ffb700"||echo "#ff3355"; }; }
    cpu_color=$(_gc "$cpu_pct"); mem_color=$(_gc "$mem_pct")

    _pvcls() { case "$1" in ACCEPT) echo pva;; DROP|REJECT) echo pvd;; *) echo pvo;; esac; }

    html_header "Tableau de bord" "dashboard"

    # Security warnings
    local warns; warns=$(_sec_warnings)
    if [ -n "${warns}" ]; then
        cat << WEOF
<div class="card" style="border-color:rgba(255,51,85,.3)">
  <div class="card-hd"><div class="card-t" style="color:var(--re)"><span class="ic">⚠</span> Alertes de sécurité</div></div>
  ${warns}
</div>
WEOF
    fi

    # Stat cards
    cat << STATSEOF
<div class="pt"><span class="ic">▣</span> Tableau de bord</div>

<div class="srow">
  <div class="sc">
    <div class="sl">INPUT</div>
    <div class="sv" id="si">${ci}</div>
    <div class="ss">politique : $(_pol_badge "${pi}")</div>
    <span class="sbg $([ "${pi}" = "ACCEPT" ]&&echo a||echo d)">${pi:-?}</span>
  </div>
  <div class="sc g">
    <div class="sl">OUTPUT</div>
    <div class="sv g" id="so">${co}</div>
    <div class="ss">politique : $(_pol_badge "${po}")</div>
    <span class="sbg $([ "${po}" = "ACCEPT" ]&&echo a||echo d)">${po:-?}</span>
  </div>
  <div class="sc y">
    <div class="sl">FORWARD</div>
    <div class="sv y" id="sf">${cf}</div>
    <div class="ss">politique : $(_pol_badge "${pf}")</div>
    <span class="sbg $([ "${pf}" = "ACCEPT" ]&&echo a||echo d)">${pf:-?}</span>
  </div>
  <div class="sc p">
    <div class="sl">Total règles</div>
    <div class="sv p" id="st">${ct}</div>
    <div class="ss">toutes chaînes</div>
  </div>
  <div class="sc">
    <div class="sl">Connexions</div>
    <div class="sv w" id="sconn">${conns}</div>
    <div class="ss">établies TCP</div>
  </div>
</div>
STATSEOF

    if [ "${has_ip6}" -eq 1 ]; then
        cat << IP6EOF
<div class="card" style="border-color:rgba(124,58,237,.22)">
  <div class="card-hd">
    <div class="card-t" style="color:var(--ac2)"><span class="ic">⊕</span> IPv6 — ip6tables</div>
    <a href="/rules?v=6" class="btn btn-sm" style="border-color:rgba(124,58,237,.3);color:var(--ac2)">Gérer →</a>
  </div>
  <div class="srow" style="margin-bottom:0">
    <div class="sc" style="border-color:rgba(124,58,237,.15)">
      <div class="sl">INPUT6</div><div class="sv p" id="si6">${ci6}</div>
    </div>
    <div class="sc" style="border-color:rgba(124,58,237,.15)">
      <div class="sl">OUTPUT6</div><div class="sv p" id="so6">${co6}</div>
    </div>
    <div class="sc" style="border-color:rgba(124,58,237,.15)">
      <div class="sl">FORWARD6</div><div class="sv p" id="sf6">${cf6}</div>
    </div>
    <div class="sc" style="border-color:rgba(124,58,237,.15)">
      <div class="sl">Total IPv6</div><div class="sv p" id="st6">${ct6}</div>
    </div>
  </div>
</div>
IP6EOF
    fi

    # System + gauges
    cat << SYSEOF
<div class="g2">

  <div class="card">
    <div class="card-hd"><div class="card-t"><span class="ic">⊞</span> Système</div>
      <a href="/network" class="btn btn-sm btn-s">Réseau →</a></div>
    <div style="display:grid;grid-template-columns:1fr 1fr;gap:.5rem;margin-bottom:.9rem">
      <div><div class="sl">Hôte</div><div style="font-family:var(--mo);color:var(--ac);font-size:.88rem">${hn}</div></div>
      <div><div class="sl">IP</div><div style="font-family:var(--mo);font-size:.85rem">${iv}</div></div>
      <div><div class="sl">Uptime</div><div style="font-family:var(--mo);color:var(--gr);font-size:.82rem">${uv}</div></div>
      <div><div class="sl">Load avg</div><div style="font-family:var(--mo);font-size:.82rem">${load}</div></div>
    </div>
    <div class="sl" style="margin-bottom:.45rem">Politiques par défaut</div>
    <div class="prow">
      <div class="pi"><span class="pn2">INPUT</span><span class="pv $(_pvcls "${pi}")">${pi:-?}</span></div>
      <div class="pi"><span class="pn2">OUTPUT</span><span class="pv $(_pvcls "${po}")">${po:-?}</span></div>
      <div class="pi"><span class="pn2">FORWARD</span><span class="pv $(_pvcls "${pf}")">${pf:-?}</span></div>
    </div>
  </div>

  <div class="card">
    <div class="card-hd"><div class="card-t"><span class="ic">◎</span> Ressources système</div></div>
    <div style="display:flex;flex-direction:column;gap:1rem">
      <div style="display:flex;align-items:center;gap:.9rem">
        <div id="cpu-gauge" style="position:relative;width:72px;height:72px;border-radius:50%;background:conic-gradient(${cpu_color} ${cpu_deg}deg,#162035 ${cpu_deg}deg 360deg);flex-shrink:0;display:grid;place-items:center">
          <div style="width:54px;height:54px;border-radius:50%;background:var(--b1);display:flex;flex-direction:column;align-items:center;justify-content:center">
            <span class="gi" style="font-family:var(--mo);font-size:.85rem;font-weight:800;color:${cpu_color}">${cpu_pct}%</span>
          </div>
        </div>
        <div style="flex:1">
          <div style="font-family:var(--mo);font-size:.72rem;font-weight:700;color:var(--tx);text-transform:uppercase;letter-spacing:.07em;margin-bottom:.3rem">CPU</div>
          <div style="font-family:var(--mo);font-size:.67rem;color:var(--mu);margin-bottom:.3rem">${ncpu} cœur(s) · load ${load}</div>
          <div style="height:4px;background:var(--b3);border-radius:2px;overflow:hidden">
            <div class="gb" style="height:100%;width:${cpu_pct}%;background:${cpu_color};border-radius:2px;transition:width .8s"></div>
          </div>
        </div>
      </div>
      <div style="display:flex;align-items:center;gap:.9rem">
        <div id="mem-gauge" style="position:relative;width:72px;height:72px;border-radius:50%;background:conic-gradient(${mem_color} ${mem_deg}deg,#162035 ${mem_deg}deg 360deg);flex-shrink:0;display:grid;place-items:center">
          <div style="width:54px;height:54px;border-radius:50%;background:var(--b1);display:flex;flex-direction:column;align-items:center;justify-content:center">
            <span class="gi" style="font-family:var(--mo);font-size:.85rem;font-weight:800;color:${mem_color}">${mem_pct}%</span>
          </div>
        </div>
        <div style="flex:1">
          <div style="font-family:var(--mo);font-size:.72rem;font-weight:700;color:var(--tx);text-transform:uppercase;letter-spacing:.07em;margin-bottom:.3rem">RAM</div>
          <div style="font-family:var(--mo);font-size:.67rem;color:var(--mu);margin-bottom:.3rem">$(awk "BEGIN{printf \"%.0f/%.0f MiB\", $mem_used/1024, $mem_t/1024}")</div>
          <div style="height:4px;background:var(--b3);border-radius:2px;overflow:hidden">
            <div class="gb" style="height:100%;width:${mem_pct}%;background:${mem_color};border-radius:2px;transition:width .8s"></div>
          </div>
        </div>
      </div>
    </div>
  </div>

</div>
SYSEOF

    # Services + Quick ban
    cat << QEOF
<div class="g2">

  <div class="card">
    <div class="card-hd"><div class="card-t"><span class="ic">⊕</span> Services détectés</div></div>
    <div class="pgrid">
$(
    local pd; pd=$(ss -tlnp 2>/dev/null||netstat -tlnp 2>/dev/null||echo "")
    while IFS= read -r pline; do
        local pnum sname
        pnum=$(echo "${pline}"|awk '{print $4}'|rev|cut -d: -f1|rev)
        [[ "${pnum}" =~ ^[0-9]+$ ]]||continue
        case "${pnum}" in
            22)    sname="SSH" ;;     80)   sname="HTTP" ;;    443)  sname="HTTPS" ;;
            25)    sname="SMTP" ;;    587)  sname="SMTPS" ;;   993)  sname="IMAPS" ;;
            3306)  sname="MySQL" ;;   5432) sname="PgSQL" ;;   6379) sname="Redis" ;;
            8080)  sname="HTTP-alt" ;;51820) sname="WireGuard" ;;*)  sname="port ${pnum}" ;;
        esac
        local ia; ia=$(iptables -L INPUT -n 2>/dev/null|grep "dpt:${pnum}"|grep -c ACCEPT 2>/dev/null); ia=${ia:-0}
        if [ "${ia}" -gt 0 ]; then
            printf '      <span class="pc po" title="ACCEPT dans iptables">%s:%s ✓</span>\n' "${sname}" "${pnum}"
        else
            printf '      <span class="pc pn" title="Aucune règle ACCEPT">%s:%s</span>\n' "${sname}" "${pnum}"
        fi
    done < <(echo "${pd}"|grep LISTEN|grep -v '^Netid'||true)
)
    </div>
  </div>

  <div class="card">
    <div class="card-hd"><div class="card-t"><span class="ic">⊘</span> Bannissement rapide</div></div>
    <form method="POST" action="/quick-ban">
      <div class="fgrid">
        <div class="fg" style="grid-column:span 2">
          <label for="qbip">Adresse IP</label>
          <input type="text" id="qbip" name="ip" placeholder="192.168.1.100 ou 10.0.0.0/24" required>
        </div>
        <div class="fg">
          <label for="qbch">Chaîne</label>
          <select id="qbch" name="chain">
            <option value="INPUT">INPUT</option>
            <option value="OUTPUT">OUTPUT</option>
            <option value="FORWARD">FORWARD</option>
          </select>
        </div>
        <div class="fg">
          <label for="qbac">Action</label>
          <select id="qbac" name="action">
            <option value="DROP">DROP</option>
            <option value="REJECT">REJECT</option>
            <option value="ACCEPT">ACCEPT</option>
          </select>
        </div>
        <div class="fg">
          <label>&nbsp;</label>
          <button class="btn btn-d" type="submit">⊘ Bannir</button>
        </div>
      </div>
    </form>
$(
    if [ -f "${_LOG_FILE}" ]; then
        local bans; bans=$(grep -i "quick-ban\|quick ban" "${_LOG_FILE}" 2>/dev/null|tail -5)
        if [ -n "${bans}" ]; then
            echo '<hr class="dv"><div style="font-size:.72rem;color:var(--mu);font-family:var(--mo);margin-bottom:.3rem">Bans récents</div>'
            echo "${bans}" | while IFS= read -r bl; do
                local ts_b ip_b act_b
                ts_b=$(echo "${bl}"|awk '{print $1" "$2}')
                ip_b=$(echo "${bl}"|grep -oP '[\d.]+/\d+|[\d.]{7,}')
                act_b=$(echo "${bl}"|grep -oP 'DROP|REJECT|ACCEPT'|tail -1)
                printf '<div style="display:flex;gap:.5rem;padding:.18rem 0;font-family:var(--mo);font-size:.72rem;border-bottom:1px solid var(--bd)"><span style="color:var(--mu2)">%s</span><span>%s</span><span class="badge %s">%s</span></div>\n' \
                    "${ts_b}" "${ip_b}" "$([ "${act_b}" = "DROP" ]||[ "${act_b}" = "REJECT" ]&&echo bd||echo ba)" "${act_b:-?}"
            done
            echo '</div>'
        fi
    fi
)
  </div>

</div>
QEOF

    # Chart + recent logs
    cat << CHARTEOF
<div class="card">
  <div class="card-hd">
    <div class="card-t"><span class="ic">◫</span> Répartition des règles</div>
    <span class="mu" style="font-size:.7rem;font-family:var(--mo)">mis à jour toutes les <span id="ri-lbl">4</span>s</span>
  </div>
  <div class="chwrap"><canvas id="rChart"></canvas></div>
</div>

<div class="card">
  <div class="card-hd">
    <div class="card-t"><span class="ic">≡</span> Activité récente</div>
    <a href="/logs" class="btn btn-sm btn-s">Tout voir →</a>
  </div>
  <div class="logblock">
    <div class="logbody" style="max-height:200px">
$(
    if [ -f "${_LOG_FILE}" ]; then
        tail -n 12 "${_LOG_FILE}"|while IFS= read -r l; do
            local cls; echo "${l}"|grep -qi accept&&cls=la||echo "${l}"|grep -qi "drop\|reject\|deni"&&cls=ld||echo "${l}"|grep -qi "error\|fail\|erreur"&&cls=le||cls=li
            local s; s=$(printf '%s' "${l}"|sed 's/&/\&amp;/g;s/</\&lt;/g;s/>/\&gt;/g')
            printf '      <div class="ll %s">%s</div>\n' "${cls}" "${s}"
        done
    else echo '      <div class="ll li">Aucune entrée disponible.</div>'; fi
)
    </div>
  </div>
</div>

<div class="card">
  <div class="card-hd"><div class="card-t"><span class="ic">⚡</span> Actions rapides</div></div>
  <div class="ab">
    <form method="POST" action="/apply-preset" style="display:inline">
      <input type="hidden" name="preset" value="web">
      <button class="btn btn-s" type="submit">🌐 Web (HTTP+HTTPS+SSH)</button>
    </form>
    <form method="POST" action="/apply-preset" style="display:inline">
      <input type="hidden" name="preset" value="ssh">
      <button class="btn btn-s" type="submit">🔑 SSH uniquement</button>
    </form>
    <form method="POST" action="/apply-preset" style="display:inline" onsubmit="return confirm('Mode panique : tout bloquer ?')">
      <input type="hidden" name="preset" value="panic">
      <button class="btn btn-d" type="submit">⚠ Mode Panique</button>
    </form>
    <form method="POST" action="/apply-preset" style="display:inline" onsubmit="return confirm('Vider toutes les règles ?')">
      <input type="hidden" name="preset" value="flush_all">
      <button class="btn btn-w" type="submit">⟳ Flush All</button>
    </form>
    <a href="/rules" class="btn btn-p">Gérer les règles →</a>
    <a href="/export" class="btn btn-s" title="Télécharger iptables-save">↓ Exporter</a>
  </div>
</div>
CHARTEOF

    html_footer
}

# ── page_rules ────────────────────────────────────────────────────────────────
page_rules() {
    local fm; fm=$(printf '%s' "${QUERY_STRING:-}"|grep -oE 'msg=[^&]*'|cut -d= -f2)
    local ipver; ipver=$(printf '%s' "${QUERY_STRING:-}"|grep -oE 'v=[^&]*'|cut -d= -f2)
    [ "$ipver" = "6" ] && local _ipt="ip6tables" || local _ipt="iptables"
    local has_ip6=0; command -v ip6tables &>/dev/null && has_ip6=1

    html_header "Règles iptables" "rules"
    printf '<div class="pt"><span class="ic">⊟</span> Règles iptables</div>\n'
    [ -n "${fm}" ] && _flash_msg "${fm}"

    # ── Onglet IPv4 / IPv6 ───────────────────────────────────────────────────
    if [ "${has_ip6}" -eq 1 ]; then
        local t4="" t6=""
        [ "$ipver" = "6" ] && t6=' style="background:rgba(124,58,237,.12);border-color:rgba(124,58,237,.4);color:var(--ac2)"' || t4=' style="background:rgba(0,210,255,.1);border-color:var(--ac);color:var(--ac)"'
        printf '<div style="display:flex;gap:.4rem;margin-bottom:.9rem">\n'
        printf '  <a href="/rules" class="btn btn-sm btn-s"%s>IPv4 iptables</a>\n' "${t4}"
        printf '  <a href="/rules?v=6" class="btn btn-sm btn-s"%s>IPv6 ip6tables</a>\n' "${t6}"
        printf '</div>\n'
    fi

    _chain_table() {
        local ch="$1"
        local raw total_rules
        raw=$("${_ipt}" -L "${ch}" --line-numbers -n 2>/dev/null||true)
        total_rules=$(printf '%s' "${raw}"|tail -n+3|grep -v '^$'|wc -l)

        cat << CHTEOF
<div class="card">
  <div class="card-hd">
    <div class="card-t"><span class="ic">▷</span> Chaîne ${ch} <span class="badge bb">${total_rules}</span></div>
    <div style="display:flex;gap:.4rem;align-items:center;flex-wrap:wrap">
      <div class="srch"><input type="search" placeholder="Filtrer…" data-search="tbl-${ch}" style="width:140px"></div>
      <a href="/export" class="btn btn-sm btn-s" title="Exporter toutes les règles">↓</a>
      <form method="POST" action="/flush" style="display:inline">
        <input type="hidden" name="chain" value="${ch}">
        <input type="hidden" name="ipt" value="${ipver:-4}">
        <button class="btn btn-sm btn-d" type="submit" onclick="return confirm('Vider la chaîne ${ch} ?')">⊘ Vider</button>
      </form>
    </div>
  </div>
  <div class="tw">
  <table id="tbl-${ch}">
    <thead><tr><th>#</th><th>Cible</th><th>Proto</th><th>Source</th><th>Destination</th><th>Options</th><th style="text-align:center">Ordre</th><th></th></tr></thead>
    <tbody>
CHTEOF
        local lno=0 total_lno=0
        while IFS= read -r line; do
            lno=$((lno+1))
            [ "${lno}" -le 2 ]&&continue; [ -z "${line}" ]&&continue
            total_lno=$((total_lno+1))
        done <<< "${raw}"

        lno=0; local ruleno=0
        while IFS= read -r line; do
            lno=$((lno+1)); [ "${lno}" -le 2 ]&&continue; [ -z "${line}" ]&&continue
            ruleno=$((ruleno+1))
            local num tgt prot src dst opts
            num=$(echo "${line}"|awk '{print $1}')
            tgt=$(echo "${line}"|awk '{print $2}')
            prot=$(echo "${line}"|awk '{print $3}')
            src=$(echo "${line}"|awk '{print $4}')
            dst=$(echo "${line}"|awk '{print $5}')
            opts=$(echo "${line}"|awk '{$1=$2=$3=$4=$5="";print $0}'|sed 's/^ *//')
            local up_dis="" dn_dis=""
            [ "${ruleno}" -eq 1 ]&&up_dis=' style="opacity:.25;pointer-events:none"'
            [ "${ruleno}" -eq "${total_lno}" ]&&dn_dis=' style="opacity:.25;pointer-events:none"'
            cat << ROWEOF
    <tr>
      <td style="color:var(--mu);font-size:.72rem">${num}</td>
      <td>$(_tgt_badge "${tgt}")</td>
      <td>${prot}</td>
      <td>${src}</td>
      <td>${dst}</td>
      <td style="color:var(--mu);font-size:.74rem;max-width:180px">${opts}</td>
      <td style="text-align:center;white-space:nowrap">
        <form method="POST" action="/move-rule" style="display:inline">
          <input type="hidden" name="num" value="${num}"><input type="hidden" name="chain" value="${ch}"><input type="hidden" name="dir" value="up"><input type="hidden" name="ipt" value="${ipver:-4}">
          <button class="btn btn-sm btn-s" type="submit" title="Monter"${up_dis}>↑</button>
        </form>
        <form method="POST" action="/move-rule" style="display:inline">
          <input type="hidden" name="num" value="${num}"><input type="hidden" name="chain" value="${ch}"><input type="hidden" name="dir" value="down"><input type="hidden" name="ipt" value="${ipver:-4}">
          <button class="btn btn-sm btn-s" type="submit" title="Descendre"${dn_dis}>↓</button>
        </form>
      </td>
      <td>
        <form method="POST" action="/delete-rule" style="display:inline">
          <input type="hidden" name="num" value="${num}"><input type="hidden" name="chain" value="${ch}"><input type="hidden" name="ipt" value="${ipver:-4}">
          <button class="btn btn-sm btn-d" type="submit" onclick="return confirm('Supprimer règle #${num} de ${ch} ?')" title="Supprimer">✕</button>
        </form>
      </td>
    </tr>
ROWEOF
        done <<< "${raw}"

        if [ "${total_lno}" -eq 0 ]; then
            printf '    <tr><td colspan="8" style="text-align:center;padding:1.2rem;color:var(--mu);font-size:.82rem">Aucune règle dans cette chaîne</td></tr>\n'
        fi
        printf '    </tbody>\n  </table>\n  </div>\n</div>\n'
    }

    for ch in INPUT OUTPUT FORWARD; do _chain_table "${ch}"; done

    # Chaînes personnalisées
    local custom_chains
    custom_chains=$("${_ipt}" -L --line-numbers -n 2>/dev/null | grep '^Chain' | awk '{print $2}' | grep -vE '^(INPUT|OUTPUT|FORWARD)$' || true)
    if [ -n "${custom_chains}" ]; then
        printf '<div class="card"><div class="card-hd"><div class="card-t"><span class="ic">◧</span> Chaînes personnalisées</div></div>\n'
        printf '<div style="display:flex;flex-wrap:wrap;gap:.4rem;margin-bottom:.7rem">\n'
        for cch in ${custom_chains}; do
            local ccount; ccount=$("${_ipt}" -L "${cch}" --line-numbers -n 2>/dev/null|tail -n+3|grep -v '^$'|wc -l)
            printf '<span class="badge bp" style="font-size:.76rem;padding:.2rem .6rem">%s <span style="color:var(--mu);margin-left:.3rem">%s règle(s)</span></span>\n' "${cch}" "${ccount}"
        done
        printf '</div>\n'
        printf '<div style="display:flex;gap:.4rem;flex-wrap:wrap">\n'
        for cch in ${custom_chains}; do
            printf '<form method="POST" action="/delete-chain" style="display:inline"><input type="hidden" name="name" value="%s"><input type="hidden" name="ipt" value="%s"><button class="btn btn-sm btn-d" type="submit" onclick="return confirm('"'"'Supprimer la chaîne %s ?'"'"')">✕ %s</button></form>\n' "${cch}" "${ipver:-4}" "${cch}" "${cch}"
        done
        printf '</div></div>\n'
    fi

    cat << FORMEOF
<div class="card">
  <div class="card-hd">
    <div class="card-t"><span class="ic">⊕</span> Ajouter une règle</div>
    <span class="badge $([ "${ipver}" = "6" ]&&echo bp||echo bb)">$([ "${ipver}" = "6" ]&&echo "IPv6 ip6tables"||echo "IPv4 iptables")</span>
  </div>
  <form method="POST" action="/add-rule">
    <input type="hidden" name="ipt" value="${ipver:-4}">
    <div class="fgrid">
      <div class="fg"><label>Chaîne</label>
        <select name="chain"><option value="INPUT">INPUT</option><option value="OUTPUT">OUTPUT</option><option value="FORWARD">FORWARD</option></select></div>
      <div class="fg"><label>Protocole</label>
        <select name="proto"><option value="tcp">TCP</option><option value="udp">UDP</option><option value="icmp">ICMP</option><option value="all">Tous</option></select></div>
      <div class="fg"><label>Port (vide=tous)</label>
        <input type="text" name="port" placeholder="80  ou  8000:8080"></div>
      <div class="fg"><label>IP source (vide=toutes)</label>
        <input type="text" name="src" placeholder="192.168.1.0/24"></div>
      <div class="fg"><label>Action</label>
        <select name="action"><option value="ACCEPT">ACCEPT</option><option value="DROP">DROP</option><option value="REJECT">REJECT</option></select></div>
      <div class="fg"><label>Commentaire (optionnel)</label>
        <input type="text" name="comment" placeholder="ex : Allow HTTP" maxlength="64"></div>
      <div class="fg"><label>&nbsp;</label>
        <button class="btn btn-p" type="submit">⊕ Ajouter</button></div>
    </div>
  </form>
</div>

<div class="card">
  <div class="card-hd"><div class="card-t"><span class="ic">◧</span> Créer une chaîne personnalisée</div></div>
  <form method="POST" action="/add-chain" style="display:flex;gap:.5rem;align-items:flex-end;flex-wrap:wrap">
    <input type="hidden" name="ipt" value="${ipver:-4}">
    <div class="fg" style="flex:1;min-width:160px"><label>Nom de la chaîne</label>
      <input type="text" name="name" placeholder="ex : MY_CHAIN" maxlength="28" pattern="[a-zA-Z0-9_-]+" required></div>
    <button class="btn btn-g" type="submit">⊕ Créer</button>
  </form>
</div>
FORMEOF

    html_footer
}

# ── page_logs ─────────────────────────────────────────────────────────────────
page_logs() {
    local log_count
    log_count=$([ -f "${_LOG_FILE}" ]&&wc -l<"${_LOG_FILE}"||echo 0)

    html_header "Journaux" "logs"
    cat << LOGEOF
<div class="pt"><span class="ic">≡</span> Journaux Fire-UX</div>
<div class="logblock">
  <div class="logtb">
    <div class="srch"><input type="search" id="lsrch" placeholder="Rechercher…" style="width:200px"></div>
    <select id="lflt" style="width:130px">
      <option value="">Tous</option>
      <option value="accept">ACCEPT</option>
      <option value="drop">DROP/REJECT</option>
      <option value="error">Erreurs</option>
    </select>
    <button id="arb" class="btn btn-sm btn-s">⏸ Pause</button>
    <button onclick="const b=document.getElementById('lb');b&&(b.scrollTop=b.scrollHeight)" class="btn btn-sm btn-s">↓ Bas</button>
    <form method="POST" action="/clear-logs" style="display:inline" onsubmit="return confirm('Vider tous les journaux ?')">
      <button class="btn btn-sm btn-d" type="submit">⊘ Vider</button>
    </form>
    <span style="margin-left:auto;font-family:var(--mo);font-size:.67rem;color:var(--mu)">
      total : <span id="logcnt">${log_count}</span> · 5s
    </span>
  </div>
  <div class="logbody" id="lb">
$(
    if [ -f "${_LOG_FILE}" ]; then
        tail -n 100 "${_LOG_FILE}"|while IFS= read -r l; do
            local cls; echo "${l}"|grep -qi accept&&cls=la||echo "${l}"|grep -qi "drop\|reject\|deni"&&cls=ld||echo "${l}"|grep -qi "error\|fail\|erreur"&&cls=le||cls=li
            local s; s=$(printf '%s' "${l}"|sed 's/&/\&amp;/g;s/</\&lt;/g;s/>/\&gt;/g')
            printf '    <div class="ll %s">%s</div>\n' "${cls}" "${s}"
        done
    else echo '    <div class="ll li">Fichier journal introuvable : '"${_LOG_FILE}"'</div>'; fi
)
  </div>
</div>
LOGEOF
    html_footer
}

# ── page_profiles ─────────────────────────────────────────────────────────────
page_profiles() {
    local fm; fm=$(printf '%s' "${QUERY_STRING:-}"|grep -oE 'msg=[^&]*'|cut -d= -f2)

    html_header "Profils" "profiles"
    printf '<div class="pt"><span class="ic">◈</span> Profils sauvegardés</div>\n'
    [ -n "${fm}" ] && _flash_msg "${fm}"

    cat << PROFEOF
<div class="card">
  <div class="card-hd">
    <div class="card-t"><span class="ic">◫</span> Profils iptables</div>
    <form method="POST" action="/save-snapshot" style="display:inline;display:flex;gap:.4rem;align-items:center">
      <input type="text" name="name" placeholder="Nom (optionnel)" maxlength="48" style="width:180px;padding:.22rem .52rem;font-size:.71rem">
      <button class="btn btn-sm btn-g" type="submit">💾 Snapshot</button>
    </form>
  </div>
PROFEOF

    if [ -d "${_PROFILES_DIR}" ] && [ -n "$(ls -A "${_PROFILES_DIR}" 2>/dev/null)" ]; then
        echo '  <div class="tw"><table>'
        echo '    <thead><tr><th>Nom</th><th>Date</th><th>Taille</th><th>Aperçu</th><th></th></tr></thead>'
        echo '    <tbody>'
        for pf in "${_PROFILES_DIR}"/*; do
            [ -f "${pf}" ]||continue
            local pn pd ps pv
            pn=$(basename "${pf}")
            pd=$(date -r "${pf}" '+%Y-%m-%d %H:%M' 2>/dev/null||stat -c '%y' "${pf}" 2>/dev/null|cut -d. -f1)
            ps=$(du -sh "${pf}" 2>/dev/null|awk '{print $1}')
            pv=$(head -n 2 "${pf}" 2>/dev/null|tr '\n' ' '|sed 's/&/\&amp;/g;s/</\&lt;/g;s/>/\&gt;/g')
            cat << ROWEOF
    <tr>
      <td><code>${pn}</code></td>
      <td style="color:var(--mu);font-size:.75rem">${pd}</td>
      <td style="color:var(--mu)">${ps}</td>
      <td style="max-width:240px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;font-size:.72rem;color:var(--mu)">${pv}</td>
      <td style="white-space:nowrap">
        <form method="POST" action="/apply-profile" style="display:inline">
          <input type="hidden" name="name" value="${pn}">
          <button class="btn btn-sm btn-w" type="submit" onclick="return confirm('Appliquer ${pn} ?')">Appliquer</button>
        </form>
        <form method="POST" action="/delete-profile" style="display:inline">
          <input type="hidden" name="name" value="${pn}">
          <button class="btn btn-sm btn-d" type="submit" onclick="return confirm('Supprimer le profil ${pn} ?')">✕</button>
        </form>
      </td>
    </tr>
ROWEOF
        done
        echo '    </tbody></table></div>'
    else
        echo '  <p style="color:var(--mu);font-size:.88rem;padding:.5rem 0">Aucun profil. Cliquez sur « Snapshot actuel » pour créer le premier.</p>'
    fi
    echo '</div>'

    cat << HEOF
<div class="card">
  <div class="card-hd"><div class="card-t"><span class="ic">?</span> Comment utiliser</div></div>
  <ul style="color:var(--mu);font-size:.85rem;line-height:1.9;padding-left:1.1rem">
    <li><strong style="color:var(--tx)">Snapshot actuel</strong> — sauvegarde l'état courant sous un profil horodaté.</li>
    <li><strong style="color:var(--tx)">Appliquer</strong> — restaure les règles via <code>iptables-restore</code>.</li>
    <li><strong style="color:var(--tx)">Supprimer</strong> — efface le fichier de profil définitivement.</li>
    <li>Stockage : <code>${_PROFILES_DIR}/</code></li>
  </ul>
</div>
HEOF
    html_footer
}

# ── page_network ──────────────────────────────────────────────────────────────
page_network() {
    html_header "Réseau" "network"
    printf '<div class="pt"><span class="ic">⊕</span> Réseau</div>\n'

    # Interfaces
    echo '<div class="card"><div class="card-hd"><div class="card-t"><span class="ic">⊕</span> Interfaces réseau</div></div>'
    echo '<div class="igrid">'
    while IFS= read -r iface; do
        local ip mac state dc
        ip=$(ip addr show "${iface}" 2>/dev/null|grep 'inet '|awk '{print $2}'|head -1||echo "—")
        mac=$(ip addr show "${iface}" 2>/dev/null|grep 'link/ether'|awk '{print $2}'|head -1||echo "—")
        state=$(ip link show "${iface}" 2>/dev/null|grep -o 'state [A-Z]*'|awk '{print $2}'||echo "?")
        dc=$( [ "${state}" = "UP" ]&&echo ud||echo dd )
        cat << IFEOF
  <div class="ifc">
    <div class="ifn">${iface}</div>
    <div class="ifip">${ip:-—}</div>
    <div class="ifm">${mac:-—}</div>
    <div class="ifs"><span class="${dc}"></span>${state}</div>
  </div>
IFEOF
    done < <(ip -o link show 2>/dev/null|awk -F': ' '{print $2}'|awk '{print $1}'|sed 's/@.*//'||true)
    echo '</div></div>'

    # Routing
    echo '<div class="card"><div class="card-hd"><div class="card-t"><span class="ic">⇢</span> Table de routage</div></div>'
    echo '<div class="tw"><table><thead><tr><th>Destination</th><th>Passerelle</th><th>Interface</th><th>Proto</th><th>Metric</th></tr></thead><tbody>'
    while IFS= read -r rline; do
        [ -z "${rline}" ]&&continue
        local dest gw dev proto metric
        dest=$(echo "${rline}"|awk '{print $1}')
        gw=$(echo "${rline}"|grep -oP 'via \K[^ ]+'||echo "—")
        dev=$(echo "${rline}"|grep -oP 'dev \K[^ ]+'||echo "—")
        proto=$(echo "${rline}"|grep -oP 'proto \K[^ ]+'||echo "—")
        metric=$(echo "${rline}"|grep -oP 'metric \K[^ ]+'||echo "—")
        printf '  <tr><td>%s</td><td>%s</td><td><span class="badge bb">%s</span></td><td><span class="badge bg">%s</span></td><td class="mu">%s</td></tr>\n' \
            "${dest}" "${gw}" "${dev}" "${proto}" "${metric}"
    done < <(ip route show 2>/dev/null||true)
    echo '</tbody></table></div></div>'

    # Listening ports
    echo '<div class="card"><div class="card-hd"><div class="card-t"><span class="ic">⊡</span> Ports en écoute</div></div>'
    echo '<div class="tw"><table><thead><tr><th>Proto</th><th>Adresse locale</th><th>PID / Processus</th></tr></thead><tbody>'
    local lc=0
    while IFS= read -r lline; do
        [ -z "${lline}" ] && continue
        local lproto laddr lpid
        lproto=$(echo "${lline}" | awk '{print $1}')
        laddr=$(echo "${lline}"  | awk '{print $4}')
        lpid=$(echo "${lline}"   | awk '{print $6}' | grep -oP 'pid=\K[0-9]+' | head -1 || true)
        local lpname="—"
        [ -n "${lpid}" ] && lpname=$(cat "/proc/${lpid}/comm" 2>/dev/null || echo "pid ${lpid}")
        printf '  <tr><td><span class="badge bg">%s</span></td><td style="font-family:var(--mo);font-size:.78rem">%s</td><td style="color:var(--mu);font-size:.75rem">%s</td></tr>\n' \
            "${lproto}" "${laddr}" "${lpname}"
        lc=$((lc+1))
    done < <(ss -tlnp 2>/dev/null | tail -n+2 | grep -v '^$' || true)
    [ "${lc}" -eq 0 ] && echo '  <tr><td colspan="3" class="mu" style="text-align:center;padding:.8rem">Aucun port en écoute détecté</td></tr>'
    echo '</tbody></table></div></div>'

    # Active connections
    local cc; cc=$(ss -tn state established 2>/dev/null|tail -n+2|wc -l||echo 0)
    echo '<div class="card">'
    printf '<div class="card-hd"><div class="card-t"><span class="ic">⊡</span> Connexions établies</div><span class="badge bb">%s</span></div>\n' "${cc}"
    echo '<div class="tw"><table><thead><tr><th>Proto</th><th>Local</th><th>Distant</th></tr></thead><tbody>'
    local cn=0
    while IFS= read -r cline; do
        [ $cn -ge 25 ]&&break; [ -z "${cline}" ]||echo "${cline}"|grep -q '^Netid'&&continue
        printf '  <tr><td><span class="badge bg">%s</span></td><td>%s</td><td>%s</td></tr>\n' \
            "$(echo "${cline}"|awk '{print $1}')" \
            "$(echo "${cline}"|awk '{print $4}')" \
            "$(echo "${cline}"|awk '{print $5}')"
        cn=$((cn+1))
    done < <(ss -tn state established 2>/dev/null|tail -n+2||true)
    [ "${cc}" -gt 25 ]&&printf '  <tr><td colspan="3" class="mu" style="text-align:center;font-size:.75rem">… et %d autres</td></tr>\n' "$((cc-25))"
    echo '</tbody></table></div></div>'

    html_footer
}

# ── page_settings ─────────────────────────────────────────────────────────────
page_settings() {
    local pid_val; pid_val="${SERVER_PID:-—}"
    local fm; fm=$(printf '%s' "${QUERY_STRING:-}"|grep -oE 'msg=[^&]*'|cut -d= -f2)
    local conf="/etc/fire-ux/web.conf"
    local cur_port="8080"
    [ -f "${conf}" ] && { cur_port=$(grep -oP 'WEB_PORT=\K[0-9]+' "${conf}" 2>/dev/null || echo "8080"); }
    local auth_status="Désactivée"
    [ -f "/etc/fire-ux/.auth" ] && [ -s "/etc/fire-ux/.auth" ] && auth_status="Activée (mot de passe défini)"

    html_header "Paramètres" "settings"
    [ -n "${fm}" ] && _flash_msg "${fm}"

    cat << 'SETEOF'
<div class="pt"><span class="ic">⚙</span> Paramètres</div>

<div class="card">
  <div class="card-hd"><div class="card-t"><span class="ic">⊞</span> Interface web</div></div>

  <div class="set-row">
    <div class="set-info">
      <div class="set-lbl">Intervalle de rafraîchissement</div>
      <div class="set-desc">Fréquence de mise à jour des statistiques</div>
    </div>
    <div class="set-ctrl">
      <select id="set-refresh" onchange="localStorage.setItem('refresh',this.value);toast('Rechargement dans 1s…','info');setTimeout(()=>location.reload(),1000)" style="width:auto">
        <option value="2">2 secondes</option>
        <option value="4">4 secondes (défaut)</option>
        <option value="10">10 secondes</option>
        <option value="30">30 secondes</option>
        <option value="0">Désactivé</option>
      </select>
    </div>
  </div>

  <div class="set-row">
    <div class="set-info">
      <div class="set-lbl">Lignes de logs affichées</div>
      <div class="set-desc">Nombre de lignes dans la vue des journaux</div>
    </div>
    <div class="set-ctrl">
      <select id="set-loglines" onchange="localStorage.setItem('loglines',this.value);toast('Sauvegardé','ok')" style="width:auto">
        <option value="50">50 lignes</option>
        <option value="100">100 lignes (défaut)</option>
        <option value="200">200 lignes</option>
        <option value="500">500 lignes</option>
      </select>
    </div>
  </div>

  <div class="set-row">
    <div class="set-info">
      <div class="set-lbl">Auto-scroll des logs</div>
      <div class="set-desc">Faire défiler automatiquement vers les nouvelles entrées</div>
    </div>
    <div class="set-ctrl">
      <label class="toggle">
        <input type="checkbox" id="set-autoscroll" onchange="localStorage.setItem('autoscroll',this.checked);toast('Sauvegardé','ok')">
        <span class="slider"></span>
      </label>
    </div>
  </div>

  <div class="set-row">
    <div class="set-info">
      <div class="set-lbl">Effacer les paramètres</div>
      <div class="set-desc">Réinitialiser tous les paramètres aux valeurs par défaut</div>
    </div>
    <div class="set-ctrl">
      <button class="btn btn-sm btn-d" onclick="localStorage.clear();toast('Paramètres réinitialisés','ok');setTimeout(()=>location.reload(),1000)">Réinitialiser</button>
    </div>
  </div>
</div>

<div class="card">
  <div class="card-hd"><div class="card-t"><span class="ic">⊙</span> API endpoints</div></div>
  <div class="tw"><table>
    <thead><tr><th>Route</th><th>Méthode</th><th>Description</th></tr></thead>
    <tbody>
      <tr><td><a href="/" style="color:var(--ac)">/</a></td><td><span class="badge bg">GET</span></td><td>Tableau de bord</td></tr>
      <tr><td><a href="/rules" style="color:var(--ac)">/rules</a></td><td><span class="badge bg">GET</span></td><td>Gestion des règles</td></tr>
      <tr><td><a href="/logs" style="color:var(--ac)">/logs</a></td><td><span class="badge bg">GET</span></td><td>Journaux</td></tr>
      <tr><td><a href="/network" style="color:var(--ac)">/network</a></td><td><span class="badge bg">GET</span></td><td>Réseau et interfaces</td></tr>
      <tr><td><a href="/profiles" style="color:var(--ac)">/profiles</a></td><td><span class="badge bg">GET</span></td><td>Profils sauvegardés</td></tr>
      <tr><td><a href="/api/stats" style="color:var(--ac)">/api/stats</a></td><td><span class="badge bg">GET</span></td><td>JSON stats système + iptables</td></tr>
      <tr><td><a href="/api/logs" style="color:var(--ac)">/api/logs?n=100</a></td><td><span class="badge bg">GET</span></td><td>JSON dernières N lignes de log</td></tr>
      <tr><td><a href="/api/health" style="color:var(--ac)">/api/health</a></td><td><span class="badge bg">GET</span></td><td>JSON alertes de sécurité</td></tr>
      <tr><td><a href="/export" style="color:var(--ac)">/export</a></td><td><span class="badge bg">GET</span></td><td>Télécharger iptables-save</td></tr>
      <tr><td>/quick-ban</td><td><span class="badge by">POST</span></td><td>Bannir une IP rapidement</td></tr>
      <tr><td>/add-rule</td><td><span class="badge by">POST</span></td><td>Ajouter une règle</td></tr>
      <tr><td>/delete-rule</td><td><span class="badge by">POST</span></td><td>Supprimer une règle</td></tr>
      <tr><td>/move-rule</td><td><span class="badge by">POST</span></td><td>Déplacer une règle (up/down)</td></tr>
      <tr><td>/apply-preset</td><td><span class="badge by">POST</span></td><td>Appliquer un preset</td></tr>
      <tr><td><a href="/api/rules?chain=INPUT" style="color:var(--ac)">/api/rules?chain=INPUT</a></td><td><span class="badge bg">GET</span></td><td>JSON règles d'une chaîne (param: chain, v=6)</td></tr>
      <tr><td>/clear-logs</td><td><span class="badge by">POST</span></td><td>Vider le fichier journal</td></tr>
      <tr><td>/add-chain</td><td><span class="badge by">POST</span></td><td>Créer une chaîne personnalisée</td></tr>
      <tr><td>/delete-chain</td><td><span class="badge by">POST</span></td><td>Supprimer une chaîne personnalisée</td></tr>
      <tr><td>/save-settings</td><td><span class="badge by">POST</span></td><td>Sauvegarder les paramètres serveur</td></tr>
    </tbody>
  </table></div>
</div>

<div class="card">
  <div class="card-hd"><div class="card-t"><span class="ic">ℹ</span> À propos</div></div>
  <div style="font-size:.85rem;color:var(--mu);line-height:2">
SETEOF

    printf '    <p><strong style="color:var(--tx)">Fire-UX</strong> — Interface web de gestion iptables pure Bash</p>\n'
    printf '    <p>Version : <code>%s</code> &nbsp;·&nbsp; PID serveur : <code>%s</code></p>\n' "${_VERSION}" "${pid_val}"
    cat << 'SETEOF2'
    <p>Raccourcis : <code>1</code>–<code>6</code> navigation &nbsp;·&nbsp; <code>E</code> export &nbsp;·&nbsp; <code>?</code> aide &nbsp;·&nbsp; <code>Esc</code> fermer sidebar</p>
  </div>
</div>
SETEOF2

    # Paramètres serveur
    printf '<div class="card">\n'
    printf '<div class="card-hd"><div class="card-t"><span class="ic">⊞</span> Configuration serveur</div></div>\n'
    printf '<form method="POST" action="/save-settings">\n'
    printf '<div class="set-row"><div class="set-info"><div class="set-lbl">Port HTTP</div><div class="set-desc">Port d'\''écoute du serveur web (redémarrage requis)</div></div>\n'
    printf '<div class="set-ctrl"><input type="number" name="port" value="%s" min="1024" max="65535" style="width:100px"></div></div>\n' "${cur_port}"
    printf '<div class="set-row"><div class="set-info"><div class="set-lbl">Authentification HTTP Basic</div><div class="set-desc">Configurez le mot de passe avec <code>fire-ux</code> (CLI) → section auth</div></div>\n'
    printf '<div class="set-ctrl"><span class="badge %s">%s</span></div></div>\n' \
        "$([ "${auth_status}" = "Désactivée" ] && echo "bd" || echo "ba")" "${auth_status}"
    printf '<div style="margin-top:.8rem"><button class="btn btn-p" type="submit">Sauvegarder</button></div>\n'
    printf '</form>\n</div>\n'

    html_footer
}
