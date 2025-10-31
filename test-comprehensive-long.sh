#!/bin/bash
# Umfassender Langzeit-Test für 1 Stunde
# Testet: Node, Mining, Wallets, Transaktionen, Balance, UTXOs

# set -e entfernt, da einzelne Fehler nicht den gesamten Test stoppen sollen

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TEST_DURATION=3600  # 1 Stunde in Sekunden
TARGET_BLOCKS=200
DATA_DIR="data-comprehensive-test"
RPC_URL="http://localhost:16316"
NODE_LOG="node-comprehensive-test.log"
MINER_LOG="miner-comprehensive-test.log"
WALLET1_LOG="wallet1-comprehensive-test.log"
WALLET2_LOG="wallet2-comprehensive-test.log"

# Cleanup function
cleanup() {
    echo ""
    echo "=== CLEANUP ==="
    pkill - kto kalon-node-v2 kalon-miner-v2 2>/dev/null || true
    sleep 2
    echo "✅ Prozesse beendet"
}

trap cleanup EXIT

echo "=== UMFASSENDER LANGZEIT-TEST ==="
echo "Dauer: 1 Stunde"
echo "Ziel: Block $TARGET_BLOCKS"
echo ""

# Step 1: Cleanup
echo "1. Cleanup..."
killall -9 kalon-node-v2 kalon-miner-v2 2>/dev/null || true
pkill -9 -f "test-comprehensive|timeout.*kalon" 2>/dev/null || true
sleep 2
lsof -ti:16316 -ti:17335 2>/dev/null | xargs kill -9 2>/dev/null || true
sleep 2
cleanup
rm -rf "$DATA_DIR" 2>/dev/null || true
mkdir -p "$DATA_DIR"
echo -e "${GREEN}✅ Cleanup abgeschlossen${NC}"

# Step 2: Backup und konfiguriere Genesis für schnelles Mining
echo ""
echo "2. Konfiguriere Genesis für schnelles Mining..."
cp genesis/testnet.json genesis/testnet.json.backup-test
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
    "initialDifficulty": 15,
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
echo -e "${GREEN}✅ Genesis konfiguriert (Difficulty: 15)${NC}"

# Step 3: Build
echo ""
echo "3. Baue Binaries..."
go build -o build-v2/kalon-node-v2 ./cmd/kalon-node-v2
go build -o build-v2/kalon-miner-v2 ./cmd/kalon-miner-v2
go build -o build-v2/kalon-wallet ./cmd/kalon-wallet
echo -e "${GREEN}✅ Binaries gebaut${NC}"

# Step 4: Start Node
echo ""
echo "4. Starte Node..."
./build-v2/kalon-node-v2 -datadir "$DATA_DIR" -genesis genesis/testnet.json -rpc :16316 -p2p :17335 > "$NODE_LOG" 2>&1 &
NODE_PID=$!
sleep 8

if ! kill -0 $NODE_PID 2>/dev/null; then
    echo -e "${RED}❌ Node startet nicht!${NC}"
    tail -n 30 "$NODE_LOG"
    exit 1
fi

# Wait for RPC to be ready
for i in {1..20}; do
    if curl -s "$RPC_URL/rpc" -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getHeight","id":1}' > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Node läuft (PID: $NODE_PID)${NC}"
        break
    fi
    if [ $i -eq 20 ]; then
        echo -e "${RED}❌ RPC nicht erreichbar!${NC}"
        tail -n 30 "$NODE_LOG"
        exit 1
    fi
    sleep 1
done

# Step 5: Create Wallets
echo ""
echo "5. Erstelle Wallets..."
WALLET1_OUTPUT=$(./build-v2/kalon-wallet create 2>&1 | tee "$WALLET1_LOG")
WALLET1=$(echo "$WALLET1_OUTPUT" | grep -i "address" | grep -oE '[a-f0-9]{40}' | head -n 1)
if [ -z "$WALLET1" ]; then
    WALLET1="8cc92a1d253973db54f716e0f8747988dbbe9116"
    echo -e "${YELLOW}⚠️ Verwende Standard-Wallet 1${NC}"
fi

WALLET2_OUTPUT=$(./build-v2/kalon-wallet create 2>&1 | tee "$WALLET2_LOG")
WALLET2=$(echo "$WALLET2_OUTPUT" | grep -i "address" | grep -oE '[a-f0-9]{40}' | head -n 1)
if [ -z "$WALLET2" ]; then
    # Generate different default
    WALLET2="a1b2c3d4e5f6789012345678901234567890abcd"
    echo -e "${YELLOW}⚠️ Verwende Standard-Wallet 2${NC}"
fi

echo "Wallet 1: $WALLET1"
echo "Wallet 2: $WALLET2"
echo -e "${GREEN}✅ Wallets erstellt${NC}"

# Step 6: Start Miner mit 2 Threads
echo ""
echo "6. Starte Miner mit 2 Threads für Wallet 1..."
timeout $TEST_DURATION ./build-v2/kalon-miner-v2 -wallet "$WALLET1" -threads 2 -rpc "$RPC_URL" > "$MINER_LOG" 2>&1 &
MINER_PID=$!
echo -e "${GREEN}✅ Miner läuft (PID: $MINER_PID)${NC}"
sleep 5

# Step 7: Monitoring Loop
echo ""
echo "7. Starte Monitoring (1 Stunde)..."
echo "   Prüfe alle 60 Sekunden..."
START_TIME=$(date +%s)
LAST_HEIGHT=0
LAST_BALANCE1=0
LAST_BALANCE2=0
BLOCKS_MINED=0
TX_COUNT=0
ERROR_COUNT=0
MAX_ERRORS=100

for i in $(seq 1 $((TEST_DURATION / 60))); do
    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - START_TIME))
    ELAPSED_MIN=$((ELAPSED / 60))
    
    # Check Node
    if ! kill -0 $NODE_PID 2>/dev/null; then
        echo -e "${RED}❌ Node abgestürzt!${NC}"
        tail -n 30 "$NODE_LOG"
        exit 1
    fi
    
    # Check Miner
    if ! kill -0 $MINER_PID 2>/dev/null; then
        echo -e "${YELLOW}⚠️ Miner beendet${NC}"
    fi
    
    # Get current height
    HEIGHT=$(curl -s "$RPC_URL/rpc" -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getHeight","id":1}' 2>/dev/null | jq -r .result 2>/dev/null || echo "0")
    if [ "$HEIGHT" == "null" ] || [ -z "$HEIGHT" ]; then
        HEIGHT=0
    fi
    
    # Count errors
    CURRENT_ERRORS=$(tail -n 200 "$MINER_LOG" | grep -ic "failed\|error\|invalid character" || echo 0)
    if [ "$CURRENT_ERRORS" -gt "$ERROR_COUNT" ]; then
        NEW_ERRORS=$((CURRENT_ERRORS - ERROR_COUNT))
        ERROR_COUNT=$CURRENT_ERRORS
        if [ "$NEW_ERRORS" -gt 0 ]; then
            echo -e "${YELLOW}⚠️ $NEW_ERRORS neue Fehler gefunden (Total: $ERROR_COUNT)${NC}"
            tail -n 50 "$MINER_LOG" | grep -i "failed\|error\|invalid" | tail -n 3
        fi
    fi
    
    # Get balances
    BALANCE1=$(curl -s "$RPC_URL/rpc" -H "Content-Type: application/json" -d "{\"jsonrpc\":\"2.0\",\"method\":\"getBalance\",\"params\":{\"address\":\"$WALLET1\"},\"id\":1}" 2>/dev/null | jq -r .result 2>/dev/null || echo "0")
    BALANCE2=$(curl -s "$RPC_URL/rpc" -H "Content-Type: application/json" -d "{\"jsonrpc\":\"2.0\",\"method\":\"getBalance\",\"params\":{\"address\":\"$WALLET2\"},\"id\":1}" 2>/dev/null | jq -r .result 2>/dev/null || echo "0")
    
    if [ "$BALANCE1" == "null" ] || [ -z "$BALANCE1" ]; then
        BALANCE1=0
    fi
    if [ "$BALANCE2" == "null" ] || [ -z "$BALANCE2" ]; then
        BALANCE2=0
    fi
    
    # Calculate blocks mined
    BLOCKS_FOUND=$(tail -n 500 "$MINER_LOG" | grep -ic "block found\|submitted successfully" || echo 0)
    
    # Check if height increased
    if [ "$HEIGHT" -gt "$LAST_HEIGHT" ]; then
        BLOCKS_MINED=$((HEIGHT - LAST_HEIGHT))
        LAST_HEIGHT=$HEIGHT
        echo ""
        echo -e "${GREEN}📊 Status nach ${ELAPSED_MIN} Minuten:${NC}"
        echo "   Höhe: $HEIGHT / $TARGET_BLOCKS"
        echo "   Wallet 1 Balance: $BALANCE1"
        echo "   Wallet 2 Balance: $BALANCE2"
        echo "   Fehler: $ERROR_COUNT"
        
        # Send transaction every 20 blocks
        if [ $((HEIGHT % 20)) -eq 0 ] && [ "$BALANCE1" -gt 1000000 ]; then
            AMOUNT=$((BALANCE1 / 10))
            echo ""
            echo -e "${BLUE}📤 Sende Transaktion: $AMOUNT von Wallet1 -> Wallet2${NC}"
            TX_RESULT=$(curl -s "$RPC_URL/rpc" -H "Content-Type: application/json" -d "{\"jsonrpc\":\"2.0\",\"method\":\"sendTransaction\",\"params\":{\"from\":\"$WALLET1\",\"to\":\"$WALLET2\",\"amount\":$AMOUNT},\"id\":1}")
            if echo "$TX_RESULT" | grep -q '"error"'; then
                echo -e "${RED}❌ Transaktion fehlgeschlagen${NC}"
                echo "$TX_RESULT" | jq .
            else
                TX_COUNT=$((TX_COUNT + 1))
                echo -e "${GREEN}✅ Transaktion gesendet (Total: $TX_COUNT)${NC}"
            fi
        fi
    else
        # Progress update every 5 minutes
        if [ $((i % 5)) -eq 0 ]; then
            echo ""
            echo -e "${BLUE}📊 Status nach ${ELAPSED_MIN} Minuten:${NC}"
            echo "   Höhe: $HEIGHT / $TARGET_BLOCKS"
            echo "   Balance W1: $BALANCE1, W2: $BALANCE2"
            echo "   Blöcke gefunden: $BLOCKS_FOUND"
            echo "   Fehler: $ERROR_COUNT"
            
            # Check for stuck mining
            if [ "$HEIGHT" -eq "$LAST_HEIGHT" ] && [ "$HEIGHT" -lt "$TARGET_BLOCKS" ]; then
                echo -e "${YELLOW}⚠️ Kein Fortschritt - prüfe Miner...${NC}"
                tail -n 10 "$MINER_LOG"
            fi
        fi
    fi
    
    # Check error threshold
    if [ "$ERROR_COUNT" -gt "$MAX_ERRORS" ]; then
        echo -e "${RED}❌ Zu viele Fehler ($ERROR_COUNT > $MAX_ERRORS)!${NC}"
        echo "Letzte Fehler:"
        tail -n 100 "$MINER_LOG" | grep -i "failed\|error\|invalid" | tail -n 10
        exit 1
    fi
    
    # Check if target reached
    if [ "$HEIGHT" -ge "$TARGET_BLOCKS" ]; then
        echo ""
        echo -e "${GREEN}🎉 ZIEL ERREICHT: Block $HEIGHT erreicht!${NC}"
        break
    fi
    
    LAST_BALANCE1=$BALANCE1
    LAST_BALANCE2=$BALANCE2
    
    sleep 60
done

# Step 8: Final Results
echo ""
echo "=== FINALE ERGEBNISSE ==="
FINAL_HEIGHT=$(curl -s "$RPC_URL/rpc" -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getHeight","id":1}' 2>/dev/null | jq -r .result 2>/dev/null || echo "0")
FINAL_BALANCE1=$(curl -s "$RPC_URL/rpc" -H "Content-Type: application/json" -d "{\"jsonrpc\":\"2.0\",\"method\":\"getBalance\",\"params\":{\"address\":\"$WALLET1\"},\"id\":1}" 2>/dev/null | jq -r .result 2>/dev/null || echo "0")
FINAL_BALANCE2=$(curl -s "$RPC_URL/rpc" -H "Content-Type: application/json" -d "{\"jsonrpc\":\"2.0\",\"method\":\"getBalance\",\"params\":{\"address\":\"$WALLET2\"},\"id\":1}" 2>/dev/null | jq -r .result 2>/dev/null || echo "0")
FINAL_ERRORS=$(tail -n 1000 "$MINER_LOG" | grep -ic "failed\|error\|invalid character" || echo 0)
FINAL_BLOCKS=$(tail -n 1000 "$MINER_LOG" | grep -ic "block found\|submitted successfully" || echo 0)

echo "Finale Höhe: $FINAL_HEIGHT / $TARGET_BLOCKS"
echo "Wallet 1 Balance: $FINAL_BALANCE1"
echo "Wallet 2 Balance: $FINAL_BALANCE2"
echo "Transaktionen gesendet: $TX_COUNT"
echo "Blöcke gemined: $FINAL_BLOCKS"
echo "Fehler: $FINAL_ERRORS"

# Validate results
SUCCESS=true
if [ "$FINAL_HEIGHT" -lt "$TARGET_BLOCKS" ]; then
    echo -e "${RED}❌ Ziel nicht erreicht ($FINAL_HEIGHT < $TARGET_BLOCKS)${NC}"
    SUCCESS=false
fi

if [ "$FINAL_BALANCE1" -eq 0 ] && [ "$FINAL_HEIGHT" -gt 1 ]; then
    echo -e "${RED}❌ Wallet 1 Balance ist 0 trotz Mining!${NC}"
    SUCCESS=false
fi

if [ "$FINAL_ERRORS" -gt 50 ]; then
    echo -e "${RED}❌ Zu viele Fehler ($FINAL_ERRORS)${NC}"
    SUCCESS=false
fi

if [ "$SUCCESS" = true ]; then
    echo ""
    echo -e "${GREEN}✅ TEST ERFOLGREICH!${NC}"
    exit 0
else
    echo ""
    echo -e "${RED}❌ TEST FEHLGESCHLAGEN!${NC}"
    echo ""
    echo "Node-Log (letzte 30 Zeilen):"
    tail -n 30 "$NODE_LOG"
    echo ""
    echo "Miner-Log (Fehler):"
    tail -n 100 "$MINER_LOG" | grep -i "failed\|error\|invalid" | head -n 20
    exit 1
fi
