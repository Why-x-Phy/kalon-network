# Kalon Network - Network Konfiguration

## 🌐 **Network Definition**

Das Network wird über **Genesis-Dateien** und **Data-Directories** definiert:

### **1. Community Testnet (Standard)**
- **Genesis**: `genesis/community-testnet.json`
- **Data**: `data-community-testnet/`
- **Chain ID**: 7717
- **Symbol**: tKALON
- **Address Prefix**: tkalon
- **Block Time**: 15 Sekunden
- **Difficulty**: 1 (sehr einfach)

### **2. Testnet**
- **Genesis**: `genesis/testnet.json`
- **Data**: `data-testnet/`
- **Chain ID**: 7718
- **Symbol**: tKALON
- **Address Prefix**: tkalon
- **Block Time**: 30 Sekunden
- **Difficulty**: 1 (einfach)

### **3. Mainnet**
- **Genesis**: `genesis/mainnet.json`
- **Data**: `data-mainnet/`
- **Chain ID**: 7719
- **Symbol**: KALON
- **Address Prefix**: kalon
- **Block Time**: 30 Sekunden
- **Difficulty**: 1 (einfach)

---

## 🚀 **Network Starten**

### **Community Testnet (Standard):**
```bash
# Node starten
./scripts/start-network.sh community-testnet

# Miner starten
./scripts/start-miner.sh community-testnet kalon16aqa006ltc6gu58reqhk7hdctrq4lt3736u3pz 2
```

### **Testnet:**
```bash
# Node starten
./scripts/start-network.sh testnet

# Miner starten
./scripts/start-miner.sh testnet kalon16aqa006ltc6gu58reqhk7hdctrq4lt3736u3pz 2
```

### **Mainnet:**
```bash
# Node starten
./scripts/start-network.sh mainnet

# Miner starten
./scripts/start-miner.sh mainnet kalon16aqa006ltc6gu58reqhk7hdctrq4lt3736u3pz 2
```

---

## 🔧 **Manuelle Konfiguration**

### **Node manuell starten:**
```bash
# Community Testnet
./build/kalon-node --datadir ./data-community-testnet --genesis ./genesis/community-testnet.json --rpc :16315 --p2p :17334

# Testnet
./build/kalon-node --datadir ./data-testnet --genesis ./genesis/testnet.json --rpc :16315 --p2p :17334

# Mainnet
./build/kalon-node --datadir ./data-mainnet --genesis ./genesis/mainnet.json --rpc :16315 --p2p :17334
```

### **Miner manuell starten:**
```bash
# Community Testnet
./build/kalon-miner --wallet kalon16aqa006ltc6gu58reqhk7hdctrq4lt3736u3pz --threads 2 --rpc http://localhost:16315

# Testnet
./build/kalon-miner --wallet kalon16aqa006ltc6gu58reqhk7hdctrq4lt3736u3pz --threads 2 --rpc http://localhost:16315

# Mainnet
./build/kalon-miner --wallet kalon16aqa006ltc6gu58reqhk7hdctrq4lt3736u3pz --threads 2 --rpc http://localhost:16315
```

---

## 📊 **Network Unterschiede**

| Feature | Community Testnet | Testnet | Mainnet |
|---------|------------------|---------|---------|
| **Chain ID** | 7717 | 7718 | 7719 |
| **Symbol** | tKALON | tKALON | KALON |
| **Address Prefix** | tkalon | tkalon | kalon |
| **Block Time** | 15s | 30s | 30s |
| **Initial Reward** | 10.0 | 5.0 | 5.0 |
| **Difficulty** | 1 | 1 | 1 |
| **Launch Guard** | 48h | 24h | 48h |
| **Max Supply** | 1B | 1B | 1B |

---

## 🔄 **Network Wechseln**

### **Zwischen Networks wechseln:**
```bash
# 1. Aktuelles Network stoppen
# Ctrl+C im Node Terminal

# 2. Neues Network starten
./scripts/start-network.sh testnet

# 3. Miner für neues Network starten
./scripts/start-miner.sh testnet kalon16aqa006ltc6gu58reqhk7hdctrq4lt3736u3pz 2
```

### **Data-Directories:**
```bash
# Jedes Network hat sein eigenes Data-Directory:
ls -la data-*/
# data-community-testnet/
# data-testnet/
# data-mainnet/
```

---

## 🏗️ **Ubuntu Server Setup**

### **Master Node (185.133.249.107):**
```bash
# Community Testnet
sudo ./scripts/setup-master-node.sh 185.133.249.107 community-testnet kalon12slz9pccxhahtm0th9v7n5emm6vtkumx4pykuh 4

# Testnet
sudo ./scripts/setup-master-node.sh 185.133.249.107 testnet kalon12slz9pccxhahtm0th9v7n5emm6vtkumx4pykuh 4

# Mainnet
sudo ./scripts/setup-master-node.sh 185.133.249.107 mainnet kalon12slz9pccxhahtm0th9v7n5emm6vtkumx4pykuh 4
```

### **Slave Nodes:**
```bash
# Community Testnet
sudo ./scripts/setup-slave-node.sh 185.133.249.107 community-testnet

# Testnet
sudo ./scripts/setup-slave-node.sh 185.133.249.107 testnet

# Mainnet
sudo ./scripts/setup-slave-node.sh 185.133.249.107 mainnet
```

---

## 💰 **Wallet Adressen**

### **Community Testnet:**
- **Prefix**: `tkalon`
- **Beispiel**: `tkalon1d6yu2u0683z0eegxj7ka4sxzmles9rwe87c3jx`

### **Testnet:**
- **Prefix**: `tkalon`
- **Beispiel**: `tkalon1d6yu2u0683z0eegxj7ka4sxzmles9rwe87c3jx`

### **Mainnet:**
- **Prefix**: `kalon`
- **Beispiel**: `kalon1d6yu2u0683z0eegxj7ka4sxzmles9rwe87c3jx`

---

## 🔍 **Network Status prüfen**

### **RPC API Test:**
```bash
# Community Testnet
curl http://localhost:16315

# Testnet
curl http://localhost:16315

# Mainnet
curl http://localhost:16315
```

### **Block Height prüfen:**
```bash
# Aktuelle Blockhöhe
curl -X POST http://localhost:16315 -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getHeight","params":{},"id":1}'
```

---

## ⚠️ **Wichtige Hinweise**

### **Data-Directories:**
- **Jedes Network hat sein eigenes Data-Directory**
- **Nicht zwischen Networks mischen**
- **Backup vor Network-Wechsel erstellen**

### **Genesis-Dateien:**
- **Nicht verändern nach Start**
- **Änderungen erfordern neues Data-Directory**
- **Chain ID muss eindeutig sein**

### **Wallet Adressen:**
- **Gleiche Wallet kann in allen Networks verwendet werden**
- **Aber Adressen haben unterschiedliche Prefixes**
- **Balance ist Network-spezifisch**

---

## 🎯 **Empfohlene Konfiguration**

### **Entwicklung:**
- **Community Testnet** (schnell, einfach)

### **Testing:**
- **Testnet** (realistischer, aber noch testbar)

### **Production:**
- **Mainnet** (echte KALON Token)

---

**Das Kalon Network unterstützt jetzt alle drei Networks! 🚀**
