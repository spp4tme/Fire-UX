#!/bin/bash

# fire-ux.sh - Interactive iptables firewall manager
# Author: v0 / Claude

# ═══════════════════════════════════════════════════════════════════════════════
#  STYLE & COLOR DEFINITIONS
# ═══════════════════════════════════════════════════════════════════════════════

RESET='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

# Fire gradient (256-color ANSI)
FIRE1='\033[38;5;196m'
FIRE2='\033[38;5;202m'
FIRE3='\033[38;5;208m'
FIRE4='\033[38;5;214m'
FIRE5='\033[38;5;220m'

# UI palette
C_BORDER='\033[38;5;237m'
C_BORDER_LT='\033[38;5;243m'
C_TITLE='\033[1;38;5;214m'
C_SUBTITLE='\033[38;5;246m'
C_SUCCESS='\033[38;5;82m'
C_ERROR='\033[38;5;196m'
C_WARN='\033[38;5;220m'
C_INFO='\033[38;5;39m'
C_TEXT='\033[38;5;252m'
C_MUTED='\033[38;5;240m'
C_NUM='\033[1;38;5;208m'
C_KEY='\033[38;5;228m'
C_ACCENT='\033[38;5;75m'
C_LABEL='\033[38;5;246m'
C_HIGHLIGHT='\033[1;38;5;255m'
C_TAG_GREEN='\033[38;5;22m'
C_TAG_RED='\033[38;5;88m'

# Legacy aliases — used throughout logic code unchanged
RED="$C_ERROR"
GREEN="$C_SUCCESS"
YELLOW="$C_WARN"
BLUE="$C_INFO"
PURPLE='\033[38;5;135m'
CYAN='\033[38;5;87m'
NC="$RESET"

# ═══════════════════════════════════════════════════════════════════════════════
#  BOOTSTRAP
# ═══════════════════════════════════════════════════════════════════════════════

if [ "$EUID" -ne 0 ]; then
  echo -e "${C_ERROR}${BOLD}  ✗  This script must be run as root (sudo).${RESET}"
  exit 1
fi

CONFIG_DIR="/etc/fire-ux"
PROFILES_DIR="$CONFIG_DIR/profiles"
ROUTES_DIR="$CONFIG_DIR/routes"
LOG_FILE="/var/log/fire-ux.log"

mkdir -p "$PROFILES_DIR"
mkdir -p "$ROUTES_DIR"
touch "$LOG_FILE"

log_action() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# ═══════════════════════════════════════════════════════════════════════════════
#  UI PRIMITIVES
# ═══════════════════════════════════════════════════════════════════════════════

repeat_char() {
  local char="$1" count="$2" out=""
  for ((i=0; i<count; i++)); do out+="$char"; done
  printf '%s' "$out"
}

# ─── Message helpers ──────────────────────────────────────────────────────────

msg_ok()   { echo -e "\n  ${C_SUCCESS}${BOLD}✓${RESET}  ${C_TEXT}${1}${RESET}"; }
msg_err()  { echo -e "\n  ${C_ERROR}${BOLD}✗${RESET}  ${C_TEXT}${1}${RESET}"; }
msg_warn() { echo -e "\n  ${C_WARN}${BOLD}⚠${RESET}  ${C_TEXT}${1}${RESET}"; }
msg_info() { echo -e "\n  ${C_INFO}${BOLD}→${RESET}  ${C_TEXT}${1}${RESET}"; }

press_enter() {
  echo -e "\n  ${C_MUTED}Press ${C_KEY}[Enter]${C_MUTED} to continue...${RESET}"
  read
}

ask_confirm() {
  echo -en "\n  ${C_WARN}${BOLD}?${RESET}  ${C_TEXT}${1:-Confirm?} ${C_MUTED}[${C_KEY}y${C_MUTED}/${C_KEY}n${C_MUTED}]:${RESET}  "
  read -r _ans
  [[ "$_ans" =~ ^[Yy]$ ]]
}

# ─── Section & menu drawing ───────────────────────────────────────────────────

# Open box (left border + top rule, no right border)
open_box() {
  local title="$1"
  local width="${2:-56}"
  local dashes
  dashes=$(repeat_char '═' $((width - ${#title} - 5)))
  echo -e "\n  ${C_BORDER}╔══ ${C_TITLE}${title}${RESET} ${C_BORDER}${dashes}${RESET}"
  echo -e "  ${C_BORDER}║${RESET}"
}

close_box() {
  local width="${1:-56}"
  local dashes
  dashes=$(repeat_char '═' $width)
  echo -e "  ${C_BORDER}║${RESET}"
  echo -e "  ${C_BORDER}╚${dashes}${RESET}"
}

sep_box() {
  local width="${1:-56}"
  local dashes
  dashes=$(repeat_char '─' $width)
  echo -e "  ${C_BORDER}╟${dashes}${RESET}"
}

box_row()  { echo -e "  ${C_BORDER}║${RESET}  ${1}"; }

# Styled sub-menu selector box
choice_box() {
  local title="$1"
  shift
  local dashes
  dashes=$(repeat_char '─' $((50 - ${#title} - 1)))
  echo -e "\n  ${C_BORDER_LT}┌── ${C_SUBTITLE}${title}${RESET} ${C_BORDER_LT}${dashes}${RESET}"
  for item in "$@"; do
    local num="${item%%:*}"
    local desc="${item#*:}"
    echo -e "  ${C_BORDER_LT}│${RESET}   ${C_NUM}[${num}]${RESET}  ${C_TEXT}${desc}${RESET}"
  done
  echo -e "  ${C_BORDER_LT}└$(repeat_char '─' 52)${RESET}"
  echo -en "\n  ${C_ACCENT}›${RESET}  "
}

# Labeled input prompt
ask() {
  echo -en "\n  ${C_ACCENT}›${RESET}  ${C_LABEL}${1}:${RESET}  "
}

# ═══════════════════════════════════════════════════════════════════════════════
#  HEADER
# ═══════════════════════════════════════════════════════════════════════════════

show_header() {
  clear
  echo ""
  echo -e "  ${FIRE5}██████╗ ██╗██████╗ ███████╗    ██╗   ██╗██╗  ██╗${RESET}"
  echo -e "  ${FIRE4}██╔═══╝ ██║██╔══██╗██╔════╝    ██║   ██║╚██╗██╔╝${RESET}"
  echo -e "  ${FIRE3}█████╗  ██║██████╔╝█████╗      ██║   ██║ ╚███╔╝ ${RESET}"
  echo -e "  ${FIRE2}██╔══╝  ██║██╔══██╗██╔══╝      ██║   ██║ ██╔██╗ ${RESET}"
  echo -e "  ${FIRE1}██║     ██║██║  ██║███████╗    ╚██████╔╝██╔╝ ██╗${RESET}"
  echo -e "  ${FIRE1}╚═╝     ╚═╝╚═╝  ╚═╝╚══════╝    ╚═════╝ ╚═╝  ╚═╝${RESET}"
  echo ""
  echo -e "  ${C_BORDER}$(repeat_char '─' 56)${RESET}"
  echo -e "  ${C_MUTED}Intelligent Firewall Manager  ·  $(date '+%Y-%m-%d  %H:%M:%S')${RESET}"
  echo -e "  ${C_BORDER}$(repeat_char '─' 56)${RESET}"
  echo ""
}

# Header with breadcrumb
show_section() {
  show_header
  echo -e "  ${C_MUTED}▸ Main  ▸  ${C_TITLE}${BOLD}${1}${RESET}"
}

# ═══════════════════════════════════════════════════════════════════════════════
#  DASHBOARD
# ═══════════════════════════════════════════════════════════════════════════════

show_dashboard() {
  show_section "Dashboard"
  open_box "FIREWALL STATUS"

  # Default policies
  local pol_in pol_out pol_fwd
  pol_in=$(iptables  -L INPUT   2>/dev/null | head -n1 | awk '{print $4}')
  pol_out=$(iptables -L OUTPUT  2>/dev/null | head -n1 | awk '{print $4}')
  pol_fwd=$(iptables -L FORWARD 2>/dev/null | head -n1 | awk '{print $4}')

  _policy_color() {
    case "$1" in
      ACCEPT) echo "${C_SUCCESS}" ;;
      DROP|REJECT) echo "${C_ERROR}" ;;
      *) echo "${C_MUTED}" ;;
    esac
  }

  local c_in c_out c_fwd
  c_in=$(_policy_color  "$pol_in")
  c_out=$(_policy_color "$pol_out")
  c_fwd=$(_policy_color "$pol_fwd")

  box_row "${C_SUBTITLE}Default Policies${RESET}"
  box_row "  ${C_LABEL}INPUT   ${RESET}${c_in}${BOLD}${pol_in:-?}${RESET}     ${C_LABEL}OUTPUT  ${RESET}${c_out}${BOLD}${pol_out:-?}${RESET}     ${C_LABEL}FORWARD ${RESET}${c_fwd}${BOLD}${pol_fwd:-?}${RESET}"
  echo -e "  ${C_BORDER}║${RESET}"

  # Rule counts
  local cnt_in cnt_out cnt_fwd cnt_total
  cnt_in=$(iptables  -L INPUT   -v 2>/dev/null | tail -n +3 | grep -v "^$" | wc -l)
  cnt_out=$(iptables -L OUTPUT  -v 2>/dev/null | tail -n +3 | grep -v "^$" | wc -l)
  cnt_fwd=$(iptables -L FORWARD -v 2>/dev/null | tail -n +3 | grep -v "^$" | wc -l)
  cnt_total=$((cnt_in + cnt_out + cnt_fwd))

  box_row "${C_SUBTITLE}Active Rules${RESET}"
  box_row "  ${C_LABEL}INPUT  ${C_NUM}${cnt_in}${RESET}    ${C_LABEL}OUTPUT  ${C_NUM}${cnt_out}${RESET}    ${C_LABEL}FORWARD  ${C_NUM}${cnt_fwd}${RESET}    ${C_MUTED}·  ${C_NUM}${cnt_total}${C_MUTED} total${RESET}"
  echo -e "  ${C_BORDER}║${RESET}"

  # Open ports
  local tcp_ports udp_ports
  tcp_ports=$(iptables -L INPUT -n 2>/dev/null | grep "tcp dpt:" | sed -E 's/.*dpt:([0-9]+).*/\1/' | sort -n | uniq | tr '\n' '  ')
  udp_ports=$(iptables -L INPUT -n 2>/dev/null | grep "udp dpt:" | sed -E 's/.*dpt:([0-9]+).*/\1/' | sort -n | uniq | tr '\n' '  ')

  box_row "${C_SUBTITLE}Open Ports${RESET}"
  box_row "  ${C_LABEL}TCP${RESET}  ${C_TEXT}${tcp_ports:-${C_MUTED}none}${RESET}"
  box_row "  ${C_LABEL}UDP${RESET}  ${C_TEXT}${udp_ports:-${C_MUTED}none}${RESET}"
  echo -e "  ${C_BORDER}║${RESET}"

  # Detected services
  local services=""
  echo "$tcp_ports" | grep -q '\b22\b'    && services+="${C_SUCCESS}● SSH     ${RESET}"
  echo "$tcp_ports" | grep -q '\b80\b'    && services+="${C_SUCCESS}● HTTP    ${RESET}"
  echo "$tcp_ports" | grep -q '\b443\b'   && services+="${C_SUCCESS}● HTTPS   ${RESET}"
  echo "$tcp_ports" | grep -q '\b21\b'    && services+="${C_SUCCESS}● FTP     ${RESET}"
  echo "$tcp_ports" | grep -q '\b25\b'    && services+="${C_SUCCESS}● SMTP    ${RESET}"
  echo "$udp_ports" | grep -q '\b53\b'    && services+="${C_SUCCESS}● DNS     ${RESET}"
  echo "$udp_ports" | grep -q '\b51820\b' && services+="${C_SUCCESS}● WG      ${RESET}"

  box_row "${C_SUBTITLE}Detected Services${RESET}"
  box_row "  ${services:-${C_MUTED}none detected}${RESET}"
  echo -e "  ${C_BORDER}║${RESET}"

  # IP forwarding
  local ip_fwd
  ip_fwd=$(cat /proc/sys/net/ipv4/ip_forward 2>/dev/null)
  local fwd_label fwd_color
  if [ "${ip_fwd}" = "1" ]; then
    fwd_label="ENABLED"; fwd_color="${C_SUCCESS}"
  else
    fwd_label="DISABLED"; fwd_color="${C_ERROR}"
  fi
  box_row "${C_SUBTITLE}IP Forwarding${RESET}  ${fwd_color}${BOLD}${fwd_label}${RESET}"
  echo -e "  ${C_BORDER}║${RESET}"

  # Active routes
  box_row "${C_SUBTITLE}Saved Routes${RESET}"
  if [ -d "$ROUTES_DIR" ] && [ "$(ls -A "$ROUTES_DIR" 2>/dev/null)" ]; then
    for rf in "$ROUTES_DIR"/*; do
      [ -f "$rf" ] && box_row "  ${C_ACCENT}·${RESET}  $(basename "$rf")"
    done
  else
    box_row "  ${C_MUTED}none configured${RESET}"
  fi

  close_box

  press_enter
}

# ═══════════════════════════════════════════════════════════════════════════════
#  ADD CUSTOM RULE
# ═══════════════════════════════════════════════════════════════════════════════

add_custom_rule() {
  show_section "Add Custom Rule"

  # Chain
  choice_box "Select chain" \
    "1:INPUT    — Incoming traffic" \
    "2:OUTPUT   — Outgoing traffic" \
    "3:FORWARD  — Routed traffic"
  read -r chain_choice
  case $chain_choice in
    1) chain="INPUT" ;;
    2) chain="OUTPUT" ;;
    3) chain="FORWARD" ;;
    *) msg_err "Invalid choice."; sleep 2; return ;;
  esac

  # Protocol
  choice_box "Select protocol" \
    "1:TCP" \
    "2:UDP" \
    "3:Both  (TCP and UDP)" \
    "4:ICMP  (ping)" \
    "5:All protocols"
  read -r protocol_choice
  case $protocol_choice in
    1) protocol="tcp" ;;
    2) protocol="udp" ;;
    3) protocol="all" ;;
    4) protocol="icmp" ;;
    5) protocol="all" ;;
    *) msg_err "Invalid choice."; sleep 2; return ;;
  esac

  # Port
  port=""
  if [ "$protocol" = "tcp" ] || [ "$protocol" = "udp" ]; then
    ask "Port or service  (e.g. 22, 80, 443)"
    read -r port
    if ! [[ "$port" =~ ^[0-9]+$ ]] && ! grep -q "^$port" /etc/services; then
      msg_err "Invalid port or service."; sleep 2; return
    fi
  fi

  # Source IP
  ask "Source IP  (leave empty for any)"
  read -r source_ip
  [ -z "$source_ip" ] && source_ip="0.0.0.0/0"

  # Action
  choice_box "Select action" \
    "1:ACCEPT  — Allow traffic" \
    "2:DROP    — Silently discard" \
    "3:REJECT  — Discard and send error"
  read -r action_choice
  case $action_choice in
    1) action="ACCEPT" ;;
    2) action="DROP" ;;
    3) action="REJECT" ;;
    *) msg_err "Invalid choice."; sleep 2; return ;;
  esac

  # Persistence
  choice_box "Rule lifetime" \
    "1:Permanent  — survives reboot" \
    "2:Temporary  — removed on reboot" \
    "3:Timed      — specify duration in minutes"
  read -r temp_choice

  # Build command
  cmd="iptables -A $chain"
  [ "$protocol" != "all" ]     && cmd="$cmd -p $protocol"
  [ -n "$port" ] && [ "$protocol" != "icmp" ] && cmd="$cmd --dport $port"
  [ "$source_ip" != "0.0.0.0/0" ] && cmd="$cmd -s $source_ip"
  cmd="$cmd -j $action"

  echo -e "\n  ${C_BORDER_LT}$(repeat_char '─' 54)${RESET}"
  echo -e "  ${C_SUBTITLE}Rule preview:${RESET}  ${C_HIGHLIGHT}${cmd}${RESET}"
  echo -e "  ${C_BORDER_LT}$(repeat_char '─' 54)${RESET}"

  ask_confirm "Apply this rule?" || { msg_warn "Cancelled."; press_enter; return; }

  eval "$cmd"
  if [ $? -eq 0 ]; then
    msg_ok "Rule added successfully!"
    log_action "Added rule: $cmd"

    if [ "$temp_choice" = "3" ]; then
      ask "Duration in minutes"
      read -r duration
      if [[ "$duration" =~ ^[0-9]+$ ]]; then
        (
          sleep $((duration * 60))
          rule_num=$(iptables -L "$chain" --line-numbers | grep "$action" | tail -1 | awk '{print $1}')
          [ -n "$rule_num" ] && iptables -D "$chain" "$rule_num"
          log_action "Auto-removed timed rule after ${duration}m: $cmd"
        ) &
        msg_info "Rule will be removed automatically after ${duration} minutes."
      else
        msg_warn "Invalid duration — rule added as permanent."
      fi
    fi

    if [ "$temp_choice" = "1" ]; then
      if command -v iptables-save > /dev/null; then
        iptables-save > /etc/iptables/rules.v4 2>/dev/null || iptables-save > /etc/iptables.rules
        msg_ok "Rules saved permanently."
      else
        msg_warn "iptables-save not found — rule may not persist after reboot."
      fi
    fi
  else
    msg_err "Failed to add rule."
  fi

  press_enter
}

# ═══════════════════════════════════════════════════════════════════════════════
#  DELETE RULES
# ═══════════════════════════════════════════════════════════════════════════════

delete_rules() {
  show_section "Delete Rules"

  choice_box "Select operation" \
    "1:Delete specific rule" \
    "2:Flush a chain  (all rules)" \
    "3:Full reset  (all rules + policies)" \
    "4:Back to main menu"
  read -r delete_choice

  case $delete_choice in
    1)
      choice_box "Select chain" \
        "1:INPUT" "2:OUTPUT" "3:FORWARD"
      read -r chain_choice
      case $chain_choice in
        1) chain="INPUT" ;; 2) chain="OUTPUT" ;; 3) chain="FORWARD" ;;
        *) msg_err "Invalid choice."; sleep 2; return ;;
      esac

      echo ""
      echo -e "  ${C_SUBTITLE}Current rules in ${C_TITLE}${chain}${RESET}${C_SUBTITLE}:${RESET}"
      echo -e "  ${C_BORDER}$(repeat_char '─' 54)${RESET}"
      iptables -L "$chain" --line-numbers -n 2>/dev/null | while IFS= read -r line; do
        echo -e "  ${C_MUTED}${line}${RESET}"
      done
      echo -e "  ${C_BORDER}$(repeat_char '─' 54)${RESET}"

      ask "Rule number to delete"
      read -r rule_num
      if [[ "$rule_num" =~ ^[0-9]+$ ]]; then
        msg_warn "This will delete rule #${rule_num} from ${chain}."
        ask_confirm "Proceed?" || { msg_warn "Cancelled."; press_enter; return; }
        iptables -D "$chain" "$rule_num"
        if [ $? -eq 0 ]; then
          msg_ok "Rule #${rule_num} deleted."
          log_action "Deleted rule #$rule_num from $chain"
          command -v iptables-save > /dev/null && \
            { iptables-save > /etc/iptables/rules.v4 2>/dev/null || iptables-save > /etc/iptables.rules; }
        else
          msg_err "Failed to delete rule."
        fi
      else
        msg_err "Invalid rule number."
      fi
      ;;

    2)
      choice_box "Select chain to flush" \
        "1:INPUT" "2:OUTPUT" "3:FORWARD" "4:All chains"
      read -r chain_choice
      case $chain_choice in
        1) chain="INPUT" ;; 2) chain="OUTPUT" ;; 3) chain="FORWARD" ;; 4) chain="all" ;;
        *) msg_err "Invalid choice."; sleep 2; return ;;
      esac

      msg_warn "All rules in ${chain} will be deleted."
      ask_confirm "Proceed?" || { msg_warn "Cancelled."; press_enter; return; }

      if [ "$chain" = "all" ]; then
        iptables -F
        msg_ok "All chains flushed."
        log_action "Flushed all chains"
      else
        iptables -F "$chain"
        msg_ok "${chain} chain flushed."
        log_action "Flushed $chain chain"
      fi
      command -v iptables-save > /dev/null && \
        { iptables-save > /etc/iptables/rules.v4 2>/dev/null || iptables-save > /etc/iptables.rules; }
      ;;

    3)
      echo -e "\n  ${C_ERROR}${BOLD}  ██  FULL RESET WARNING${RESET}"
      echo -e "  ${C_ERROR}  All rules, custom chains, and policies will be wiped.${RESET}"
      echo -e "  ${C_ERROR}  You may lose network access if no safety rules are added.${RESET}"
      echo -en "\n  ${C_WARN}${BOLD}?${RESET}  ${C_TEXT}Type ${C_KEY}RESET${C_TEXT} to confirm:${RESET}  "
      read -r confirm
      if [ "$confirm" = "RESET" ]; then
        local ts; ts=$(date +%Y%m%d%H%M%S)
        local bk="$PROFILES_DIR/backup_before_reset_$ts"
        iptables-save > "$bk"

        iptables -F; iptables -X
        iptables -t nat -F; iptables -t nat -X
        iptables -t mangle -F; iptables -t mangle -X
        iptables -P INPUT ACCEPT; iptables -P OUTPUT ACCEPT; iptables -P FORWARD ACCEPT

        msg_ok "Firewall reset."
        msg_info "Backup saved: ${bk}"
        log_action "Reset firewall (backup: $bk)"

        ask_confirm "Add basic safety rules now? (lo, ESTABLISHED, SSH, DROP rest)" && {
          iptables -A INPUT -i lo -j ACCEPT
          iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
          iptables -A INPUT -p tcp --dport 22 -j ACCEPT
          iptables -P INPUT DROP; iptables -P FORWARD DROP; iptables -P OUTPUT ACCEPT
          msg_ok "Basic safety rules applied."
          log_action "Added basic safety rules after reset"
          command -v iptables-save > /dev/null && \
            { iptables-save > /etc/iptables/rules.v4 2>/dev/null || iptables-save > /etc/iptables.rules; }
        }
      else
        msg_warn "Reset cancelled."
      fi
      ;;

    4) return ;;
    *) msg_err "Invalid choice."; sleep 2; return ;;
  esac

  press_enter
}

# ═══════════════════════════════════════════════════════════════════════════════
#  PROFILE MANAGEMENT
# ═══════════════════════════════════════════════════════════════════════════════

manage_profiles() {
  show_section "Profile Management"

  choice_box "Select operation" \
    "1:Save current rules as profile" \
    "2:Load a profile" \
    "3:Delete a profile" \
    "4:List profiles" \
    "5:Back to main menu"
  read -r profile_choice

  case $profile_choice in
    1)
      ask "Profile name"
      read -r profile_name
      [ -z "$profile_name" ] && { msg_err "Name cannot be empty."; press_enter; return; }
      profile_name=$(echo "$profile_name" | tr -cd '[:alnum:]._-')
      local pf="$PROFILES_DIR/$profile_name"
      if [ -f "$pf" ]; then
        ask_confirm "Profile already exists. Overwrite?" || { msg_warn "Cancelled."; press_enter; return; }
      fi
      iptables-save > "$pf"
      [ $? -eq 0 ] && { msg_ok "Profile '${profile_name}' saved."; log_action "Saved profile: $profile_name"; } \
                   || msg_err "Failed to save profile."
      ;;

    2)
      echo -e "\n  ${C_SUBTITLE}Available profiles:${RESET}"
      ls -1 "$PROFILES_DIR" 2>/dev/null | while read -r p; do
        echo -e "  ${C_ACCENT}·${RESET}  ${C_TEXT}${p}${RESET}"
      done
      ask "Profile name to load"
      read -r profile_name
      local pf="$PROFILES_DIR/$profile_name"
      if [ -f "$pf" ]; then
        msg_warn "This will replace all current rules."
        ask_confirm "Proceed?" || { msg_warn "Cancelled."; press_enter; return; }
        local ts; ts=$(date +%Y%m%d%H%M%S)
        local bk="$PROFILES_DIR/backup_before_load_$ts"
        iptables-save > "$bk"
        iptables-restore < "$pf"
        if [ $? -eq 0 ]; then
          msg_ok "Profile '${profile_name}' loaded."
          log_action "Loaded profile: $profile_name"
          command -v iptables-save > /dev/null && \
            { iptables-save > /etc/iptables/rules.v4 2>/dev/null || iptables-save > /etc/iptables.rules; }
        else
          msg_err "Failed to load profile. Restoring backup..."
          iptables-restore < "$bk"
        fi
      else
        msg_err "Profile not found."
      fi
      ;;

    3)
      echo -e "\n  ${C_SUBTITLE}Available profiles:${RESET}"
      ls -1 "$PROFILES_DIR" 2>/dev/null | while read -r p; do
        echo -e "  ${C_ACCENT}·${RESET}  ${C_TEXT}${p}${RESET}"
      done
      ask "Profile name to delete"
      read -r profile_name
      local pf="$PROFILES_DIR/$profile_name"
      if [ -f "$pf" ]; then
        msg_warn "This will permanently delete '${profile_name}'."
        ask_confirm "Proceed?" || { msg_warn "Cancelled."; press_enter; return; }
        rm "$pf"
        [ $? -eq 0 ] && { msg_ok "Profile deleted."; log_action "Deleted profile: $profile_name"; } \
                     || msg_err "Failed to delete profile."
      else
        msg_err "Profile not found."
      fi
      ;;

    4)
      echo ""
      local profiles
      profiles=$(ls -1 "$PROFILES_DIR" 2>/dev/null)
      if [ -z "$profiles" ]; then
        msg_info "No profiles found."
      else
        echo -e "  ${C_SUBTITLE}Saved profiles:${RESET}"
        echo -e "  ${C_BORDER}$(repeat_char '─' 40)${RESET}"
        echo "$profiles" | while read -r p; do
          local size; size=$(du -sh "$PROFILES_DIR/$p" 2>/dev/null | awk '{print $1}')
          echo -e "  ${C_ACCENT}·${RESET}  ${C_TEXT}${p}${RESET}  ${C_MUTED}(${size})${RESET}"
        done
        echo -e "  ${C_BORDER}$(repeat_char '─' 40)${RESET}"
      fi
      ;;

    5) return ;;
    *) msg_err "Invalid choice."; sleep 2; return ;;
  esac

  press_enter
}

# ═══════════════════════════════════════════════════════════════════════════════
#  QUICK TOGGLE
# ═══════════════════════════════════════════════════════════════════════════════

quick_toggle() {
  show_section "Quick Toggle"

  choice_box "Select mode" \
    "1:Enhanced Security  — block all except SSH + ESTABLISHED" \
    "2:Maintenance Mode   — allow all traffic temporarily" \
    "3:Restore Backup     — roll back to a previous state" \
    "4:Back to main menu"
  read -r toggle_choice

  local ts; ts=$(date +%Y%m%d%H%M%S)

  case $toggle_choice in
    1)
      msg_info "All incoming traffic except SSH and ESTABLISHED will be blocked."
      ask_confirm "Enable enhanced security?" || { msg_warn "Cancelled."; press_enter; return; }

      local bk="$PROFILES_DIR/backup_before_enhanced_$ts"
      iptables-save > "$bk"
      iptables -F; iptables -X
      iptables -P INPUT DROP; iptables -P FORWARD DROP; iptables -P OUTPUT ACCEPT
      iptables -A INPUT -i lo -j ACCEPT
      iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
      iptables -A INPUT -p tcp --dport 22 -j ACCEPT

      msg_ok "Enhanced security mode active."
      msg_info "Backup: ${bk}"
      log_action "Enhanced security enabled (backup: $bk)"
      ;;

    2)
      ask "Duration in minutes  (0 = indefinite)"
      read -r duration
      if ! [[ "$duration" =~ ^[0-9]+$ ]]; then
        msg_err "Invalid duration."; press_enter; return
      fi

      msg_warn "All traffic will be allowed. Use only in trusted environments."
      ask_confirm "Enable maintenance mode?" || { msg_warn "Cancelled."; press_enter; return; }

      local bk="$PROFILES_DIR/backup_before_maintenance_$ts"
      iptables-save > "$bk"
      iptables -F; iptables -X
      iptables -P INPUT ACCEPT; iptables -P FORWARD ACCEPT; iptables -P OUTPUT ACCEPT

      msg_ok "Maintenance mode enabled."
      msg_info "Backup: ${bk}"
      log_action "Maintenance mode enabled (backup: $bk)"

      if [ "$duration" -gt 0 ]; then
        msg_info "Will auto-revert in ${duration} minutes."
        ( sleep $((duration * 60))
          iptables-restore < "$bk"
          log_action "Maintenance mode auto-disabled after ${duration}m"
        ) &
      fi
      ;;

    3)
      echo -e "\n  ${C_SUBTITLE}Available backups:${RESET}"
      ls -1 "$PROFILES_DIR" 2>/dev/null | grep "^backup_" | while read -r b; do
        echo -e "  ${C_ACCENT}·${RESET}  ${C_TEXT}${b}${RESET}"
      done
      ask "Backup name to restore"
      read -r backup_name
      local bk="$PROFILES_DIR/$backup_name"
      if [ -f "$bk" ]; then
        msg_warn "Current rules will be replaced."
        ask_confirm "Proceed?" || { msg_warn "Cancelled."; press_enter; return; }

        local cur="$PROFILES_DIR/backup_before_restore_$ts"
        iptables-save > "$cur"
        iptables-restore < "$bk"
        if [ $? -eq 0 ]; then
          msg_ok "Rules restored from '${backup_name}'."
          log_action "Restored from backup: $backup_name"
          command -v iptables-save > /dev/null && \
            { iptables-save > /etc/iptables/rules.v4 2>/dev/null || iptables-save > /etc/iptables.rules; }
        else
          msg_err "Restore failed. Rolling back..."
          iptables-restore < "$cur"
        fi
      else
        msg_err "Backup not found."
      fi
      ;;

    4) return ;;
    *) msg_err "Invalid choice."; sleep 2; return ;;
  esac

  press_enter
}

# ═══════════════════════════════════════════════════════════════════════════════
#  DEFAULT POLICIES
# ═══════════════════════════════════════════════════════════════════════════════

set_default_policies() {
  show_section "Default Policies"

  local pol_in pol_out pol_fwd
  pol_in=$(iptables  -L INPUT   2>/dev/null | head -n1 | awk '{print $4}')
  pol_out=$(iptables -L OUTPUT  2>/dev/null | head -n1 | awk '{print $4}')
  pol_fwd=$(iptables -L FORWARD 2>/dev/null | head -n1 | awk '{print $4}')

  echo -e "\n  ${C_SUBTITLE}Current default policies:${RESET}"
  echo -e "  ${C_BORDER}$(repeat_char '─' 40)${RESET}"
  echo -e "  ${C_LABEL}INPUT  ${RESET}  ${C_TEXT}${pol_in:-?}${RESET}"
  echo -e "  ${C_LABEL}OUTPUT ${RESET}  ${C_TEXT}${pol_out:-?}${RESET}"
  echo -e "  ${C_LABEL}FORWARD${RESET}  ${C_TEXT}${pol_fwd:-?}${RESET}"
  echo -e "  ${C_BORDER}$(repeat_char '─' 40)${RESET}"

  choice_box "Select chain to modify" \
    "1:INPUT" "2:OUTPUT" "3:FORWARD" "4:Back"
  read -r chain_choice
  case $chain_choice in
    1) chain="INPUT" ;; 2) chain="OUTPUT" ;; 3) chain="FORWARD" ;;
    4) return ;;
    *) msg_err "Invalid choice."; sleep 2; return ;;
  esac

  choice_box "New policy for ${chain}" \
    "1:ACCEPT  — allow all by default" \
    "2:DROP    — silently discard by default" \
    "3:REJECT  — discard + error by default"
  read -r policy_choice
  case $policy_choice in
    1) policy="ACCEPT" ;; 2) policy="DROP" ;; 3) policy="REJECT" ;;
    *) msg_err "Invalid choice."; sleep 2; return ;;
  esac

  if [ "$chain" = "INPUT" ] && [ "$policy" = "DROP" ]; then
    echo -e "\n  ${C_ERROR}${BOLD}  ⚠  LOCKOUT RISK${RESET}"
    echo -e "  ${C_ERROR}  Setting INPUT to DROP without an SSH rule will lock you out.${RESET}"
    ask_confirm "Do you have an ACCEPT rule for SSH?" || {
      ask_confirm "Add an SSH ACCEPT rule now?" && {
        iptables -A INPUT -p tcp --dport 22 -j ACCEPT
        msg_ok "SSH rule added."
      }
    }
  fi

  msg_warn "Changing ${chain} default policy to ${policy}."
  ask_confirm "Confirm?" || { msg_warn "Cancelled."; press_enter; return; }

  iptables -P "$chain" "$policy"
  if [ $? -eq 0 ]; then
    msg_ok "Policy for ${chain} set to ${policy}."
    log_action "Changed default policy: $chain → $policy"
    command -v iptables-save > /dev/null && \
      { iptables-save > /etc/iptables/rules.v4 2>/dev/null || iptables-save > /etc/iptables.rules; }
  else
    msg_err "Failed to change policy."
  fi

  press_enter
}

# ═══════════════════════════════════════════════════════════════════════════════
#  AUDIT & MONITORING
# ═══════════════════════════════════════════════════════════════════════════════

audit_and_monitor() {
  show_section "Audit & Monitoring"

  choice_box "Select operation" \
    "1:View rules with packet counters" \
    "2:View active rules  (non-zero hits)" \
    "3:Filter by protocol" \
    "4:Filter by port" \
    "5:Export audit report" \
    "6:Back to main menu"
  read -r audit_choice

  _print_chain() {
    local c="$1" filter="${2:-}"
    echo -e "\n  ${C_TITLE}${BOLD}── ${c} ──────────────────────────────────${RESET}"
    if [ -n "$filter" ]; then
      iptables -L "$c" -v -n 2>/dev/null | grep -i "$filter" | while IFS= read -r line; do
        echo -e "  ${C_TEXT}${line}${RESET}"
      done
    else
      iptables -L "$c" -v -n 2>/dev/null | tail -n +3 | while IFS= read -r line; do
        echo -e "  ${C_TEXT}${line}${RESET}"
      done
    fi
  }

  case $audit_choice in
    1)
      for c in INPUT OUTPUT FORWARD; do _print_chain "$c"; done
      ;;
    2)
      msg_info "Showing only rules with recorded hits:"
      for c in INPUT OUTPUT FORWARD; do
        echo -e "\n  ${C_TITLE}${BOLD}── ${c} ──────────────────────────────────${RESET}"
        iptables -L "$c" -v -n 2>/dev/null | grep -v "0     0" | grep -v "^Chain" | while IFS= read -r line; do
          echo -e "  ${C_TEXT}${line}${RESET}"
        done
      done
      ;;
    3)
      choice_box "Select protocol" "1:TCP" "2:UDP" "3:ICMP"
      read -r proto_choice
      case $proto_choice in
        1) proto="tcp" ;; 2) proto="udp" ;; 3) proto="icmp" ;;
        *) msg_err "Invalid choice."; press_enter; return ;;
      esac
      for c in INPUT OUTPUT FORWARD; do _print_chain "$c" "$proto"; done
      ;;
    4)
      ask "Port number"
      read -r port
      if ! [[ "$port" =~ ^[0-9]+$ ]]; then
        msg_err "Invalid port."; press_enter; return
      fi
      for c in INPUT OUTPUT FORWARD; do _print_chain "$c" "dpt:$port"; done
      ;;
    5)
      local ts; ts=$(date +%Y%m%d%H%M%S)
      local rpt="/tmp/fire-ux_audit_${ts}.txt"
      {
        echo "═══════════════════════════════════════════════"
        echo "  FIRE-UX  ·  Audit Report  ·  $(date)"
        echo "═══════════════════════════════════════════════"
        echo ""
        echo "DEFAULT POLICIES"
        echo "  INPUT:   $(iptables -L INPUT   2>/dev/null | head -n1 | awk '{print $4}')"
        echo "  OUTPUT:  $(iptables -L OUTPUT  2>/dev/null | head -n1 | awk '{print $4}')"
        echo "  FORWARD: $(iptables -L FORWARD 2>/dev/null | head -n1 | awk '{print $4}')"
        echo ""
        echo "INPUT CHAIN"; iptables -L INPUT   -v -n 2>/dev/null
        echo "OUTPUT CHAIN"; iptables -L OUTPUT  -v -n 2>/dev/null
        echo "FORWARD CHAIN"; iptables -L FORWARD -v -n 2>/dev/null
        echo ""
        echo "ACTIVE CONNECTIONS"
        netstat -tuln 2>/dev/null || ss -tuln 2>/dev/null
        echo ""
        echo "RECENT LOG (last 50 entries)"
        tail -n 50 "$LOG_FILE" 2>/dev/null
      } > "$rpt"
      msg_ok "Audit report exported to: ${rpt}"
      log_action "Exported audit report to $rpt"
      ;;
    6) return ;;
    *) msg_err "Invalid choice."; sleep 2; return ;;
  esac

  press_enter
}

# ═══════════════════════════════════════════════════════════════════════════════
#  PRECONFIGURED RULES
# ═══════════════════════════════════════════════════════════════════════════════

preconfigured_rules() {
  show_section "Preconfigured Rules"

  choice_box "Select preset" \
    "1:Basic Server     — SSH only" \
    "2:Web Server       — HTTP + HTTPS + SSH" \
    "3:Mail Server      — SMTP/POP3/IMAP + SSH" \
    "4:FTP Server       — FTP passive + SSH" \
    "5:VPN Server       — WireGuard + NAT + SSH" \
    "6:Database Server  — MySQL/PG/Mongo/Redis + SSH" \
    "7:ERPNext Server   — port 8080 via WireGuard" \
    "8:Back to main menu"
  read -r preset_choice

  [ "$preset_choice" = "8" ] && return
  [[ ! "$preset_choice" =~ ^[1-7]$ ]] && { msg_err "Invalid choice."; sleep 2; return; }

  local ts; ts=$(date +%Y%m%d%H%M%S)
  local bk="$PROFILES_DIR/backup_before_preset_$ts"
  iptables-save > "$bk"

  msg_warn "This will replace all current rules. Backup: ${bk}"
  ask_confirm "Apply preset?" || { msg_warn "Cancelled."; press_enter; return; }

  # Common base setup
  _apply_base() {
    iptables -F; iptables -X
    iptables -P INPUT DROP; iptables -P FORWARD DROP; iptables -P OUTPUT ACCEPT
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    iptables -A INPUT -p tcp --dport 22 -j ACCEPT
    iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
  }

  _save_rules() {
    command -v iptables-save > /dev/null && \
      { iptables-save > /etc/iptables/rules.v4 2>/dev/null || iptables-save > /etc/iptables.rules; }
  }

  case $preset_choice in
    1)
      _apply_base
      msg_ok "Basic server preset applied  (SSH + ICMP)."
      log_action "Applied preset: basic server"
      ;;
    2)
      _apply_base
      iptables -A INPUT -p tcp --dport 80  -j ACCEPT
      iptables -A INPUT -p tcp --dport 443 -j ACCEPT
      msg_ok "Web server preset applied  (SSH, HTTP, HTTPS, ICMP)."
      log_action "Applied preset: web server"
      ;;
    3)
      _apply_base
      for p in 25 465 587 110 995 143 993; do
        iptables -A INPUT -p tcp --dport $p -j ACCEPT
      done
      msg_ok "Mail server preset applied  (SSH, SMTP/S, POP3/S, IMAP/S, ICMP)."
      log_action "Applied preset: mail server"
      ;;
    4)
      _apply_base
      iptables -A INPUT -p tcp --dport 21         -j ACCEPT
      iptables -A INPUT -p tcp --dport 1024:1048  -j ACCEPT
      modprobe nf_conntrack_ftp 2>/dev/null || modprobe ip_conntrack_ftp 2>/dev/null
      msg_ok "FTP server preset applied  (SSH, FTP control+passive, ICMP)."
      log_action "Applied preset: FTP server"
      ;;
    5)
      _apply_base
      iptables -A INPUT   -p udp --dport 51820       -j ACCEPT
      iptables -A FORWARD -i wg0 -j ACCEPT
      iptables -A FORWARD -o wg0 -j ACCEPT
      iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
      echo 1 > /proc/sys/net/ipv4/ip_forward
      grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf 2>/dev/null || \
        echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
      msg_ok "WireGuard VPN preset applied  (SSH, WG 51820, NAT, IP forwarding)."
      log_action "Applied preset: WireGuard VPN"
      ;;
    6)
      _apply_base
      for p in 3306 5432 27017 6379; do
        iptables -A INPUT -p tcp --dport $p -j ACCEPT
      done
      msg_ok "Database preset applied  (SSH, MySQL, PG, MongoDB, Redis, ICMP)."
      log_action "Applied preset: database server"
      ;;
    7)
      iptables -F; iptables -X
      iptables -P INPUT DROP; iptables -P FORWARD DROP; iptables -P OUTPUT ACCEPT
      iptables -A INPUT -i lo -j ACCEPT
      iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
      iptables -A INPUT -p tcp --dport 22 -j ACCEPT
      iptables -A INPUT -p tcp --dport 8080 -i wg0 -s 10.0.0.0/24 -j ACCEPT
      msg_ok "ERPNext preset applied  (SSH + port 8080 via wg0/10.0.0.0/24)."
      log_action "Applied preset: ERPNext"
      ;;
  esac

  _save_rules
  press_enter
}

# ═══════════════════════════════════════════════════════════════════════════════
#  TEST MODE
# ═══════════════════════════════════════════════════════════════════════════════

test_mode() {
  show_section "Test Mode"

  echo -e "  ${C_SUBTITLE}Apply a rule temporarily. It will be auto-removed when the timer ends.${RESET}"
  echo -e "  ${C_MUTED}Press ${C_KEY}Ctrl+C${C_MUTED} at any time to cancel and restore immediately.${RESET}"

  local ts; ts=$(date +%Y%m%d%H%M%S)
  local bk="$PROFILES_DIR/backup_before_test_$ts"
  iptables-save > "$bk"

  # Chain
  choice_box "Select chain" \
    "1:INPUT  — Incoming traffic" \
    "2:OUTPUT — Outgoing traffic" \
    "3:FORWARD — Routed traffic"
  read -r chain_choice
  case $chain_choice in
    1) chain="INPUT" ;; 2) chain="OUTPUT" ;; 3) chain="FORWARD" ;;
    *) msg_err "Invalid choice."; sleep 2; return ;;
  esac

  # Protocol
  choice_box "Select protocol" \
    "1:TCP" "2:UDP" "3:Both" "4:ICMP" "5:All"
  read -r protocol_choice
  case $protocol_choice in
    1) protocol="tcp" ;; 2) protocol="udp" ;;
    3) protocol="all" ;; 4) protocol="icmp" ;; 5) protocol="all" ;;
    *) msg_err "Invalid choice."; sleep 2; return ;;
  esac

  # Port
  port=""
  if [ "$protocol" = "tcp" ] || [ "$protocol" = "udp" ]; then
    ask "Port or service  (e.g. 22, 80, 443)"
    read -r port
    if ! [[ "$port" =~ ^[0-9]+$ ]] && ! grep -q "^$port" /etc/services; then
      msg_err "Invalid port."; sleep 2; return
    fi
  fi

  # Source IP
  ask "Source IP  (empty = any)"
  read -r source_ip
  [ -z "$source_ip" ] && source_ip="0.0.0.0/0"

  # Action
  choice_box "Select action" \
    "1:ACCEPT" "2:DROP" "3:REJECT"
  read -r action_choice
  case $action_choice in
    1) action="ACCEPT" ;; 2) action="DROP" ;; 3) action="REJECT" ;;
    *) msg_err "Invalid choice."; sleep 2; return ;;
  esac

  # Duration
  ask "Test duration in minutes"
  read -r duration
  if ! [[ "$duration" =~ ^[0-9]+$ ]] || [ "$duration" -eq 0 ]; then
    msg_err "Invalid duration."; sleep 2; return
  fi

  # Build command
  cmd="iptables -A $chain"
  [ "$protocol" != "all" ] && cmd="$cmd -p $protocol"
  [ -n "$port" ] && [ "$protocol" != "icmp" ] && cmd="$cmd --dport $port"
  [ "$source_ip" != "0.0.0.0/0" ] && cmd="$cmd -s $source_ip"
  cmd="$cmd -j $action"

  echo -e "\n  ${C_BORDER_LT}$(repeat_char '─' 54)${RESET}"
  echo -e "  ${C_SUBTITLE}Test rule:${RESET}  ${C_HIGHLIGHT}${cmd}${RESET}"
  echo -e "  ${C_SUBTITLE}Duration: ${RESET}  ${C_WARN}${duration} min${RESET}"
  echo -e "  ${C_BORDER_LT}$(repeat_char '─' 54)${RESET}"

  ask_confirm "Start test?" || { msg_warn "Cancelled."; press_enter; return; }

  eval "$cmd"
  if [ $? -ne 0 ]; then
    msg_err "Failed to apply test rule."; press_enter; return
  fi

  msg_ok "Test rule active. Counting down..."
  log_action "Test mode started: $cmd (${duration}m)"

  trap 'echo -e "\n\n  ${C_WARN}${BOLD}⚠${RESET}  ${C_TEXT}Test cancelled — restoring rules...${RESET}"; iptables-restore < "$bk"; log_action "Test mode cancelled manually"; echo -e "  ${C_SUCCESS}✓  Rules restored.${RESET}"; exit 0' INT

  echo ""
  for ((i=duration*60; i>=0; i--)); do
    local mins=$((i/60)) secs=$((i%60))
    local bar_total=40
    local bar_done=$(( (duration*60 - i) * bar_total / (duration*60) ))
    local bar_left=$(( bar_total - bar_done ))
    local bar
    bar="${C_SUCCESS}$(repeat_char '█' $bar_done)${C_MUTED}$(repeat_char '░' $bar_left)${RESET}"
    printf "\r  ${bar}  ${C_NUM}%02d:%02d${RESET} remaining " "$mins" "$secs"
    sleep 1
  done

  trap - INT

  echo -e "\n"
  msg_info "Timer expired. Restoring previous rules..."
  iptables-restore < "$bk"
  [ $? -eq 0 ] && { msg_ok "Rules restored."; log_action "Test mode completed after ${duration}m"; } \
               || { msg_err "Restore failed — manual intervention may be required."; }

  press_enter
}

# ═══════════════════════════════════════════════════════════════════════════════
#  NETWORK ROUTING
# ═══════════════════════════════════════════════════════════════════════════════

manage_network_routing() {
  show_section "Network Routing"

  choice_box "Select operation" \
    "1:Create new route" \
    "2:View existing routes" \
    "3:Delete a route" \
    "4:Enable / Disable IP forwarding" \
    "5:Back to main menu"
  read -r route_choice

  case $route_choice in
    1) create_network_route ;;
    2) view_network_routes ;;
    3) delete_network_route ;;
    4) toggle_ip_forwarding ;;
    5) return ;;
    *) msg_err "Invalid choice."; sleep 2; return ;;
  esac
}

# ─── Create route ─────────────────────────────────────────────────────────────

create_network_route() {
  show_section "Network Routing  ›  Create Route"

  ask "Route name"
  read -r route_name
  [ -z "$route_name" ] && { msg_err "Name cannot be empty."; press_enter; return; }
  route_name=$(echo "$route_name" | tr -cd '[:alnum:]._-')
  local rf="$ROUTES_DIR/$route_name"

  if [ -f "$rf" ]; then
    ask_confirm "Route already exists. Overwrite?" || { msg_warn "Cancelled."; press_enter; return; }
  fi

  ask "Source interface  (e.g. wg0)"
  read -r source_interface
  [ -z "$source_interface" ] && { msg_err "Cannot be empty."; press_enter; return; }

  ask "Source network  (e.g. 10.0.0.0/24)"
  read -r source_network
  [ -z "$source_network" ] && { msg_err "Cannot be empty."; press_enter; return; }

  ask "Destination interface  (e.g. eth0)"
  read -r dest_interface
  [ -z "$dest_interface" ] && { msg_err "Cannot be empty."; press_enter; return; }

  ask "Destination network  (e.g. 192.168.1.0/24)"
  read -r dest_network
  [ -z "$dest_network" ] && { msg_err "Cannot be empty."; press_enter; return; }

  ask "Specific port to forward  (empty = all traffic)"
  read -r forward_port

  local protocol=""
  if [ -n "$forward_port" ]; then
    choice_box "Protocol for port forwarding" "1:TCP" "2:UDP" "3:Both"
    read -r proto_choice
    case $proto_choice in
      1) protocol="tcp" ;; 2) protocol="udp" ;; *) protocol="both" ;;
    esac
  fi

  ask_confirm "Enable NAT for this route?" && local enable_nat="y" || local enable_nat="n"

  # Build route script
  local tmp; tmp=$(mktemp)
  cat > "$tmp" <<EOF
# Enable IP forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

# Forward between interfaces
iptables -A FORWARD -i $source_interface -o $dest_interface -s $source_network -d $dest_network -j ACCEPT
iptables -A FORWARD -i $dest_interface -o $source_interface -s $dest_network -d $source_network -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
EOF

  if [ -n "$forward_port" ]; then
    [ "$protocol" = "tcp" ] || [ "$protocol" = "both" ] && cat >> "$tmp" <<EOF
iptables -A FORWARD -i $source_interface -o $dest_interface -p tcp -s $source_network -d $dest_network --dport $forward_port -j ACCEPT
iptables -A FORWARD -i $dest_interface -o $source_interface -p tcp -s $dest_network -d $source_network --sport $forward_port -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
EOF
    [ "$protocol" = "udp" ] || [ "$protocol" = "both" ] && cat >> "$tmp" <<EOF
iptables -A FORWARD -i $source_interface -o $dest_interface -p udp -s $source_network -d $dest_network --dport $forward_port -j ACCEPT
iptables -A FORWARD -i $dest_interface -o $source_interface -p udp -s $dest_network -d $source_network --sport $forward_port -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
EOF
  fi

  [[ "$enable_nat" =~ ^[Yy]$ ]] && echo "iptables -t nat -A POSTROUTING -s $source_network -o $dest_interface -j MASQUERADE" >> "$tmp"

  cat >> "$tmp" <<'EOF'
if [ -f /etc/sysctl.conf ]; then
  grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf || echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
fi
EOF

  cp "$tmp" "$rf"
  rm "$tmp"

  echo -e "\n  ${C_SUBTITLE}Route configuration:${RESET}"
  echo -e "  ${C_BORDER}$(repeat_char '─' 52)${RESET}"
  while IFS= read -r line; do echo -e "  ${C_MUTED}${line}${RESET}"; done < "$rf"
  echo -e "  ${C_BORDER}$(repeat_char '─' 52)${RESET}"

  ask_confirm "Apply this route now?" && {
    bash "$rf"
    if [ $? -eq 0 ]; then
      msg_ok "Route applied."
      log_action "Applied network route: $route_name"
      command -v iptables-save > /dev/null && \
        { iptables-save > /etc/iptables/rules.v4 2>/dev/null || iptables-save > /etc/iptables.rules; }
    else
      msg_err "Failed to apply route."
    fi
  } || msg_info "Route saved but not applied."

  press_enter
}

# ─── View routes ──────────────────────────────────────────────────────────────

view_network_routes() {
  show_section "Network Routing  ›  View Routes"

  if [ -d "$ROUTES_DIR" ] && [ "$(ls -A "$ROUTES_DIR" 2>/dev/null)" ]; then
    for rf in "$ROUTES_DIR"/*; do
      [ -f "$rf" ] || continue
      local rn; rn=$(basename "$rf")
      echo -e "\n  ${C_TITLE}${BOLD}── ${rn} $(repeat_char '─' $((44 - ${#rn})))${RESET}"
      while IFS= read -r line; do echo -e "  ${C_MUTED}${line}${RESET}"; done < "$rf"
      echo -e "  ${C_BORDER}$(repeat_char '─' 52)${RESET}"
    done
  else
    msg_info "No routes configured."
  fi

  press_enter
}

# ─── Delete route ─────────────────────────────────────────────────────────────

delete_network_route() {
  show_section "Network Routing  ›  Delete Route"

  if [ ! -d "$ROUTES_DIR" ] || [ -z "$(ls -A "$ROUTES_DIR" 2>/dev/null)" ]; then
    msg_info "No routes found."
    press_enter; return
  fi

  echo -e "\n  ${C_SUBTITLE}Available routes:${RESET}"
  ls -1 "$ROUTES_DIR" 2>/dev/null | while read -r r; do
    echo -e "  ${C_ACCENT}·${RESET}  ${C_TEXT}${r}${RESET}"
  done

  ask "Route name to delete"
  read -r route_name
  local rf="$ROUTES_DIR/$route_name"

  if [ ! -f "$rf" ]; then
    msg_err "Route not found."; press_enter; return
  fi

  msg_warn "This will permanently delete '${route_name}'."
  ask_confirm "Proceed?" || { msg_warn "Cancelled."; press_enter; return; }

  ask_confirm "Also remove the iptables rules from the active ruleset?" && {
    local tmp; tmp=$(mktemp)
    grep "^iptables -A" "$rf" | sed 's/-A/-D/g' > "$tmp"
    bash "$tmp"
    [ $? -eq 0 ] && msg_ok "Route rules removed from iptables." || msg_err "Some rules could not be removed."
    rm "$tmp"
    command -v iptables-save > /dev/null && \
      { iptables-save > /etc/iptables/rules.v4 2>/dev/null || iptables-save > /etc/iptables.rules; }
  }

  rm "$rf"
  [ $? -eq 0 ] && { msg_ok "Route '${route_name}' deleted."; log_action "Deleted route: $route_name"; } \
               || msg_err "Failed to delete route file."

  press_enter
}

# ─── IP Forwarding toggle ─────────────────────────────────────────────────────

toggle_ip_forwarding() {
  show_section "Network Routing  ›  IP Forwarding"

  local cur; cur=$(cat /proc/sys/net/ipv4/ip_forward 2>/dev/null)

  if [ "$cur" = "1" ]; then
    echo -e "\n  ${C_LABEL}Current status:${RESET}  ${C_SUCCESS}${BOLD}● ENABLED${RESET}"
    ask_confirm "Disable IP forwarding?" || { msg_warn "Cancelled."; press_enter; return; }
    echo 0 > /proc/sys/net/ipv4/ip_forward
    [ $? -eq 0 ] && {
      msg_ok "IP forwarding disabled."
      log_action "Disabled IP forwarding"
      sed -i 's/net.ipv4.ip_forward=1/net.ipv4.ip_forward=0/g' /etc/sysctl.conf 2>/dev/null
    } || msg_err "Failed to disable IP forwarding."
  else
    echo -e "\n  ${C_LABEL}Current status:${RESET}  ${C_ERROR}${BOLD}● DISABLED${RESET}"
    ask_confirm "Enable IP forwarding?" || { msg_warn "Cancelled."; press_enter; return; }
    echo 1 > /proc/sys/net/ipv4/ip_forward
    [ $? -eq 0 ] && {
      msg_ok "IP forwarding enabled."
      log_action "Enabled IP forwarding"
      if grep -q "net.ipv4.ip_forward" /etc/sysctl.conf 2>/dev/null; then
        sed -i 's/net.ipv4.ip_forward=0/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
      else
        echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
      fi
    } || msg_err "Failed to enable IP forwarding."
  fi

  press_enter
}

# ═══════════════════════════════════════════════════════════════════════════════
#  MAIN MENU
# ═══════════════════════════════════════════════════════════════════════════════

main_menu() {
  while true; do
    show_header

    echo -e "  ${C_BORDER}╔══ ${C_TITLE}MAIN MENU${RESET} ${C_BORDER}$(repeat_char '═' 44)${RESET}"
    echo -e "  ${C_BORDER}║${RESET}"
    echo -e "  ${C_BORDER}║${RESET}   ${C_NUM}[1]${RESET}  ${C_TEXT}Dashboard${RESET}              ${C_MUTED}·${RESET}  ${C_NUM}[6]${RESET}  ${C_TEXT}Default Policies${RESET}"
    echo -e "  ${C_BORDER}║${RESET}   ${C_NUM}[2]${RESET}  ${C_TEXT}Add Custom Rule${RESET}        ${C_MUTED}·${RESET}  ${C_NUM}[7]${RESET}  ${C_TEXT}Audit & Monitoring${RESET}"
    echo -e "  ${C_BORDER}║${RESET}   ${C_NUM}[3]${RESET}  ${C_TEXT}Delete Rules${RESET}           ${C_MUTED}·${RESET}  ${C_NUM}[8]${RESET}  ${C_TEXT}Preconfigured Rules${RESET}"
    echo -e "  ${C_BORDER}║${RESET}   ${C_NUM}[4]${RESET}  ${C_TEXT}Profile Management${RESET}     ${C_MUTED}·${RESET}  ${C_NUM}[9]${RESET}  ${C_TEXT}Test Mode${RESET}"
    echo -e "  ${C_BORDER}║${RESET}   ${C_NUM}[5]${RESET}  ${C_TEXT}Quick Toggle${RESET}           ${C_MUTED}·${RESET}  ${C_NUM}[10]${RESET} ${C_TEXT}Network Routing${RESET}"
    echo -e "  ${C_BORDER}║${RESET}"
    echo -e "  ${C_BORDER}╟$(repeat_char '─' 54)${RESET}"
    echo -e "  ${C_BORDER}║${RESET}   ${C_MUTED}[0]${RESET}  ${C_MUTED}Exit${RESET}"
    echo -e "  ${C_BORDER}╚$(repeat_char '═' 54)${RESET}"

    echo ""
    echo -en "  ${C_ACCENT}›${RESET}  ${C_LABEL}Enter your choice${RESET}  ${C_MUTED}(0–10):${RESET}  "
    read -r choice

    case $choice in
      1)  show_dashboard ;;
      2)  add_custom_rule ;;
      3)  delete_rules ;;
      4)  manage_profiles ;;
      5)  quick_toggle ;;
      6)  set_default_policies ;;
      7)  audit_and_monitor ;;
      8)  preconfigured_rules ;;
      9)  test_mode ;;
      10) manage_network_routing ;;
      0)
        show_header
        echo -e "  ${FIRE3}${BOLD}  Au revoir !${RESET}  ${C_MUTED}Fire-UX terminé.${RESET}"
        echo ""
        exit 0
        ;;
      *)
        msg_err "Invalid choice — please enter 0 to 10."
        sleep 2
        ;;
    esac
  done
}

# ═══════════════════════════════════════════════════════════════════════════════
#  ENTRY POINT
# ═══════════════════════════════════════════════════════════════════════════════

if ! command -v iptables &> /dev/null; then
  echo -e "${C_WARN}  iptables not found. Attempting installation...${RESET}"
  if [ "$EUID" -ne 0 ]; then
    sudo apt update && sudo apt install -y iptables
  else
    apt update && apt install -y iptables
  fi

  if ! command -v iptables &> /dev/null; then
    for p in /sbin/iptables /usr/sbin/iptables; do
      if [ -f "$p" ]; then
        iptables() { "$p" "$@"; }; export -f iptables
        break
      fi
    done
    command -v iptables &> /dev/null || { echo -e "${C_ERROR}  ✗  Could not install iptables.${RESET}"; exit 1; }
  fi
fi

if ! iptables -V &> /dev/null; then
  echo -e "${C_ERROR}  ✗  iptables is installed but not working. Run 'iptables -V' to diagnose.${RESET}"
  exit 1
fi

log_action "Script started"
main_menu
