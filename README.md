# 🔥 Fire-UX — Gestionnaire iptables

[![ShellCheck](https://github.com/spp4tme/Fire-UX/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/spp4tme/Fire-UX/actions/workflows/shellcheck.yml)
[![License: MIT](https://img.shields.io/badge/Licence-MIT-blue.svg)](LICENSE)
![Bash](https://img.shields.io/badge/Bash-5%2B-green)
![Platform](https://img.shields.io/badge/Plateforme-Linux-lightgrey)

Fire-UX est un **gestionnaire iptables 100 % Bash** proposant deux interfaces :

- **CLI interactif** (`fire-ux.sh`) — terminal coloré avec menus, dashboard, règles temporisées
- **Interface web** (`web-server.sh`) — dashboard HTTP accessible depuis un navigateur, sans dépendance Node/Python

---

## Sommaire

- [Installation](#installation)
- [CLI interactif](#cli-interactif)
- [Interface web](#interface-web)
  - [Démarrage](#démarrage)
  - [Pages](#pages)
  - [API JSON](#api-json)
  - [Routes POST](#routes-post)
- [Structure du projet](#structure-du-projet)
- [Dépendances](#dépendances)
- [Commandes Make](#commandes-make)
- [Préréglages inclus](#préréglages-inclus)
- [Sécurité](#sécurité)
- [Licence](#licence)

---

## Installation

### Automatique (recommandé)

```bash
git clone https://github.com/spp4tme/Fire-UX.git
cd Fire-UX
sudo bash install.sh
```

L'installateur :
- détecte le gestionnaire de paquets (`apt` / `dnf` / `yum` / `pacman`)
- installe les dépendances système
- copie les scripts dans `/usr/local/bin/` et `/usr/local/lib/fire-ux/`
- crée les répertoires de configuration dans `/etc/fire-ux/`
- installe et active le service systemd `fire-ux-web`

### Via Make

```bash
sudo make install
```

### Manuelle

```bash
sudo chmod +x fire-ux.sh web-server.sh
sudo ./fire-ux.sh          # CLI
sudo ./web-server.sh 8080  # Interface web
```

---

## CLI interactif

```bash
sudo bash fire-ux.sh
```

> Doit être lancé en root — `iptables` requiert les privilèges noyau.

### Menu principal

| # | Section | Description |
|---|---------|-------------|
| 1 | Tableau de bord | Vue live : politiques, règles actives, ports ouverts, services détectés |
| 2 | Ajouter une règle | Création guidée : protocole, port, IP source, action, durée optionnelle |
| 3 | Supprimer des règles | Par numéro, par chaîne ou réinitialisation complète |
| 4 | Gestion des profils | Sauvegarder / charger / supprimer des snapshots iptables |
| 5 | Basculement rapide | Sécurité renforcée ou mode maintenance en un clic |
| 6 | Politiques par défaut | Configurer INPUT / OUTPUT / FORWARD |
| 7 | Audit & surveillance | Filtres, compteurs de paquets, export de rapport |
| 8 | Règles préconfigurées | Préréglages par type de serveur |
| 9 | Mode test | Règle temporaire avec rollback automatique après N minutes |
| 10 | Routage réseau | Forwarding inter-interfaces, NAT, redirection de port |
| 11 | Changer le mot de passe | Modifier le mot de passe du CLI |

---

## Interface web

Serveur HTTP pur Bash basé sur `socat` (ou `ncat` en fallback). Aucune dépendance Python, Node ou Ruby.

### Démarrage

```bash
# Démarrage direct
sudo bash web-server.sh
sudo bash web-server.sh 9090   # port personnalisé (défaut : 8080)

# Via systemd (après install.sh)
sudo systemctl start fire-ux-web
sudo systemctl enable fire-ux-web   # démarrage automatique
sudo systemctl status fire-ux-web

# Accès
http://IP_SERVEUR:8080
```

> Si une instance est déjà en cours, `web-server.sh` la tue automatiquement avant de démarrer.

### Pages

| URL | Description |
|-----|-------------|
| `/` | **Tableau de bord** — compteurs IPv4/IPv6, jauges CPU/RAM, alertes de sécurité, quick-ban, préréglages |
| `/rules` | **Règles** — tableau par chaîne (INPUT/OUTPUT/FORWARD), déplacement ↑↓, suppression, ajout, chaînes personnalisées. Toggle IPv4 / IPv6 |
| `/logs` | **Journaux** — live tail toutes les 5 s, filtre texte + niveau, pause, vidage |
| `/profiles` | **Profils** — liste des snapshots, application via `iptables-restore`, suppression |
| `/network` | **Réseau** — interfaces, table de routage, ports en écoute (PID + processus), connexions établies |
| `/settings` | **Paramètres** — intervalle de rafraîchissement, lignes de logs, port serveur, liste des routes API |

#### Tableau de bord — détail

- **Stat cards** : nombre de règles INPUT / OUTPUT / FORWARD / total, connexions TCP établies
- **Carte IPv6** : compteurs ip6tables en temps réel (si `ip6tables` disponible)
- **Alertes de sécurité** : INPUT DROP sans SSH, sans ESTABLISHED, OUTPUT DROP, absence de filtrage
- **Jauges CPU et RAM** : mise à jour automatique via `/api/stats`
- **Quick-ban** : bloquer une IP (CIDR supporté) en un clic
- **Préréglages** : Web (HTTP/HTTPS/SSH), SSH uniquement, Mode panique, Flush total

#### Page Règles — détail

- **Onglet IPv4 / IPv6** : `?v=6` pour basculer sur `ip6tables`
- **Tableau par chaîne** : numéro, cible, protocole, source, destination, options (commentaires inclus), boutons ↑↓ et ✕
- **Recherche** : filtre texte en temps réel par chaîne
- **Vider une chaîne** : bouton par chaîne ou global
- **Ajouter une règle** : chaîne, protocole, port (ou plage `8000:8080`), IP source (CIDR), action, **commentaire optionnel** (`-m comment`)
- **Chaînes personnalisées** : créer (`POST /add-chain`) et supprimer (`POST /delete-chain`) des chaînes utilisateur

#### Page Profils — détail

- **Snapshot nommé** : champ texte optionnel — si vide, nom automatique `snapshot_YYYYMMDDHHMMSS`
- **Stockage** : `/etc/fire-ux/profiles/`
- **Restauration** : `iptables-restore < profil`
- **Export** : télécharger `iptables-save` complet via `/export`

#### Page Réseau — détail

- **Interfaces** : nom, IP/masque, MAC, état (UP/DOWN)
- **Table de routage** : destination, passerelle, interface, proto, métrique
- **Ports en écoute** : `ss -tlnp` — protocole, adresse locale, PID et nom du processus
- **Connexions établies** : jusqu'à 25 connexions TCP actives

### API JSON

Toutes les routes API retournent du JSON avec `Access-Control-Allow-Origin: *`.

#### `GET /api/stats`

Stats système + iptables, mise à jour toutes les N secondes par le dashboard.

```json
{
  "rules_input": 3,
  "rules_output": 0,
  "rules_forward": 0,
  "policy_input": "DROP",
  "policy_output": "ACCEPT",
  "policy_forward": "DROP",
  "rules_input6": 0,
  "rules_output6": 0,
  "rules_forward6": 0,
  "server_pid": "1234",
  "uptime": "2 hours, 15 minutes",
  "hostname": "srv-prod",
  "ip": "192.168.1.50",
  "mem_pct": 42,
  "cpu_pct": 8,
  "connections": 12,
  "load": "0.25",
  "timestamp": "2026-05-29 14:00:00"
}
```

#### `GET /api/rules?chain=INPUT[&v=6]`

Règles d'une chaîne en JSON. `v=6` pour `ip6tables`.

```json
{
  "chain": "INPUT",
  "version": "",
  "policy": "DROP",
  "rules": [
    {
      "num": "1",
      "target": "ACCEPT",
      "proto": "tcp",
      "src": "0.0.0.0/0",
      "dst": "0.0.0.0/0",
      "opts": "tcp dpt:22 /* Allow SSH */"
    }
  ]
}
```

Paramètres :

| Paramètre | Valeurs | Défaut |
|-----------|---------|--------|
| `chain` | `INPUT`, `OUTPUT`, `FORWARD` | `INPUT` |
| `v` | `6` (ip6tables) | IPv4 |

#### `GET /api/logs?n=100`

Dernières N lignes du journal `/var/log/fire-ux.log` (max 500).

```json
{
  "lines": [
    "2026-05-29 14:00:00 - Règle ajoutée : iptables -A INPUT -p tcp --dport 80 -j ACCEPT"
  ],
  "count": 42
}
```

#### `GET /api/health`

Alertes de sécurité de la configuration iptables actuelle.

```json
{
  "warnings": [
    { "level": "danger",  "msg": "INPUT DROP sans règle SSH (port 22)" },
    { "level": "warning", "msg": "Politique OUTPUT DROP active" },
    { "level": "info",    "msg": "Aucun filtrage INPUT actif" }
  ],
  "count": 1
}
```

#### `GET /export`

Télécharge `iptables-save` complet en fichier `.rules`.

### Routes POST

| Route | Paramètres | Description |
|-------|-----------|-------------|
| `/apply-preset` | `preset=web\|ssh\|panic\|flush_all` | Applique un préréglage complet |
| `/add-rule` | `chain`, `proto`, `port`, `src`, `action`, `comment`, `ipt=4\|6` | Ajoute une règle |
| `/delete-rule` | `num`, `chain`, `ipt=4\|6` | Supprime la règle numéro N |
| `/move-rule` | `num`, `chain`, `dir=up\|down`, `ipt=4\|6` | Déplace une règle |
| `/flush` | `chain=INPUT\|OUTPUT\|FORWARD\|all`, `ipt=4\|6` | Vide une ou toutes les chaînes |
| `/add-chain` | `name`, `ipt=4\|6` | Crée une chaîne personnalisée |
| `/delete-chain` | `name`, `ipt=4\|6` | Supprime une chaîne personnalisée |
| `/save-snapshot` | `name` (optionnel) | Sauvegarde un snapshot dans `/etc/fire-ux/profiles/` |
| `/apply-profile` | `name` | Restaure un profil via `iptables-restore` |
| `/delete-profile` | `name` | Supprime un fichier de profil |
| `/quick-ban` | `ip`, `action=DROP\|REJECT\|ACCEPT`, `chain` | Insère une règle en position 1 |
| `/clear-logs` | — | Vide `/var/log/fire-ux.log` |
| `/save-settings` | `port` | Sauvegarde la config dans `/etc/fire-ux/web.conf` |

---

## Structure du projet

```
Fire-UX/
├── fire-ux.sh          CLI interactif (menus, dashboard terminal, auth, profils)
├── web-server.sh       Serveur HTTP (boucle socat/ncat, fork par connexion)
├── handle_request.sh   Routeur HTTP (parsing, dispatch, handlers POST, API JSON)
├── web-ui.sh           Générateur HTML/CSS/JS (pages, composants, styles)
├── install.sh          Installateur (dépendances, répertoires, service systemd)
├── uninstall.sh        Désinstallateur propre
├── Makefile            Automatisation (install, test, lint, audit)
├── README.md           Ce fichier
├── CHANGELOG.md        Journal des modifications
├── LICENSE             Licence MIT
├── tests/
│   └── fire-ux.bats    Tests automatisés (bats-core)
└── docs/
    ├── ARCHITECTURE.md Schéma d'architecture
    └── DEMO.md         Scénario de démonstration
```

### Flux d'une requête HTTP

```
Navigateur → socat → handle_request.sh
                         │
                         ├── source web-ui.sh       (fonctions HTML)
                         ├── parse headers + body
                         ├── routing case
                         │     ├── GET /  → page_dashboard()
                         │     ├── GET /rules?v=6 → page_rules() avec ip6tables
                         │     ├── GET /api/stats → _api_stats() → JSON
                         │     ├── POST /add-rule → _handle_add_rule() → iptables
                         │     └── ...
                         └── printf HTTP/1.1 → socat → Navigateur
```

---

## Dépendances

| Paquet | Requis | Rôle |
|--------|--------|------|
| `iptables` | Oui | Gestion du pare-feu IPv4 |
| `ip6tables` | Optionnel | Support IPv6 (détecté automatiquement) |
| `socat` | Oui (web) | Serveur TCP pour l'interface web |
| `ncat` | Fallback | Alternatif à socat |
| `ipset` | Oui | Listes d'IP |
| `curl` | Oui | Téléchargements |
| `at` | Oui | Règles temporisées (CLI) |
| `iptables-persistent` | Recommandé | Persistence au redémarrage |
| `bats-core` | Optionnel | Tests (`make test`) |
| `shellcheck` | Optionnel | Analyse statique (`make lint`) |

Installation manuelle des dépendances web :

```bash
# Debian / Ubuntu
apt install socat iptables ip6tables

# RHEL / CentOS
dnf install socat iptables ip6tables
```

---

## Commandes Make

```
make install      Installe Fire-UX (requiert root)
make uninstall    Désinstalle Fire-UX (requiert root)
make web-start    Démarre l'interface web sur le port 8080
make web-stop     Arrête l'interface web
make test         Suite de tests bats-core
make lint         Analyse shellcheck
make audit        Rapport d'audit iptables
make help         Liste toutes les cibles
```

---

## Préréglages inclus

### Interface web (`/apply-preset`)

| Preset | Politique INPUT | Règles ouvertes |
|--------|----------------|-----------------|
| `web` | DROP | lo, ESTABLISHED, SSH (22), HTTP (80), HTTPS (443), ICMP |
| `ssh` | DROP | lo, ESTABLISHED, SSH (22), ICMP |
| `panic` | DROP | lo uniquement (OUTPUT DROP aussi) |
| `flush_all` | ACCEPT | Toutes les règles effacées, tout ouvert |

### CLI (menu 8)

| Préréglage | Ports ouverts |
|------------|---------------|
| Serveur de base | 22 |
| Serveur web | 22, 80, 443 |
| Messagerie | 25, 465, 587, 110, 995, 143, 993 |
| VPN WireGuard | 22, 51820/UDP |
| Base de données | 3306, 5432, 27017, 6379 |
| FTP | 21, 1024–1048 |
| ERPNext | 8080 (réseau WireGuard uniquement) |

---

## Sécurité

> L'interface web **n'a pas d'authentification** par défaut.

**Mesures recommandées :**

1. **Restreindre l'accès par IP** — n'autoriser que votre IP à atteindre le port 8080 :

```bash
# Autoriser seulement votre IP
iptables -A INPUT -p tcp --dport 8080 -s VOTRE_IP -j ACCEPT
iptables -A INPUT -p tcp --dport 8080 -j DROP
```

2. **Écouter sur loopback uniquement** — modifier `WEB_HOST` dans `web-server.sh` :

```bash
WEB_HOST="127.0.0.1"   # accessible uniquement via SSH tunnel
```

Puis se connecter avec un tunnel SSH :

```bash
ssh -L 8080:127.0.0.1:8080 user@serveur
# Ouvrir http://localhost:8080 en local
```

3. **Activer le Basic Auth** — le CLI `fire-ux` configure un mot de passe (SHA256) dans `/etc/fire-ux/.auth`. L'interface web peut être modifiée pour le lire.

---

## Licence

Ce projet est distribué sous licence [MIT](LICENSE) — © 2026 Fire-UX Contributors.
