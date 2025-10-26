#!/bin/bash
# Kalon Network - Komplette Neuinstallation
# Auf einem neuen Server ausführen

set -e  # Stop bei Fehlern

echo "🚀 Kalon Network - Komplette Neuinstallation"
echo "=============================================="
echo ""

# 1. Git Repository clonen
echo "📦 Schritt 1: Repository clonen..."
git clone https://github.com/Why-x-Phy/kalon-network.git
cd kalon-network

# 2. Go Version prüfen
echo ""
echo "🔍 Schritt 2: Go Version prüfen..."
go version

# 3. Builds erstellen
echo ""
echo "🔨 Schritt 3: Builds erstellen..."
echo "  - Node..."
go build -o build-v2/kalon-node-v2 cmd/kalon-node-v2/main.go
echo "  - Miner..."
go build -o build-v2/kalon-miner-v2 cmd/kalon-miner-v2/main.go
echo "  - Wallet..."
go build -o build-v2/kalon-wallet cmd/kalon-wallet/main.go
echo "✅ Builds fertig!"

# 4. Directorys erstellen
echo ""
echo "📁 Schritt 4: Directorys erstellen..."
rm -rf data-v2/testnet
mkdir -p data-v2/testnet

# 5. Node starten
echo ""
echo "🚀 Schritt 5: Node starten..."
./build-v2/kalon-node-v2 \
  -datadir data-v2/testnet \
  -genesis genesis/testnet.json \
  -rpc :16316 > /tmp/kalon_node.log 2>&1 &

NODE_PID=$!
echo "✅ Node gestartet (PID: $NODE_PID)"

# 6. Warten bis Node bereit ist
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

# 8. Wallet erstellen
echo ""
echo "💰 Schritt 7: Wallet erstellen..."
echo "⚠️  Benutze 'enter' für leere Passphrase!"
./build-v2/kalon-wallet create --output wallet.json <<EOF

EOF

# Adresse aus wallet.json extrahieren
if [ -f wallet.json ]; then
  WALLET_ADDRESS=$(cat wallet.json | grep -o '"address":"[^"]*"' | cut -d'"' -f4)
  echo "✅ Wallet erstellt!"
  echo "Address: $WALLET_ADDRESS"
  
  # In Datei speichern
  echo "$WALLET_ADDRESS" > /tmp/kalon_address.txt
else
  echo "❌ Wallet konnte nicht erstellt werden"
  exit 1
fi

# 9. Miner starten
echo ""
echo "⛏  Schritt 8: Miner starten..."
./build-v2/kalon-miner-v2 \
  -wallet "$WALLET_ADDRESS" \
  -threads 1 \
  -rpc http://localhost:16316 > /tmp/kalon_miner.log 2>&1 &

MINER_PID=$!
echo "✅ Miner gestartet (PID: $MINER_PID)"

# 10. Warten bis Miner läuft
echo ""
echo "⏳ Warte auf Mining..."
sleep 5

# 11. Finale Tests
echo ""
echo "🧪 Schritt 9: Tests..."
echo "  - Height prüfen..."
HEIGHT=$(curl -s -X POST http://localhost:16316/rpc \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"getHeight","params":{},"id":1}' | jq -r '.result')
echo "  Height: $HEIGHT"

echo "  - Balance prüfen..."
BALANCE=$(curl -s -X POST http://localhost:16316/rpc \
  -H "Content-Type: application/json" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"getBalance\",\"params\":{\"address\":\"$WALLET_ADDRESS\"},\"id\":2}" | jq -r '.result')
echo "  Balance: $BALANCE"

# 12. Finale Info
echo ""
echo "✅ KALON NETWORK INSTALLATION FERTIG!"
echo "=============================================="
echo "Node PID: $NODE_PID"
echo "Miner PID: $MINER_PID"
echo "Wallet Address: $WALLET_ADDRESS"
echo "Balance: $BALANCE"
echo ""
echo "📋 Nützliche Befehle:"
echo "  tail -f /tmp/kalon_node.log       # Node Logs"
echo "  tail -f /tmp/kalon_miner.log      # Miner Logs"
echo "  pkill -f kalon                     # Alles beenden"
echo "  cat /tmp/kalon_address.txt        # Wallet Adresse"
echo ""

# Prozesse anzeigen
ps aux | grep kalon | grep -v grep || echo "Keine Kalon Prozesse gefunden"

