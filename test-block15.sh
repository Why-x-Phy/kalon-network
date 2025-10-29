#!/bin/bash

echo "=== KALON BLOCK 15 TEST SCRIPT ==="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
DATA_DIR="data-block15-test"
NODE_LOG="node-block15-test.log"
MINER_LOG="miner-block15-test.log"
RPC_URL="http://localhost:16316"
WALLET="8cc92a1d253973db54f716e0f8747988dbbe9116"
TEST_DURATION=600  # 10 Minuten

# Cleanup function
cleanup() {
    echo ""
    echo "=== CLEANUP ==="
    pkill -9 -f kalon 2>/dev/null
    sleep 2
    echo "✅ Prozesse gestoppt"
}

# Trap Ctrl+C
trap cleanup EXIT INT TERM

# Step 1: Cleanup
echo "1. Cleanup..."
pkill -9 -f kalon 2>/dev/null || true
rm -rf "$DATA_DIR"
mkdir -p "$DATA_DIR"
sleep 2

# Step 2: Check binaries
echo ""
echo "2. Prüfe Binaries..."
if [ ! -f "./build-v2/kalon-node-v2" ]; then
    echo -e "${RED}❌ kalon-node-v2 nicht gefunden!${NC}"
    echo "Bitte zuerst bauen: go build -o build-v2/kalon-node-v2 cmd/kalon-node-v2/main.go"
    exit 1
fi
if [ ! -f "./build-v2/kalon-miner-v2" ]; then
    echo -e "${RED}❌ kalon-miner-v2 nicht gefunden!${NC}"
    echo "Bitte zuerst bauen: go build -o build-v2/kalon-miner-v2 cmd/kalon-miner-v2/main.go"
    exit 1
fi
echo -e "${GREEN}✅ Binaries gefunden${NC}"

# Step 3: Check genesis file
echo ""
echo "3. Prüfe Genesis-Datei..."
if [ ! -f "genesis/testnet.json" ]; then
    echo -e "${RED}❌ genesis/testnet.json nicht gefunden!${NC}"
    exit 1
fi
INITIAL_DIFF=$(grep -A 1 "difficulty" genesis/testnet.json | grep "initialDifficulty" | grep -o '[0-9]*')
echo "   Initial Difficulty: $INITIAL_DIFF"
echo -e "${GREEN}✅ Genesis-Datei gefunden${NC}"

# Step 4: Start Node
echo ""
echo "4. Starte Node..."
nohup ./build-v2/kalon-node-v2 -datadir "$DATA_DIR" -genesis genesis/testnet.json -rpc :16316 -p2p :17335 > "$NODE_LOG" 2>&1 &
NODE_PID=$!
sleep 5

# Check if node is running
if ! ps -p $NODE_PID > /dev/null 2>&1; then
    echo -e "${RED}❌ Node konnte nicht gestartet werden!${NC}"
    echo "Log:"
    tail -n 20 "$NODE_LOG"
    exit 1
fi
echo -e "${GREEN}✅ Node läuft (PID: $NODE_PID)${NC}"

# Step 5: Check Node Health
echo ""
echo "5. Prüfe Node Health..."
for i in {1..10}; do
    HEIGHT=$(curl -s "$RPC_URL/rpc" -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getHeight","id":1}' 2>/dev/null | jq -r .result 2>/dev/null)
    if [ "$HEIGHT" != "null" ] && [ -n "$HEIGHT" ]; then
        echo "   Height: $HEIGHT"
        echo -e "${GREEN}✅ Node antwortet${NC}"
        break
    fi
    if [ $i -eq 10 ]; then
        echo -e "${RED}❌ Node antwortet nicht!${NC}"
        tail -n 30 "$NODE_LOG"
        exit 1
    fi
    sleep 1
done

# Step 6: Check Difficulty
echo ""
echo "6. Prüfe Difficulty..."
DIFFICULTY=$(curl -s "$RPC_URL/rpc" -H "Content-Type: application/json" -d "{\"jsonrpc\":\"2.0\",\"method\":\"createBlockTemplate\",\"params\":{\"miner\":\"$WALLET\"},\"id\":1}" | jq -r .result.difficulty 2>/dev/null)
echo "   Difficulty: $DIFFICULTY"
EXPECTED_DIFF=$((INITIAL_DIFF * 4))
if [ "$DIFFICULTY" == "$EXPECTED_DIFF" ] || [ "$DIFFICULTY" == "$INITIAL_DIFF" ]; then
    echo -e "${GREEN}✅ Difficulty korrekt${NC}"
else
    echo -e "${YELLOW}⚠️ Difficulty: $DIFFICULTY (erwartet: $EXPECTED_DIFF oder $INITIAL_DIFF)${NC}"
fi

# Step 7: Start Miner
echo ""
echo "7. Starte Miner (für $((TEST_DURATION / 60)) Minuten)..."
timeout $TEST_DURATION ./build-v2/kalon-miner-v2 -wallet "$WALLET" -threads 1 -rpc "$RPC_URL" > "$MINER_LOG" 2>&1 &
MINER_PID=$!
echo -e "${GREEN}✅ Miner läuft (PID: $MINER_PID)${NC}"

# Step 8: Monitor Progress
echo ""
echo "8. Überwache Mining..."
echo "   Prüfe alle 30 Sekunden den Status..."
PREV_HEIGHT=0
NO_CHANGE_COUNT=0

for i in $(seq 1 $((TEST_DURATION / 30))); do
    sleep 30
    
    CURRENT_HEIGHT=$(curl -s "$RPC_URL/rpc" -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getHeight","id":1}' 2>/dev/null | jq -r .result 2>/dev/null)
    BLOCKS_FOUND=$(grep -c "Block found" "$MINER_LOG" 2>/dev/null || echo 0)
    ERRORS=$(grep -c "Failed\|invalid character" "$MINER_LOG" 2>/dev/null || echo 0)
    
    if [ "$CURRENT_HEIGHT" != "$PREV_HEIGHT" ]; then
        echo "   [$i] Height: $CURRENT_HEIGHT | Blöcke gefunden: $BLOCKS_FOUND | Fehler: $ERRORS"
        PREV_HEIGHT=$CURRENT_HEIGHT
        NO_CHANGE_COUNT=0
    else
        NO_CHANGE_COUNT=$((NO_CHANGE_COUNT + 1))
        if [ $NO_CHANGE_COUNT -eq 4 ]; then
            echo "   [$i] Kein Fortschritt seit 2 Minuten..."
        fi
    fi
    
    # Check for Block 15 errors
    if grep -q "Block #15\|Block #14\|Block #16" "$MINER_LOG" 2>/dev/null; then
        BLOCK15_ERROR=$(grep -A 2 "Block #15\|Block #14\|Block #16" "$MINER_LOG" 2>/dev/null | grep -E "Failed\|invalid" | head -n 1)
        if [ -n "$BLOCK15_ERROR" ]; then
            echo ""
            echo -e "${YELLOW}⚠️ FEHLER BEI BLOCK 15 GEFUNDEN!${NC}"
            echo "   Fehler: $BLOCK15_ERROR"
        fi
    fi
done

# Step 9: Final Results
echo ""
echo "=== TEST ERGEBNISSE ==="
echo ""

FINAL_HEIGHT=$(curl -s "$RPC_URL/rpc" -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getHeight","id":1}' 2>/dev/null | jq -r .result 2>/dev/null)
FINAL_BLOCKS=$(grep -c "Block found" "$MINER_LOG" 2>/dev/null || echo 0)
FINAL_ERRORS=$(grep -c "Failed\|invalid character" "$MINER_LOG" 2>/dev/null || echo 0)
SUBMISSIONS=$(grep -c "submitted successfully" "$MINER_LOG" 2>/dev/null || echo 0)

echo "Finale Höhe: $FINAL_HEIGHT"
echo "Blöcke gefunden: $FINAL_BLOCKS"
echo "Erfolgreiche Submissions: $SUBMISSIONS"
echo "Fehler: $FINAL_ERRORS"
echo ""

# Check Block 15 specifically
echo "=== BLOCK 15 ANALYSE ==="
BLOCK15_FOUND=$(grep -c "Block #15\|Block found.*#15" "$MINER_LOG" 2>/dev/null || echo 0)
BLOCK15_ERRORS=$(grep "Block #15" "$MINER_LOG" 2>/dev/null | grep -c "Failed\|invalid" || echo 0)

if [ "$BLOCK15_FOUND" -gt 0 ]; then
    echo "Block 15 gefunden: Ja ($BLOCK15_FOUNDx)"
    if [ "$BLOCK15_ERRORS" -gt 0 ]; then
        echo -e "${RED}❌ FEHLER BEI BLOCK 15: $BLOCK15_ERRORS${NC}"
        echo ""
        echo "Fehler-Details:"
        grep -A 5 "Block #15" "$MINER_LOG" 2>/dev/null | grep -E "Failed\|invalid" | head -n 5
    else
        echo -e "${GREEN}✅ Block 15 ohne Fehler${NC}"
    fi
else
    echo "Block 15 gefunden: Nein"
fi

echo ""

# Show errors around block 15
if [ "$FINAL_HEIGHT" -ge 15 ]; then
    echo "=== LOGS UM BLOCK 15 ==="
    echo ""
    echo "Miner-Log:"
    grep -E "Block #1[456]|Failed|invalid" "$MINER_LOG" 2>/dev/null | head -n 20
    echo ""
    echo "Node-Log (letzte 50 Zeilen):"
    tail -n 50 "$NODE_LOG" 2>/dev/null | grep -E "Block #1[456]|ERROR|PANIC|Failed" || echo "Keine relevanten Fehler gefunden"
fi

echo ""
echo "=== ZUSAMMENFASSUNG ==="
if [ "$FINAL_HEIGHT" -ge 20 ]; then
    echo -e "${GREEN}✅ TEST ERFOLGREICH: Block 20+ erreicht${NC}"
elif [ "$FINAL_HEIGHT" -ge 15 ]; then
    echo -e "${YELLOW}⚠️ BLOCK 15 PROBLEM: Höhe = $FINAL_HEIGHT${NC}"
else
    echo -e "${RED}❌ TEST FEHLGESCHLAGEN: Nur Höhe $FINAL_HEIGHT erreicht${NC}"
fi

echo ""
echo "Log-Dateien:"
echo "  Node: $NODE_LOG"
echo "  Miner: $MINER_LOG"
echo ""

# Cleanup
cleanup

echo "Test abgeschlossen!"
