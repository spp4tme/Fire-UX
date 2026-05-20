# Architecture de Fire-UX

## Vue d'ensemble

Fire-UX est un script Bash interactif qui fournit une interface TUI (Text User
Interface) unifiée pour administrer le pare-feu Linux via `iptables`. Il
centralise la création, la sauvegarde, l'audit et le test des règles dans un
terminal coloré, sans exiger la mémorisation de la syntaxe `iptables` brute.

---

## Schéma d'architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                         UTILISATEUR                              │
│          (terminal interactif  OU  flags CLI : --help …)         │
└──────────────────────────┬───────────────────────────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────────────────────────┐
│                        fire-ux.sh                                │
│                                                                  │
│  ┌──────────────┐  ┌───────────────┐  ┌────────────────────────┐ │
│  │  Menu TUI    │  │  Validation   │  │  Gestion des profils   │ │
│  │  (dashboard, │  │  validate_ip  │  │  save / load / delete  │ │
│  │   presets…)  │  │  validate_port│  │  /etc/fire-ux/profiles/│ │
│  └──────┬───────┘  └──────┬────────┘  └───────────┬────────────┘ │
│         └─────────────────┴─────────────────────┐ │             │
│                                                 ▼ ▼             │
│  ┌──────────────────────────────────────────────────────────────┐ │
│  │                    Moteur de règles                          │ │
│  │     (construction, confirmation, eval de la commande)        │ │
│  └───────────────────────────┬──────────────────────────────────┘ │
│                              │                                   │
│  ┌───────────────────────────▼──────────────────────────────────┐ │
│  │                  Journal d'actions                           │ │
│  │              /var/log/fire-ux.log                            │ │
│  └──────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  ┌──────────────────────┐   ┌──────────────────────────────────┐ │
│  │  Règles temporisées  │   │    Routage réseau / ipset        │ │
│  │  /etc/fire-ux/timed/ │   │  (GeoIP, listes d'IP bloquées)   │ │
│  └──────────────────────┘   └──────────────────────────────────┘ │
└──────────────────────────────┬───────────────────────────────────┘
                               │
              ┌────────────────┼─────────────────┐
              ▼                ▼                 ▼
      ┌──────────────┐ ┌──────────────┐  ┌──────────────┐
      │   iptables   │ │  ip6tables   │  │    ipset     │
      │   (IPv4)     │ │   (IPv6)     │  │ (listes IP)  │
      └──────┬───────┘ └──────┬───────┘  └──────┬───────┘
             └────────────────┴──────────────────┘
                              │
                              ▼
              ┌───────────────────────────────┐
              │          NOYAU LINUX          │
              │     Netfilter / nftables      │
              │  (application effective des   │
              │   règles sur le trafic réseau)│
              └───────────────────────────────┘
```

---

## Description des composants

### Script principal — `fire-ux.sh`

Point d'entrée unique de l'outil. Orchestre le menu TUI, valide les entrées
utilisateur, construit les commandes `iptables` et délègue les actions aux
sous-fonctions. Doit être exécuté en root car `iptables` requiert les
privilèges noyau.

**Fichier :** `/usr/local/bin/fire-ux` (après installation)

### Profils — `/etc/fire-ux/profiles/`

Fichiers de sauvegarde au format `iptables-save`. Chaque profil est un
instantané complet du pare-feu (ex. `prod-web-server`, `vpn-mode`). Des
sauvegardes automatiques horodatées (`backup_before_reset_YYYYMMDDHHMMSS`)
sont créées avant toute opération destructive.

### Règles temporisées — `/etc/fire-ux/timed/`

Métadonnées des règles à durée limitée. Le daemon `at` planifie la suppression
automatique à l'expiration du délai. Le mode test utilise un mécanisme de
restauration similaire via `iptables-restore`.

### Journal d'actions — `/var/log/fire-ux.log`

Trace horodatée au format `YYYY-MM-DD HH:MM:SS - message` de toutes les
actions effectuées : ajout/suppression de règles, chargements de profil,
changements de politique, activations de modes, démarrage du script. Sert de
base pour l'audit de sécurité et la traçabilité.

### GeoIP / ipset (dépendance optionnelle)

Si `ipset` et `geoip-bin` (ou `mmdb-bin`) sont installés, Fire-UX peut
constituer des listes d'adresses IP par pays et les injecter comme cibles dans
`iptables`. Cela permet de bloquer ou restreindre le trafic selon l'origine
géographique (ex. : autoriser uniquement FR et DE).

---

## Flux d'une règle typique

```
1. L'utilisateur sélectionne "Ajouter une règle personnalisée"
       │
       ▼
2. fire-ux.sh invite à choisir : chaîne, protocole, port, IP source, action
       │
       ▼
3. validate_ip() et validate_port() vérifient chaque entrée
       │  échec → message d'erreur + retour au menu
       ▼  succès →
4. Construction de la commande :
       iptables -A INPUT -p tcp --dport 443 -s 0.0.0.0/0 -j ACCEPT
       │
       ▼
5. Affichage de la commande et demande de confirmation (y/n)
       │  n → annulation propre
       ▼  y →
6. eval de la commande → iptables applique la règle dans Netfilter
       │
       ▼
7. log_action() écrit dans /var/log/fire-ux.log
       │
       ▼
8. Si règle permanente : iptables-save → /etc/iptables/rules.v4
       │
       ▼
9. Si règle temporisée : at planifie iptables -D dans N minutes
```

---

## Dépendances optionnelles

| Dépendance            | Rôle                                                          |
|-----------------------|---------------------------------------------------------------|
| `iptables-persistent` | Persistence des règles au redémarrage (Debian/Ubuntu)         |
| `iptables-services`   | Équivalent RHEL/CentOS de iptables-persistent                 |
| `ipset`               | Listes d'IP haute performance (GeoIP, blocages massifs)       |
| `at`                  | Planification de la suppression des règles temporisées        |
| `bats-core`           | Exécution de la suite de tests (`make test`)                  |
| `shellcheck`          | Analyse statique du code Bash (`make lint`)                   |
| `geoip-bin`           | Base de données de géolocalisation IP pour le filtrage par pays |
