#!/usr/bin/env bats
# =============================================================================
# Nom         : fire-ux.bats
# Description : Tests automatisés pour Fire-UX (framework bats-core)
# Usage       : bats tests/fire-ux.bats    (depuis la racine du projet)
# Auteur      : Fire-UX Contributors
# Version     : 1.0.0
# =============================================================================
#
# Prérequis dans fire-ux.sh pour que tous ces tests passent :
#   1. --help géré AVANT la vérification root ; affiche "Fire-UX" et exit 0
#   2. --dry-run désactive les appels iptables effectifs
#   3. Fonctions validate_ip(), validate_port(), check_deps() définies
#   4. Guard en fin de script :
#        [ "${FIRE_UX_TEST:-0}" -ne 1 ] && main_menu
# =============================================================================

# ─── Chemin vers le script principal ─────────────────────────────────────────
SCRIPT_PATH="${BATS_TEST_DIRNAME}/../fire-ux.sh"

# ─── Chargement des fonctions internes (mode non-interactif) ─────────────────
load_functions() {
    export FIRE_UX_TEST=1
    # shellcheck disable=SC1090
    source "${SCRIPT_PATH}" 2>/dev/null || true
}

# ─── Présence et exécutabilité ───────────────────────────────────────────────

@test "fire-ux.sh est présent dans le répertoire du projet" {
    [ -f "${SCRIPT_PATH}" ]
}

@test "fire-ux.sh est exécutable" {
    [ -x "${SCRIPT_PATH}" ]
}

# ─── Flags de ligne de commande ──────────────────────────────────────────────

@test "--help retourne un code de sortie 0" {
    run bash "${SCRIPT_PATH}" --help
    [ "${status}" -eq 0 ]
}

@test "--help affiche 'Fire-UX' dans la sortie" {
    run bash "${SCRIPT_PATH}" --help
    [[ "${output}" == *"Fire-UX"* ]]
}

@test "--dry-run combiné à --help se termine sans erreur" {
    run bash "${SCRIPT_PATH}" --dry-run --help
    [ "${status}" -eq 0 ]
}

@test "--dry-run ne modifie pas les règles iptables" {
    local rules_before
    rules_before=$(iptables-save 2>/dev/null || echo "non-root")

    if [ "${rules_before}" = "non-root" ]; then
        skip "Nécessite les droits root pour lire les règles iptables"
    fi

    run bash "${SCRIPT_PATH}" --dry-run

    local rules_after
    rules_after=$(iptables-save 2>/dev/null || echo "non-root")
    [ "${rules_before}" = "${rules_after}" ]
}

# ─── validate_ip() ───────────────────────────────────────────────────────────

@test "validate_ip() accepte une adresse IPv4 valide (192.168.1.1)" {
    load_functions
    if ! declare -f validate_ip &>/dev/null; then
        skip "validate_ip() n'est pas encore définie dans fire-ux.sh"
    fi
    run validate_ip "192.168.1.1"
    [ "${status}" -eq 0 ]
}

@test "validate_ip() accepte un bloc CIDR valide (10.0.0.0/8)" {
    load_functions
    if ! declare -f validate_ip &>/dev/null; then
        skip "validate_ip() n'est pas encore définie dans fire-ux.sh"
    fi
    run validate_ip "10.0.0.0/8"
    [ "${status}" -eq 0 ]
}

@test "validate_ip() rejette une adresse hors limites (999.999.999.999)" {
    load_functions
    if ! declare -f validate_ip &>/dev/null; then
        skip "validate_ip() n'est pas encore définie dans fire-ux.sh"
    fi
    run validate_ip "999.999.999.999"
    [ "${status}" -ne 0 ]
}

@test "validate_ip() rejette une chaîne non-IP (pas-une-ip)" {
    load_functions
    if ! declare -f validate_ip &>/dev/null; then
        skip "validate_ip() n'est pas encore définie dans fire-ux.sh"
    fi
    run validate_ip "pas-une-ip"
    [ "${status}" -ne 0 ]
}

# ─── validate_port() ─────────────────────────────────────────────────────────

@test "validate_port() accepte le port 80" {
    load_functions
    if ! declare -f validate_port &>/dev/null; then
        skip "validate_port() n'est pas encore définie dans fire-ux.sh"
    fi
    run validate_port "80"
    [ "${status}" -eq 0 ]
}

@test "validate_port() accepte la plage 1:1024" {
    load_functions
    if ! declare -f validate_port &>/dev/null; then
        skip "validate_port() n'est pas encore définie dans fire-ux.sh"
    fi
    run validate_port "1:1024"
    [ "${status}" -eq 0 ]
}

@test "validate_port() rejette le port 99999 (hors limites 1-65535)" {
    load_functions
    if ! declare -f validate_port &>/dev/null; then
        skip "validate_port() n'est pas encore définie dans fire-ux.sh"
    fi
    run validate_port "99999"
    [ "${status}" -ne 0 ]
}

@test "validate_port() rejette la valeur non numérique 'abc'" {
    load_functions
    if ! declare -f validate_port &>/dev/null; then
        skip "validate_port() n'est pas encore définie dans fire-ux.sh"
    fi
    run validate_port "abc"
    [ "${status}" -ne 0 ]
}

# ─── check_deps() ────────────────────────────────────────────────────────────

@test "check_deps() retourne 0 si iptables est présent" {
    load_functions
    if ! declare -f check_deps &>/dev/null; then
        skip "check_deps() n'est pas encore définie dans fire-ux.sh"
    fi
    if ! command -v iptables &>/dev/null; then
        skip "iptables n'est pas installé sur ce système"
    fi
    run check_deps
    [ "${status}" -eq 0 ]
}

# ─── État post-installation ──────────────────────────────────────────────────

@test "/etc/fire-ux/ existe après installation" {
    if [ ! -f "/usr/local/bin/fire-ux" ]; then
        skip "Fire-UX n'est pas installé (lancez : sudo make install)"
    fi
    [ -d "/etc/fire-ux" ]
}

@test "/etc/fire-ux/profiles/ existe après installation" {
    if [ ! -f "/usr/local/bin/fire-ux" ]; then
        skip "Fire-UX n'est pas installé (lancez : sudo make install)"
    fi
    [ -d "/etc/fire-ux/profiles" ]
}

@test "/usr/local/bin/fire-ux est présent et exécutable" {
    if [ ! -f "/usr/local/bin/fire-ux" ]; then
        skip "Fire-UX n'est pas installé (lancez : sudo make install)"
    fi
    [ -x "/usr/local/bin/fire-ux" ]
}

@test "/var/log/fire-ux.log existe après installation" {
    if [ ! -f "/usr/local/bin/fire-ux" ]; then
        skip "Fire-UX n'est pas installé (lancez : sudo make install)"
    fi
    [ -f "/var/log/fire-ux.log" ]
}
