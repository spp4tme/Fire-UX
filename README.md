# 🛡️ Fire-UX

[![ShellCheck](https://github.com/spp4tme/Fire-UX/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/spp4tme/Fire-UX/actions/workflows/shellcheck.yml)
[![License: MIT](https://img.shields.io/badge/Licence-MIT-blue.svg)](LICENSE)
![Bash](https://img.shields.io/badge/Bash-5%2B-green)
![Platform](https://img.shields.io/badge/Plateforme-Linux-lightgrey)

---

`fire-ux.sh` est un **script Bash interactif** pour administrer le pare-feu Linux via `iptables` depuis un terminal coloré et structuré — sans connaître la syntaxe `iptables` par cœur.

---

## 🔧 Ce que fait Fire-UX

- **🧭 Tableau de bord en temps réel** — politiques, règles actives, ports ouverts, services détectés.
- **🧩 Création de règles guidée** — protocole, port, IP source, action, durée optionnelle.
- **💾 Gestion de profils** — sauvegarde et restauration d'instantanés complets du pare-feu.
- **📋 Préréglages prêts à l'emploi** — Web, FTP, VPN, messagerie, base de données, ERPNext.
- **🧪 Mode test avec rollback automatique** — essayez une règle N minutes, retour garanti.
- **📈 Audit exportable** — rapport complet avec compteurs de paquets et journal horodaté.
- **🔀 Routage réseau** — forwarding inter-interfaces, NAT, redirection de port.

---

## 🎯 Fonctionnalités du menu

| # | Entrée | Description |
|---|--------|-------------|
| 1 | **Tableau de bord** | Vue d'ensemble live du pare-feu |
| 2 | **Ajouter une règle** | Création guidée avec règles temporisées |
| 3 | **Supprimer des règles** | Par numéro, par chaîne ou réinitialisation complète |
| 4 | **Gestion des profils** | Sauvegarder / charger / supprimer |
| 5 | **Basculement rapide** | Sécurité renforcée ou mode maintenance |
| 6 | **Politiques par défaut** | Configurer INPUT / OUTPUT / FORWARD |
| 7 | **Audit & surveillance** | Filtres, compteurs, export de rapport |
| 8 | **Règles préconfigurées** | Préréglages par type de serveur |
| 9 | **Mode test** | Règle temporaire avec restauration automatique |
| 10 | **Routage réseau** | Forwarding, NAT, toggle IP forwarding |

---

## 🚀 Installation

### Méthode recommandée — installateur automatique

```bash
git clone git@github.com:spp4tme/Fire-UX.git
cd Fire-UX
sudo bash install.sh
```

L'installateur détecte la distribution (`apt` / `dnf` / `yum` / `pacman`), installe les
dépendances, crée les répertoires de configuration et copie le binaire dans
`/usr/local/bin/fire-ux`.

### Via Make

```bash
sudo make install
```

### Méthode manuelle

```bash
sudo chmod +x fire-ux.sh
sudo ./fire-ux.sh
```

---

## ▶️ Utilisation

```bash
sudo fire-ux
```

> Fire-UX doit être exécuté en root — `iptables` requiert les privilèges noyau.

---

## 🛠️ Commandes Make disponibles

```
make install    Installe Fire-UX sur le système (requiert root)
make uninstall  Désinstalle Fire-UX du système (requiert root)
make test       Lance la suite de tests automatisés (nécessite bats-core)
make audit      Génère un rapport d'audit des règles iptables actives
make lint       Analyse statique du code Bash avec shellcheck
make help       Affiche toutes les cibles disponibles
```

---

## 📜 Préréglages inclus

| Préréglage | Ports ouverts |
|------------|---------------|
| **Serveur de base** | 22 (SSH) |
| **Serveur web** | 22, 80, 443 |
| **Serveur de messagerie** | 25, 465, 587, 110, 995, 143, 993 |
| **VPN (WireGuard)** | 22, 51820/UDP |
| **Serveur de base de données** | 3306, 5432, 27017, 6379 |
| **Serveur FTP** | 21, 1024–1048 |
| **ERPNext** | 8080 (restreint au réseau WireGuard) |

---

## 🗂️ Structure du projet

```
Fire-UX/
├── fire-ux.sh                  Script principal
├── install.sh                  Installateur automatique
├── uninstall.sh                Désinstallateur propre
├── Makefile                    Automatisation des tâches
├── CHANGELOG.md                Journal des modifications
├── LICENSE                     Licence MIT
├── tests/
│   └── fire-ux.bats            Tests automatisés (bats-core)
├── docs/
│   ├── ARCHITECTURE.md         Schéma d'architecture et flux
│   └── DEMO.md                 Scénario de démonstration BTS
└── .github/
    ├── workflows/
    │   └── shellcheck.yml      CI analyse statique
    └── ISSUE_TEMPLATE/
        ├── bug_report.md
        └── feature_request.md
```

---

## 📦 Dépendances

| Paquet | Requis | Rôle |
|--------|--------|------|
| `iptables` | Oui | Gestion du pare-feu |
| `ipset` | Oui | Listes d'IP (GeoIP, blocages) |
| `curl` | Oui | Téléchargements |
| `at` | Oui | Règles temporisées |
| `iptables-persistent` | Recommandé | Persistence au redémarrage |
| `bats-core` | Optionnel | Tests automatisés (`make test`) |
| `shellcheck` | Optionnel | Analyse statique (`make lint`) |

---

## ⚠️ Avertissement

**N'appliquez pas de règles de pare-feu sans savoir ce que vous faites.**
Une mauvaise configuration peut bloquer votre accès SSH ou déconnecter des services.

Utilisez le **mode test** ou effectuez des sauvegardes avant tout changement majeur.

---

## 📄 Licence

Ce projet est distribué sous licence [MIT](LICENSE) — © 2026 Fire-UX Contributors.
