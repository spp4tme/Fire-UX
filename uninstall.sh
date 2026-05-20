#!/bin/bash
# =============================================================================
# Nom         : uninstall.sh
# Description : Désinstallateur propre pour le projet Fire-UX
# Usage       : sudo bash uninstall.sh
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
readonly LOG_FILE="/var/log/fire-ux.log"

# ─── Vérification des droits root ────────────────────────────────────────────
if [ "${EUID}" -ne 0 ]; then
    echo -e "${RED}Erreur : ce script doit être exécuté en root (sudo bash uninstall.sh).${NC}"
    exit 1
fi

# ─── Bannière ────────────────────────────────────────────────────────────────
echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║    Désinstallation de Fire-UX v1.0.0    ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
echo ""

# ─── Avertissement règles iptables ───────────────────────────────────────────
echo -e "${YELLOW}┌──────────────────────────────────────────────────────────────┐${NC}"
echo -e "${YELLOW}│  ATTENTION : Les règles iptables actives ne seront PAS       │${NC}"
echo -e "${YELLOW}│  supprimées automatiquement par ce désinstallateur.          │${NC}"
echo -e "${YELLOW}│                                                              │${NC}"
echo -e "${YELLOW}│  Pour les réinitialiser manuellement :                       │${NC}"
echo -e "${YELLOW}│    sudo iptables -F && sudo iptables -X                      │${NC}"
echo -e "${YELLOW}│    sudo iptables -P INPUT   ACCEPT                           │${NC}"
echo -e "${YELLOW}│    sudo iptables -P OUTPUT  ACCEPT                           │${NC}"
echo -e "${YELLOW}│    sudo iptables -P FORWARD ACCEPT                           │${NC}"
echo -e "${YELLOW}└──────────────────────────────────────────────────────────────┘${NC}"
echo ""

# ─── Confirmation ────────────────────────────────────────────────────────────
echo -e "${RED}Confirmez la désinstallation en tapant exactement 'oui' :${NC} "
read -r confirm || true

if [ "${confirm}" != "oui" ]; then
    echo -e "${YELLOW}Désinstallation annulée.${NC}"
    exit 0
fi

echo ""
echo -e "${CYAN}Suppression des fichiers Fire-UX...${NC}"
echo ""

# ─── Suppression du binaire ──────────────────────────────────────────────────
if [ -f "${INSTALL_BIN}" ]; then
    rm -f "${INSTALL_BIN}"
    echo -e "${GREEN}  ✔ Binaire supprimé        : ${INSTALL_BIN}${NC}"
else
    echo -e "${YELLOW}  ⚠ Binaire absent          : ${INSTALL_BIN}${NC}"
fi

# ─── Suppression de la configuration ─────────────────────────────────────────
if [ -d "${CONFIG_DIR}" ]; then
    rm -rf "${CONFIG_DIR}"
    echo -e "${GREEN}  ✔ Configuration supprimée : ${CONFIG_DIR}/${NC}"
else
    echo -e "${YELLOW}  ⚠ Config absente          : ${CONFIG_DIR}/${NC}"
fi

# ─── Suppression du journal ───────────────────────────────────────────────────
if [ -f "${LOG_FILE}" ]; then
    rm -f "${LOG_FILE}"
    echo -e "${GREEN}  ✔ Journal supprimé        : ${LOG_FILE}${NC}"
else
    echo -e "${YELLOW}  ⚠ Journal absent          : ${LOG_FILE}${NC}"
fi

# ─── Résumé ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║       Désinstallation terminée !        ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Rappel : les règles iptables actives restent en place.${NC}"
echo -e "${YELLOW}Réinitialisez-les manuellement si nécessaire.${NC}"
echo ""
