#!/bin/bash

# Vollständiger Test für Block Fee

echo "=== VOLLSTÄNDIGER BLOCK FEE TEST ==="
echo ""

# Cleanup
pkill -f kalon-node-v2 2>/dev/null || true
pkill -f kalon-miner-v2 2>/dev/null || true
sleep 2
rm -rf data-testnet/* wallet1.json wallet2.json treasury-wallet.json wallet_address.txt

# 1. Starte Node
echo "1. Starte Node..."
./build-v2/kalon-node-v2 -rpc 127.0.0.1:16316 -datadir data-testnet -genesis genesis/testnet.json > node.log 2>&1 &
sleep 5
echo "   ✓ Node gestartet"
echo ""

# 2. Prüfe Node
echo "2. Prüfe Node..."
HEIGHT=$(curl -s http://localhost:16316/rpc -X POST -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getHeight","params":{},"id":1}' 2>/dev/null | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('result', 0))" 2>/dev/null || echo "0")
echo "   Height: $HEIGHT"
echo ""

# 3. Erstelle Miner Wallet
echo "3. Erstelle Miner Wallet..."
echo "" | ./build-v2/kalon-wallet create --output wallet1.json 2>&1 | grep -oP 'kalon1[^\s]+' | head -1 > wallet_address.txt
WALLET=$(cat wallet_address.txt 2>/dev/null || echo "")
if [ -z "$WALLET" ]; then
    if [ -f wallet1.json ]; then
        WALLET=$(./build-v2/kalon-wallet info --input wallet1.json 2>&1 | grep -oP '"address":\s*"\K[^"]+' | head -1)
    fi
fi
echo "   Miner Wallet: $WALLET"
echo ""

# 4. Prüfe Treasury Wallet
echo "4. Prüfe Treasury Wallet..."
TREASURY="kalon1df7552b7f9f25986fd33511e68d5ba5e37fd12d3"
echo "   Treasury: $TREASURY"
echo ""

# 5. Starte Miner
echo "5. Starte Miner..."
if [ -n "$WALLET" ]; then
    ./build-v2/kalon-miner-v2 -rpc http://localhost:16316 -wallet "$WALLET" -threads 1 > miner.log 2>&1 &
    echo "   ✓ Miner gestartet"
    echo "   Warte 60 Sekunden auf Blöcke..."
    sleep 60
else
    echo "   ✗ Wallet nicht gefunden"
fi
echo ""

# 6. Prüfe Ergebnisse
echo "6. Prüfe Ergebnisse..."
HEIGHT=$(curl -s http://localhost:16316/rpc -X POST -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getHeight","params":{},"id":1}' 2>/dev/null | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('result', 0))" 2>/dev/null || echo "0")
MINER_BALANCE=$(curl -s http://localhost:16316/rpc -X POST -H "Content-Type: application/json" -d "{\"jsonrpc\":\"2.0\",\"method\":\"getBalance\",\"params\":{\"address\":\"$WALLET\"},\"id\":1}" 2>/dev/null | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('result', 0))" 2>/dev/null || echo "0")
TREASURY_BALANCE=$(curl -s http://localhost:16316/rpc -X POST -H "Content-Type: application/json" -d "{\"jsonrpc\":\"2.0\",\"method\":\"getBalance\",\"params\":{\"address\":\"$TREASURY\"},\"id\":1}" 2>/dev/null | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('result', 0))" 2>/dev/null || echo "0")

echo ""
echo "=== ERGEBNISSE ==="
echo "Height: $HEIGHT"
echo "Miner Balance: $MINER_BALANCE"
echo "Treasury Balance: $TREASURY_BALANCE"

if [ "$HEIGHT" -gt 0 ]; then
    EXPECTED_MINER=$(python3 << EOF
height = $HEIGHT
block_reward = 5.0
block_reward_units = int(block_reward * 1000000)
block_fee_rate = 0.05
miner_reward_per_block = int(block_reward_units * (1 - block_fee_rate))
expected = height * miner_reward_per_block
print(expected)
EOF
)
    EXPECTED_TREASURY=$(python3 << EOF
height = $HEIGHT
block_reward = 5.0
block_reward_units = int(block_reward * 1000000)
block_fee_rate = 0.05
treasury_reward_per_block = int(block_reward_units * block_fee_rate)
expected = height * treasury_reward_per_block
print(expected)
EOF
)
    echo "Erwartete Miner Balance (95% von $HEIGHT Blöcken): $EXPECTED_MINER"
    echo "Erwartete Treasury Balance (5% von $HEIGHT Blöcken): $EXPECTED_TREASURY"
fi

echo ""
echo "=== STATUS ==="
if [ "$HEIGHT" -gt 0 ]; then
    echo "✓ Blöcke wurden gemined ($HEIGHT)"
else
    echo "✗ Keine Blöcke gemined"
fi

if [ "$MINER_BALANCE" -gt 0 ]; then
    if [ "$MINER_BALANCE" -eq "$EXPECTED_MINER" ]; then
        echo "✓ Miner Balance korrekt ($MINER_BALANCE = erwartet: $EXPECTED_MINER)"
    else
        echo "⚠ Miner Balance: $MINER_BALANCE (erwartet: $EXPECTED_MINER)"
    fi
else
    echo "✗ Miner Balance ist 0"
fi

if [ "$TREASURY_BALANCE" -gt 0 ]; then
    if [ "$TREASURY_BALANCE" -eq "$EXPECTED_TREASURY" ]; then
        echo "✓ Treasury Balance korrekt ($TREASURY_BALANCE = erwartet: $EXPECTED_TREASURY)"
    else
        echo "⚠ Treasury Balance: $TREASURY_BALANCE (erwartet: $EXPECTED_TREASURY)"
    fi
else
    echo "✗ Treasury Balance ist 0"
fi

echo ""
echo "=== CLEANUP ==="
pkill -f kalon-node-v2
pkill -f kalon-miner-v2
echo "Node und Miner gestoppt"

