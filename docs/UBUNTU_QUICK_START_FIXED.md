# Kalon Network Ubuntu Quick Start Guide (Fixed)

## 🚀 **Schnelle Installation für Ubuntu Server**

### **Voraussetzungen:**
- Ubuntu 20.04+ Server
- Root-Zugang oder sudo-Berechtigung
- Mindestens 2GB RAM
- 10GB freier Speicherplatz

---

## **1. Installation ausführen:**

```bash
# Repository klonen
git clone https://github.com/Why-x-Phy/kalon-network.git
cd kalon-network

# Installation ausführen
sudo ./scripts/install-ubuntu-simple.sh
```

---

## **2. Master Node für Testnet einrichten:**

```bash
# Wallet erstellen
kalon-wallet create --passphrase ""

# Wallet-Adresse notieren (z.B. kalon1abc...)

# Master Node konfigurieren
sudo ./scripts/setup-master-node.sh 185.133.249.107 testnet <WALLET_ADDRESS> 4
```

---

## **3. Master Node starten:**

```bash
# Alle Services starten
kalon-master-start

# Status prüfen
kalon-master-status

# Logs anzeigen
kalon-master-logs node
kalon-master-logs miner
```

---

## **4. Slave Node einrichten (optional):**

```bash
# Auf anderem Server
sudo ./scripts/install-ubuntu-simple.sh
sudo ./scripts/setup-slave-node.sh 185.133.249.107 testnet <WALLET_ADDRESS> 2
kalon-slave-start
```

---

## **5. Explorer installieren (optional):**

```bash
# Explorer hinzufügen
sudo ./scripts/install-explorer.sh

# Services neu starten
kalon-master-start
```

---

## **6. Überprüfung:**

```bash
# Node Status
curl http://localhost:16316/health

# Blockchain Info
curl -X POST http://localhost:16316 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"getHeight","params":{},"id":1}'

# Mining Info
curl -X POST http://localhost:16316 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"getMiningInfo","params":{},"id":1}'
```

---

## **7. Wichtige Ports:**

- **RPC (Testnet):** 16316
- **P2P (Testnet):** 17335
- **Explorer:** 3000

---

## **8. Management Commands:**

```bash
# Master Node
kalon-master-start    # Starten
kalon-master-stop     # Stoppen
kalon-master-status   # Status
kalon-master-logs     # Logs
kalon-master-monitor  # Live-Monitor

# Slave Node
kalon-slave-start     # Starten
kalon-slave-stop      # Stoppen
kalon-slave-status    # Status
kalon-slave-logs      # Logs
kalon-slave-monitor   # Live-Monitor
```

---

## **9. Troubleshooting:**

### **Block-Chaining Problem behoben:**
- ✅ Parent Hash wird korrekt übertragen
- ✅ Block-Nummern sind konsistent
- ✅ Timestamp-Validierung funktioniert
- ✅ Proof of Work wird akzeptiert

### **Wallet Problem behoben:**
- ✅ Windows-kompatible Passphrase-Eingabe
- ✅ Automatische Wallet-Erstellung
- ✅ Korrekte Adress-Generierung

### **Häufige Probleme:**

```bash
# Node startet nicht
sudo systemctl status kalon-master-node
sudo journalctl -u kalon-master-node -f

# Miner startet nicht
sudo systemctl status kalon-master-miner
sudo journalctl -u kalon-master-miner -f

# RPC nicht erreichbar
sudo ufw allow 16316/tcp
sudo ufw allow 17335/tcp
```

---

## **10. Nächste Schritte:**

1. **Master Node** läuft stabil
2. **Mining** funktioniert korrekt
3. **Slave Nodes** können sich verbinden
4. **Explorer** zeigt Blöcke an
5. **Community** kann Wallets erstellen

---

## **🎯 Erfolg!**

Die Kalon Network Blockchain läuft jetzt korrekt auf Ubuntu mit:
- ✅ **Sauberer Blockchain** (keine 0000... Parent Hashes)
- ✅ **Korrektem Mining** (Blöcke werden akzeptiert)
- ✅ **Funktionierender Wallet** (Adressen werden generiert)
- ✅ **Stabilem Node** (RPC und P2P funktionieren)

**Ready for Community! 🚀**
