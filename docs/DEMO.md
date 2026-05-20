# Scénario de démonstration Fire-UX — BTS SIO

## Contexte fictif

> Tu es administrateur système pour **MediaPME**, une PME de 40 personnes qui
> héberge son site vitrine sur un VPS Debian 12. Le serveur est exposé sur
> Internet sans pare-feu actif. Ta mission : sécuriser le serveur, tester les
> règles sans risquer un lockout SSH, puis sauvegarder le profil de production.

---

## Étape 1 — Installation via `install.sh`

### Commande exacte

```bash
git clone https://github.com/spp4tme/fire-ux.git
cd fire-ux
sudo bash install.sh
```

### Ce que l'examinateur voit

```
╔══════════════════════════════════════════╗
║     Installation de Fire-UX v1.0.0      ║
╚══════════════════════════════════════════╝

Gestionnaire de paquets détecté : apt
Installation des dépendances requises...
Dépendances installées avec succès.
bats disponible.

Création des répertoires de configuration...
  /etc/fire-ux/          (750)
  /etc/fire-ux/profiles/ (750)
  /etc/fire-ux/timed/    (750)

Création du fichier de journal...
  /var/log/fire-ux.log (640)

Installation du script principal...
  /usr/local/bin/fire-ux (+x)

╔══════════════════════════════════════════╗
║        Installation réussie !           ║
╚══════════════════════════════════════════╝

  Binaire      : /usr/local/bin/fire-ux
  Config       : /etc/fire-ux/
  Profils      : /etc/fire-ux/profiles/
  Timed rules  : /etc/fire-ux/timed/
  Journal      : /var/log/fire-ux.log

Démarrez Fire-UX avec : sudo fire-ux
```

### Point technique à expliquer à l'oral

> « L'installateur détecte automatiquement le gestionnaire de paquets : `apt`
> sur Debian/Ubuntu, `dnf` sur Fedora/RHEL, `pacman` sur Arch. Les répertoires
> sont créés avec les permissions `750` (lecture/écriture/exécution pour root
> uniquement) et le journal avec `640` (lisible par le groupe). Cela respecte le
> principe du moindre privilège. »

---

## Étape 2 — Lancement et découverte du dashboard

### Commande exacte

```bash
sudo fire-ux
# Puis taper : 1 (Dashboard)
```

### Ce que l'examinateur voit

```
╔════════════════════════════════════════════════════════════╗
║                      FIRE-UX                              ║
╚════════════════════════════════════════════════════════════╝

╔═══ FIREWALL STATUS ═══╗

Default Policies:
  INPUT: ACCEPT
  OUTPUT: ACCEPT
  FORWARD: ACCEPT

Active Rules:
  INPUT: 0 rules
  OUTPUT: 0 rules
  FORWARD: 0 rules
  TOTAL: 0 rules

Open Ports:
  TCP: None
  UDP: None

Allowed Services:
  None detected

IP Forwarding Status:
  Disabled
```

### Point technique à expliquer à l'oral

> « Le dashboard lit en temps réel les règles actives via `iptables -L`. On
> voit que toutes les politiques sont à `ACCEPT` : tout le trafic passe, le
> serveur est complètement ouvert. C'est l'état par défaut d'un VPS vierge,
> et c'est précisément ce qu'on va corriger. »

---

## Étape 3 — Application du preset "Serveur Web"

### Commande exacte

```
Menu principal → 8 (Preconfigured Rules) → 2 (Web server HTTP/HTTPS)
Confirmer : y
```

### Ce que l'examinateur voit

```
╔═══ PRECONFIGURED RULES ═══╗
Select a preset:
1) Basic server (SSH only)
2) Web server (HTTP/HTTPS)
...
Enter your choice (1-8): 2

Applying web server preset...
Warning: This will replace all current rules.
Confirm? (y/n): y

Web server preset applied successfully!
```

### Vérification immédiate (retour au dashboard)

```
Default Policies:
  INPUT: DROP      ← sécurisé
  OUTPUT: ACCEPT
  FORWARD: DROP    ← sécurisé

Open Ports:
  TCP: 22 80 443

Allowed Services:
  SSH (22) HTTP (80) HTTPS (443)
```

### Point technique à expliquer à l'oral

> « Le preset applique une stratégie de liste blanche : la politique par défaut
> passe à `DROP` sur INPUT et FORWARD. Seuls les ports 22 (SSH), 80 (HTTP) et
> 443 (HTTPS) sont ouverts. On autorise aussi les connexions `ESTABLISHED` et
> `RELATED` via `conntrack` pour ne pas bloquer les réponses aux requêtes
> sortantes. »

---

## Étape 4 — Règle temporisée de 5 minutes pour un accès debug

### Commande exacte

```
Menu principal → 9 (Test Mode)
Chain    : 1 (INPUT)
Protocol : 1 (TCP)
Port     : 8080
Source IP: (vide = any)
Action   : 1 (ACCEPT)
Duration : 5 minutes
Confirm  : y
```

### Ce que l'examinateur voit

```
╔═══ TEST MODE ═══╗
This mode allows you to test a rule temporarily.
The rule will be automatically removed after the specified time.

Rule to be tested:
iptables -A INPUT -p tcp --dport 8080 -j ACCEPT

Test duration: 5 minutes
Confirm? (y/n): y

Test rule applied successfully!
Test in progress. Rule will be removed in 5 minutes.
Press Ctrl+C to cancel and restore previous rules.

Time remaining: 04:59  ← compte à rebours en direct
```

### Point technique à expliquer à l'oral

> « Le mode test applique la règle immédiatement puis lance un compte à rebours.
> À l'expiration, `iptables-restore` restaure l'état sauvegardé juste avant le
> test. Si l'admin fait Ctrl+C, la restauration est immédiate. C'est crucial
> pour tester une règle risquée sans provoquer de lockout permanent. »

---

## Étape 5 — Détection d'un service bloqué dans le dashboard

### Commande exacte

```
Menu principal → 1 (Dashboard)
```

### Ce que l'examinateur voit

```
Open Ports:
  TCP: 22 80 443

Allowed Services:
  SSH (22) HTTP (80) HTTPS (443)
```

> *Scénario : le développeur signale que son application sur le port 3000 est
> inaccessible depuis l'extérieur.*

### Point technique à expliquer à l'oral

> « Le dashboard montre que le port 3000 n'apparaît pas dans les ports ouverts.
> Comme la politique INPUT est à DROP, tout port non explicitement autorisé est
> bloqué silencieusement. Pour corriger, on ajouterait une règle via le menu
> "Add Custom Rule" avec port 3000, TCP, action ACCEPT. »

---

## Étape 6 — Protection anti-brute-force SSH

### Commande exacte

```
Menu principal → 2 (Add Custom Rule)
Chain    : 1 (INPUT)
Protocol : 1 (TCP)
Port     : 22
Source IP: (vide)
Action   : 1 (ACCEPT)

# Après cette règle de base, exécuter en complément :
sudo iptables -I INPUT -p tcp --dport 22 -m state --state NEW \
    -m recent --set --name SSH
sudo iptables -I INPUT -p tcp --dport 22 -m state --state NEW \
    -m recent --update --seconds 60 --hitcount 4 --name SSH -j DROP
```

### Ce que l'examinateur voit

```
Rule added successfully!
```

### Point technique à expliquer à l'oral

> « Le module `recent` de Netfilter maintient une liste des IPs qui ont tenté
> une connexion SSH. Si une IP fait plus de 3 tentatives en 60 secondes, la
> 4e est droppée. C'est une protection légère contre les attaques par dictionnaire.
> Pour une protection plus robuste en production, on utiliserait `fail2ban` en
> complément. »

---

## Étape 7 — Génération du rapport d'audit

### Commande exacte

```
Menu principal → 7 (Audit & Monitoring) → 5 (Export audit report)
```

### Ce que l'examinateur voit

```
Audit report exported to /tmp/iptables_audit_20260520143022.txt
```

### Contenu du rapport (extrait)

```
IPTABLES AUDIT REPORT - Wed May 20 14:30:22 UTC 2026
=======================================

DEFAULT POLICIES:
INPUT: DROP
OUTPUT: ACCEPT
FORWARD: DROP

INPUT CHAIN RULES:
Chain INPUT (policy DROP)
 pkts bytes target  prot opt in  out  source    destination
  142  8520 ACCEPT  all  --  lo  any  anywhere  anywhere
 1203 72180 ACCEPT  all  --  any any  anywhere  anywhere  ctstate RELATED,ESTABLISHED
   12   720 ACCEPT  tcp  --  any any  anywhere  anywhere  tcp dpt:ssh
    8   480 ACCEPT  tcp  --  any any  anywhere  anywhere  tcp dpt:http
    5   300 ACCEPT  tcp  --  any any  anywhere  anywhere  tcp dpt:https

RECENT FIREWALL LOGS:
2026-05-20 14:15:03 - Applied web server preset
2026-05-20 14:22:17 - Started test mode: iptables -A INPUT -p tcp --dport 8080 -j ACCEPT (5 min)
2026-05-20 14:27:17 - Test mode completed after 5 minutes
```

### Point technique à expliquer à l'oral

> « Le rapport d'audit combine les règles actives avec leurs compteurs de paquets,
> les connexions réseau actives (`ss -tuln`), et le journal Fire-UX. Les compteurs
> de paquets (`pkts/bytes`) permettent d'identifier les règles jamais utilisées
> qui alourdissent inutilement le pare-feu. Ce rapport peut être envoyé au RSSI
> pour validation de la configuration. »

---

## Étape 8 — Sauvegarde du profil "prod-web-server"

### Commande exacte

```
Menu principal → 4 (Profile Management) → 1 (Save current rules as profile)
Profile name: prod-web-server
```

### Ce que l'examinateur voit

```
╔═══ PROFILE MANAGEMENT ═══╗
Enter profile name: prod-web-server

Profile saved successfully!
```

### Vérification

```bash
ls -lh /etc/fire-ux/profiles/
# prod-web-server                      ← profil de production
# backup_before_preset_20260520141503  ← sauvegarde automatique
# backup_before_test_20260520142217    ← sauvegarde avant le test
```

### Point technique à expliquer à l'oral

> « `iptables-save` sérialise toutes les règles des tables filter, nat et mangle
> dans un fichier texte. `iptables-restore` peut les réinjecter en une seule
> opération atomique, ce qui est plus sûr qu'un script qui rejoue des commandes
> une par une. On peut ainsi gérer plusieurs environnements : `prod-web-server`,
> `maintenance-mode`, `vpn-mode`, et basculer en quelques secondes. »

---

## Récapitulatif des commandes clés

| Étape | Commande |
|-------|----------|
| Installation | `sudo bash install.sh` |
| Lancement | `sudo fire-ux` |
| Rapport d'audit | `sudo make audit` |
| Tests automatisés | `make test` |
| Vérification qualité | `make lint` |
| Désinstallation | `sudo bash uninstall.sh` |
