#!/bin/bash
cd /home/whyphyc/Kalon/kalon
pkill -9 -f kalon || true
rm -rf data-v2/testnet wallet.json
mkdir -p data-v2/testnet

echo "" | ./build-v2/kalon-wallet create 2>&1 | grep "Address:"
WALLET=$(cat wallet.json | jq -r .address)
echo "Wallet: $WALLET"

./build-v2/kalon-node-v2 -datadir data-v2/testnet -genesis genesis/testnet.json -rpc :16316 > /tmp/node.log 2>&1 &
sleep 7
echo "Node started"

timeout 5 ./build-v2/kalon-miner-v2 -wallet "$WALLET" -threads 1 -rpc http://localhost:16316 2>&1 | tail -10

sleep 2
BALANCE=$(curl -s http://localhost:16316/rpc -H "Content-Type: application/json" -d "{\"jsonrpc\":\"2.0\",\"method\":\"getBalance\",\"params\":{\"address\":\"$WALLET\"},\"id\":2}" | jq -r .result)
echo ""
echo "BALANCE: $BALANCE"

if [ "$BALANCE" != "null" ] && [ "$BALANCE" != "" ] && [ "$BALANCE" -gt "0" ] 2>/dev/null; then
    echo "✅✅✅ SUCCESS - BALANCE FUNKTIONIERT!"
    exit 0
else
    echo "❌ Balance still 0"
    cat /tmp/node.log | grep -E "(AddUTXO|Balance)" | tail -10
    exit 1
fi

