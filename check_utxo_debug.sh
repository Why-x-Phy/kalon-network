#!/bin/bash
# Check what's in the UTXO set
cd /home/whyphyc/Kalon/kalon

echo "=== UTXO Debug Test ==="
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
./build-v2/kalon-node-v2 -datadir data-v2/testnet -genesis genesis/testnet.json -rpc :16316 > /tmp/utxo_test.log 2>&1 &
sleep 7

echo ""
echo "3. Mining 1 block..."
timeout 5 ./build-v2/kalon-miner-v2 -wallet "$WALLET" -threads 1 -rpc http://localhost:16316 2>&1 | grep -E "(Block found|submitted)" | head -5

echo ""
echo "4. Checking balance..."
sleep 2
BALANCE=$(curl -s http://localhost:16316/rpc -H "Content-Type: application/json" -d "{\"jsonrpc\":\"2.0\",\"method\":\"getBalance\",\"params\":{\"address\":\"$WALLET\"},\"id\":2}" | jq -r .result)
echo "Balance: $BALANCE"

echo ""
echo "5. Checking logs for address formats..."
cat /tmp/utxo_test.log | grep -E "(Parsed.*address|DEBUG.*Miner address)" | tail -5

pkill -9 -f kalon

