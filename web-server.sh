#!/bin/bash
# =============================================================================
# Nom         : web-server.sh
# Description : Serveur HTTP Fire-UX — boucle socat/ncat.
#               Délègue chaque connexion à handle_request.sh via socat EXEC:
#               stdin/stdout du sous-processus sont directement connectés au
#               socket TCP — c'est le seul mode fiable avec socat.
# Usage       : sudo bash web-server.sh [port]
# Port défaut : 8080
# Auteur      : Fire-UX Contributors
# Version     : 1.0.0
# =============================================================================

# Pas de set -e : la boucle while doit relancer socat sans quitter le serveur
set -uo pipefail

# ─── Configuration ────────────────────────────────────────────────────────────
WEB_PORT="${1:-8080}"
WEB_HOST="0.0.0.0"
VERSION="1.0.0"

# ─── Vérification des droits root ────────────────────────────────────────────
if [ "${EUID}" -ne 0 ]; then
    echo "Erreur : ce script doit être exécuté en root." >&2
    exit 1
fi

# ─── Chemin absolu du répertoire du script ────────────────────────────────────
# $(cd … && pwd) résout les liens symboliques et donne un chemin absolu
# fiable quel que soit le répertoire courant au moment du lancement
# (ex : appel via systemd, chemin relatif, lien symbolique).
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ─── Localisation du handler ──────────────────────────────────────────────────
# Cherche handle_request.sh dans le même dossier que ce script,
# puis dans le répertoire d'installation système.
if [ -f "${SCRIPT_DIR}/handle_request.sh" ]; then
    HANDLER="${SCRIPT_DIR}/handle_request.sh"
elif [ -f "/usr/local/lib/fire-ux/handle_request.sh" ]; then
    HANDLER="/usr/local/lib/fire-ux/handle_request.sh"
else
    echo "Erreur : handle_request.sh introuvable." >&2
    echo "  Cherché dans : ${SCRIPT_DIR}" >&2
    echo "  Cherché dans : /usr/local/lib/fire-ux/" >&2
    exit 1
fi

chmod +x "${HANDLER}"

# ─── Détection de l'outil réseau ──────────────────────────────────────────────
# socat en priorité, ncat en fallback
if command -v socat &>/dev/null; then
    NET_TOOL="socat"
elif command -v ncat &>/dev/null; then
    NET_TOOL="ncat"
else
    echo "Erreur : socat ou ncat est requis." >&2
    echo "  apt install socat   OU   apt install ncat" >&2
    exit 1
fi

# ─── Enregistrement du PID ────────────────────────────────────────────────────
echo $$ > /run/fire-ux-web.pid

# ─── Démarrage ────────────────────────────────────────────────────────────────
echo "Fire-UX Web Interface v${VERSION} — PID $$" >&2
echo "Outil réseau : ${NET_TOOL}" >&2
echo "Handler      : ${HANDLER}" >&2
echo "Écoute sur   : http://${WEB_HOST}:${WEB_PORT}" >&2

# ─── Boucle principale ────────────────────────────────────────────────────────
# La boucle while relance automatiquement socat/ncat s'il s'arrête.
# Chaque connexion crée un sous-processus bash qui exécute HANDLER :
#   fd 0 (stdin)  du sous-processus = données reçues du socket TCP
#   fd 1 (stdout) du sous-processus = données envoyées vers le socket TCP
# Le chemin du handler est ABSOLU : socat hérite du CWD du serveur,
# pas nécessairement le répertoire du projet.
while true; do
    if [ "${NET_TOOL}" = "socat" ]; then
        # reuseaddr : réutilise l'adresse sans attendre la fin du TIME_WAIT
        # fork      : un sous-processus par connexion (parallélisme)
        # EXEC:     : connecte stdin/stdout du sous-processus au socket
        socat \
            TCP-LISTEN:"${WEB_PORT}",reuseaddr,fork,bind="${WEB_HOST}" \
            EXEC:"bash ${HANDLER}" \
            2>/dev/null || true
    else
        # ncat --sh-exec : équivalent fonctionnel de socat EXEC:
        ncat \
            --listen "${WEB_HOST}" "${WEB_PORT}" \
            --keep-open \
            --sh-exec "bash ${HANDLER}" \
            2>/dev/null || true
    fi

    echo "$(date '+%Y-%m-%d %H:%M:%S') — ${NET_TOOL} arrêté, redémarrage dans 1 s..." >&2
    sleep 1
done
