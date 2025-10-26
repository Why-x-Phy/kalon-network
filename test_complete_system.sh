#!/bin/bash
# Kompletter System-Test für Kalon Network
set -e  # Stop bei Fehlern

echo "🧹 SCHRITT 1: Cleanup"
echo "===================="
pkill -f kalon || true
sleep 2
rm -rf data-v2/testnet wallet.json
mkdir -p data-v2/testnet
echo "✅ Cleanup abgeschlossen"
echo ""

echo "🔨 SCHRITT 2: Builds erstellen"
echo "==============================="
go build -o build-v2/kalon-node-v2 cmd/kalon-node-v2/main.go
go build -o build-v2/kalon-miner-v2 cmd/kalon-miner-v2/main.go
go build -o build-v2/kalon-wallet cmd/kalon-wallet/main.go
echo "✅ Builds abgeschlossen"
echo ""

echo "🚀 SCHRITT 3: Node starten"
echo "========================="
./build-v2/kalon-node-v2 -datadir data-v2/testnet -genesis genesis/testnet.json -rpc :16316 > /tmp/kalon_node_test.log 2>&1 &
NODE_PID=$!
echo "Node PID: $NODE_PID"
sleep 5

# Prüfe ob Node läuft
if ! ps -p $NODE_PID > /dev/null; then
    echo "❌ Node läuft nicht!"
    cat /tmp/kalon_node_test.log
    exit 1
fi
echo "✅ Node läuft"
echo ""

echo "💰 SCHRITT 4: Wallet erstellen"
echo "=============================="
echo "" | ./build-v2/kalon-wallet create > /tmp/wallet_creation.log 2>&1
WALLET_ADDRESS=$(cat wallet.json | jq -r .address)
echo "Wallet: $WALLET_ADDRESS"
echo "✅ Wallet erstellt"
echo ""

echo "⛏ SCHRITT 5: Mining (30 Sekunden)"
echo "=================================="
timeout 30 ./build-v2/kalon-miner-v2 -wallet "$WALLET_ADDRESS" -threads 1 -rpc http://localhost:16316 > /tmp/kalon_miner_test.log 2>&1 &
MINER_PID=$!
sleep 30
pkill -P $MINER_PID || true
echo "✅ Mining abgeschlossen"
echo ""

echo "📊 SCHRITT 6: Ergebnisse prüfen"
echo "==============================="

# Height
HEIGHT=$(curl -s -X POST http://localhost:16316/rpc -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"getHeight","params":{},"id":1}' | jq -r .result)
echo "Height: $HEIGHT"

# Blocks gefunden?
BLOCKS_FOUND=$(grep -c "submitted successfully" /tmp/kalon_miner_test.log || echo "0")
echo "Blocks gefunden: $BLOCKS_FOUND"

# Balance
BALANCE=$(curl -s -X POST http://localhost:16316/rpc -H "Content-Type: application/json" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"getBalance\",\"params\":{\"address\":\"$WALLET_ADDRESS\"},\"id\":2}" | jq -r .result)
echo "Balance: $BALANCE"

# UTXO Check
UTXO_COUNT=$(grep "UTXO created" /tmp/kalon_node_test.log | wc -l)
echo "UTXOs erstellt: $UTXO_COUNT"

echo ""
echo "🧹 SCHRITT 7: Cleanup"
echo "===================="
pkill -f kalon
rm -f wallet.json
echo "✅ Cleanup abgeschlossen"
echo ""

echo "📋 FINALES ERGEBNIS"
echo "==================="
if [ "$BALANCE" -gt "0" ]; then
    echo "✅ TESTS ERFOLGREICH!"
    echo "   - Height: $HEIGHT"
    echo "   - Blocks: $BLOCKS_FOUND"
    echo "   - Balance: $BALANCE"
    echo "   - UTXOs: $UTXO_COUNT"
    exit 0
else
    echo "❌ TESTS FEHLGESCHLAGEN!"
    echo "   - Height: $HEIGHT"
    echo "   - Blocks: $BLOCKS_FOUND"
    echo "   - Balance: $BALANCE (sollte > 0 sein!)"
    echo "   - UTXOs: $UTXO_COUNT"
    exit 1
fi

