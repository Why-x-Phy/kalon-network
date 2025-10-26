# Kalon Network - Server Deployment Anleitung

## 🚀 Schnellstart auf neuem Server

### 1. Repository clonen
```bash
git clone https://github.com/Why-x-Phy/kalon-network.git
cd kalon-network
```

### 2. Builds erstellen
```bash
# Node bauen
go build -o build-v2/kalon-node-v2 cmd/kalon-node-v2/main.go

# Miner bauen
go build -o build-v2/kalon-miner-v2 cmd/kalon-miner-v2/main.go
```

### 3. Node starten
```bash
# Clean start
rm -rf data-v2/testnet
mkdir -p data-v2/testnet

# Node im Hintergrund starten
./build-v2/kalon-node-v2 \
  -datadir data-v2/testnet \
  -genesis genesis/testnet.json \
  -rpc :16316 &

# Logs anzeigen
tail -f /tmp/node.log
```

### 4. Node testen
```bash
# Health Check
curl -X POST http://localhost:16316/rpc \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"getHeight","params":{},"id":1}'

# Sollte aktuelle Height zurückgeben
```

### 5. Miner starten
```bash
# Miner mit Wallet starten (Adresse: all zeros)
./build-v2/kalon-miner-v2 \
  -wallet 0000000000000000000000000000000000000000 \
  -threads 1 \
  -rpc http://localhost:16316
```

### 6. Balance prüfen
```bash
# Balance abfragen
curl -X POST http://localhost:16316/rpc \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"getBalance","params":{"address":"0000000000000000000000000000000000000000"},"id":2}'

# Sollte: 5000000 (oder höher) zurückgeben
```

## 🛠 Alternative: Nur Builds kopieren

Falls du die Builds bereits hast, einfach kopieren:

```bash
# Auf neuem Server
cd kalon-network
# Node Build kopieren und ausführen
./build-v2/kalon-node-v2 -datadir data-v2/testnet -genesis genesis/testnet.json -rpc :16316 &
./build-v2/kalon-miner-v2 -wallet 0000000000000000000000000000000000 -threads 1 -rpc http://localhost:16316
```

## 🧹 Prozesse beenden

```bash
# Alle Kalon-Prozesse stoppen
pkill -f kalon-node
pkill -f kalon-miner

# Oder spezifisch
pkill -f kalon-node-v2
pkill -f kalon-miner-v2
```

## 📊 Monitoring

```bash
# Aktuelle Height prüfen
curl -s -X POST http://localhost:16316/rpc \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"getHeight","params":{},"id":1}' | jq -r '.result'

# Best Block abfragen
curl -s -X POST http://localhost:16316/rpc \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"getBestBlock","params":{},"id":1}' | jq
```

## 🔧 Konfiguration

### Node Parameter
- `-datadir`: Blockchain-Datenverzeichnis (z.B. `data-v2/testnet`)
- `-genesis`: Genesis-Datei (z.B. `genesis/testnet.json`)
- `-rpc`: RPC Server Adresse (z.B. `:16316`)
- `-p2p`: P2P Server Adresse (z.B. `:17335`)

### Miner Parameter
- `-wallet`: Miner Adresse (Hex-String, 40 Zeichen)
- `-threads`: Anzahl Mining-Threads (z.B. `1`)
- `-rpc`: RPC Server URL (z.B. `http://localhost:16316`)
- `-stats`: Stats-Reporting Interval (z.B. `30s`)

## 🧪 Vollständiger Test

```bash
#!/bin/bash
# test_kalon.sh

# Clean start
pkill -f kalon
rm -rf data-v2/testnet
mkdir -p data-v2/testnet

# Node starten
echo "🚀 Starte Node..."
./build-v2/kalon-node-v2 -datadir data-v2/testnet -genesis genesis/testnet.json -rpc :16316 > /tmp/node.log 2>&1 &

# Warten
sleep 3

# Test 1: Height
echo ""
echo "📊 Test 1: Height"
HEIGHT=$(curl -s -X POST http://localhost:16316/rpc -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getHeight","params":{},"id":1}' | jq -r '.result')
echo "Height: $HEIGHT"

# Test 2: Mine einige Blöcke
echo ""
echo "⛏ Test 2: Mining..."
timeout 5 ./build-v2/kalon-miner-v2 -wallet 0000000000000000000000000000000000000000 -threads 1 -rpc http://localhost:16316 2>&1 | grep -E "Block found|submitted successfully" | head -5

# Test 3: Balance
echo ""
echo "💰 Test 3: Balance"
BALANCE=$(curl -s -X POST http://localhost:16316/rpc -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getBalance","params":{"address":"0000000000000000000000000000000000000000"},"id":2}' | jq -r '.result')
echo "Balance: $BALANCE"

# Cleanup
echo ""
echo "🧹 Cleanup..."
pkill -f kalon

echo ""
if [ "$BALANCE" -gt "0" ]; then
  echo "✅ Tests erfolgreich! Balance: $BALANCE"
else
  echo "❌ Tests fehlgeschlagen! Balance: $BALANCE"
fi
```

## 📝 Notizen

- **Wichtig**: Nach Tests immer alle Prozesse beenden!
- **Port**: RPC läuft auf Port `16316`
- **Testnet**: Aktuell läuft Testnet-Modus
- **Difficulty**: Testnet hat Difficulty 1 (sehr einfach)

## 🔗 Git-Integration

Auf dem neuen Server Git konfigurieren:

```bash
# Git konfigurieren
git config user.email "kalon@your-server.com"
git config user.name "Kalon Server"

# Remote checken
git remote -v

# Updates holen
git pull origin master
```

## 🎯 Quick Commands Reference

```bash
# Komplett neu starten
pkill -f kalon && rm -rf data-v2/testnet && mkdir -p data-v2/testnet && ./build-v2/kalon-node-v2 -datadir data-v2/testnet -genesis genesis/testnet.json -rpc :16316 &

# Balance prüfen
curl -X POST http://localhost:16316/rpc -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getBalance","params":{"address":"0000000000000000000000000000000000000000"},"id":2}'

# Alles stoppen
pkill -f kalon

# Logs anzeigen
tail -f /tmp/node.log
```

