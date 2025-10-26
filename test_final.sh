#!/bin/bash
# Finaler Test - Balance muss funktionieren!

echo "🧹 CLEANUP"
pkill -f kalon || true
sleep 1
rm -rf data-v2/testnet wallet.json
mkdir -p data-v2/testnet

echo ""
echo "🔨 BUILD"
go build -o build-v2/kalon-node-v2 cmd/kalon-node-v2/main.go
go build -o build-v2/kalon-miner-v2 cmd/kalon-miner-v2/main.go
go build -o build-v2/kalon-wallet cmd/kalon-wallet/main.go

echo ""
echo "🚀 NODE STARTEN"
./build-v2/kalon-node-v2 -datadir data-v2/testnet -genesis genesis/testnet.json -rpc :16316 > /tmp/node.log 2>&1 &
NODE_PID=$!
sleep 3
ps aux | grep kalon-node | grep -v grep | head -1

echo ""
echo "💰 WALLET ERSTELLEN"
echo "" | ./build-v2/kalon-wallet create > /tmp/wallet.log 2>&1
WALLET_ADDRESS=$(cat wallet.json | jq -r .address)
echo "Address: $WALLET_ADDRESS"

echo ""
echo "⛏ MINING (10 Sekunden)"
timeout 10 ./build-v2/kalon-miner-v2 -wallet "$WALLET_ADDRESS" -threads 1 -rpc http://localhost:16316 2>&1 | grep "submitted successfully" | wc -l
echo "Mining abgeschlossen"

echo ""
echo "📊 ERGEBNISSE"
HEIGHT=$(curl -s -X POST http://localhost:16316/rpc -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getHeight","params":{},"id":1}' | jq -r .result)
echo "Height: $HEIGHT"

BALANCE=$(curl -s -X POST http://localhost:16316/rpc -H "Content-Type: application/json" -d "{\"jsonrpc\":\"2.0\",\"method\":\"getBalance\",\"params\":{\"address\":\"$WALLET_ADDRESS\"},\"id\":2}" | jq -r .result)
echo "💰 BALANCE: $BALANCE"

if [ "$BALANCE" -gt "0" ]; then
    echo ""
    echo "✅✅✅ TESTS ERFOLGREICH! ✅✅✅"
    echo "Balance: $BALANCE"
    pkill -f kalon
    exit 0
else
    echo ""
    echo "❌ FEHLER: Balance = 0"
    echo ""
    echo "🔍 DEBUG:"
    tail -20 /tmp/node.log | grep "UTXO created"
    pkill -f kalon
    exit 1
fi

