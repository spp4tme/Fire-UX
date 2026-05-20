#!/bin/bash
# =============================================================================
# Nom         : install.sh
# Description : Installateur automatique pour le projet Fire-UX
# Usage       : sudo bash install.sh
# Auteur      : Fire-UX Contributors
# Version     : 1.0.0
# =============================================================================

set -euo pipefail

# ─── Couleurs ────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ─── Constantes ──────────────────────────────────────────────────────────────
readonly INSTALL_BIN="/usr/local/bin/fire-ux"
readonly CONFIG_DIR="/etc/fire-ux"
readonly PROFILES_DIR="${CONFIG_DIR}/profiles"
readonly TIMED_DIR="${CONFIG_DIR}/timed"
readonly LOG_FILE="/var/log/fire-ux.log"
readonly SOURCE_SCRIPT="fire-ux.sh"

# ─── Vérification des droits root ────────────────────────────────────────────
if [ "${EUID}" -ne 0 ]; then
    echo -e "${RED}Erreur : ce script doit être exécuté en root (sudo bash install.sh).${NC}"
    exit 1
fi

# ─── Bannière ────────────────────────────────────────────────────────────────
echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Installation de Fire-UX v1.0.0      ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
echo ""

# ─── Détection du gestionnaire de paquets ────────────────────────────────────
detect_pkg_manager() {
    if command -v apt-get &>/dev/null; then
        echo "apt"
    elif command -v dnf &>/dev/null; then
        echo "dnf"
    elif command -v yum &>/dev/null; then
        echo "yum"
    elif command -v pacman &>/dev/null; then
        echo "pacman"
    else
        echo ""
    fi
}

# ─── Installation des dépendances ────────────────────────────────────────────
install_deps() {
    local pkg_manager
    pkg_manager=$(detect_pkg_manager)

    if [ -z "${pkg_manager}" ]; then
        echo -e "${RED}Erreur : aucun gestionnaire reconnu (apt/dnf/yum/pacman).${NC}"
        exit 1
    fi

    echo -e "${CYAN}Gestionnaire de paquets détecté : ${pkg_manager}${NC}"
    echo -e "${CYAN}Installation des dépendances requises...${NC}"

    # Tableau de dépendances (conforme shellcheck SC2086)
    local -a deps_common=("iptables" "ipset" "curl" "at")

    case "${pkg_manager}" in
        apt)
            apt-get update -qq
            DEBIAN_FRONTEND=noninteractive apt-get install -y \
                "${deps_common[@]}" iptables-persistent
            ;;
        dnf)
            dnf install -y "${deps_common[@]}" iptables-services
            ;;
        yum)
            yum install -y "${deps_common[@]}" iptables-services
            ;;
        pacman)
            pacman -Sy --noconfirm "${deps_common[@]}"
            ;;
    esac

    echo -e "${GREEN}Dépendances installées avec succès.${NC}"
    echo ""

    # Vérification optionnelle de bats (tests automatisés)
    echo -e "${CYAN}Vérification de bats (optionnel)...${NC}"
    if ! command -v bats &>/dev/null; then
        echo -e "${YELLOW}Avertissement : bats n'est pas installé.${NC}"
        echo -e "${YELLOW}  make test ne sera pas disponible.${NC}"
        echo -e "${YELLOW}  Installez-le : https://github.com/bats-core/bats-core${NC}"
    else
        echo -e "${GREEN}bats disponible.${NC}"
    fi
    echo ""
}

# ─── Création des répertoires de configuration ───────────────────────────────
create_dirs() {
    echo -e "${CYAN}Création des répertoires de configuration...${NC}"

    mkdir -p "${PROFILES_DIR}"
    mkdir -p "${TIMED_DIR}"

    chmod 750 "${CONFIG_DIR}"
    chmod 750 "${PROFILES_DIR}"
    chmod 750 "${TIMED_DIR}"

    echo -e "${GREEN}  ${CONFIG_DIR}/          (750)${NC}"
    echo -e "${GREEN}  ${PROFILES_DIR}/  (750)${NC}"
    echo -e "${GREEN}  ${TIMED_DIR}/      (750)${NC}"
    echo ""
}

# ─── Création du fichier de journal ──────────────────────────────────────────
create_log() {
    echo -e "${CYAN}Création du fichier de journal...${NC}"

    touch "${LOG_FILE}"
    chmod 640 "${LOG_FILE}"

    echo -e "${GREEN}  ${LOG_FILE} (640)${NC}"
    echo ""
}

# ─── Copie et installation du script principal ───────────────────────────────
install_script() {
    echo -e "${CYAN}Installation du script principal...${NC}"

    if [ ! -f "${SOURCE_SCRIPT}" ]; then
        echo -e "${RED}Erreur : ${SOURCE_SCRIPT} introuvable dans le répertoire courant.${NC}"
        echo -e "${RED}Lancez install.sh depuis la racine du projet.${NC}"
        exit 1
    fi

    cp "${SOURCE_SCRIPT}" "${INSTALL_BIN}"
    chmod +x "${INSTALL_BIN}"

    echo -e "${GREEN}  ${INSTALL_BIN} (+x)${NC}"
    echo ""
}

# ─── Résumé de l'installation ────────────────────────────────────────────────
print_summary() {
    echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║        Installation réussie !           ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${GREEN}Binaire      :${NC} ${INSTALL_BIN}"
    echo -e "  ${GREEN}Config       :${NC} ${CONFIG_DIR}/"
    echo -e "  ${GREEN}Profils      :${NC} ${PROFILES_DIR}/"
    echo -e "  ${GREEN}Timed rules  :${NC} ${TIMED_DIR}/"
    echo -e "  ${GREEN}Journal      :${NC} ${LOG_FILE}"
    echo ""
    echo -e "${CYAN}Démarrez Fire-UX avec :${NC} sudo fire-ux"
    echo ""
}

# ─── Point d'entrée ──────────────────────────────────────────────────────────
install_deps
create_dirs
create_log
install_script
print_summary
