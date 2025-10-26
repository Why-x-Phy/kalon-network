#!/bin/bash
# Kalon Network - Update auf neueste Version
# Führt git pull aus, baut neu und startet Node + Miner

set -e  # Stop bei Fehlern

echo "🔄 Kalon Network - Update"
echo "=========================="
echo ""

# Check ob im richtigen Directory
if [ ! -d "kalon-network" ]; then
  echo "❌ Kein kalon-network Directory gefunden!"
  echo "Führe erst INSTALLATION_COMPLETE.sh aus"
  exit 1
fi

cd kalon-network

# 1. Alte Prozesse beenden
echo "🛑 Schritt 1: Alte Prozesse beenden..."
pkill -f kalon || echo "Keine alten Prozesse gefunden"
sleep 2

# 2. Git Pull
echo ""
echo "📥 Schritt 2: Updates holen..."
git pull origin master
echo "✅ Updates geholt"

# 3. Neu bauen
echo ""
echo "🔨 Schritt 3: Neu bauen..."
go build -o build-v2/kalon-node-v2 cmd/kalon-node-v2/main.go
go build -o build-v2/kalon-miner-v2 cmd/kalon-miner-v2/main.go
go build -o build-v2/kalon-wallet cmd/kalon-wallet/main.go
echo "✅ Builds fertig"

# 4. Wallet Adresse laden
echo ""
echo "🔍 Schritt 4: Wallet Adresse laden..."
if [ -f /tmp/kalon_address.txt ]; then
  WALLET_ADDRESS=$(cat /tmp/kalon_address.txt)
  echo "Wallet Address: $WALLET_ADDRESS"
else
  echo "⚠️  Keine gespeicherte Adresse gefunden"
  echo "Frage nach Wallet-Adresse..."
  echo "Bitte deine Wallet-Adresse eingeben:"
  read WALLET_ADDRESS
fi

# 5. Node starten
echo ""
echo "🚀 Schritt 5: Node starten..."
./build-v2/kalon-node-v2 \
  -datadir data-v2/testnet \
  -genesis genesis/testnet.json \
  -rpc :16316 > /tmp/kalon_node.log 2>&1 &

NODE_PID=$!
echo "✅ Node gestartet (PID: $NODE_PID)"

# 6. Warten
echo ""
echo "⏳ Warte auf Node..."
sleep 5

# 7. Health Check
echo ""
echo "🔍 Schritt 6: Health Check..."
HEIGHT=$(curl -s -X POST http://localhost:16316/rpc \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"getHeight","params":{},"id":1}' | jq -r '.result')
echo "✅ Node läuft! Height: $HEIGHT"

# 8. Miner starten
echo ""
echo "⛏  Schritt 7: Miner starten..."
./build-v2/kalon-miner-v2 \
  -wallet "$WALLET_ADDRESS" \
  -threads 1 \
  -rpc http://localhost:16316 > /tmp/kalon_miner.log 2>&1 &

MINER_PID=$!
echo "✅ Miner gestartet (PID: $MINER_PID)"

# 9. Warten
echo ""
echo "⏳ Warte auf Mining..."
sleep 5

# 10. Tests
echo ""
echo "🧪 Schritt 8: Tests..."
BALANCE=$(curl -s -X POST http://localhost:16316/rpc \
  -H "Content-Type: application/json" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"getBalance\",\"params\":{\"address\":\"$WALLET_ADDRESS\"},\"id\":2}" | jq -r '.result')
echo "Balance: $BALANCE"

echo ""
echo "✅ UPDATE FERTIG!"
echo "================"
echo "Node PID: $NODE_PID"
echo "Miner PID: $MINER_PID"
echo "Balance: $BALANCE"
echo ""

