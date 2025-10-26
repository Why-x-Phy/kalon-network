# Kalon Network - Komplette Anleitung

## 🏗️ **Architektur Übersicht**

### **Master Node (185.133.249.107)**
- **Rolle**: Haupt-Node, bestimmt die Blockhöhe
- **Mining**: Aktiv mit 4 Threads
- **Wallet**: `kalon12slz9pccxhahtm0th9v7n5emm6vtkumx4pykuh`
- **Ports**: RPC (16315), P2P (17334), Explorer (3000)

### **Slave Nodes**
- **Rolle**: Folgen dem Master, syncen automatisch
- **Mining**: Aktiv mit 2 Threads
- **Wallet**: Auto-generiert oder spezifiziert
- **Ports**: RPC (16315), P2P (17334)

---

## 🚀 **Installation & Setup**

### **1. Ubuntu Server Installation**

#### **Master Node Setup (185.133.249.107):**
```bash
# 1. Installation
wget https://raw.githubusercontent.com/Why-x-Phy/kalon-network/master/scripts/install-ubuntu.sh
chmod +x install-ubuntu.sh
sudo ./install-ubuntu.sh

# 2. Master Node konfigurieren
# Community Testnet (Standard)
sudo ./scripts/setup-master-node.sh 185.133.249.107 community-testnet kalon12slz9pccxhahtm0th9v7n5emm6vtkumx4pykuh 4

# Testnet
sudo ./scripts/setup-master-node.sh 185.133.249.107 testnet kalon12slz9pccxhahtm0th9v7n5emm6vtkumx4pykuh 4

# Mainnet
sudo ./scripts/setup-master-node.sh 185.133.249.107 mainnet kalon12slz9pccxhahtm0th9v7n5emm6vtkumx4pykuh 4

# 3. Master Node starten
sudo kalon-master-start
```

#### **Slave Node Setup:**
```bash
# 1. Installation
wget https://raw.githubusercontent.com/Why-x-Phy/kalon-network/master/scripts/install-ubuntu.sh
chmod +x install-ubuntu.sh
sudo ./install-ubuntu.sh

# 2. Slave Node konfigurieren
sudo ./scripts/setup-slave-node.sh 185.133.249.107 community-testnet

# 3. Slave Node starten
sudo kalon-slave-start
```

### **2. Lokale Entwicklung (Windows)**

```bash
# 1. Repository klonen
git clone https://github.com/Why-x-Phy/kalon-network.git
cd kalon-network

# 2. Binaries bauen
go build -o build/kalon-node.exe cmd/kalon-node/main.go
go build -o build/kalon-miner.exe cmd/kalon-miner/main.go
go build -o build/kalon-wallet.exe cmd/kalon-wallet/main.go
```

---

## 💰 **Wallet Management**

### **Neue Wallet erstellen:**
```bash
# Ubuntu
kalon-wallet create

# Windows
./build/kalon-wallet.exe create
```

### **Wallet importieren:**
```bash
# Ubuntu
kalon-wallet import --mnemonic "your mnemonic phrase here"

# Windows
./build/kalon-wallet.exe import --mnemonic "your mnemonic phrase here"
```

### **Wallet Balance prüfen:**
```bash
# Ubuntu
kalon-wallet balance --address kalon1d6yu2u0683z0eegxj7ka4sxzmles9rwe87c3jx

# Windows
./build/kalon-wallet.exe balance --address kalon1d6yu2u0683z0eegxj7ka4sxzmles9rwe87c3jx
```

---

## 🖥️ **Node Management**

### **Node starten:**

#### **Ubuntu (Master):**
```bash
sudo kalon-master-start
```

#### **Ubuntu (Slave):**
```bash
sudo kalon-slave-start
```

#### **Windows (Lokal):**
```bash
./scripts/start-network.sh community-testnet
```

### **Node Status prüfen:**

#### **Ubuntu (Master):**
```bash
sudo kalon-master-status
```

#### **Ubuntu (Slave):**
```bash
sudo kalon-slave-status
```

### **Node stoppen:**

#### **Ubuntu (Master):**
```bash
sudo kalon-master-stop
```

#### **Ubuntu (Slave):**
```bash
sudo kalon-slave-stop
```

#### **Windows (Lokal):**
```bash
# Ctrl+C im Node Terminal
```

---

## ⛏️ **Mining Management**

### **Miner starten:**

#### **Ubuntu (Master):**
```bash
# Läuft automatisch mit Master Node
sudo kalon-master-start
```

#### **Ubuntu (Slave):**
```bash
# Läuft automatisch mit Slave Node
sudo kalon-slave-start
```

#### **Windows (Lokal):**
```bash
./scripts/start-miner.sh community-testnet kalon16aqa006ltc6gu58reqhk7hdctrq4lt3736u3pz 2
```

### **Mining Parameter:**
- **Threads**: Anzahl der Mining-Threads (Standard: 2)
- **Wallet**: Mining-Reward Adresse
- **Network**: community-testnet, testnet, mainnet

---

## 🔧 **Service Management (Ubuntu)**

### **Master Node Services:**
```bash
# Services starten
sudo systemctl start kalon-master
sudo systemctl start kalon-master-miner
sudo systemctl start kalon-master-explorer

# Services stoppen
sudo systemctl stop kalon-master-explorer
sudo systemctl stop kalon-master-miner
sudo systemctl stop kalon-master

# Status prüfen
sudo systemctl status kalon-master
```

### **Slave Node Services:**
```bash
# Services starten
sudo systemctl start kalon-slave
sudo systemctl start kalon-slave-miner
sudo systemctl start kalon-slave-sync

# Services stoppen
sudo systemctl stop kalon-slave-sync
sudo systemctl stop kalon-slave-miner
sudo systemctl stop kalon-slave

# Status prüfen
sudo systemctl status kalon-slave
```

---

## 📊 **Monitoring & Logs**

### **Real-time Monitoring:**

#### **Master Node:**
```bash
sudo kalon-master-monitor
```

#### **Slave Node:**
```bash
sudo kalon-slave-monitor
```

### **Logs anzeigen:**

#### **Master Node:**
```bash
# Alle Logs
sudo kalon-master-logs

# Spezifische Logs
sudo kalon-master-logs node
sudo kalon-master-logs miner
sudo kalon-master-logs explorer
```

#### **Slave Node:**
```bash
# Alle Logs
sudo kalon-slave-logs

# Spezifische Logs
sudo kalon-slave-logs node
sudo kalon-slave-logs miner
sudo kalon-slave-logs sync
```

---

## 🌐 **Netzwerk Zugriff**

### **Master Node (185.133.249.107):**
- **RPC API**: http://185.133.249.107:16315
- **Explorer**: http://185.133.249.107:3000
- **P2P**: 185.133.249.107:17334

### **Slave Nodes:**
- **Local RPC**: http://localhost:16315
- **P2P**: localhost:17334

---

## 🔄 **Backup & Updates**

### **Backup erstellen:**
```bash
# Master Node
sudo kalon-master-backup community-testnet

# Backup Location
ls -la /var/backups/kalon/
```

### **System aktualisieren:**
```bash
# Master Node
sudo kalon-master-update

# Slave Node
sudo kalon-slave-update
```

---

## 🔄 **Git & Branch Management**

### **Repository Setup:**
```bash
# Repository klonen
git clone https://github.com/Why-x-Phy/kalon-network.git
cd kalon-network

# Aktueller Branch prüfen
git branch

# Alle Branches anzeigen
git branch -a
```

### **Updates von Master Branch:**
```bash
# Aktuelle Änderungen committen
git add .
git commit -m "Deine Änderungen beschreiben"

# Master Branch holen
git fetch origin

# Auf Master Branch wechseln
git checkout master

# Neueste Änderungen pullen
git pull origin master

# Binaries neu bauen
make build
# oder für Windows:
go build -o build/kalon-node.exe cmd/kalon-node/main.go
go build -o build/kalon-miner.exe cmd/kalon-miner/main.go
go build -o build/kalon-wallet.exe cmd/kalon-wallet/main.go
```

### **Feature Branch erstellen:**
```bash
# Neuen Branch erstellen
git checkout -b feature/neue-funktion

# Änderungen machen und committen
git add .
git commit -m "Neue Funktion implementiert"

# Branch pushen
git push origin feature/neue-funktion

# Pull Request erstellen auf GitHub
```

### **Branch wechseln:**
```bash
# Zu anderem Branch wechseln
git checkout branch-name

# Branch löschen (lokal)
git branch -d branch-name

# Branch löschen (remote)
git push origin --delete branch-name
```

### **Merge Konflikte lösen:**
```bash
# Merge Konflikte anzeigen
git status

# Konflikte in Dateien manuell lösen
# Dann:
git add .
git commit -m "Merge Konflikte gelöst"
```

---

## 🚨 **Troubleshooting**

### **Häufige Probleme:**

#### **Service startet nicht:**
```bash
# Logs prüfen
sudo journalctl -u kalon-master -n 50

# Permissions prüfen
sudo chown -R kalon:kalon /var/lib/kalon
sudo chown -R kalon:kalon /opt/kalon
```

#### **RPC Verbindung fehlgeschlagen:**
```bash
# Service Status prüfen
sudo systemctl status kalon-master

# Port prüfen
sudo netstat -tlnp | grep 16315

# Firewall prüfen
sudo ufw status
```

#### **Sync Probleme:**
```bash
# Master Verbindung prüfen
curl http://185.133.249.107:16315

# Sync Service prüfen
sudo systemctl status kalon-slave-sync

# Sync Service neustarten
sudo systemctl restart kalon-slave-sync
```

#### **Git Probleme:**
```bash
# Uncommitted changes stashen
git stash

# Stash wieder anwenden
git stash pop

# Remote URL prüfen
git remote -v

# Remote URL ändern
git remote set-url origin https://github.com/Why-x-Phy/kalon-network.git
```

---

## 📋 **Schnellstart Checkliste**

### **Master Node Setup:**
- [ ] Ubuntu Server bereit
- [ ] `install-ubuntu.sh` ausführen
- [ ] `setup-master-node.sh` ausführen
- [ ] `kalon-master-start` ausführen
- [ ] RPC API testen: http://185.133.249.107:16315

### **Slave Node Setup:**
- [ ] Ubuntu Server bereit
- [ ] `install-ubuntu.sh` ausführen
- [ ] `setup-slave-node.sh` ausführen
- [ ] `kalon-slave-start` ausführen
- [ ] Sync Status prüfen

### **Lokale Entwicklung:**
- [ ] Repository klonen
- [ ] Binaries bauen
- [ ] `start-network.sh` ausführen
- [ ] `start-miner.sh` ausführen
- [ ] Mining testen

### **Update Workflow:**
- [ ] Aktuelle Änderungen committen
- [ ] `git pull origin master` ausführen
- [ ] Binaries neu bauen
- [ ] Services neustarten
- [ ] Funktion testen

---

## 🔧 **Wartung & Monitoring**

### **Tägliche Checks:**
```bash
# Service Status
sudo systemctl status kalon-master
sudo systemctl status kalon-slave

# Disk Space
df -h /var/lib/kalon

# Memory Usage
free -h

# Network Connectivity
curl http://185.133.249.107:16315
```

### **Wöchentliche Wartung:**
```bash
# Backup erstellen
sudo kalon-master-backup community-testnet

# Logs rotieren
sudo journalctl --vacuum-time=7d

# System Updates
sudo apt update && sudo apt upgrade -y
```

### **Monatliche Wartung:**
```bash
# Vollständiges Backup
sudo kalon-master-backup community-testnet
sudo kalon-master-backup testnet
sudo kalon-master-backup mainnet

# Logs archivieren
sudo tar -czf /var/backups/kalon/logs-$(date +%Y%m).tar.gz /var/log/kalon/

# Performance Monitoring
sudo kalon-master-monitor
```

---

## 📞 **Support & Community**

### **GitHub Repository:**
- **URL**: https://github.com/Why-x-Phy/kalon-network
- **Issues**: https://github.com/Why-x-Phy/kalon-network/issues
- **Wiki**: https://github.com/Why-x-Phy/kalon-network/wiki

### **Dokumentation:**
- **Installation**: `docs/UBUNTU_INSTALLATION.md`
- **API**: `docs/API_REFERENCE.md`
- **Development**: `docs/DEVELOPMENT.md`

### **Community:**
- **Discord**: [Link zur Discord Community]
- **Telegram**: [Link zur Telegram Gruppe]
- **Reddit**: [Link zum Reddit Subreddit]

---

## 📄 **Lizenz**

Dieses Projekt ist unter der MIT Lizenz lizenziert - siehe die [LICENSE](LICENSE) Datei für Details.

---

## 🎯 **Zusammenfassung**

Das Kalon Network ist ein vollständig funktionsfähiges Blockchain-System mit:

- ✅ **Multi-Network Support**: Community Testnet, Testnet, Mainnet
- ✅ **Token System**: tKALON für Testnets, KALON für Mainnet
- ✅ **Mining**: RandomX Algorithmus mit Difficulty Adjustment
- ✅ **RPC API**: Vollständige JSON-RPC Schnittstelle
- ✅ **Explorer**: Web-basierte Blockchain Explorer
- ✅ **Ubuntu Ready**: Automatisierte Installation und Management
- ✅ **Git Integration**: Vollständige Version Control Unterstützung

**Das System ist bereit für die Community! 🚀**
