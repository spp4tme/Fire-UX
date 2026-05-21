# Interface Web Fire-UX

Documentation de l'interface web minimaliste de Fire-UX.
Aucune dépendance externe : uniquement Bash, socat (ou ncat), iptables, ss et
les coreutils standard présents sur tout Linux.

---

## Architecture technique

```
┌─────────────────────────────────────────────────────────────────┐
│                        Navigateur web                           │
│                  http://IP_SERVEUR:8080/...                      │
└───────────────────────────┬─────────────────────────────────────┘
                            │ requête HTTP GET / POST
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                      web-server.sh                              │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  socat TCP-LISTEN:8080 … SYSTEM:'bash route_request'    │    │
│  │  (fallback : ncat --listen 8080 --sh-exec …)            │    │
│  └──────────────────┬──────────────────────────────────────┘    │
│                     │ parse méthode + chemin + body             │
│                     ▼                                           │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │               Routeur (route_request)                   │    │
│  │  GET /          → handle_dashboard()                    │    │
│  │  GET /rules     → handle_rules()                        │    │
│  │  GET /logs      → handle_logs()                         │    │
│  │  GET /profiles  → handle_profiles()                     │    │
│  │  GET /status    → handle_status()   (JSON)              │    │
│  │  POST /add-rule → handle_add_rule()                     │    │
│  │  POST /delete-rule → handle_delete_rule()               │    │
│  │  POST /flush    → handle_flush()                        │    │
│  │  POST /apply-preset → handle_apply_preset()             │    │
│  │  POST /save-snapshot → handle_save_snapshot()           │    │
│  │  POST /apply-profile → handle_apply_profile()           │    │
│  └──────────────────┬──────────────────────────────────────┘    │
│                     │ source web-ui.sh                          │
│                     ▼                                           │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                   web-ui.sh                             │    │
│  │  html_header() · page_dashboard() · page_rules()        │    │
│  │  page_logs()   · page_profiles()  · html_footer()       │    │
│  └──────────────────┬──────────────────────────────────────┘    │
│                     │ appels système                            │
│                     ▼                                           │
│         iptables · ss · hostname · uptime · tail                │
└─────────────────────────────────────────────────────────────────┘
                            │ réponse HTTP (HTML ou JSON)
                            ▼
                      Navigateur web
```

**Fichiers concernés :**

| Fichier | Rôle | Emplacement après installation |
|---|---|---|
| `web-server.sh` | Serveur HTTP, routeur, handlers | `/usr/local/lib/fire-ux/web-server.sh` |
| `web-ui.sh` | Générateur HTML / CSS | `/usr/local/lib/fire-ux/web-ui.sh` |
| `fire-ux-web.service` | Service systemd | `/etc/systemd/system/fire-ux-web.service` |

---

## Démarrage du serveur web

### Via systemd (recommandé après installation)

```bash
# Démarrer
sudo systemctl start fire-ux-web

# Arrêter
sudo systemctl stop fire-ux-web

# Statut
systemctl status fire-ux-web

# Journaux en temps réel
journalctl -u fire-ux-web -f
```

### Via make

```bash
make web-start    # démarre le service
make web-stop     # arrête le service
make web-status   # affiche l'état
make web-log      # journaux en temps réel
```

### Manuellement (sans systemd)

```bash
sudo bash /usr/local/lib/fire-ux/web-server.sh 8080
# ou avec un port personnalisé :
sudo bash /usr/local/lib/fire-ux/web-server.sh 9090
```

---

## Pages et routes

### `GET /` — Tableau de bord

Vue d'ensemble du pare-feu en temps réel :

- **Statut système** : nom d'hôte, IP principale, uptime
- **Politiques par défaut** : INPUT / OUTPUT / FORWARD avec code couleur
- **Compteur de règles** par chaîne
- **Services détectés** : ports en écoute (`ss`) croisés avec les règles ACCEPT
- **Activité récente** : 10 dernières lignes du journal `/var/log/fire-ux.log`
- **Actions rapides** : Preset Web, Preset SSH, Mode Panique, Flush All

La page se rafraîchit automatiquement toutes les 30 secondes.

---

### `GET /rules` — Règles iptables

Affiche les trois chaînes principales (INPUT, OUTPUT, FORWARD) sous forme de
tableaux interactifs :

- Numéro, cible (badge coloré), protocole, source, destination, options
- Bouton **Supprimer** par règle (POST `/delete-rule`)
- Bouton **Vider la chaîne** par tableau (POST `/flush`)
- **Formulaire d'ajout** en bas : chaîne, protocole, port, IP source, action

---

### `GET /logs` — Journaux

Affiche les 50 dernières lignes de `/var/log/fire-ux.log` avec coloration :

| Couleur | Contenu |
|---|---|
| Vert | Lignes contenant `ACCEPT` |
| Rouge | Lignes contenant `DROP`, `REJECT` ou `denied` |
| Jaune | Lignes contenant `error`, `fail` ou `erreur` |
| Gris | Toutes les autres entrées |

---

### `GET /profiles` — Profils

Liste les profils sauvegardés dans `/etc/fire-ux/profiles/` :

- Nom, date de création, taille, aperçu des premières lignes
- Bouton **Appliquer** (POST `/apply-profile`) — restaure via `iptables-restore`
- Bouton **Snapshot actuel** (POST `/save-snapshot`) — sauvegarde l'état courant

---

### `GET /status` — Statut JSON

Retourne un objet JSON minimaliste pour monitoring externe :

```json
{
  "rules_input": 4,
  "rules_output": 0,
  "rules_forward": 0,
  "ipv6": false,
  "uptime": "up 2 hours, 14 minutes",
  "server_pid": 1234
}
```

---

### Routes POST

| Route | Paramètres body | Effet |
|---|---|---|
| `/add-rule` | `chain`, `proto`, `port`, `src`, `action` | Ajoute une règle iptables |
| `/delete-rule` | `num`, `chain` | Supprime la règle numérotée |
| `/flush` | `chain` (`INPUT`/`OUTPUT`/`FORWARD`/`all`) | Vide une ou toutes les chaînes |
| `/apply-preset` | `preset` (`web`/`ssh`/`panic`/`flush_all`) | Applique un preset complet |
| `/save-snapshot` | *(aucun)* | Sauvegarde l'état courant en profil |
| `/apply-profile` | `name` | Restaure un profil sauvegardé |

---

## Sécurité

> **⚠ AVERTISSEMENT** : Le serveur web **n'a aucune authentification**.
> Toute personne pouvant atteindre le port 8080 peut modifier vos règles
> iptables et prendre le contrôle du pare-feu.

### Recommandations

1. **Ne jamais exposer le port 8080 sur Internet.** Ce serveur est conçu
   pour un accès local ou depuis un VPN uniquement.

2. **Restreindre l'accès à une IP de confiance via iptables** (voir ci-dessous).

3. Si vous avez besoin d'un accès distant, utilisez un tunnel SSH :
   ```bash
   ssh -L 8080:127.0.0.1:8080 utilisateur@serveur
   # puis ouvrez http://127.0.0.1:8080 dans votre navigateur local
   ```

### Exemple de règle iptables pour sécuriser le port 8080

Remplacez `192.168.1.50` par l'IP de votre poste d'administration :

```bash
# Autoriser uniquement votre IP de confiance
sudo iptables -A INPUT -p tcp --dport 8080 -s 192.168.1.50 -j ACCEPT

# Bloquer tout autre accès au port 8080
sudo iptables -A INPUT -p tcp --dport 8080 -j DROP
```

Pour un sous-réseau entier (ex. réseau VPN `10.8.0.0/24`) :

```bash
sudo iptables -A INPUT -p tcp --dport 8080 -s 10.8.0.0/24 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 8080 -j DROP
```

---

## Prérequis

Le serveur détecte automatiquement l'outil réseau disponible dans cet ordre :

1. `socat` (recommandé) — `apt install socat`
2. `ncat` — `apt install ncat`
3. `nc` (fallback basique, sans parallélisme)

Vérifiez la disponibilité :

```bash
which socat ncat nc
```
