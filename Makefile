# =============================================================================
# Nom         : Makefile
# Description : Automatisation des tâches du projet Fire-UX
# Usage       : make <target>
# Auteur      : Fire-UX Contributors
# Version     : 1.0.0
# =============================================================================

SHELL            := /bin/bash
SCRIPT           := fire-ux.sh
INSTALL_SCRIPT   := install.sh
UNINSTALL_SCRIPT := uninstall.sh
TEST_DIR         := tests/

.DEFAULT_GOAL := help

.PHONY: install uninstall test audit lint web-start web-stop web-status web-log help

install: ## Installe Fire-UX sur le système (requiert root)
	@sudo bash $(INSTALL_SCRIPT)

uninstall: ## Désinstalle Fire-UX du système (requiert root)
	@sudo bash $(UNINSTALL_SCRIPT)

test: ## Lance la suite de tests automatisés (nécessite bats-core)
	@if command -v bats &>/dev/null; then \
		echo "Lancement des tests bats..."; \
		bats $(TEST_DIR); \
	else \
		echo "Erreur : bats n'est pas installé."; \
		echo "  https://github.com/bats-core/bats-core"; \
		exit 1; \
	fi

audit: ## Génère un rapport d'audit des règles iptables actives
	@sudo bash $(SCRIPT) --audit-report

lint: ## Analyse statique du code Bash avec shellcheck
	@if command -v shellcheck &>/dev/null; then \
		echo "Analyse shellcheck en cours..."; \
		shellcheck --format=gcc $(SCRIPT) $(INSTALL_SCRIPT) $(UNINSTALL_SCRIPT); \
		echo "Aucune erreur détectée."; \
	else \
		echo "Erreur : shellcheck n'est pas installé."; \
		exit 1; \
	fi

web-start: ## Démarre le service web Fire-UX (interface sur :8080)
	@sudo systemctl start fire-ux-web

web-stop: ## Arrête le service web Fire-UX
	@sudo systemctl stop fire-ux-web

web-status: ## Affiche l'état du service web Fire-UX
	@systemctl status fire-ux-web

web-log: ## Suit les journaux du service web Fire-UX en temps réel
	@journalctl -u fire-ux-web -f

help: ## Affiche cette aide
	@echo ""
	@echo "╔═══════════════════════════════════════════════════════════╗"
	@echo "║               Fire-UX — Cibles disponibles               ║"
	@echo "╚═══════════════════════════════════════════════════════════╝"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| sort \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'
	@echo ""
