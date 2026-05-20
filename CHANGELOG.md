# Journal des modifications — Fire-UX

Toutes les modifications notables de ce projet sont documentées dans ce
fichier, au format [Keep a Changelog](https://keepachangelog.com/fr/1.0.0/).

Ce projet adhère au [versionnage sémantique](https://semver.org/lang/fr/).

---

## [1.0.0] — 2026-05-20

### Ajouté

#### Interface et navigation
- Interface TUI interactive avec en-tête coloré Fire-UX
- Tableau de bord en temps réel : politiques par défaut, compteurs de règles,
  ports ouverts, services détectés, état du forwarding IP, routes actives
- Menu principal à 10 entrées numérotées

#### Gestion des règles
- Création de règles personnalisées : choix de la chaîne (INPUT/OUTPUT/FORWARD),
  du protocole (TCP/UDP/ICMP/tous), du port ou service, de l'IP source,
  de l'action (ACCEPT/DROP/REJECT)
- Règles temporisées avec suppression automatique planifiée
- Suppression de règle par numéro de ligne
- Vidage d'une chaîne ou de toutes les chaînes
- Réinitialisation complète du pare-feu avec sauvegarde automatique préalable
- Mode test avec compte à rebours et restauration automatique (Ctrl+C inclus)

#### Profils et sauvegardes
- Sauvegarde du jeu de règles courant sous un nom de profil personnalisé
- Chargement d'un profil avec sauvegarde automatique de l'état précédent
- Suppression et listage des profils disponibles
- Sauvegardes horodatées automatiques avant chaque opération destructive

#### Préréglages serveur
- Serveur de base (SSH uniquement, politique DROP)
- Serveur web (SSH + HTTP + HTTPS, politique DROP)
- Serveur de messagerie (SMTP/SMTPS/Submission/POP3S/IMAPS, politique DROP)
- Serveur FTP avec module de suivi de connexion (`nf_conntrack_ftp`)
- Serveur VPN WireGuard avec NAT et activation du forwarding IP
- Serveur de base de données (MySQL, PostgreSQL, MongoDB, Redis)
- Serveur ERPNext (port 8080 restreint au réseau WireGuard)

#### Modes rapides
- Mode sécurité renforcée : DROP général sauf SSH et connexions établies
- Mode maintenance : ACCEPT général avec durée optionnelle et restauration auto
- Restauration d'une sauvegarde depuis la liste des backups disponibles

#### Politiques par défaut
- Configuration interactive de la politique par défaut pour INPUT, OUTPUT
  et FORWARD (ACCEPT / DROP / REJECT) avec avertissement anti-lockout SSH

#### Audit et surveillance
- Affichage des règles avec compteurs de paquets et d'octets
- Filtre des règles actives (paquets ≠ 0) par chaîne
- Filtrage des règles par protocole (TCP/UDP/ICMP)
- Filtrage des règles par numéro de port
- Export d'un rapport d'audit complet en texte (règles, connexions actives,
  dernières lignes du journal)

#### Routage réseau
- Création de routes avec forwarding inter-interfaces, NAT optionnel,
  redirection de port spécifique (TCP/UDP/les deux)
- Visualisation et suppression des routes sauvegardées
- Activation / désactivation interactive du forwarding IP avec persistence
  dans `/etc/sysctl.conf`

#### Journal
- Fichier `/var/log/fire-ux.log` horodaté (format ISO 8601) pour toutes
  les actions : ajout/suppression de règles, chargements de profil,
  changements de politique, activations de modes

#### Outillage
- Installateur `install.sh` avec détection automatique de distro
  (apt / dnf / yum / pacman) et installation des dépendances
- Désinstallateur `uninstall.sh` avec confirmation explicite
- `Makefile` avec cibles `install`, `uninstall`, `test`, `audit`, `lint`, `help`
- Suite de tests `bats` couvrant présence du script, flags CLI,
  fonctions de validation et état post-installation
- Workflow GitHub Actions pour l'analyse statique shellcheck sur push/PR

### Sécurité

- Vérification des droits root à l'entrée du script et des installateurs
- Sauvegarde automatique systématique avant toute modification destructive
- Mode test avec restauration garantie : lockout impossible si mal configuré
- Avertissement explicite avant réinitialisation (saisie du mot `RESET`)
- Avertissement anti-lockout SSH lors du passage de INPUT à DROP
- Proposition automatique d'une règle SSH de secours si aucune règle n'est
  en place avant de passer INPUT en DROP
- Permissions restrictives sur les répertoires de configuration (750)
  et le journal (640) : accès root uniquement
- Assainissement (`tr -cd '[:alnum:]._-'`) des noms de profils et de routes
  fournis par l'utilisateur pour prévenir les injections de chemin
- Support de `ipset` pour la gestion de listes d'IP haute performance
  (filtrage GeoIP, blocages massifs)

---

[1.0.0]: https://github.com/spp4tme/fire-ux/releases/tag/v1.0.0
