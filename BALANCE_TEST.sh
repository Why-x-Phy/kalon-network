#!/bin/bash
# Kalon Balance Test - SIMPLE VERSION

echo "🚀 Kalon Balance Test"
echo "====================="
echo ""

cd ~/kalon-network
git pull origin master

# Stoppe alte Prozesse
pkill -f kalon-node
pkill -f kalon-miner
sleep 2

# Baue neu
echo "🔨 Baue kalon-node-v2 und kalon-miner-v2..."
go build -o build-v2/kalon-node-v2 ./cmd/kalon-node-v2
go build -o build-v2/kalon-miner-v2 ./cmd/kalon-miner-v2

if [ ! -f "build-v2/kalon-node-v2" ]; then
    echo "❌ kalon-node-v2 konnte nicht gebaut werden!"
    exit 1
fi

echo "✅ Build erfolgreich"
echo ""

# Node starten
echo "🚀 Starte Node..."
nohup ./build-v2/kalon-node-v2 --datadir data-v2/testnet --genesis genesis/testnet.json --rpc :16316 --p2p :17335 > node-v2.log 2>&1 &
sleep 5

# Miner starten
echo "⛏️ Starte Miner..."
nohup ./build-v2/kalon-miner-v2 --wallet kalon1r9wen9um8qwfdxdyk9u5yr3sd5ym5vrj72cttt --threads 2 --rpc http://localhost:16316 > miner-v2.log 2>&1 &

# Warten auf Block
echo "⏳ Warte 60 Sekunden auf geminten Block..."
sleep 60

# Balance prüfen
echo ""
echo "💰 Prüfe Balance:"
BALANCE=$(curl -s http://localhost:16316 -X POST -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"getBalance","params":{"address":"kalon1r9wen9um8qwfdxdyk9u5yr3sd5ym5vrj72cttt"}}' 2>/dev/null | jq -r '.result' 2>/dev/null)

if [ "$BALANCE" = "0" ] || [ -z "$BALANCE" ]; then
    echo "❌ BALANCE = $BALANCE (BUG!)"
    echo ""
    echo "Debug:"
    tail -50 node-v2.log | grep "UTXO\|Address"
else
    echo "✅ BALANCE = $BALANCE (FUNKTIONIERT!)"
fi

echo ""
echo "📊 Logs:"
echo "  tail -f node-v2.log"
echo "  tail -f miner-v2.log"
