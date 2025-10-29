#!/bin/bash
# Exakter Test wie lokal - für Server

set -e

echo "=== EXAKTER TEST WIE LOKAL ==="
echo ""

# 1. System-Info
echo "Go Version:"
go version
echo ""
echo "System:"
uname -a
echo ""

# 2. Cleanup
echo "Cleanup..."
pkill -f kalon-node-v2 kalon-miner-v2 2>/dev/null || true
sleep 2
rm -rf data/testnet data-quick-test 2>/dev/null || true
mkdir -p data/testnet

# 3. Build
echo "Build..."
go build -v -o build-v2/kalon-node-v2 ./cmd/kalon-node-v2
go build -v -o build-v2/kalon-miner-v2 ./cmd/kalon-miner-v2

# 4. Start Node
echo ""
echo "Starte Node..."
./build-v2/kalon-node-v2 -datadir data/testnet -genesis genesis/testnet.json -rpc :16316 -p2p :17335 > node-test.log 2>&1 &
NODE_PID=$!
sleep 8

if ! kill -0 $NODE_PID 2>/dev/null; then
    echo "❌ Node startet nicht!"
    tail -n 30 node-test.log
    exit 1
fi

# 5. Test RPC
echo "Teste RPC..."
HEIGHT=$(curl -s http://localhost:16316/rpc -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getHeight","id":1}' 2>/dev/null | jq -r .result 2>/dev/null)
echo "Height: $HEIGHT"

# 6. Test createBlockTemplate
WALLET="8cc92a1d253973db54f716e0f8747988dbbe9116"
echo ""
echo "Teste createBlockTemplate mit Wallet: $WALLET"
TEMPLATE=$(curl -s http://localhost:16316/rpc -H "Content-Type: application/json" -d "{\"jsonrpc\":\"2.0\",\"method\":\"createBlockTemplate\",\"params\":{\"miner\":\"$WALLET\"},\"id\":1}")
echo "Response:"
echo "$TEMPLATE" | jq . 2>/dev/null || echo "$TEMPLATE"

if echo "$TEMPLATE" | grep -q '"error"'; then
    echo "❌ FEHLER!"
    echo "Node-Log:"
    tail -n 30 node-test.log
    pkill -f kalon-node-v2
    exit 1
else
    echo "✅ createBlockTemplate funktioniert!"
fi

# 7. Start Miner
echo ""
echo "Starte Miner (30s)..."
timeout 30 ./build-v2/kalon-miner-v2 -wallet "$WALLET" -threads 1 -rpc http://localhost:16316 > miner-test.log 2>&1 &
MINER_PID=$!
sleep 5

# 8. Monitor
echo "Monitoring..."
for i in {1..5}; do
    sleep 5
    H=$(curl -s http://localhost:16316/rpc -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getHeight","id":1}' 2>/dev/null | jq -r .result 2>/dev/null)
    E=$(tail -n 50 miner-test.log | grep -ic "failed\|error\|invalid" || echo 0)
    B=$(tail -n 50 miner-test.log | grep -ic "block found\|submitted" || echo 0)
    echo "[$((i*5))s] H=$H, Errors=$E, Blocks=$B"
done

# 9. Results
echo ""
echo "=== ERGEBNIS ==="
FINAL_H=$(curl -s http://localhost:16316/rpc -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getHeight","id":1}' 2>/dev/null | jq -r .result 2>/dev/null)
FINAL_E=$(tail -n 100 miner-test.log | grep -ic "failed\|error\|invalid" || echo 0)

echo "Final Height: $FINAL_H"
echo "Fehler: $FINAL_E"

if [ "$FINAL_E" -gt 0 ]; then
    echo ""
    echo "❌ FEHLER GEFUNDEN:"
    tail -n 50 miner-test.log | grep -i "failed\|error\|invalid" | head -n 10
    echo ""
    echo "Node-Log (letzte 20):"
    tail -n 20 node-test.log
fi

pkill -f kalon-node-v2 kalon-miner-v2 2>/dev/null || true
