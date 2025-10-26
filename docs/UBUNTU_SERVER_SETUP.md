# Kalon Network - Ubuntu Server Setup

## 🖥️ **Master Node Installation (185.133.249.107)**

### **Vorbereitung:**
```bash
# 1. Server aktualisieren
sudo apt update && sudo apt upgrade -y

# 2. Bestehende Installation löschen (falls vorhanden)
sudo systemctl stop kalon-master* 2>/dev/null || true
sudo systemctl stop kalon-slave* 2>/dev/null || true
sudo rm -rf /opt/kalon
sudo rm -rf /var/lib/kalon
sudo rm -rf /etc/kalon
sudo rm -rf /var/log/kalon
sudo userdel kalon 2>/dev/null || true
```

### **Installation:**
```bash
# 1. Repository klonen
cd /tmp
git clone https://github.com/Why-x-Phy/kalon-network.git
cd kalon-network

# 2. Installation ausführen
sudo ./scripts/install-ubuntu.sh

# 3. Master Node für Testnet konfigurieren
sudo ./scripts/setup-master-node.sh 185.133.249.107 testnet kalon12slz9pccxhahtm0th9v7n5emm6vtkumx4pykuh 4

# 4. Master Node starten
sudo kalon-master-start
```

---

## 🌐 **Network Auswahl**

### **Community Testnet (Empfohlen für Entwicklung):**
```bash
sudo ./scripts/setup-master-node.sh 185.133.249.107 community-testnet kalon12slz9pccxhahtm0th9v7n5emm6vtkumx4pykuh 4
```

### **Testnet (Empfohlen für Testing):**
```bash
sudo ./scripts/setup-master-node.sh 185.133.249.107 testnet kalon12slz9pccxhahtm0th9v7n5emm6vtkumx4pykuh 4
```

### **Mainnet (Production):**
```bash
sudo ./scripts/setup-master-node.sh 185.133.249.107 mainnet kalon12slz9pccxhahtm0th9v7n5emm6vtkumx4pykuh 4
```

---

## 🔧 **Service Management**

### **Master Node Services:**
```bash
# Services starten
sudo kalon-master-start

# Services stoppen
sudo kalon-master-stop

# Status prüfen
sudo kalon-master-status

# Logs anzeigen
sudo kalon-master-logs

# Real-time Monitoring
sudo kalon-master-monitor
```

### **Einzelne Services:**
```bash
# Node starten
sudo systemctl start kalon-master

# Miner starten
sudo systemctl start kalon-master-miner

# Explorer starten
sudo systemctl start kalon-master-explorer

# Status prüfen
sudo systemctl status kalon-master
sudo systemctl status kalon-master-miner
sudo systemctl status kalon-master-explorer
```

---

## 📊 **Monitoring & Logs**

### **Real-time Monitoring:**
```bash
# Master Node Monitor
sudo kalon-master-monitor

# Spezifische Logs
sudo kalon-master-logs node
sudo kalon-master-logs miner
sudo kalon-master-logs explorer
```

### **System Logs:**
```bash
# Alle Kalon Logs
sudo journalctl -u kalon-master* -f

# Spezifische Service Logs
sudo journalctl -u kalon-master -f
sudo journalctl -u kalon-master-miner -f
sudo journalctl -u kalon-master-explorer -f
```

---

## 🌐 **Netzwerk Zugriff**

### **Firewall Konfiguration:**
```bash
# RPC API (für externe Verbindungen)
sudo ufw allow 16315/tcp

# P2P (für andere Nodes)
sudo ufw allow 17334/tcp

# Explorer (Web Interface)
sudo ufw allow 3000/tcp

# SSH (wichtig!)
sudo ufw allow ssh

# Firewall aktivieren
sudo ufw enable
```

### **Zugriff testen:**
```bash
# RPC API
curl http://185.133.249.107:16315

# Explorer
curl http://185.133.249.107:3000

# Block Height prüfen
curl -X POST http://185.133.249.107:16315 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"getHeight","params":{},"id":1}'
```

---

## 🔄 **Backup & Updates**

### **Backup erstellen:**
```bash
# Vollständiges Backup
sudo kalon-master-backup testnet

# Backup Location
ls -la /var/backups/kalon/
```

### **System aktualisieren:**
```bash
# Update ausführen
sudo kalon-master-update

# Services neustarten
sudo kalon-master-stop
sudo kalon-master-start
```

---

## 🚨 **Troubleshooting**

### **Service startet nicht:**
```bash
# Logs prüfen
sudo journalctl -u kalon-master -n 50

# Permissions prüfen
sudo chown -R kalon:kalon /var/lib/kalon
sudo chown -R kalon:kalon /opt/kalon

# Service neustarten
sudo systemctl restart kalon-master
```

### **RPC Verbindung fehlgeschlagen:**
```bash
# Service Status
sudo systemctl status kalon-master

# Port prüfen
sudo netstat -tlnp | grep 16315

# Firewall prüfen
sudo ufw status

# Service neustarten
sudo systemctl restart kalon-master
```

### **Mining Probleme:**
```bash
# Miner Status
sudo systemctl status kalon-master-miner

# Miner Logs
sudo journalctl -u kalon-master-miner -f

# Miner neustarten
sudo systemctl restart kalon-master-miner
```

---

## 📋 **Schnellstart Checkliste**

### **Vor der Installation:**
- [ ] Ubuntu Server bereit (20.04 LTS oder neuer)
- [ ] Root/Sudo Zugriff
- [ ] Internet Verbindung
- [ ] Mindestens 2GB RAM
- [ ] Mindestens 10GB freier Speicherplatz

### **Installation:**
- [ ] Server aktualisieren
- [ ] Bestehende Installation löschen (falls vorhanden)
- [ ] Repository klonen
- [ ] Installation ausführen
- [ ] Master Node konfigurieren
- [ ] Master Node starten

### **Nach der Installation:**
- [ ] Services prüfen
- [ ] RPC API testen
- [ ] Explorer testen
- [ ] Mining Status prüfen
- [ ] Firewall konfigurieren

---

## 🎯 **Empfohlene Konfiguration**

### **Für Testnet:**
```bash
# Master Node Setup
sudo ./scripts/setup-master-node.sh 185.133.249.107 testnet kalon12slz9pccxhahtm0th9v7n5emm6vtkumx4pykuh 4

# Starten
sudo kalon-master-start

# Monitoring
sudo kalon-master-monitor
```

### **Für Community Testnet:**
```bash
# Master Node Setup
sudo ./scripts/setup-master-node.sh 185.133.249.107 community-testnet kalon12slz9pccxhahtm0th9v7n5emm6vtkumx4pykuh 4

# Starten
sudo kalon-master-start

# Monitoring
sudo kalon-master-monitor
```

---

## 🔐 **Sicherheit**

### **SSH Konfiguration:**
```bash
# SSH Keys verwenden
ssh-keygen -t ed25519 -C "your-email@example.com"

# SSH Config
sudo nano /etc/ssh/sshd_config
# PasswordAuthentication no
# PermitRootLogin no

# SSH neustarten
sudo systemctl restart ssh
```

### **Firewall Regeln:**
```bash
# Nur notwendige Ports öffnen
sudo ufw allow ssh
sudo ufw allow 16315/tcp  # RPC
sudo ufw allow 17334/tcp  # P2P
sudo ufw allow 3000/tcp   # Explorer

# Firewall aktivieren
sudo ufw enable
```

---

**Das Kalon Network Master Node Setup ist jetzt vollständig dokumentiert! 🚀**
