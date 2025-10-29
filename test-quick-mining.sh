#!/bin/bash
# Schneller Mining-Test mit niedriger Difficulty

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

DATA_DIR="data-quick-test"
RPC_URL="http://localhost:16316"
WALLET="8cc92a1d253973db54f716e0f8747988dbbe9116"

echo "=== SCHNELLER MINING-TEST ==="
echo ""

# Cleanup
rm -rf "$DATA_DIR" && mkdir -p "$DATA_DIR"

# 1. Backup testnet.json
cp genesis/testnet.json genesis/testnet.json.backup

# 2. Setze niedrige Difficulty (10)
echo "Setze Difficulty auf 10 für schnelles Mining..."
cat > genesis/testnet.json << 'GENESIS'
{
  "chainId": 7718,
  "name": "Kalon Testnet",
  "symbol": "tKALON",
  "blockTimeTargetSeconds": 30,
  "maxSupply": 1000000000,
  "initialBlockReward": 5.0,
  "halvingSchedule": [],
  "difficulty": {
    "algo": "LWMA",
    "window": 120,
    "initialDifficulty": 10,
    "maxAdjustPerBlockPct": 25,
    "launchGuard": {
      "enabled": false,
      "durationHours": 24,
      "difficultyFloorMultiplier": 1.0,
      "initialReward": 2.0
    }
  },
  "addressFormat": { "type": "bech32", "hrp": "tkalon" },
  "premine": { "enabled": false },
  "treasuryAddress": "tkalon1treasury0000000000000000000000000000000000000000000000000000000000",
  "networkFee": {
    "blockFeeRate": 0.05,
    "txFeeShareTreasury": 0.20,
    "baseTxFee": 0.01,
    "gasPrice": 1000
  },
  "governance": {
    "parameters": {
      "networkFeeRate": 0.05,
      "txFeeShareTreasury": 0.20,
      "treasuryCapPercent": 10
    }
  }
}
GENESIS

# 3. Build
echo "Baue Node..."
go build -o build-v2/kalon-node-v2 ./cmd/kalon-node-v2
go build -o build-v2/kalon-miner-v2 ./cmd/kalon-miner-v2

# 4. Start Node
echo ""
echo "Starte Node..."
./build-v2/kalon-node-v2 -datadir "$DATA_DIR" -genesis genesis/testnet.json > node-quick.log 2>&1 &
NODE_PID=$!

# Wait for node to start
echo "   Warte auf Node-Start..."
for i in {1..20}; do
    if curl -s "$RPC_URL/rpc" -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getHeight","id":1}' > /dev/null 2>&1; then
        echo "   ✅ Node läuft!"
        break
    fi
    if [ $i -eq 20 ]; then
        echo "   ❌ Node startet nicht!"
        echo "   Node-Logs:"
        cat node-quick.log
        exit 1
    fi
    sleep 1
done

# 5. Check Height
HEIGHT=$(curl -s "$RPC_URL/rpc" -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getHeight","id":1}' 2>/dev/null | jq -r .result 2>/dev/null)
echo "Start-Höhe: $HEIGHT"

# 6. Start Miner
echo ""
echo "Starte Miner für 60 Sekunden..."
timeout 60 ./build-v2/kalon-miner-v2 -wallet "$WALLET" -threads 1 -rpc "$RPC_URL" > miner-quick.log 2>&1 &
MINER_PID=$!

# 7. Monitor
echo ""
echo "Überwache Mining..."
for i in {1..12}; do
    sleep 5
    CURRENT_HEIGHT=$(curl -s "$RPC_URL/rpc" -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getHeight","id":1}' 2>/dev/null | jq -r .result 2>/dev/null)
    BLOCKS_FOUND=$(tail -n 50 miner-quick.log | grep -i "block found\|submitted" | wc -l)
    ERRORS=$(tail -n 50 miner-quick.log | grep -i "error\|failed" | wc -l)
    
    if [ -z "$CURRENT_HEIGHT" ] || [ "$CURRENT_HEIGHT" == "null" ]; then
        CURRENT_HEIGHT=0
    fi
    
    echo "  Sekunde $((i * 5)): Höhe=$CURRENT_HEIGHT, Blöcke=$BLOCKS_FOUND, Fehler=$ERRORS"
done

# 8. Check Results
FINAL_HEIGHT=$(curl -s "$RPC_URL/rpc" -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getHeight","id":1}' 2>/dev/null | jq -r .result 2>/dev/null)
FINAL_BLOCKS=$(tail -n 100 miner-quick.log | grep -i "block found\|submitted" | wc -l)

echo ""
echo "=== ERGEBNIS ==="
echo "Finale Höhe: $FINAL_HEIGHT"
echo "Blöcke gefunden: $FINAL_BLOCKS"

# Fix empty height
if [ -z "$FINAL_HEIGHT" ] || [ "$FINAL_HEIGHT" == "null" ]; then
    FINAL_HEIGHT=0
fi

if [ "$FINAL_HEIGHT" -gt 1 ]; then
    echo -e "${GREEN}✅ TEST ERFOLGREICH: Blöcke wurden gefunden!${NC}"
else
    echo -e "${RED}❌ TEST FEHLGESCHLAGEN: Keine Blöcke gefunden!${NC}"
    echo ""
    echo "Node-Logs (letzte 30 Zeilen):"
    tail -n 30 node-quick.log
    echo ""
    echo "Miner-Logs (letzte 30 Zeilen):"
    tail -n 30 miner-quick.log
fi

# 9. Cleanup
kill $MINER_PID 2>/dev/null || true
kill $NODE_PID 2>/dev/null || true
mv genesis/testnet.json.backup genesis/testnet.json
rm -rf "$DATA_DIR"

echo ""
echo "=== FERTIG ==="
