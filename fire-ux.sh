#!/bin/bash

# fire-ux.sh - Script interactif de gestion du pare-feu iptables
# Author: v0
# Date: 2025-03-23

# Colors for better UI
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}This script must be run as root (sudo).${NC}"
  exit 1
fi

# Configuration directory
CONFIG_DIR="/etc/fire-ux"
PROFILES_DIR="$CONFIG_DIR/profiles"
ROUTES_DIR="$CONFIG_DIR/routes"
LOG_FILE="/var/log/fire-ux.log"

# Create necessary directories if they don't exist
mkdir -p "$PROFILES_DIR"
mkdir -p "$ROUTES_DIR"
touch "$LOG_FILE"

# Log function
log_action() {
  local message="$1"
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$LOG_FILE"
}

# Function to display header
show_header() {
  clear
  echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║                      ${CYAN}FIRE-UX${BLUE}                              ║${NC}"
  echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
  echo ""
}

# Function to display dashboard
show_dashboard() {
  show_header
  
  echo -e "${CYAN}╔═══ FIREWALL STATUS ═══╗${NC}"
  
  # Default policies
  echo -e "${YELLOW}Default Policies:${NC}"
  echo -e "  INPUT: $(iptables -L INPUT | head -n1 | awk '{print $4}')"
  echo -e "  OUTPUT: $(iptables -L OUTPUT | head -n1 | awk '{print $4}')"
  echo -e "  FORWARD: $(iptables -L FORWARD | head -n1 | awk '{print $4}')"
  
  # Count rules
  local input_rules=$(iptables -L INPUT -v | tail -n +3 | grep -v "^$" | wc -l)
  local output_rules=$(iptables -L OUTPUT -v | tail -n +3 | grep -v "^$" | wc -l)
  local forward_rules=$(iptables -L FORWARD -v | tail -n +3 | grep -v "^$" | wc -l)
  local total_rules=$((input_rules + output_rules + forward_rules))
  
  echo -e "\n${YELLOW}Active Rules:${NC}"
  echo -e "  INPUT: $input_rules rules"
  echo -e "  OUTPUT: $output_rules rules"
  echo -e "  FORWARD: $forward_rules rules"
  echo -e "  TOTAL: $total_rules rules"
  
  # Open ports
  echo -e "\n${YELLOW}Open Ports:${NC}"
  local open_tcp_ports=$(iptables -L INPUT -n | grep "tcp dpt:" | sed -E 's/.*dpt:([0-9]+).*/\1/' | sort -n | uniq | tr '\n' ' ')
  local open_udp_ports=$(iptables -L INPUT -n | grep "udp dpt:" | sed -E 's/.*dpt:([0-9]+).*/\1/' | sort -n | uniq | tr '\n' ' ')
  
  if [ -n "$open_tcp_ports" ]; then
    echo -e "  TCP: $open_tcp_ports"
  else
    echo -e "  TCP: None"
  fi
  
  if [ -n "$open_udp_ports" ]; then
    echo -e "  UDP: $open_udp_ports"
  else
    echo -e "  UDP: None"
  fi
  
  # Check for common services
  echo -e "\n${YELLOW}Allowed Services:${NC}"
  local services=""
  
  if echo "$open_tcp_ports" | grep -q "22"; then
    services+="SSH (22) "
  fi
  if echo "$open_tcp_ports" | grep -q "80"; then
    services+="HTTP (80) "
  fi
  if echo "$open_tcp_ports" | grep -q "443"; then
    services+="HTTPS (443) "
  fi
  if echo "$open_tcp_ports" | grep -q "21"; then
    services+="FTP (21) "
  fi
  if echo "$open_udp_ports" | grep -q "53"; then
    services+="DNS (53) "
  fi
  if echo "$open_udp_ports" | grep -q "51820"; then
    services+="WireGuard (51820) "
  fi
  
  if [ -n "$services" ]; then
    echo -e "  $services"
  else
    echo -e "  None detected"
  fi
  
  # Recent activity (top 5 rules by packet count)
  echo -e "\n${YELLOW}Recent Activity (Top 5 Rules):${NC}"
  iptables -L INPUT -v -n | tail -n +3 | sort -rn -k 1 | head -5 | \
    awk '{printf "  %s packets (%s bytes) - %s\n", $1, $2, $0}' | \
    sed -E 's/  [0-9]+ packets $$[0-9]+ bytes$$ - [0-9]+ [0-9]+ //g'
  
  # IP Forwarding status
  echo -e "\n${YELLOW}IP Forwarding Status:${NC}"
  if [ "$(cat /proc/sys/net/ipv4/ip_forward)" -eq 1 ]; then
    echo -e "  ${GREEN}Enabled${NC}"
  else
    echo -e "  ${RED}Disabled${NC}"
  fi
  
  # Active network routes
  echo -e "\n${YELLOW}Active Network Routes:${NC}"
  if [ -d "$ROUTES_DIR" ] && [ "$(ls -A "$ROUTES_DIR" 2>/dev/null)" ]; then
    for route_file in "$ROUTES_DIR"/*; do
      if [ -f "$route_file" ]; then
        route_name=$(basename "$route_file")
        echo -e "  - $route_name"
      fi
    done
  else
    echo -e "  None configured"
  fi
  
  echo -e "\n${BLUE}Press Enter to continue...${NC}"
  read
}

# Function to add a custom rule
add_custom_rule() {
  show_header
  echo -e "${CYAN}╔═══ ADD CUSTOM RULE ═══╗${NC}"
  
  # Choose chain
  echo -e "${YELLOW}Select chain:${NC}"
  echo "1) INPUT (incoming traffic)"
  echo "2) OUTPUT (outgoing traffic)"
  echo "3) FORWARD (traffic being routed)"
  echo -e "${BLUE}Enter your choice (1-3):${NC} "
  read -r chain_choice
  
  case $chain_choice in
    1) chain="INPUT" ;;
    2) chain="OUTPUT" ;;
    3) chain="FORWARD" ;;
    *) 
      echo -e "${RED}Invalid choice. Returning to main menu.${NC}"
      sleep 2
      return
      ;;
  esac
  
  # Choose protocol
  echo -e "\n${YELLOW}Select protocol:${NC}"
  echo "1) TCP"
  echo "2) UDP"
  echo "3) Both (TCP and UDP)"
  echo "4) ICMP (ping)"
  echo "5) All protocols"
  echo -e "${BLUE}Enter your choice (1-5):${NC} "
  read -r protocol_choice
  
  case $protocol_choice in
    1) protocol="tcp" ;;
    2) protocol="udp" ;;
    3) protocol="all" ;;
    4) protocol="icmp" ;;
    5) protocol="all" ;;
    *) 
      echo -e "${RED}Invalid choice. Returning to main menu.${NC}"
      sleep 2
      return
      ;;
  esac
  
  # Port (if TCP or UDP)
  port=""
  if [ "$protocol" = "tcp" ] || [ "$protocol" = "udp" ]; then
    echo -e "\n${YELLOW}Enter port number or service name:${NC}"
    echo "Examples: 22 (SSH), 80 (HTTP), 443 (HTTPS), etc."
    echo -e "${BLUE}Port/Service:${NC} "
    read -r port
    
    if ! [[ "$port" =~ ^[0-9]+$ ]] && ! grep -q "^$port" /etc/services; then
      echo -e "${RED}Invalid port or service. Returning to main menu.${NC}"
      sleep 2
      return
    fi
  fi
  
  # Source IP address
  echo -e "\n${YELLOW}Enter source IP address:${NC}"
  echo "Examples: 192.168.1.10, 10.0.0.0/8, or leave empty for any"
  echo -e "${BLUE}Source IP:${NC} "
  read -r source_ip
  
  # If empty, use any
  if [ -z "$source_ip" ]; then
    source_ip="0.0.0.0/0"
  fi
  
  # Action
  echo -e "\n${YELLOW}Select action:${NC}"
  echo "1) ACCEPT (allow traffic)"
  echo "2) DROP (silently discard traffic)"
  echo "3) REJECT (discard and send error message)"
  echo -e "${BLUE}Enter your choice (1-3):${NC} "
  read -r action_choice
  
  case $action_choice in
    1) action="ACCEPT" ;;
    2) action="DROP" ;;
    3) action="REJECT" ;;
    *) 
      echo -e "${RED}Invalid choice. Returning to main menu.${NC}"
      sleep 2
      return
      ;;
  esac
  
  # Temporary rule?
  echo -e "\n${YELLOW}Is this a temporary rule?${NC}"
  echo "1) No (permanent)"
  echo "2) Yes (will be removed after system reboot)"
  echo "3) Timed (specify duration in minutes)"
  echo -e "${BLUE}Enter your choice (1-3):${NC} "
  read -r temp_choice
  
  # Build the iptables command
  cmd="iptables -A $chain"
  
  if [ "$protocol" != "all" ]; then
    cmd="$cmd -p $protocol"
  fi
  
  if [ -n "$port" ] && [ "$protocol" != "icmp" ]; then
    cmd="$cmd --dport $port"
  fi
  
  if [ "$source_ip" != "0.0.0.0/0" ]; then
    cmd="$cmd -s $source_ip"
  fi
  
  cmd="$cmd -j $action"
  
  # Confirm rule
  echo -e "\n${YELLOW}Rule to be added:${NC}"
  echo -e "${GREEN}$cmd${NC}"
  echo -e "\n${BLUE}Confirm? (y/n):${NC} "
  read -r confirm
  
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    # Execute the command
    eval "$cmd"
    
    if [ $? -eq 0 ]; then
      echo -e "${GREEN}Rule added successfully!${NC}"
      log_action "Added rule: $cmd"
      
      # Handle temporary rule
      if [ "$temp_choice" = "3" ]; then
        echo -e "\n${YELLOW}Enter duration in minutes:${NC} "
        read -r duration
        
        if [[ "$duration" =~ ^[0-9]+$ ]]; then
          # Create a background job to remove the rule after the specified time
          (
            sleep $((duration * 60))
            # Find and delete the rule (this is a simplified approach)
            rule_num=$(iptables -L $chain --line-numbers | grep "$action" | tail -1 | awk '{print $1}')
            if [ -n "$rule_num" ]; then
              iptables -D $chain $rule_num
              log_action "Removed temporary rule after $duration minutes: $cmd"
            fi
          ) &
          echo -e "${GREEN}Rule will be automatically removed after $duration minutes.${NC}"
        else
          echo -e "${RED}Invalid duration. Rule added as permanent.${NC}"
        fi
      fi
      
      # Save if permanent
      if [ "$temp_choice" = "1" ]; then
        if command -v iptables-save > /dev/null; then
            if command -v iptables-save > /dev/null; then
              iptables-save > /etc/iptables/rules.v4 2>/dev/null || iptables-save > /etc/iptables.rules
            else
            echo -e "${YELLOW}Warning: iptables-save not found. Rules may not persist after reboot.${NC}"
          fi
          echo -e "${GREEN}Rules saved permanently.${NC}"
        else
          echo -e "${YELLOW}Warning: iptables-save not found. Rule may not persist after reboot.${NC}"
        fi
      fi
    else
      echo -e "${RED}Failed to add rule.${NC}"
    fi
  else
    echo -e "${YELLOW}Operation cancelled.${NC}"
  fi
  
  echo -e "\n${BLUE}Press Enter to continue...${NC}"
  read
}

# Function to delete rules
delete_rules() {
  show_header
  echo -e "${CYAN}╔═══ DELETE RULES ═══╗${NC}"
  
  echo -e "${YELLOW}Select option:${NC}"
  echo "1) Delete specific rule"
  echo "2) Delete all rules in a chain"
  echo "3) Reset firewall (delete all rules)"
  echo "4) Back to main menu"
  echo -e "${BLUE}Enter your choice (1-4):${NC} "
  read -r delete_choice
  
  case $delete_choice in
    1)
      # Delete specific rule
      echo -e "\n${YELLOW}Select chain:${NC}"
      echo "1) INPUT"
      echo "2) OUTPUT"
      echo "3) FORWARD"
      echo -e "${BLUE}Enter your choice (1-3):${NC} "
      read -r chain_choice
      
      case $chain_choice in
        1) chain="INPUT" ;;
        2) chain="OUTPUT" ;;
        3) chain="FORWARD" ;;
        *) 
          echo -e "${RED}Invalid choice. Returning to main menu.${NC}"
          sleep 2
          return
          ;;
      esac
      
      # Show rules with line numbers
      echo -e "\n${YELLOW}Current rules in $chain chain:${NC}"
      iptables -L $chain --line-numbers
      
      echo -e "\n${YELLOW}Enter rule number to delete:${NC} "
      read -r rule_num
      
      if [[ "$rule_num" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Warning: This will delete rule #$rule_num from the $chain chain.${NC}"
        echo -e "${BLUE}Confirm? (y/n):${NC} "
        read -r confirm
        
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
          iptables -D $chain $rule_num
          
          if [ $? -eq 0 ]; then
            echo -e "${GREEN}Rule deleted successfully!${NC}"
            log_action "Deleted rule #$rule_num from $chain chain"
            
            # Save changes
            if command -v iptables-save > /dev/null; then
              iptables-save > /etc/iptables/rules.v4 2>/dev/null || iptables-save > /etc/iptables.rules
            fi
          else
            echo -e "${RED}Failed to delete rule.${NC}"
          fi
        else
          echo -e "${YELLOW}Operation cancelled.${NC}"
        fi
      else
        echo -e "${RED}Invalid rule number.${NC}"
      fi
      ;;
      
    2)
      # Delete all rules in a chain
      echo -e "\n${YELLOW}Select chain to flush:${NC}"
      echo "1) INPUT"
      echo "2) OUTPUT"
      echo "3) FORWARD"
      echo "4) All chains"
      echo -e "${BLUE}Enter your choice (1-4):${NC} "
      read -r chain_choice
      
      case $chain_choice in
        1) chain="INPUT" ;;
        2) chain="OUTPUT" ;;
        3) chain="FORWARD" ;;
        4) chain="all" ;;
        *) 
          echo -e "${RED}Invalid choice. Returning to main menu.${NC}"
          sleep 2
          return
          ;;
      esac
      
      echo -e "${RED}Warning: This will delete ALL rules in the $chain chain.${NC}"
      echo -e "${BLUE}Confirm? (y/n):${NC} "
      read -r confirm
      
      if [[ "$confirm" =~ ^[Yy]$ ]]; then
        if [ "$chain" = "all" ]; then
          iptables -F
          echo -e "${GREEN}All chains flushed successfully!${NC}"
          log_action "Flushed all chains"
        else
          iptables -F $chain
          echo -e "${GREEN}$chain chain flushed successfully!${NC}"
          log_action "Flushed $chain chain"
        fi
        
        # Save changes
        if command -v iptables-save > /dev/null; then
          iptables-save > /etc/iptables/rules.v4 2>/dev/null || iptables-save > /etc/iptables.rules
        fi
      else
        echo -e "${YELLOW}Operation cancelled.${NC}"
      fi
      ;;
      
    3)
      # Reset firewall
      echo -e "${RED}WARNING: This will delete ALL rules, chains, and reset default policies.${NC}"
      echo -e "${RED}You may lose network connectivity if you don't have proper default rules.${NC}"
      echo -e "${BLUE}Are you ABSOLUTELY sure? (type 'RESET' to confirm):${NC} "
      read -r confirm
      
      if [ "$confirm" = "RESET" ]; then
        # Save current rules first
        local timestamp=$(date +%Y%m%d%H%M%S)
        local backup_file="$PROFILES_DIR/backup_before_reset_$timestamp"
        
        iptables-save > "$backup_file"
        
        # Reset everything
        iptables -F
        iptables -X
        iptables -t nat -F
        iptables -t nat -X
        iptables -t mangle -F
        iptables -t mangle -X
        
        # Set default policies to ACCEPT
        iptables -P INPUT ACCEPT
        iptables -P OUTPUT ACCEPT
        iptables -P FORWARD ACCEPT
        
        echo -e "${GREEN}Firewall reset successfully!${NC}"
        echo -e "${YELLOW}Backup saved to $backup_file${NC}"
        log_action "Reset firewall (backup saved to $backup_file)"
        
        # Add basic rules to prevent lockout
        echo -e "${YELLOW}Would you like to add basic safety rules? (y/n):${NC} "
        read -r add_safety
        
        if [[ "$add_safety" =~ ^[Yy]$ ]]; then
          # Allow loopback
          iptables -A INPUT -i lo -j ACCEPT
          
          # Allow established connections
          iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
          
          # Allow SSH
          iptables -A INPUT -p tcp --dport 22 -j ACCEPT
          
          # Set default policies
          iptables -P INPUT DROP
          iptables -P FORWARD DROP
          iptables -P OUTPUT ACCEPT
          
          echo -e "${GREEN}Basic safety rules added.${NC}"
          log_action "Added basic safety rules after reset"
          
          # Save changes
          if command -v iptables-save > /dev/null; then
            iptables-save > /etc/iptables/rules.v4 2>/dev/null || iptables-save > /etc/iptables.rules
          fi
        fi
      else
        echo -e "${YELLOW}Operation cancelled.${NC}"
      fi
      ;;
      
    4)
      # Back to main menu
      return
      ;;
      
    *)
      echo -e "${RED}Invalid choice. Returning to main menu.${NC}"
      sleep 2
      return
      ;;
  esac
  
  echo -e "\n${BLUE}Press Enter to continue...${NC}"
  read
}

# Function to save and restore profiles
manage_profiles() {
  show_header
  echo -e "${CYAN}╔═══ PROFILE MANAGEMENT ═══╗${NC}"
  
  echo -e "${YELLOW}Select option:${NC}"
  echo "1) Save current rules as profile"
  echo "2) Load profile"
  echo "3) Delete profile"
  echo "4) List available profiles"
  echo "5) Back to main menu"
  echo -e "${BLUE}Enter your choice (1-5):${NC} "
  read -r profile_choice
  
  case $profile_choice in
    1)
      # Save profile
      echo -e "\n${YELLOW}Enter profile name:${NC} "
      read -r profile_name
      
      if [ -z "$profile_name" ]; then
        echo -e "${RED}Profile name cannot be empty.${NC}"
      else
        # Sanitize profile name
        profile_name=$(echo "$profile_name" | tr -cd '[:alnum:]._-')
        profile_file="$PROFILES_DIR/$profile_name"
        
        # Check if profile already exists
        if [ -f "$profile_file" ]; then
          echo -e "${YELLOW}Profile already exists. Overwrite? (y/n):${NC} "
          read -r overwrite
          
          if ! [[ "$overwrite" =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}Operation cancelled.${NC}"
            echo -e "\n${BLUE}Press Enter to continue...${NC}"
            read
            return
          fi
        fi
        
        # Save rules to profile
        iptables-save > "$profile_file"
        
        if [ $? -eq 0 ]; then
          echo -e "${GREEN}Profile saved successfully!${NC}"
          log_action "Saved profile: $profile_name"
        else
          echo -e "${RED}Failed to save profile.${NC}"
        fi
      fi
      ;;
      
    2)
      # Load profile
      echo -e "\n${YELLOW}Available profiles:${NC}"
      ls -1 "$PROFILES_DIR" 2>/dev/null
      
      echo -e "\n${YELLOW}Enter profile name to load:${NC} "
      read -r profile_name
      
      profile_file="$PROFILES_DIR/$profile_name"
      
      if [ -f "$profile_file" ]; then
        echo -e "${RED}Warning: This will replace all current rules.${NC}"
        echo -e "${BLUE}Confirm? (y/n):${NC} "
        read -r confirm
        
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
          # Backup current rules
          local timestamp=$(date +%Y%m%d%H%M%S)
          local backup_file="$PROFILES_DIR/backup_before_load_$timestamp"
          iptables-save > "$backup_file"
          
          # Load profile
          iptables-restore < "$profile_file"
          
          if [ $? -eq 0 ]; then
            echo -e "${GREEN}Profile loaded successfully!${NC}"
            log_action "Loaded profile: $profile_name"
            
            # Save changes
            if command -v iptables-save > /dev/null; then
              iptables-save > /etc/iptables/rules.v4 2>/dev/null || iptables-save > /etc/iptables.rules
            fi
          else
            echo -e "${RED}Failed to load profile.${NC}"
            echo -e "${YELLOW}Restoring previous rules...${NC}"
            iptables-restore < "$backup_file"
          fi
        else
          echo -e "${YELLOW}Operation cancelled.${NC}"
        fi
      else
        echo -e "${RED}Profile not found.${NC}"
      fi
      ;;
      
    3)
      # Delete profile
      echo -e "\n${YELLOW}Available profiles:${NC}"
      ls -1 "$PROFILES_DIR" 2>/dev/null
      
      echo -e "\n${YELLOW}Enter profile name to delete:${NC} "
      read -r profile_name
      
      profile_file="$PROFILES_DIR/$profile_name"
      
      if [ -f "$profile_file" ]; then
        echo -e "${RED}Warning: This will permanently delete the profile.${NC}"
        echo -e "${BLUE}Confirm? (y/n):${NC} "
        read -r confirm
        
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
          rm "$profile_file"
          
          if [ $? -eq 0 ]; then
            echo -e "${GREEN}Profile deleted successfully!${NC}"
            log_action "Deleted profile: $profile_name"
          else
            echo -e "${RED}Failed to delete profile.${NC}"
          fi
        else
          echo -e "${YELLOW}Operation cancelled.${NC}"
        fi
      else
        echo -e "${RED}Profile not found.${NC}"
      fi
      ;;
      
    4)
      # List profiles
      echo -e "\n${YELLOW}Available profiles:${NC}"
      
      if [ -d "$PROFILES_DIR" ]; then
        profiles=$(ls -1 "$PROFILES_DIR" 2>/dev/null)
        
        if [ -z "$profiles" ]; then
          echo -e "${BLUE}No profiles found.${NC}"
        else
          echo -e "${BLUE}$profiles${NC}"
        fi
      else
        echo -e "${BLUE}No profiles found.${NC}"
      fi
      ;;
      
    5)
      # Back to main menu
      return
      ;;
      
    *)
      echo -e "${RED}Invalid choice. Returning to main menu.${NC}"
      sleep 2
      return
      ;;
  esac
  
  echo -e "\n${BLUE}Press Enter to continue...${NC}"
  read
}

# Function to quickly enable/disable firewall
quick_toggle() {
  show_header
  echo -e "${CYAN}╔═══ QUICK TOGGLE ═══╗${NC}"
  
  echo -e "${YELLOW}Select option:${NC}"
  echo "1) Enable enhanced security (block all except essential services)"
  echo "2) Maintenance mode (allow all traffic temporarily)"
  echo "3) Restore previous rules"
  echo "4) Back to main menu"
  echo -e "${BLUE}Enter your choice (1-4):${NC} "
  read -r toggle_choice
  
  case $toggle_choice in
    1)
      # Enhanced security
      echo -e "${YELLOW}This will block all incoming traffic except SSH and established connections.${NC}"
      echo -e "${BLUE}Confirm? (y/n):${NC} "
      read -r confirm
      
      if [[ "$confirm" =~ ^[Yy]$ ]]; then
        # Backup current rules
        local timestamp=$(date +%Y%m%d%H%M%S)
        local backup_file="$PROFILES_DIR/backup_before_enhanced_$timestamp"
        iptables-save > "$backup_file"
        
        # Clear existing rules
        iptables -F
        iptables -X
        
        # Set default policies
        iptables -P INPUT DROP
        iptables -P FORWARD DROP
        iptables -P OUTPUT ACCEPT
        
        # Allow loopback
        iptables -A INPUT -i lo -j ACCEPT
        
        # Allow established connections
        iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
        
        # Allow SSH
        iptables -A INPUT -p tcp --dport 22 -j ACCEPT
        
        echo -e "${GREEN}Enhanced security mode enabled!${NC}"
        echo -e "${YELLOW}Backup saved to $backup_file${NC}"
        log_action "Enabled enhanced security mode (backup saved to $backup_file)"
      else
        echo -e "${YELLOW}Operation cancelled.${NC}"
      fi
      ;;
      
    2)
      # Maintenance mode
      echo -e "${YELLOW}Enter duration in minutes (0 for indefinite):${NC} "
      read -r duration
      
      if ! [[ "$duration" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Invalid duration.${NC}"
        echo -e "\n${BLUE}Press Enter to continue...${NC}"
        read
        return
      fi
      
      echo -e "${RED}Warning: This will allow ALL traffic to your system.${NC}"
      echo -e "${BLUE}Confirm? (y/n):${NC} "
      read -r confirm
      
      if [[ "$confirm" =~ ^[Yy]$ ]]; then
        # Backup current rules
        local timestamp=$(date +%Y%m%d%H%M%S)
        local backup_file="$PROFILES_DIR/backup_before_maintenance_$timestamp"
        iptables-save > "$backup_file"
        
        # Clear existing rules
        iptables -F
        iptables -X
        
        # Set default policies to ACCEPT
        iptables -P INPUT ACCEPT
        iptables -P FORWARD ACCEPT
        iptables -P OUTPUT ACCEPT
        
        echo -e "${GREEN}Maintenance mode enabled!${NC}"
        echo -e "${YELLOW}Backup saved to $backup_file${NC}"
        log_action "Enabled maintenance mode (backup saved to $backup_file)"
        
        if [ "$duration" -gt 0 ]; then
          echo -e "${YELLOW}Maintenance mode will be disabled after $duration minutes.${NC}"
          
          # Create a background job to restore rules after the specified time
          (
            sleep $((duration * 60))
            iptables-restore < "$backup_file"
            log_action "Automatically disabled maintenance mode after $duration minutes"
          ) &
        fi
      else
        echo -e "${YELLOW}Operation cancelled.${NC}"
      fi
      ;;
      
    3)
      # Restore previous rules
      echo -e "\n${YELLOW}Available backups:${NC}"
      ls -1 "$PROFILES_DIR" | grep "backup_" 2>/dev/null
      
      echo -e "\n${YELLOW}Enter backup name to restore:${NC} "
      read -r backup_name
      
      backup_file="$PROFILES_DIR/$backup_name"
      
      if [ -f "$backup_file" ]; then
        echo -e "${RED}Warning: This will replace all current rules.${NC}"
        echo -e "${BLUE}Confirm? (y/n):${NC} "
        read -r confirm
        
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
          # Backup current rules
          local timestamp=$(date +%Y%m%d%H%M%S)
          local current_backup="$PROFILES_DIR/backup_before_restore_$timestamp"
          iptables-save > "$current_backup"
          
          # Restore backup
          iptables-restore < "$backup_file"
          
          if [ $? -eq 0 ]; then
            echo -e "${GREEN}Rules restored successfully!${NC}"
            log_action "Restored rules from backup: $backup_name"
            
            # Save changes
            if command -v iptables-save > /dev/null; then
              iptables-save > /etc/iptables/rules.v4 2>/dev/null || iptables-save > /etc/iptables.rules
            fi
          else
            echo -e "${RED}Failed to restore rules.${NC}"
            echo -e "${YELLOW}Restoring previous rules...${NC}"
            iptables-restore < "$current_backup"
          fi
        else
          echo -e "${YELLOW}Operation cancelled.${NC}"
        fi
      else
        echo -e "${RED}Backup not found.${NC}"
      fi
      ;;
      
    4)
      # Back to main menu
      return
      ;;
      
    *)
      echo -e "${RED}Invalid choice. Returning to main menu.${NC}"
      sleep 2
      return
      ;;
  esac
  
  echo -e "\n${BLUE}Press Enter to continue...${NC}"
  read
}

# Function to set default policies
set_default_policies() {
  show_header
  echo -e "${CYAN}╔═══ DEFAULT POLICIES ═══╗${NC}"
  
  echo -e "${YELLOW}Current default policies:${NC}"
  echo -e "  INPUT: $(iptables -L INPUT | head -n1 | awk '{print $4}')"
  echo -e "  OUTPUT: $(iptables -L OUTPUT | head -n1 | awk '{print $4}')"
  echo -e "  FORWARD: $(iptables -L FORWARD | head -n1 | awk '{print $4}')"
  
  echo -e "\n${YELLOW}Select chain to modify:${NC}"
  echo "1) INPUT"
  echo "2) OUTPUT"
  echo "3) FORWARD"
  echo "4) Back to main menu"
  echo -e "${BLUE}Enter your choice (1-4):${NC} "
  read -r chain_choice
  
  case $chain_choice in
    1) chain="INPUT" ;;
    2) chain="OUTPUT" ;;
    3) chain="FORWARD" ;;
    4) return ;;
    *) 
      echo -e "${RED}Invalid choice. Returning to main menu.${NC}"
      sleep 2
      return
      ;;
  esac
  
  echo -e "\n${YELLOW}Select policy for $chain chain:${NC}"
  echo "1) ACCEPT (allow all traffic by default)"
  echo "2) DROP (silently discard traffic by default)"
  echo "3) REJECT (discard and send error message by default)"
  echo -e "${BLUE}Enter your choice (1-3):${NC} "
  read -r policy_choice
  
  case $policy_choice in
    1) policy="ACCEPT" ;;
    2) policy="DROP" ;;
    3) policy="REJECT" ;;
    *) 
      echo -e "${RED}Invalid choice. Returning to main menu.${NC}"
      sleep 2
      return
      ;;
  esac
  
  # Warning for potentially dangerous settings
  if [ "$chain" = "INPUT" ] && [ "$policy" = "DROP" ]; then
    echo -e "${RED}WARNING: Setting INPUT policy to DROP will block all incoming connections${NC}"
    echo -e "${RED}that are not explicitly allowed. This may lock you out of SSH.${NC}"
    echo -e "${YELLOW}Do you have rules to allow necessary services? (y/n):${NC} "
    read -r has_rules
    
    if ! [[ "$has_rules" =~ ^[Yy]$ ]]; then
      echo -e "${YELLOW}Would you like to add a rule to allow SSH first? (y/n):${NC} "
      read -r add_ssh
      
      if [[ "$add_ssh" =~ ^[Yy]$ ]]; then
        iptables -A INPUT -p tcp --dport 22 -j ACCEPT
        echo -e "${GREEN}Rule added to allow SSH.${NC}"
      fi
    fi
  fi
  
  echo -e "${RED}Warning: Changing default policy to $policy for $chain chain.${NC}"
  echo -e "${BLUE}Confirm? (y/n):${NC} "
  read -r confirm
  
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    iptables -P $chain $policy
    
    if [ $? -eq 0 ]; then
      echo -e "${GREEN}Default policy changed successfully!${NC}"
      log_action "Changed default policy for $chain to $policy"
      
      # Save changes
      if command -v iptables-save > /dev/null; then
        iptables-save > /etc/iptables/rules.v4 2>/dev/null || iptables-save > /etc/iptables.rules
      fi
    else
      echo -e "${RED}Failed to change default policy.${NC}"
    fi
  else
    echo -e "${YELLOW}Operation cancelled.${NC}"
  fi
  
  echo -e "\n${BLUE}Press Enter to continue...${NC}"
  read
}

# Function for audit and monitoring
audit_and_monitor() {
  show_header
  echo -e "${CYAN}╔═══ AUDIT & MONITORING ═══╗${NC}"
  
  echo -e "${YELLOW}Select option:${NC}"
  echo "1) View rules with packet counters"
  echo "2) View recently used rules"
  echo "3) Filter rules by protocol"
  echo "4) Filter rules by port"
  echo "5) Export audit report"
  echo "6) Back to main menu"
  echo -e "${BLUE}Enter your choice (1-6):${NC} "
  read -r audit_choice
  
  case $audit_choice in
    1)
      # View rules with packet counters
      echo -e "\n${YELLOW}Rules with packet counters:${NC}"
      echo -e "${BLUE}INPUT chain:${NC}"
      iptables -L INPUT -v -n
      echo -e "\n${BLUE}OUTPUT chain:${NC}"
      iptables -L OUTPUT -v -n
      echo -e "\n${BLUE}FORWARD chain:${NC}"
      iptables -L FORWARD -v -n
      ;;
      
    2)
      # View recently used rules (rules with non-zero packet count)
      echo -e "\n${YELLOW}Recently used rules:${NC}"
      echo -e "${BLUE}INPUT chain:${NC}"
      iptables -L INPUT -v -n | grep -v "0     0" | grep -v "Chain INPUT"
      echo -e "\n${BLUE}OUTPUT chain:${NC}"
      iptables -L OUTPUT -v -n | grep -v "0     0" | grep -v "Chain OUTPUT"
      echo -e "\n${BLUE}FORWARD chain:${NC}"
      iptables -L FORWARD -v -n | grep -v "0     0" | grep -v "Chain FORWARD"
      ;;
      
    3)
      # Filter rules by protocol
      echo -e "\n${YELLOW}Select protocol:${NC}"
      echo "1) TCP"
      echo "2) UDP"
      echo "3) ICMP"
      echo -e "${BLUE}Enter your choice (1-3):${NC} "
      read -r proto_choice
      
      case $proto_choice in
        1) proto="tcp" ;;
        2) proto="udp" ;;
        3) proto="icmp" ;;
        *) 
          echo -e "${RED}Invalid choice. Returning to main menu.${NC}"
          sleep 2
          return
          ;;
      esac
      
      echo -e "\n${YELLOW}Rules for $proto protocol:${NC}"
      echo -e "${BLUE}INPUT chain:${NC}"
      iptables -L INPUT -v -n | grep -i $proto
      echo -e "\n${BLUE}OUTPUT chain:${NC}"
      iptables -L OUTPUT -v -n | grep -i $proto
      echo -e "\n${BLUE}FORWARD chain:${NC}"
      iptables -L FORWARD -v -n | grep -i $proto
      ;;
      
    4)
      # Filter rules by port
      echo -e "\n${YELLOW}Enter port number:${NC} "
      read -r port
      
      if ! [[ "$port" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Invalid port number.${NC}"
        echo -e "\n${BLUE}Press Enter to continue...${NC}"
        read
        return
      fi
      
      echo -e "\n${YELLOW}Rules for port $port:${NC}"
      echo -e "${BLUE}INPUT chain:${NC}"
      iptables -L INPUT -v -n | grep -i "dpt:$port"
      echo -e "\n${BLUE}OUTPUT chain:${NC}"
      iptables -L OUTPUT -v -n | grep -i "dpt:$port"
      echo -e "\n${BLUE}FORWARD chain:${NC}"
      iptables -L FORWARD -v -n | grep -i "dpt:$port"
      ;;
      
    5)
      # Export audit report
      local timestamp=$(date +%Y%m%d%H%M%S)
      local report_file="/tmp/iptables_audit_$timestamp.txt"
      
      echo "IPTABLES AUDIT REPORT - $(date)" > "$report_file"
      echo "=======================================" >> "$report_file"
      
      echo -e "\nDEFAULT POLICIES:" >> "$report_file"
      echo "INPUT: $(iptables -L INPUT | head -n1 | awk '{print $4}')" >> "$report_file"
      echo "OUTPUT: $(iptables -L OUTPUT | head -n1 | awk '{print $4}')" >> "$report_file"
      echo "FORWARD: $(iptables -L FORWARD | head -n1 | awk '{print $4}')" >> "$report_file"
      
      echo -e "\nINPUT CHAIN RULES:" >> "$report_file"
      iptables -L INPUT -v -n >> "$report_file"
      
      echo -e "\nOUTPUT CHAIN RULES:" >> "$report_file"
      iptables -L OUTPUT -v -n >> "$report_file"
      
      echo -e "\nFORWARD CHAIN RULES:" >> "$report_file"
      iptables -L FORWARD -v -n >> "$report_file"
      
      echo -e "\nACTIVE CONNECTIONS:" >> "$report_file"
      netstat -tuln >> "$report_file" 2>/dev/null || ss -tuln >> "$report_file"
      
      echo -e "\nRECENT FIREWALL LOGS:" >> "$report_file"
      tail -n 50 "$LOG_FILE" >> "$report_file" 2>/dev/null
      
      echo -e "${GREEN}Audit report exported to $report_file${NC}"
      log_action "Exported audit report to $report_file"
      ;;
      
    6)
      # Back to main menu
      return
      ;;
      
    *)
      echo -e "${RED}Invalid choice. Returning to main menu.${NC}"
      sleep 2
      return
      ;;
  esac
  
  echo -e "\n${BLUE}Press Enter to continue...${NC}"
  read
}

# Function for preconfigured rules
preconfigured_rules() {
  show_header
  echo -e "${CYAN}╔═══ PRECONFIGURED RULES ═══╗${NC}"
  
  echo -e "${YELLOW}Select a preset:${NC}"
  echo "1) Basic server (SSH only)"
  echo "2) Web server (HTTP/HTTPS)"
  echo "3) Mail server (SMTP/POP3/IMAP)"
  echo "4) FTP server"
  echo "5) VPN server (WireGuard)"
  echo "6) Database server"
  echo "7) ERPNext server (port 8080)"
  echo "8) Back to main menu"
  echo -e "${BLUE}Enter your choice (1-8):${NC} "
  read -r preset_choice
  
  # Backup current rules before applying preset
  local timestamp=$(date +%Y%m%d%H%M%S)
  local backup_file="$PROFILES_DIR/backup_before_preset_$timestamp"
  iptables-save > "$backup_file"
  
  case $preset_choice in
    1)
      # Basic server (SSH only)
      echo -e "${YELLOW}Applying basic server preset...${NC}"
      
      # Confirm
      echo -e "${RED}Warning: This will replace all current rules.${NC}"
      echo -e "${BLUE}Confirm? (y/n):${NC} "
      read -r confirm
      
      if [[ "$confirm" =~ ^[Yy]$ ]]; then
        # Clear existing rules
        iptables -F
        iptables -X
        
        # Set default policies
        iptables -P INPUT DROP
        iptables -P FORWARD DROP
        iptables -P OUTPUT ACCEPT
        
        # Allow loopback
        iptables -A INPUT -i lo -j ACCEPT
        
        # Allow established connections
        iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
        
        # Allow SSH
        iptables -A INPUT -p tcp --dport 22 -j ACCEPT
        
        # Allow ping
        iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
        
        echo -e "${GREEN}Basic server preset applied successfully!${NC}"
        log_action "Applied basic server preset"
        
        # Save changes
        if command -v iptables-save > /dev/null; then
          iptables-save > /etc/iptables/rules.v4 2>/dev/null || iptables-save > /etc/iptables.rules
        fi
      else
        echo -e "${YELLOW}Operation cancelled.${NC}"
      fi
      ;;
      
    2)
      # Web server (HTTP/HTTPS)
      echo -e "${YELLOW}Applying web server preset...${NC}"
      
      # Confirm
      echo -e "${RED}Warning: This will replace all current rules.${NC}"
      echo -e "${BLUE}Confirm? (y/n):${NC} "
      read -r confirm
      
      if [[ "$confirm" =~ ^[Yy]$ ]]; then
        # Clear existing rules
        iptables -F
        iptables -X
        
        # Set default policies
        iptables -P INPUT DROP
        iptables -P FORWARD DROP
        iptables -P OUTPUT ACCEPT
        
        # Allow loopback
        iptables -A INPUT -i lo -j ACCEPT
        
        # Allow established connections
        iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
        
        # Allow SSH
        iptables -A INPUT -p tcp --dport 22 -j ACCEPT
        
        # Allow HTTP
        iptables -A INPUT -p tcp --dport 80 -j ACCEPT
        
        # Allow HTTPS
        iptables -A INPUT -p tcp --dport 443 -j ACCEPT
        
        # Allow ping
        iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
        
        echo -e "${GREEN}Web server preset applied successfully!${NC}"
        log_action "Applied web server preset"
        
        # Save changes
        if command -v iptables-save > /dev/null; then
          iptables-save > /etc/iptables/rules.v4 2>/dev/null || iptables-save > /etc/iptables.rules
        fi
      else
        echo -e "${YELLOW}Operation cancelled.${NC}"
      fi
      ;;
      
    3)
      # Mail server (SMTP/POP3/IMAP)
      echo -e "${YELLOW}Applying mail server preset...${NC}"
      
      # Confirm
      echo -e "${RED}Warning: This will replace all current rules.${NC}"
      echo -e "${BLUE}Confirm? (y/n):${NC} "
      read -r confirm
      
      if [[ "$confirm" =~ ^[Yy]$ ]]; then
        # Clear existing rules
        iptables -F
        iptables -X
        
        # Set default policies
        iptables -P INPUT DROP
        iptables -P FORWARD DROP
        iptables -P OUTPUT ACCEPT
        
        # Allow loopback
        iptables -A INPUT -i lo -j ACCEPT
        
        # Allow established connections
        iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
        
        # Allow SSH
        iptables -A INPUT -p tcp --dport 22 -j ACCEPT
        
        # Allow SMTP
        iptables -A INPUT -p tcp --dport 25 -j ACCEPT
        
        # Allow SMTPS
        iptables -A INPUT -p tcp --dport 465 -j ACCEPT
        
        # Allow Submission
        iptables -A INPUT -p tcp --dport 587 -j ACCEPT
        
        # Allow POP3
        iptables -A INPUT -p tcp --dport 110 -j ACCEPT
        
        # Allow POP3S
        iptables -A INPUT -p tcp --dport 995 -j ACCEPT
        
        # Allow IMAP
        iptables -A INPUT -p tcp --dport 143 -j ACCEPT
        
        # Allow IMAPS
        iptables -A INPUT -p tcp --dport 993 -j ACCEPT
        
        # Allow ping
        iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
        
        echo -e "${GREEN}Mail server preset applied successfully!${NC}"
        log_action "Applied mail server preset"
        
        # Save changes
        if command -v iptables-save > /dev/null; then
          iptables-save > /etc/iptables/rules.v4 2>/dev/null || iptables-save > /etc/iptables.rules
        fi
      else
        echo -e "${YELLOW}Operation cancelled.${NC}"
      fi
      ;;
      
    4)
      # FTP server
      echo -e "${YELLOW}Applying FTP server preset...${NC}"
      
      # Confirm
      echo -e "${RED}Warning: This will replace all current rules.${NC}"
      echo -e "${BLUE}Confirm? (y/n):${NC} "
      read -r confirm
      
      if [[ "$confirm" =~ ^[Yy]$ ]]; then
        # Clear existing rules
        iptables -F
        iptables -X
        
        # Set default policies
        iptables -P INPUT DROP
        iptables -P FORWARD DROP
        iptables -P OUTPUT ACCEPT
        
        # Allow loopback
        iptables -A INPUT -i lo -j ACCEPT
        
        # Allow established connections
        iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
        
        # Allow SSH
        iptables -A INPUT -p tcp --dport 22 -j ACCEPT
        
        # Allow FTP control
        iptables -A INPUT -p tcp --dport 21 -j ACCEPT
        
        # Allow FTP data (passive mode)
        iptables -A INPUT -p tcp --dport 1024:1048 -j ACCEPT
        
        # Load FTP connection tracking module
        modprobe nf_conntrack_ftp || modprobe ip_conntrack_ftp 2>/dev/null
        
        # Allow ping
        iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
        
        echo -e "${GREEN}FTP server preset applied successfully!${NC}"
        log_action "Applied FTP server preset"
        
        # Save changes
        if command -v iptables-save > /dev/null; then
          iptables-save > /etc/iptables/rules.v4 2>/dev/null || iptables-save > /etc/iptables.rules
        fi
      else
        echo -e "${YELLOW}Operation cancelled.${NC}"
      fi
      ;;
      
    5)
      # VPN server (WireGuard)
      echo -e "${YELLOW}Applying WireGuard VPN server preset...${NC}"
      
      # Confirm
      echo -e "${RED}Warning: This will replace all current rules.${NC}"
      echo -e "${BLUE}Confirm? (y/n):${NC} "
      read -r confirm
      
      if [[ "$confirm" =~ ^[Yy]$ ]]; then
        # Clear existing rules
        iptables -F
        iptables -X
        
        # Set default policies
        iptables -P INPUT DROP
        iptables -P FORWARD DROP
        iptables -P OUTPUT ACCEPT
        
        # Allow loopback
        iptables -A INPUT -i lo -j ACCEPT
        
        # Allow established connections
        iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
        
        # Allow SSH
        iptables -A INPUT -p tcp --dport 22 -j ACCEPT
        
        # Allow WireGuard
        iptables -A INPUT -p udp --dport 51820 -j ACCEPT
        
        # Allow forwarding for WireGuard
        iptables -A FORWARD -i wg0 -j ACCEPT
        iptables -A FORWARD -o wg0 -j ACCEPT
        
        # Enable NAT for VPN clients
        iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
        
        # Allow ping
        iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
        
        # Enable IP forwarding
        echo 1 > /proc/sys/net/ipv4/ip_forward
        
        echo -e "${GREEN}WireGuard VPN server preset applied successfully!${NC}"
        log_action "Applied WireGuard VPN server preset"
        
        # Save changes
        if command -v iptables-save > /dev/null; then
          iptables-save > /etc/iptables/rules.v4 2>/dev/null || iptables-save > /etc/iptables.rules
        fi
        
        # Make IP forwarding persistent
        if [ -f /etc/sysctl.conf ]; then
          if ! grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf; then
            echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
          fi
        fi
      else
        echo -e "${YELLOW}Operation cancelled.${NC}"
      fi
      ;;
      
    6)
      # Database server
      echo -e "${YELLOW}Applying database server preset...${NC}"
      
      # Confirm
      echo -e "${RED}Warning: This will replace all current rules.${NC}"
      echo -e "${BLUE}Confirm? (y/n):${NC} "
      read -r confirm
      
      if [[ "$confirm" =~ ^[Yy]$ ]]; then
        # Clear existing rules
        iptables -F
        iptables -X
        
        # Set default policies
        iptables -P INPUT DROP
        iptables -P FORWARD DROP
        iptables -P OUTPUT ACCEPT
        
        # Allow loopback
        iptables -A INPUT -i lo -j ACCEPT
        
        # Allow established connections
        iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
        
        # Allow SSH
        iptables -A INPUT -p tcp --dport 22 -j ACCEPT
        
        # Allow MySQL/MariaDB
        iptables -A INPUT -p tcp --dport 3306 -j ACCEPT
        
        # Allow PostgreSQL
        iptables -A INPUT -p tcp --dport 5432 -j ACCEPT
        
        # Allow MongoDB
        iptables -A INPUT -p tcp --dport 27017 -j ACCEPT
        
        # Allow Redis
        iptables -A INPUT -p tcp --dport 6379 -j ACCEPT
        
        # Allow ping
        iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
        
        echo -e "${GREEN}Database server preset applied successfully!${NC}"
        log_action "Applied database server preset"
        
        # Save changes
        if command -v iptables-save > /dev/null; then
          iptables-save > /etc/iptables/rules.v4 2>/dev/null || iptables-save > /etc/iptables.rules
        fi
      else
        echo -e "${YELLOW}Operation cancelled.${NC}"
      fi
      ;;

    7)
      # ERPNext server (port 8080)
      echo -e "${YELLOW}Applying ERPNext server preset...${NC}"
      
      # Confirm
      echo -e "${RED}Warning: This will replace all current rules.${NC}"
      echo -e "${BLUE}Confirm? (y/n):${NC} "
      read -r confirm
      
      if [[ "$confirm" =~ ^[Yy]$ ]]; then
        # Clear existing rules
        iptables -F
        iptables -X

        # Set default policies
        iptables -P INPUT DROP
        iptables -P FORWARD DROP
        iptables -P OUTPUT ACCEPT

        # Allow loopback and established connections
        iptables -A INPUT -i lo -j ACCEPT
        iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

        # Allow SSH (optional)
        iptables -A INPUT -p tcp --dport 22 -j ACCEPT

        # Allow ERPNext web interface (port 8080)
        iptables -A INPUT -p tcp --dport 8080 -i wg0 -s 10.0.0.0/24 -j ACCEPT

        echo -e "${GREEN}ERPNext preset applied successfully!${NC}"
        log_action "Applied ERPNext server preset"

        # Save changes
        if command -v iptables-save > /dev/null; then
          iptables-save > /etc/iptables/rules.v4 2>/dev/null || iptables-save > /etc/iptables.rules
        fi
      else
        echo -e "${YELLOW}Operation cancelled.${NC}"
      fi
      ;;

    8)
      # Back to main menu
      return
      ;;
      
    *)
      echo -e "${RED}Invalid choice. Returning to main menu.${NC}"
      sleep 2
      return
      ;;
  esac
  
  echo -e "\n${BLUE}Press Enter to continue...${NC}"
  read
}

# Function for test mode
test_mode() {
  show_header
  echo -e "${CYAN}╔═══ TEST MODE ═══╗${NC}"
  
  echo -e "${YELLOW}This mode allows you to test a rule temporarily.${NC}"
  echo -e "${YELLOW}The rule will be automatically removed after the specified time.${NC}"
  
  # Backup current rules
  local timestamp=$(date +%Y%m%d%H%M%S)
  local backup_file="$PROFILES_DIR/backup_before_test_$timestamp"
  iptables-save > "$backup_file"
  
  # Choose chain
  echo -e "\n${YELLOW}Select chain:${NC}"
  echo "1) INPUT (incoming traffic)"
  echo "2) OUTPUT (outgoing traffic)"
  echo "3) FORWARD (traffic being routed)"
  echo -e "${BLUE}Enter your choice (1-3):${NC} "
  read -r chain_choice
  
  case $chain_choice in
    1) chain="INPUT" ;;
    2) chain="OUTPUT" ;;
    3) chain="FORWARD" ;;
    *) 
      echo -e "${RED}Invalid choice. Returning to main menu.${NC}"
      sleep 2
      return
      ;;
  esac
  
  # Choose protocol
  echo -e "\n${YELLOW}Select protocol:${NC}"
  echo "1) TCP"
  echo "2) UDP"
  echo "3) Both (TCP and UDP)"
  echo "4) ICMP (ping)"
  echo "5) All protocols"
  echo -e "${BLUE}Enter your choice (1-5):${NC} "
  read -r protocol_choice
  
  case $protocol_choice in
    1) protocol="tcp" ;;
    2) protocol="udp" ;;
    3) protocol="all" ;;
    4) protocol="icmp" ;;
    5) protocol="all" ;;
    *) 
      echo -e "${RED}Invalid choice. Returning to main menu.${NC}"
      sleep 2
      return
      ;;
  esac
  
  # Port (if TCP or UDP)
  port=""
  if [ "$protocol" = "tcp" ] || [ "$protocol" = "udp" ]; then
    echo -e "\n${YELLOW}Enter port number or service name:${NC}"
    echo "Examples: 22 (SSH), 80 (HTTP), 443 (HTTPS), etc."
    echo -e "${BLUE}Port/Service:${NC} "
    read -r port
    
    if ! [[ "$port" =~ ^[0-9]+$ ]] && ! grep -q "^$port" /etc/services; then
      echo -e "${RED}Invalid port or service. Returning to main menu.${NC}"
      sleep 2
      return
    fi
  fi
  
  # Source IP address
  echo -e "\n${YELLOW}Enter source IP address:${NC}"
  echo "Examples: 192.168.1.10, 10.0.0.0/8, or leave empty for any"
  echo -e "${BLUE}Source IP:${NC} "
  read -r source_ip
  
  # If empty, use any
  if [ -z "$source_ip" ]; then
    source_ip="0.0.0.0/0"
  fi
  
  # Action
  echo -e "\n${YELLOW}Select action:${NC}"
  echo "1) ACCEPT (allow traffic)"
  echo "2) DROP (silently discard traffic)"
  echo "3) REJECT (discard and send error message)"
  echo -e "${BLUE}Enter your choice (1-3):${NC} "
  read -r action_choice
  
  case $action_choice in
    1) action="ACCEPT" ;;
    2) action="DROP" ;;
    3) action="REJECT" ;;
    *) 
      echo -e "${RED}Invalid choice. Returning to main menu.${NC}"
      sleep 2
      return
      ;;
  esac
  
  # Test duration
  echo -e "\n${YELLOW}Enter test duration in minutes:${NC} "
  read -r duration
  
  if ! [[ "$duration" =~ ^[0-9]+$ ]] || [ "$duration" -eq 0 ]; then
    echo -e "${RED}Invalid duration. Returning to main menu.${NC}"
    sleep 2
    return
  fi
  
  # Build the iptables command
  cmd="iptables -A $chain"
  
  if [ "$protocol" != "all" ]; then
    cmd="$cmd -p $protocol"
  fi
  
  if [ -n "$port" ] && [ "$protocol" != "icmp" ]; then
    cmd="$cmd --dport $port"
  fi
  
  if [ "$source_ip" != "0.0.0.0/0" ]; then
    cmd="$cmd -s $source_ip"
  fi
  
  cmd="$cmd -j $action"
  
  # Confirm rule
  echo -e "\n${YELLOW}Rule to be tested:${NC}"
  echo -e "${GREEN}$cmd${NC}"
  echo -e "\n${YELLOW}Test duration: $duration minutes${NC}"
  echo -e "\n${BLUE}Confirm? (y/n):${NC} "
  read -r confirm
  
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    # Execute the command
    eval "$cmd"
    
    if [ $? -eq 0 ]; then
      echo -e "${GREEN}Test rule applied successfully!${NC}"
      log_action "Started test mode with rule: $cmd (duration: $duration minutes)"
      
      # Start countdown
      echo -e "\n${YELLOW}Test in progress. Rule will be removed in $duration minutes.${NC}"
      echo -e "${YELLOW}Press Ctrl+C to cancel and restore previous rules.${NC}"
      
      # Create a trap to handle Ctrl+C
      trap 'echo -e "${YELLOW}Test cancelled. Restoring previous rules...${NC}"; iptables-restore < "$backup_file"; log_action "Test mode cancelled manually"; echo -e "${GREEN}Previous rules restored.${NC}"; exit 0' INT
      
      # Countdown
      for ((i=duration*60; i>=0; i--)); do
        mins=$((i/60))
        secs=$((i%60))
        printf "\r${BLUE}Time remaining: %02d:%02d${NC}" $mins $secs
        sleep 1
      done
      
      # Restore previous rules
      echo -e "\n\n${YELLOW}Test completed. Restoring previous rules...${NC}"
      iptables-restore < "$backup_file"
      
      if [ $? -eq 0 ]; then
        echo -e "${GREEN}Previous rules restored successfully!${NC}"
        log_action "Test mode completed after $duration minutes"
      else
        echo -e "${RED}Failed to restore previous rules.${NC}"
        echo -e "${YELLOW}Manual intervention may be required.${NC}"
      fi
    else
      echo -e "${RED}Failed to apply test rule.${NC}"
    fi
  else
    echo -e "${YELLOW}Operation cancelled.${NC}"
  fi
  
  # Reset the trap
  trap - INT
  
  echo -e "\n${BLUE}Press Enter to continue...${NC}"
  read
}

# Function to manage network routing
manage_network_routing() {
  show_header
  echo -e "${CYAN}╔═══ NETWORK ROUTING MANAGEMENT ═══╗${NC}"
  
  echo -e "${YELLOW}Select option:${NC}"
  echo "1) Create new network route"
  echo "2) View existing routes"
  echo "3) Delete a route"
  echo "4) Enable/Disable IP forwarding"
  echo "5) Back to main menu"
  echo -e "${BLUE}Enter your choice (1-5):${NC} "
  read -r route_choice
  
  case $route_choice in
    1)
      # Create new network route
      create_network_route
      ;;
      
    2)
      # View existing routes
      view_network_routes
      ;;
      
    3)
      # Delete a route
      delete_network_route
      ;;
      
    4)
      # Enable/Disable IP forwarding
      toggle_ip_forwarding
      ;;
      
    5)
      # Back to main menu
      return
      ;;
      
    *)
      echo -e "${RED}Invalid choice. Returning to main menu.${NC}"
      sleep 2
      return
      ;;
  esac
}

# Function to create a new network route
create_network_route() {
  show_header
  echo -e "${CYAN}╔═══ CREATE NETWORK ROUTE ═══╗${NC}"
  
  # Get route name
  echo -e "${YELLOW}Enter a name for this route:${NC} "
  read -r route_name
  
  if [ -z "$route_name" ]; then
    echo -e "${RED}Route name cannot be empty.${NC}"
    echo -e "\n${BLUE}Press Enter to continue...${NC}"
    read
    return
  fi
  
  # Sanitize route name
  route_name=$(echo "$route_name" | tr -cd '[:alnum:]._-')
  route_file="$ROUTES_DIR/$route_name"
  
  # Check if route already exists
  if [ -f "$route_file" ]; then
    echo -e "${YELLOW}Route already exists. Overwrite? (y/n):${NC} "
    read -r overwrite
    
    if ! [[ "$overwrite" =~ ^[Yy]$ ]]; then
      echo -e "${YELLOW}Operation cancelled.${NC}"
      echo -e "\n${BLUE}Press Enter to continue...${NC}"
      read
      return
    fi
  fi
  
  # Source interface
  echo -e "\n${YELLOW}Enter source interface (e.g., wg0):${NC} "
  read -r source_interface
  
  if [ -z "$source_interface" ]; then
    echo -e "${RED}Source interface cannot be empty.${NC}"
    echo -e "\n${BLUE}Press Enter to continue...${NC}"
    read
    return
  fi
  
  # Source network
  echo -e "\n${YELLOW}Enter source network (e.g., 10.0.0.0/24):${NC} "
  read -r source_network
  
  if [ -z "$source_network" ]; then
    echo -e "${RED}Source network cannot be empty.${NC}"
    echo -e "\n${BLUE}Press Enter to continue...${NC}"
    read
    return
  fi
  
  # Destination interface
  echo -e "\n${YELLOW}Enter destination interface (e.g., eth0):${NC} "
  read -r dest_interface
  
  if [ -z "$dest_interface" ]; then
    echo -e "${RED}Destination interface cannot be empty.${NC}"
    echo -e "\n${BLUE}Press Enter to continue...${NC}"
    read
    return
  fi
  
  # Destination network
  echo -e "\n${YELLOW}Enter destination network (e.g., 192.168.1.0/24):${NC} "
  read -r dest_network
  
  if [ -z "$dest_network" ]; then
    echo -e "${RED}Destination network cannot be empty.${NC}"
    echo -e "\n${BLUE}Press Enter to continue...${NC}"
    read
    return
  fi
  
  # Specific port to forward (optional)
  echo -e "\n${YELLOW}Enter specific port to forward (leave empty for all traffic):${NC} "
  read -r forward_port
  
  # Protocol for port forwarding (if port specified)
  protocol=""
  if [ -n "$forward_port" ]; then
    echo -e "\n${YELLOW}Select protocol for port forwarding:${NC}"
    echo "1) TCP"
    echo "2) UDP"
    echo "3) Both (TCP and UDP)"
    echo -e "${BLUE}Enter your choice (1-3):${NC} "
    read -r protocol_choice
    
    case $protocol_choice in
      1) protocol="tcp" ;;
      2) protocol="udp" ;;
      3) protocol="both" ;;
      *) 
        echo -e "${RED}Invalid choice. Using both TCP and UDP.${NC}"
        protocol="both"
        ;;
    esac
  fi
  
  # Enable NAT
  echo -e "\n${YELLOW}Enable NAT for this route? (y/n):${NC} "
  read -r enable_nat
  
  # Create a temporary file with the commands
  temp_file=$(mktemp)
  
  # Add commands to enable IP forwarding
  echo "# Enable IP forwarding" > "$temp_file"
  echo "echo 1 > /proc/sys/net/ipv4/ip_forward" >> "$temp_file"
  
  # Add forwarding rules
  echo -e "\n# Allow forwarding between interfaces" >> "$temp_file"
  echo "iptables -A FORWARD -i $source_interface -o $dest_interface -s $source_network -d $dest_network -j ACCEPT" >> "$temp_file"
  echo "iptables -A FORWARD -i $dest_interface -o $source_interface -s $dest_network -d $source_network -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT" >> "$temp_file"
  
  # Add specific port forwarding if specified
  if [ -n "$forward_port" ]; then
    echo -e "\n# Port forwarding for port $forward_port" >> "$temp_file"
    
    if [ "$protocol" = "tcp" ] || [ "$protocol" = "both" ]; then
      echo "iptables -A FORWARD -i $source_interface -o $dest_interface -p tcp -s $source_network -d $dest_network --dport $forward_port -j ACCEPT" >> "$temp_file"
      echo "iptables -A FORWARD -i $dest_interface -o $source_interface -p tcp -s $dest_network -d $source_network --sport $forward_port -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT" >> "$temp_file"
    fi
    
    if [ "$protocol" = "udp" ] || [ "$protocol" = "both" ]; then
      echo "iptables -A FORWARD -i $source_interface -o $dest_interface -p udp -s $source_network -d $dest_network --dport $forward_port -j ACCEPT" >> "$temp_file"
      echo "iptables -A FORWARD -i $dest_interface -o $source_interface -p udp -s $dest_network -d $source_network --sport $forward_port -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT" >> "$temp_file"
    fi
  fi
  
  # Add NAT if requested
  if [[ "$enable_nat" =~ ^[Yy]$ ]]; then
    echo -e "\n# Enable NAT" >> "$temp_file"
    echo "iptables -t nat -A POSTROUTING -s $source_network -o $dest_interface -j MASQUERADE" >> "$temp_file"
  fi
  
  # Add commands to make IP forwarding persistent
  echo -e "\n# Make IP forwarding persistent" >> "$temp_file"
  echo "if [ -f /etc/sysctl.conf ]; then" >> "$temp_file"
  echo "  if ! grep -q \"net.ipv4.ip_forward=1\" /etc/sysctl.conf; then" >> "$temp_file"
  echo "    echo \"net.ipv4.ip_forward=1\" >> /etc/sysctl.conf" >> "$temp_file"
  echo "  fi" >> "$temp_file"
  echo "fi" >> "$temp_file"
  
  # Save the route file
  cp "$temp_file" "$route_file"
  rm "$temp_file"
  
  # Display the route configuration
  echo -e "\n${YELLOW}Route configuration:${NC}"
  cat "$route_file"
  
  # Ask if user wants to apply the route now
  echo -e "\n${YELLOW}Apply this route now? (y/n):${NC} "
  read -r apply_now
  
  if [[ "$apply_now" =~ ^[Yy]$ ]]; then
    # Apply the route
    bash "$route_file"
    
    if [ $? -eq 0 ]; then
      echo -e "${GREEN}Route applied successfully!${NC}"
      log_action "Applied network route: $route_name"
      
      # Save iptables rules
      if command -v iptables-save > /dev/null; then
        iptables-save > /etc/iptables/rules.v4 2>/dev/null || iptables-save > /etc/iptables.rules
      fi
    else
      echo -e "${RED}Failed to apply route.${NC}"
    fi
  else
    echo -e "${YELLOW}Route saved but not applied.${NC}"
  fi
  
  echo -e "\n${BLUE}Press Enter to continue...${NC}"
  read
}

# Function to view existing network routes
view_network_routes() {
  show_header
  echo -e "${CYAN}╔═══ VIEW NETWORK ROUTES ═══╗${NC}"
  
  if [ -d "$ROUTES_DIR" ] && [ "$(ls -A "$ROUTES_DIR" 2>/dev/null)" ]; then
    echo -e "${YELLOW}Available routes:${NC}"
    
    for route_file in "$ROUTES_DIR"/*; do
      if [ -f "$route_file" ]; then
        route_name=$(basename "$route_file")
        echo -e "\n${GREEN}=== $route_name ===${NC}"
        cat "$route_file"
        echo -e "${BLUE}------------------------${NC}"
      fi
    done
  else
    echo -e "${YELLOW}No routes found.${NC}"
  fi
  
  echo -e "\n${BLUE}Press Enter to continue...${NC}"
  read
}

# Function to delete a network route
delete_network_route() {
  show_header
  echo -e "${CYAN}╔═══ DELETE NETWORK ROUTE ═══╗${NC}"
  
  if [ -d "$ROUTES_DIR" ] && [ "$(ls -A "$ROUTES_DIR" 2>/dev/null)" ]; then
    echo -e "${YELLOW}Available routes:${NC}"
    ls -1 "$ROUTES_DIR" 2>/dev/null
    
    echo -e "\n${YELLOW}Enter route name to delete:${NC} "
    read -r route_name
    
    route_file="$ROUTES_DIR/$route_name"
    
    if [ -f "$route_file" ]; then
      echo -e "${RED}Warning: This will permanently delete the route.${NC}"
      echo -e "${BLUE}Confirm? (y/n):${NC} "
      read -r confirm
      
      if [[ "$confirm" =~ ^[Yy]$ ]]; then
        # Create a temporary file with commands to remove the route rules
        temp_file=$(mktemp)
        
        # Extract and reverse the iptables commands
        grep "^iptables -A" "$route_file" | sed 's/-A/-D/g' > "$temp_file"
        
        # Ask if user wants to remove the route rules from iptables
        echo -e "\n${YELLOW}Remove the route rules from iptables? (y/n):${NC} "
        read -r remove_rules
        
        if [[ "$remove_rules" =~ ^[Yy]$ ]]; then
          # Apply the reversed commands
          bash "$temp_file"
          
          if [ $? -eq 0 ]; then
            echo -e "${GREEN}Route rules removed successfully!${NC}"
            
            # Save iptables rules
            if command -v iptables-save > /dev/null; then
              iptables-save > /etc/iptables/rules.v4 2>/dev/null || iptables-save > /etc/iptables.rules
            fi
          else
            echo -e "${RED}Failed to remove route rules.${NC}"
          fi
        fi
        
        # Remove the temporary file
        rm "$temp_file"
        
        # Delete the route file
        rm "$route_file"
        
        if [ $? -eq 0 ]; then
          echo -e "${GREEN}Route deleted successfully!${NC}"
          log_action "Deleted network route: $route_name"
        else
          echo -e "${RED}Failed to delete route file.${NC}"
        fi
      else
        echo -e "${YELLOW}Operation cancelled.${NC}"
      fi
    else
      echo -e "${RED}Route not found.${NC}"
    fi
  else
    echo -e "${YELLOW}No routes found.${NC}"
  fi
  
  echo -e "\n${BLUE}Press Enter to continue...${NC}"
  read
}

# Function to toggle IP forwarding
toggle_ip_forwarding() {
  show_header
  echo -e "${CYAN}╔═══ IP FORWARDING ═══╗${NC}"
  
  # Check current IP forwarding status
  ip_forward=$(cat /proc/sys/net/ipv4/ip_forward)
  
  if [ "$ip_forward" -eq 1 ]; then
    echo -e "${YELLOW}IP forwarding is currently ${GREEN}ENABLED${NC}${YELLOW}.${NC}"
    echo -e "${YELLOW}Disable IP forwarding? (y/n):${NC} "
    read -r disable
    
    if [[ "$disable" =~ ^[Yy]$ ]]; then
      echo 0 > /proc/sys/net/ipv4/ip_forward
      
      if [ $? -eq 0 ]; then
        echo -e "${GREEN}IP forwarding disabled successfully!${NC}"
        log_action "Disabled IP forwarding"
        
        # Update sysctl.conf
        if [ -f /etc/sysctl.conf ]; then
          sed -i 's/net.ipv4.ip_forward=1/net.ipv4.ip_forward=0/g' /etc/sysctl.conf
        fi
      else
        echo -e "${RED}Failed to disable IP forwarding.${NC}"
      fi
    else
      echo -e "${YELLOW}Operation cancelled.${NC}"
    fi
  else
    echo -e "${YELLOW}IP forwarding is currently ${RED}DISABLED${NC}${YELLOW}.${NC}"
    echo -e "${YELLOW}Enable IP forwarding? (y/n):${NC} "
    read -r enable
    
    if [[ "$enable" =~ ^[Yy]$ ]]; then
      echo 1 > /proc/sys/net/ipv4/ip_forward
      
      if [ $? -eq 0 ]; then
        echo -e "${GREEN}IP forwarding enabled successfully!${NC}"
        log_action "Enabled IP forwarding"
        
        # Update sysctl.conf
        if [ -f /etc/sysctl.conf ]; then
          if grep -q "net.ipv4.ip_forward" /etc/sysctl.conf; then
            sed -i 's/net.ipv4.ip_forward=0/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
          else
            echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
          fi
        fi
      else
        echo -e "${RED}Failed to enable IP forwarding.${NC}"
      fi
    else
      echo -e "${YELLOW}Operation cancelled.${NC}"
    fi
  fi
  
  echo -e "\n${BLUE}Press Enter to continue...${NC}"
  read
}

# Main menu function
main_menu() {
  while true; do
    show_header
    echo -e "${CYAN}╔═══ MAIN MENU ═══╗${NC}"
    echo -e "${YELLOW}1)${NC} Dashboard"
    echo -e "${YELLOW}2)${NC} Add Custom Rule"
    echo -e "${YELLOW}3)${NC} Delete Rules"
    echo -e "${YELLOW}4)${NC} Profile Management"
    echo -e "${YELLOW}5)${NC} Quick Toggle"
    echo -e "${YELLOW}6)${NC} Default Policies"
    echo -e "${YELLOW}7)${NC} Audit & Monitoring"
    echo -e "${YELLOW}8)${NC} Preconfigured Rules"
    echo -e "${YELLOW}9)${NC} Test Mode"
    echo -e "${YELLOW}10)${NC} Network Routing"
    echo -e "${YELLOW}0)${NC} Exit"
    echo -e "${BLUE}Enter your choice (0-10):${NC} "
    read -r choice
    
    case $choice in
      1) show_dashboard ;;
      2) add_custom_rule ;;
      3) delete_rules ;;
      4) manage_profiles ;;
      5) quick_toggle ;;
      6) set_default_policies ;;
      7) audit_and_monitor ;;
      8) preconfigured_rules ;;
      9) test_mode ;;
      10) manage_network_routing ;;
      0) 
        echo -e "${GREEN}Merci d'avoir utilisé Fire-UX !${NC}"
        exit 0
        ;;
      *) 
        echo -e "${RED}Invalid choice. Please try again.${NC}"
        sleep 2
        ;;
    esac
  done
}

# Check if iptables is installed, and install it if not found
if ! command -v iptables &> /dev/null; then
  echo -e "${YELLOW}iptables n'est pas installé. Tentative d'installation...${NC}"
  
  # Check if we have sudo or root privileges
  if [ "$EUID" -ne 0 ]; then
    echo -e "${YELLOW}Privilèges administrateur requis pour installer iptables.${NC}"
    echo -e "${YELLOW}Exécution de sudo apt update && sudo apt install iptables${NC}"
    sudo apt update && sudo apt install iptables
  else
    # Already running as root
    echo -e "${YELLOW}Exécution de apt update && apt install iptables${NC}"
    apt update && apt install iptables
  fi
  
    # Try to find it in common locations
  if ! command -v iptables &> /dev/null; then
    if [ -f "/sbin/iptables" ]; then
      echo -e "${GREEN}iptables trouvé dans /sbin/iptables${NC}"
      # Create a function to use the full path
      iptables() {
        /sbin/iptables "$@"
      }
      export -f iptables
    elif [ -f "/usr/sbin/iptables" ]; then
      echo -e "${GREEN}iptables trouvé dans /usr/sbin/iptables${NC}"
      # Create a function to use the full path
      iptables() {
        /usr/sbin/iptables "$@"
      }
      export -f iptables
    else
      echo -e "${RED}Échec de l'installation d'iptables. Veuillez l'installer manuellement.${NC}"
      exit 1
    fi
  else
    echo -e "${GREEN}iptables a été installé avec succès!${NC}"
  fi
fi

# Test if iptables works
if ! iptables -V &> /dev/null; then
  echo -e "${RED}iptables est installé mais ne fonctionne pas correctement.${NC}"
  echo -e "${YELLOW}Essayez de l'exécuter manuellement avec 'iptables -V' pour voir l'erreur.${NC}"
  exit 1
fi

# Start the script
log_action "Script started"
main_menu
