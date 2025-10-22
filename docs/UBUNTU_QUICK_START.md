# Kalon Network - Ubuntu Quick Start

## 🚀 **Schnelle Installation ohne Explorer**

### **1. Bestehende Installation löschen:**
```bash
sudo systemctl stop kalon-master* 2>/dev/null || true
sudo rm -rf /opt/kalon
sudo rm -rf /var/lib/kalon
sudo rm -rf /etc/kalon
sudo rm -rf /var/log/kalon
sudo userdel kalon 2>/dev/null || true
```

### **2. Installation:**
```bash
# Repository klonen
cd /tmp
git clone https://github.com/Why-x-Phy/kalon-network.git
cd kalon-network

# Script ausführbar machen
chmod +x ./scripts/install-ubuntu.sh

# Installation ausführen
sudo ./scripts/install-ubuntu.sh
```

### **3. Master Node konfigurieren:**
```bash
# Testnet Master Node Setup
sudo ./scripts/setup-master-node.sh 185.133.249.107 testnet kalon12slz9pccxhahtm0th9v7n5emm6vtkumx4pykuh 4
```

### **4. Master Node starten:**
```bash
# Master Node starten
sudo kalon-master-start

# Status prüfen
sudo kalon-master-status
```

---

## 💰 **Wallet erstellen:**

### **1. Neue Wallet erstellen:**
```bash
# Wallet erstellen
kalon-wallet create

# Beispiel Output:
# Wallet created successfully!
# Address: kalon1abc123def456ghi789jkl012mno345pqr678stu901vwx234yz
# Mnemonic: word1 word2 word3 ... word24
```

### **2. Master Node mit neuer Wallet konfigurieren:**
```bash
# Master Node mit neuer Wallet konfigurieren
sudo ./scripts/setup-master-node.sh 185.133.249.107 testnet [NEUE_WALLET_ADRESSE] 4

# Master Node neustarten
sudo kalon-master-stop
sudo kalon-master-start
```

---

## ⛏️ **Mining starten:**

### **1. Mining Status prüfen:**
```bash
# Status prüfen
sudo kalon-master-status

# Logs anzeigen
sudo kalon-master-logs miner
```

### **2. Real-time Monitoring:**
```bash
# Real-time Monitoring
sudo kalon-master-monitor
```

---

## 🔧 **Service Management:**

```bash
# Alle Services starten
sudo kalon-master-start

# Alle Services stoppen
sudo kalon-master-stop

# Status prüfen
sudo kalon-master-status

# Logs anzeigen
sudo kalon-master-logs

# Real-time Monitoring
sudo kalon-master-monitor
```

---

## 📊 **Nach der Installation prüfen:**

```bash
# RPC API testen
curl http://185.133.249.107:16315

# Block Height prüfen
curl -X POST http://185.133.249.107:16315 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"getHeight","params":{},"id":1}'
```

---

## 🎯 **Zusammenfassung der Reihenfolge:**

1. **Installation** → Master Node ohne Wallet
2. **Wallet erstellen** → Neue Wallet generieren
3. **Master Node konfigurieren** → Mit neuer Wallet
4. **Mining starten** → Mining mit neuer Wallet

**Der Master Node läuft auch ohne Wallet - er braucht nur eine Wallet für das Mining!**

---

## 🚨 **Troubleshooting:**

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

---

**Das Kalon Network ist jetzt bereit für deinen Ubuntu Server! 🚀**
