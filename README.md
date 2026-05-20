
# 🛡️ Fire-UX
---

`fire-ux.sh` est un puissant **script Bash interactif** pour gérer les règles de pare-feu Linux via `iptables`, avec une interface terminal claire, sécurisée et élégante.

---

## 🔧 Ce que fait Fire-UX

- **🧭 Affiche un tableau de bord complet de votre configuration pare-feu.**
- **🧩 Permet d'ajouter, supprimer et personnaliser des règles avec des assistants.**
- **💾 Prend en charge la sauvegarde, le chargement et la gestion de profils.**
- **📋 Propose des préréglages prêts à l'emploi (Web, FTP, VPN, etc.).**
- **🧪 Inclut un mode test avec retour automatique après expiration.**
- **🔍 Permet l'audit et le filtrage en temps réel des règles actives.**

---

## 🎯 Fonctionnalités du menu

- **📊 Tableau de bord en direct** affichant les ports ouverts, les services autorisés et les statistiques des règles.
- **➕ Création de règles personnalisées** (avec prise en charge des règles temporisées).
- **🗑 Suppression de règles spécifiques**, vidage des chaînes ou réinitialisation du pare-feu.
- **💼 Gestion des profils** avec sauvegardes automatiques avant l'application des modifications.
- **🚀 Modes de basculement rapide** (sécurité renforcée / maintenance).
- **🧱 Contrôle des politiques par défaut** pour chaque chaîne (INPUT, OUTPUT, FORWARD).
- **📈 Outils d'audit et de surveillance** (activité récente, rapports exportables).
- **🧰 Modèles préconfigurés** pour les types de serveurs (FTP, VPN, base de données, etc.).
- **🧪 Mode test sécurisé** pour essayer des règles temporairement avec restauration automatique.

---

## 🚀 Installation et lancement

### 1️⃣ Cloner le dépôt
```bash
git clone https://github.com/CodeD-Roger/fire-ux.git
cd fire-ux
```

### 2️⃣ Rendre le script exécutable
```bash
sudo chmod +x fire-ux.sh
```

### 3️⃣ Exécuter le script en tant que root
```bash
sudo ./fire-ux.sh
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
| **Serveur FTP** | 21, 1024-1048 |



---


## ⚠️ Avertissement

**N'appliquez pas de règles de pare-feu sans savoir ce que vous faites.**
Une mauvaise configuration peut bloquer votre accès SSH ou déconnecter des services.

Utilisez le **mode test** ou effectuez des sauvegardes avant tout changement majeur.
