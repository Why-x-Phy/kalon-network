# Kalon Testnet - Master Node Installation & Setup

## 🎯 Ziel

Komplette Installation und Test eines Master Nodes für das Kalon Testnet.

## 📋 Voraussetzungen

- Ubuntu Server (oder ähnlich)
- Go 1.19+ installiert
- Git installiert
- Mindestens 2GB RAM
- 10GB freier Speicherplatz

## 🚀 Schritt 1: Repository klonen

```bash
# Repository klonen
git clone https://github.com/Why-x-Phy/kalon-network.git
cd kalon-network

# Aktuelle Version prüfen
git tag --sort=-version:refname | head -1
# Sollte: v1.3.0
```

## 🔨 Schritt 2: Kompilieren

```bash
# Alle Binaries kompilieren
go build -o build-v2/kalon-node-v2 cmd/kalon-node-v2/main.go
go build -o build-v2/kalon-miner-v2 cmd/kalon-miner-v2/main.go
go build -o build-v2/kalon-wallet cmd/kalon-wallet/main.go
go build -o build-v2/explorer-api explorer/api/main.go

# Ausführungsrechte setzen
chmod +x build-v2/*

# Prüfen
ls -la build-v2/
```

**Erwartete Ausgabe:**
```
-rwxr-xr-x 1 user user kalon-node-v2
-rwxr-xr-x 1 user user kalon-miner-v2
-rwxr-xr-x 1 user user kalon-wallet
-rwxr-xr-x 1 user user explorer-api
```

## 💰 Schritt 3: Wallet erstellen

```bash
# Cleanup
rm -rf data-testnet wallet-master.json

# Wallet erstellen
echo "" | ./build-v2/kalon-wallet create --name master

# Wallet-Adresse anzeigen
WALLET=$(cat wallet-master.json | jq -r .address)
echo "Master Wallet: $WALLET"

# Wallet-Details prüfen
cat wallet-master.json | jq .
```

**Erwartete Ausgabe:**
```json
{
  "address": "kalon1...",
  "publicKey": "...",
  "privateKey": "...",
  "mnemonic": "..."
}
```

## 🌐 Schritt 4: Master Node starten

```bash
# Datenverzeichnis erstellen
mkdir -p data-testnet

# Master Node starten (OHNE seednodes - wir sind der Master!)
./build-v2/kalon-node-v2 \
  -datadir data-testnet \
  -genesis genesis/testnet.json \
  -rpc :16316 \
  -p2p :17335
```

**Erwartete Logs:**
```
2025/10/28 14:00:00 🚀 Starting Professional Kalon Node v2.0
2025/10/28 14:00:00    Data Dir: data-testnet
2025/10/28 14:00:00    Genesis: genesis/testnet.json
2025/10/28 14:00:00    RPC: :16316
2025/10/28 14:00:00    P2P: :17335
2025/10/28 14:00:00 🔧 Initializing persistent storage at data-testnet/chaindb
2025/10/28 14:00:00 ✅ Blockchain initialized with height: 0
2025/10/28 14:00:00 🚀 Professional RPC Server starting on :16316
2025/10/28 14:00:00 P2P network started on :17335
2025/10/28 14:00:00 ✅ Node started successfully
```

## ⛏️ Schritt 5: Miner starten

**In einem neuen Terminal:**

```bash
cd kalon-network

# Wallet-Adresse laden
WALLET=$(cat wallet-master.json | jq -r .address)

# Miner starten
./build-v2/kalon-miner-v2 \
  -wallet "$WALLET" \
  -threads 2 \
  -rpc http://localhost:16316
```

**Erwartete Logs:**
```
2025/10/28 14:00:30 🚀 Starting Professional Kalon Miner v2.0
2025/10/28 14:00:30    Wallet: kalon1...
2025/10/28 14:00:30    Threads: 2
2025/10/28 14:00:30    RPC URL: http://localhost:16316
2025/10/28 14:00:30 ⛏️ Mining worker 0 started
2025/10/28 14:00:30 ⛏️ Mining worker 1 started
```

## 🔍 Schritt 6: System testen

### 6.1 RPC API testen

```bash
# Height prüfen
curl -s http://localhost:16316/rpc \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"getHeight","id":1}' \
  | jq .

# Balance prüfen
curl -s http://localhost:16316/rpc \
  -H "Content-Type: application/json" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"getBalance\",\"params\":{\"address\":\"$WALLET\"},\"id\":2}" \
  | jq .

# Best Block prüfen
curl -s http://localhost:16316/rpc \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"getBestBlock","id":3}' \
  | jq .
```

### 6.2 Mining überwachen

```bash
# Warten auf erste Blöcke (ca. 30 Sekunden)
sleep 30

# Height sollte > 0 sein
HEIGHT=$(curl -s http://localhost:16316/rpc \
  -d '{"jsonrpc":"2.0","method":"getHeight","id":1}' \
  | jq -r .result)
echo "Current Height: $HEIGHT"

# Balance sollte > 0 sein
BALANCE=$(curl -s http://localhost:16316/rpc \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"getBalance\",\"params\":{\"address\":\"$WALLET\"},\"id\":2}" \
  | jq -r .result)
echo "Balance: $BALANCE"
```

### 6.3 P2P Port prüfen

```bash
# P2P Port sollte offen sein
netstat -an | grep 17335

# Erwartete Ausgabe:
# tcp 0.0.0.0:17335 0.0.0.0:* LISTEN
```

## 🌐 Schritt 7: Block Explorer starten

**In einem dritten Terminal:**

```bash
cd kalon-network

# Explorer API starten
KALON_RPC_URL="http://localhost:16316" ./build-v2/explorer-api

# Erwartete Logs:
# 2025/10/28 14:01:00 Starting Kalon Explorer API on port 8081
# 2025/10/28 14:01:00 RPC URL: http://localhost:16316
# 2025/10/28 14:01:00 Explorer API starting on port 8081
```

**Explorer testen:**
```bash
# Explorer API testen
curl http://localhost:8081/network/stats | jq .

# Erwartete Ausgabe:
# {
#   "blockHeight": 5,
#   "networkHashRate": "...",
#   "totalBlocks": 5,
#   ...
# }
```

## 🧪 Schritt 8: Vollständiger Test

### 8.1 Transaktion testen

```bash
# Zweites Wallet erstellen
echo "" | ./build-v2/kalon-wallet create --name test

# Test-Wallet Adresse
TEST_WALLET=$(cat wallet-test.json | jq -r .address)
echo "Test Wallet: $TEST_WALLET"

# Transaktion senden (Master -> Test)
curl -s http://localhost:16316/rpc \
  -H "Content-Type: application/json" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"sendTransaction\",\"params\":{\"from\":\"$WALLET\",\"to\":\"$TEST_WALLET\",\"amount\":1000000},\"id\":4}" \
  | jq .

# Einen Block minen um Transaktion zu bestätigen
sleep 10

# Balances prüfen
echo "Master Balance:"
curl -s http://localhost:16316/rpc \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"getBalance\",\"params\":{\"address\":\"$WALLET\"},\"id\":2}" \
  | jq -r .result

echo "Test Balance:"
curl -s http://localhost:16316/rpc \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"getBalance\",\"params\":{\"address\":\"$TEST_WALLET\"},\"id\":2}" \
  | jq -r .result
```

### 8.2 Persistenz testen

```bash
# Node stoppen
pkill -9 -f kalon-node-v2

# Warten
sleep 3

# Node neu starten
./build-v2/kalon-node-v2 \
  -datadir data-testnet \
  -genesis genesis/testnet.json \
  -rpc :16316 \
  -p2p :17335

# Height sollte gleich bleiben (nicht 0!)
sleep 5
HEIGHT=$(curl -s http://localhost:16316/rpc \
  -d '{"jsonrpc":"2.0","method":"getHeight","id":1}' \
  | jq -r .result)
echo "Height nach Neustart: $HEIGHT"
```

## ✅ Schritt 9: Erfolgskriterien

**Der Test ist erfolgreich wenn:**

- ✅ Node startet ohne Fehler
- ✅ Miner findet Blöcke (Height > 0)
- ✅ Balance > 0 (Block Rewards)
- ✅ RPC API funktioniert
- ✅ P2P Port 17335 offen
- ✅ Explorer API läuft
- ✅ Transaktionen funktionieren
- ✅ Persistenz funktioniert (Height bleibt nach Neustart)

## 🔧 Troubleshooting

### Problem: Node startet nicht

```bash
# Prüfe ob Ports belegt sind
netstat -an | grep -E "16316|17335"

# Prüfe Logs
tail -f /tmp/kalon-node.log

# Cleanup und Neustart
pkill -9 -f kalon
rm -rf data-testnet
mkdir -p data-testnet
```

### Problem: Miner findet keine Blöcke

```bash
# Prüfe RPC Verbindung
curl http://localhost:16316/rpc \
  -d '{"jsonrpc":"2.0","method":"getHeight","id":1}'

# Prüfe Wallet
cat wallet-master.json | jq -r .address

# Prüfe Difficulty in Genesis
cat genesis/testnet.json | jq .difficulty
```

### Problem: Balance bleibt 0

```bash
# Prüfe UTXO Debug Logs
grep "UTXO" /tmp/kalon-node.log

# Prüfe Block Rewards
grep "Block #" /tmp/kalon-node.log
```

## 📊 Monitoring

### Live Monitoring Script

```bash
#!/bin/bash
# monitoring.sh

while true; do
  echo "=== $(date) ==="
  
  # Height
  HEIGHT=$(curl -s http://localhost:16316/rpc \
    -d '{"jsonrpc":"2.0","method":"getHeight","id":1}' \
    | jq -r .result)
  echo "Height: $HEIGHT"
  
  # Balance
  BALANCE=$(curl -s http://localhost:16316/rpc \
    -d "{\"jsonrpc\":\"2.0\",\"method\":\"getBalance\",\"params\":{\"address\":\"$WALLET\"},\"id\":2}" \
    | jq -r .result)
  echo "Balance: $BALANCE"
  
  # Peers
  PEERS=$(curl -s http://localhost:16316/rpc \
    -d '{"jsonrpc":"2.0","method":"getPeerCount","id":3}' \
    | jq -r .result)
  echo "Peers: $PEERS"
  
  echo ""
  sleep 10
done
```

## 🎉 Fertig!

**Master Node ist erfolgreich installiert und getestet!**

**Nächste Schritte:**
- Slave Nodes können sich mit `-seednodes "MASTER-IP:17335"` verbinden
- Weitere Miner können auf anderen Servern gestartet werden
- Block Explorer ist unter `http://MASTER-IP:8081` erreichbar

**Wichtige Informationen:**
- **Master IP**: `$(hostname -I | awk '{print $1}')`
- **P2P Port**: `17335`
- **RPC Port**: `16316`
- **Explorer Port**: `8081`
- **Wallet**: `wallet-master.json`
