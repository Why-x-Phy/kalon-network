#!/bin/bash
set -e

echo "=== CLEANUP ==="
pkill -9 -f kalon || true
rm -rf data-v2/testnet wallet.json
mkdir -p data-v2/testnet

echo ""
echo "=== 1. START NODE ==="
./build-v2/kalon-node-v2 -datadir data-v2/testnet -genesis genesis/testnet.json -rpc :16316 > /tmp/node_test.log 2>&1 &
sleep 3

echo ""
echo "=== 2. CREATE WALLET ==="
echo "" | ./build-v2/kalon-wallet create > /tmp/wallet.log 2>&1
WALLET=$(cat wallet.json | jq -r .address)
echo "Wallet: $WALLET"

echo ""
echo "=== 3. START MINING (5s) ==="
timeout 5 ./build-v2/kalon-miner-v2 -wallet "$WALLET" -threads 1 -rpc http://localhost:16316 > /tmp/miner_test.log 2>&1 &
MINER_PID=$!
sleep 6
pkill -9 -f kalon-miner || true

echo ""
echo "=== 4. CHECK BALANCE ==="
HEIGHT=$(curl -s http://localhost:16316/rpc -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getHeight","params":{},"id":1}' | jq -r .result)
echo "Height: $HEIGHT"

BALANCE=$(curl -s http://localhost:16316/rpc -H "Content-Type: application/json" -d "{\"jsonrpc\":\"2.0\",\"method\":\"getBalance\",\"params\":{\"address\":\"$WALLET\"},\"id\":2}" | jq -r .result)
echo "💰 BALANCE: $BALANCE"

if [ "$BALANCE" -gt "0" ]; then
    echo ""
    echo "✅✅✅ BALANCE FUNKTIONIERT!"
    pkill -9 -f kalon
    exit 0
else
    echo ""
    echo "❌ Balance = 0"
    echo ""
    echo "=== DEBUG INFO ==="
    tail -10 /tmp/node_test.log | grep -E "(UTXO|address|output)" || echo "No UTXO logs found"
    pkill -9 -f kalon
    exit 1
fi
