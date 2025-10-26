#!/bin/bash
set -e

echo "=== KALON BALANCE TEST ==="
pkill -9 -f kalon || true
rm -rf data-v2/testnet wallet.json
mkdir -p data-v2/testnet

echo ""
echo "1. Creating wallet..."
echo "" | ./build-v2/kalon-wallet create 2>&1 | grep "Address:"
WALLET=$(cat wallet.json | jq -r .address)
echo "Wallet: $WALLET"

echo ""
echo "2. Starting node..."
./build-v2/kalon-node-v2 -datadir data-v2/testnet -genesis genesis/testnet.json -rpc :16316 > /tmp/test.log 2>&1 &
sleep 5

echo ""
echo "3. Mining (5s)..."
timeout 5 ./build-v2/kalon-miner-v2 -wallet "$WALLET" -threads 1 -rpc http://localhost:16316 2>&1 &
MINER_PID=$!
sleep 6
kill $MINER_PID 2>/dev/null || true

echo ""
echo "4. Checking balance..."
sleep 2
BALANCE=$(curl -s http://localhost:16316/rpc -H "Content-Type: application/json" -d "{\"jsonrpc\":\"2.0\",\"method\":\"getBalance\",\"params\":{\"address\":\"$WALLET\"},\"id\":2}" | jq -r .result)

echo ""
echo "💰 BALANCE: $BALANCE"

if [ "$BALANCE" -gt "0" ]; then
    echo "🎉🎉🎉 BALANCE FUNKTIONIERT! 🎉🎉🎉"
    echo ""
    tail -50 /tmp/test.log | grep -E "(AddUTXO|Parsed|miner address)" | tail -10
else
    echo "❌ Balance = 0"
    echo ""
    tail -50 /tmp/test.log | grep -E "(AddUTXO|Parsed|miner address)" | tail -10
fi

pkill -9 -f kalon || true

