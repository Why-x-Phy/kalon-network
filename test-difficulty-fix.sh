#!/bin/bash

echo "=== KALON DIFFICULTY FIX TEST ==="
echo ""

# 1. Check current status
echo "1. Aktuelle Commits:"
git log --oneline -3
echo ""

# 2. Pull updates
echo "2. Updates holen..."
git pull origin master
echo ""

# 3. Build node
echo "3. Node neu bauen..."
go build -o build-v2/kalon-node-v2 cmd/kalon-node-v2/main.go
if [ $? -eq 0 ]; then
    echo "✅ Build erfolgreich"
else
    echo "❌ Build fehlgeschlagen"
    exit 1
fi
echo ""

# 4. Test difficulty
echo "4. Difficulty testen..."
rm -rf data-test && mkdir -p data-test
nohup ./build-v2/kalon-node-v2 -datadir data-test -genesis genesis/testnet.json -rpc :16316 -p2p :17335 > node-test.log 2>&1 &
sleep 5

echo "Difficulty Check:"
DIFFICULTY=$(curl -s http://localhost:16316/rpc -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"createBlockTemplate","params":{"miner":"8cc92a1d253973db54f716e0f8747988dbbe9116"},"id":1}' | jq -r .result.difficulty)
echo "Difficulty: $DIFFICULTY"

if [ "$DIFFICULTY" = "5000" ]; then
    echo "✅ Difficulty korrekt (5000)"
else
    echo "❌ Difficulty falsch ($DIFFICULTY)"
fi
echo ""

# 5. Test mining
echo "5. Mining testen (30 Sekunden)..."
timeout 30 ./build-v2/kalon-miner-v2 -wallet "8cc92a1d253973db54f716e0f8747988dbbe9116" -threads 1 -rpc http://localhost:16316 > miner-test.log 2>&1 &
sleep 30

echo "Mining Ergebnisse:"
BLOCKS=$(grep -c "Block found" miner-test.log || echo "0")
HEIGHT=$(curl -s http://localhost:16316/rpc -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getHeight","id":1}' | jq -r .result)
echo "Blöcke gefunden: $BLOCKS"
echo "Chain Height: $HEIGHT"

if [ "$BLOCKS" -gt 0 ]; then
    echo "✅ Mining funktioniert"
else
    echo "❌ Mining funktioniert nicht"
fi
echo ""

# 6. Cleanup
echo "6. Cleanup..."
pkill -9 -f kalon 2>/dev/null
echo "✅ Test abgeschlossen"
echo ""
echo "=== ZUSAMMENFASSUNG ==="
echo "Difficulty: $DIFFICULTY"
echo "Blöcke: $BLOCKS"
echo "Height: $HEIGHT"
