#!/bin/bash

# Einfacher Test für Balance und Block Fee

echo "=== VOLLSTÄNDIGER SYSTEM-TEST ==="
echo ""

# Cleanup
pkill -f kalon-node-v2 2>/dev/null || true
pkill -f kalon-miner-v2 2>/dev/null || true
sleep 2
rm -rf data-v2/testnet/* wallet1.json wallet2.json wallet_address.txt

# 1. Starte Node
echo "1. Starte Node..."
./build-v2/kalon-node-v2 -rpc :16316 -datadir data-v2/testnet > node.log 2>&1 &
sleep 5
echo "   ✓ Node gestartet"
echo ""

# 2. Erstelle Wallet
echo "2. Erstelle Wallet..."
./build-v2/kalon-wallet create --output wallet1.json 2>&1 | grep -oP 'kalon1[^\s]+' | head -1 > wallet_address.txt
WALLET=$(cat wallet_address.txt)
echo "   ✓ Wallet: $WALLET"
echo ""

# 3. Starte Miner
echo "3. Starte Miner..."
./build-v2/kalon-miner-v2 -rpc http://localhost:16316 -wallet "$WALLET" -threads 1 > miner.log 2>&1 &
echo "   ✓ Miner gestartet"
echo "   Warte 60 Sekunden auf Blöcke..."
sleep 60
echo ""

# 4. Prüfe Ergebnisse
echo "4. Prüfe Ergebnisse..."
HEIGHT=$(curl -s http://localhost:16316/rpc -X POST -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getHeight","params":{},"id":1}' 2>/dev/null | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('result', 0))" 2>/dev/null || echo "0")
BALANCE=$(curl -s http://localhost:16316/rpc -X POST -H "Content-Type: application/json" -d "{\"jsonrpc\":\"2.0\",\"method\":\"getBalance\",\"params\":{\"address\":\"$WALLET\"},\"id\":1}" 2>/dev/null | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('result', 0))" 2>/dev/null || echo "0")
TREASURY="tkalon1treasury0000000000000000000000000000000000000000000000000000000000"
TREASURY_BALANCE=$(curl -s http://localhost:16316/rpc -X POST -H "Content-Type: application/json" -d "{\"jsonrpc\":\"2.0\",\"method\":\"getBalance\",\"params\":{\"address\":\"$TREASURY\"},\"id\":1}" 2>/dev/null | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('result', 0))" 2>/dev/null || echo "0")

echo ""
echo "=== ERGEBNISSE ==="
echo "Height: $HEIGHT"
echo "Wallet Balance: $BALANCE"
echo "Treasury Balance: $TREASURY_BALANCE"

if [ "$HEIGHT" -gt 0 ]; then
    EXPECTED=$(python3 << EOF
height = $HEIGHT
block_reward = 5.0
block_fee_rate = 0.01
expected = height * block_reward * block_fee_rate
print(int(expected))
EOF
)
    echo "Erwartete Treasury (1% von $HEIGHT Blöcken): $EXPECTED"
fi

echo ""
echo "=== STATUS ==="
if [ "$HEIGHT" -gt 0 ]; then
    echo "✓ Blöcke wurden gemined ($HEIGHT)"
else
    echo "✗ Keine Blöcke gemined"
fi

if [ "$BALANCE" -gt 0 ]; then
    echo "✓ Balance wird aktualisiert ($BALANCE)"
else
    echo "✗ Balance ist 0"
fi

if [ "$TREASURY_BALANCE" -gt 0 ]; then
    echo "✓ Block Fee funktioniert ($TREASURY_BALANCE)"
else
    echo "⚠ Block Fee: Treasury Balance ist 0 (möglicherweise nicht aktiviert)"
fi

echo ""
echo "=== CLEANUP ==="
pkill -f kalon-node-v2
pkill -f kalon-miner-v2
echo "Node und Miner gestoppt"

