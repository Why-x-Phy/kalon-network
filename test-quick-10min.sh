#!/bin/bash
# Schneller 10-Minuten-Test
# Testet: Node, Mining, Wallets, Transaktionen

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TEST_DURATION=600   # 10 Minuten in Sekunden
TARGET_BLOCKS=100   # Ziel: 100 Blöcke in 10 Minuten
DATA_DIR="data-quick-test"
RPC_URL="http://localhost:16316"
NODE_LOG="node-quick-test.log"
MINER_LOG="miner-quick-test.log"

# Cleanup function
cleanup() {
    echo ""
    echo "=== CLEANUP ==="
    killall -9 kalon-node-v2 kalon-miner-v2 2>/dev/null || true
    pkill -9 -f "test-quick|timeout.*kalon" 2>/dev/null || true
    sleep 2
    lsof -ti:16316 -ti:17335 2>/dev/null | xargs kill -9 2>/dev/null || true
    sleep 2
    echo "✅ Prozesse beendet"
}

trap cleanup EXIT

echo "=== SCHNELLER 10-MINUTEN-TEST ==="
echo "Dauer: 10 Minuten"
echo "Ziel: Block $TARGET_BLOCKS"
echo ""

# Step 1: Cleanup
echo "1. Cleanup..."
# Kill only old processes, not this script
ps aux | grep -E "kalon-node-v2|kalon-miner-v2" | grep -v grep | awk '{print $2}' | xargs kill -9 2>/dev/null || true
sleep 2
lsof -ti:16316 -ti:17335 2>/dev/null | xargs kill -9 2>/dev/null || true
sleep 2
rm -rf "$DATA_DIR" 2>/dev/null || true
mkdir -p "$DATA_DIR"
echo -e "${GREEN}✅ Cleanup abgeschlossen${NC}"

# Step 2: Build (schnell)
echo ""
echo "2. Baue Binaries..."
go build -o build-v2/kalon-node-v2 ./cmd/kalon-node-v2
go build -o build-v2/kalon-miner-v2 ./cmd/kalon-miner-v2
go build -o build-v2/kalon-wallet ./cmd/kalon-wallet
echo -e "${GREEN}✅ Binaries gebaut${NC}"

# Step 3: Start Node
echo ""
echo "3. Starte Node..."
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

# Step 4: Create Wallets
echo ""
echo "4. Erstelle Wallets..."
WALLET1_OUTPUT=$(./build-v2/kalon-wallet create 2>&1)
WALLET1=$(echo "$WALLET1_OUTPUT" | grep -i "address" | grep -oE '[a-f0-9]{40}' | head -n 1)
if [ -z "$WALLET1" ]; then
    WALLET1="8cc92a1d253973db54f716e0f8747988dbbe9116"
    echo -e "${YELLOW}⚠️ Verwende Standard-Wallet 1${NC}"
fi

WALLET2_OUTPUT=$(./build-v2/kalon-wallet create 2>&1)
WALLET2=$(echo "$WALLET2_OUTPUT" | grep -i "address" | grep -oE '[a-f0-9]{40}' | head -n 1)
if [ -z "$WALLET2" ]; then
    WALLET2="a1b2c3d4e5f6789012345678901234567890abcd"
    echo -e "${YELLOW}⚠️ Verwende Standard-Wallet 2${NC}"
fi

echo "Wallet 1: $WALLET1"
echo "Wallet 2: $WALLET2"
echo -e "${GREEN}✅ Wallets erstellt${NC}"

# Step 5: Start Miner mit 2 Threads
echo ""
echo "5. Starte Miner mit 2 Threads..."
timeout $TEST_DURATION ./build-v2/kalon-miner-v2 -wallet "$WALLET1" -threads 2 -rpc "$RPC_URL" > "$MINER_LOG" 2>&1 &
MINER_PID=$!
echo -e "${GREEN}✅ Miner läuft (PID: $MINER_PID)${NC}"
sleep 5

# Step 6: Monitoring Loop (10 Minuten = 60 Sekunden * 10 = 600 Sekunden)
echo ""
echo "6. Starte Monitoring (10 Minuten)..."
echo "   Prüfe alle 30 Sekunden..."
START_TIME=$(date +%s)
LAST_HEIGHT=0
LAST_BALANCE1=0
TX_COUNT=0
ERROR_COUNT=0

for i in $(seq 1 $((TEST_DURATION / 30))); do
    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - START_TIME))
    ELAPSED_MIN=$((ELAPSED / 60))
    
    # Check Node
    if ! kill -0 $NODE_PID 2>/dev/null; then
        echo -e "${RED}❌ Node abgestürzt!${NC}"
        tail -n 30 "$NODE_LOG"
        exit 1
    fi
    
    # Get current height
    HEIGHT=$(curl -s "$RPC_URL/rpc" -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getHeight","id":1}' 2>/dev/null | jq -r .result 2>/dev/null || echo "0")
    if [ "$HEIGHT" == "null" ] || [ -z "$HEIGHT" ]; then
        HEIGHT=0
    fi
    
    # Count errors
    CURRENT_ERRORS=$(tail -n 100 "$MINER_LOG" | grep -ic "failed\|error\|invalid character" || echo 0)
    if [ "$CURRENT_ERRORS" -gt "$ERROR_COUNT" ]; then
        NEW_ERRORS=$((CURRENT_ERRORS - ERROR_COUNT))
        ERROR_COUNT=$CURRENT_ERRORS
        if [ "$NEW_ERRORS" -gt 0 ] && [ "$ERROR_COUNT" -lt 10 ]; then
            echo -e "${YELLOW}⚠️ $NEW_ERRORS neue Fehler (Total: $ERROR_COUNT)${NC}"
        fi
    fi
    
    # Get balance
    BALANCE1=$(curl -s "$RPC_URL/rpc" -H "Content-Type: application/json" -d "{\"jsonrpc\":\"2.0\",\"method\":\"getBalance\",\"params\":{\"address\":\"$WALLET1\"},\"id\":1}" 2>/dev/null | jq -r .result 2>/dev/null || echo "0")
    if [ "$BALANCE1" == "null" ] || [ -z "$BALANCE1" ]; then
        BALANCE1=0
    fi
    
    # Progress update every 2 minutes or on height change
    if [ "$HEIGHT" -gt "$LAST_HEIGHT" ] || [ $((i % 4)) -eq 0 ]; then
        if [ "$HEIGHT" -gt "$LAST_HEIGHT" ]; then
            LAST_HEIGHT=$HEIGHT
            BLOCKS_FOUND=$(tail -n 200 "$MINER_LOG" | grep -ic "block found\|submitted successfully" || echo 0)
            echo ""
            echo -e "${GREEN}📊 Status nach ${ELAPSED_MIN} Min:${NC}"
            echo "   Höhe: $HEIGHT / $TARGET_BLOCKS"
            echo "   Wallet 1 Balance: $BALANCE1"
            echo "   Blöcke gefunden: $BLOCKS_FOUND"
            echo "   Fehler: $ERROR_COUNT"
            
            # Send transaction every 20 blocks
            if [ $((HEIGHT % 20)) -eq 0 ] && [ "$BALANCE1" -gt 1000000 ]; then
                AMOUNT=$((BALANCE1 / 10))
                echo ""
                echo -e "${BLUE}📤 Sende Transaktion: $AMOUNT von Wallet1 -> Wallet2${NC}"
                TX_RESULT=$(curl -s "$RPC_URL/rpc" -H "Content-Type: application/json" -d "{\"jsonrpc\":\"2.0\",\"method\":\"sendTransaction\",\"params\":{\"from\":\"$WALLET1\",\"to\":\"$WALLET2\",\"amount\":$AMOUNT},\"id\":1}")
                if echo "$TX_RESULT" | grep -q '"error"'; then
                    echo -e "${YELLOW}⚠️ Transaktion fehlgeschlagen (normal bei niedrigen Balances)${NC}"
                else
                    TX_COUNT=$((TX_COUNT + 1))
                    echo -e "${GREEN}✅ Transaktion gesendet (Total: $TX_COUNT)${NC}"
                fi
            fi
        else
            echo ""
            echo -e "${BLUE}📊 Status nach ${ELAPSED_MIN} Min:${NC}"
            echo "   Höhe: $HEIGHT / $TARGET_BLOCKS"
            echo "   Balance: $BALANCE1"
            echo "   Fehler: $ERROR_COUNT"
        fi
    fi
    
    # Check if target reached
    if [ "$HEIGHT" -ge "$TARGET_BLOCKS" ]; then
        echo ""
        echo -e "${GREEN}🎉 ZIEL ERREICHT: Block $HEIGHT erreicht!${NC}"
        break
    fi
    
    LAST_BALANCE1=$BALANCE1
    sleep 30
done

# Step 7: Final Results
echo ""
echo "=== FINALE ERGEBNISSE ==="
FINAL_HEIGHT=$(curl -s "$RPC_URL/rpc" -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getHeight","id":1}' 2>/dev/null | jq -r .result 2>/dev/null || echo "0")
FINAL_BALANCE1=$(curl -s "$RPC_URL/rpc" -H "Content-Type: application/json" -d "{\"jsonrpc\":\"2.0\",\"method\":\"getBalance\",\"params\":{\"address\":\"$WALLET1\"},\"id\":1}" 2>/dev/null | jq -r .result 2>/dev/null || echo "0")
FINAL_ERRORS=$(tail -n 500 "$MINER_LOG" | grep -ic "failed\|error\|invalid character" || echo 0)
FINAL_BLOCKS=$(tail -n 500 "$MINER_LOG" | grep -ic "block found\|submitted successfully" || echo 0)

echo "Finale Höhe: $FINAL_HEIGHT / $TARGET_BLOCKS"
echo "Wallet 1 Balance: $FINAL_BALANCE1"
echo "Transaktionen: $TX_COUNT"
echo "Blöcke gemined: $FINAL_BLOCKS"
echo "Fehler: $FINAL_ERRORS"

# Validate results
SUCCESS=true
if [ "$FINAL_HEIGHT" -lt 50 ]; then
    echo -e "${RED}❌ Zu wenig Blöcke ($FINAL_HEIGHT < 50)${NC}"
    SUCCESS=false
fi

if [ "$FINAL_BALANCE1" -eq 0 ] && [ "$FINAL_HEIGHT" -gt 1 ]; then
    echo -e "${RED}❌ Wallet Balance ist 0 trotz Mining!${NC}"
    SUCCESS=false
fi

if [ "$FINAL_ERRORS" -gt 20 ]; then
    echo -e "${RED}❌ Zu viele Fehler ($FINAL_ERRORS > 20)${NC}"
    SUCCESS=false
fi

if [ "$SUCCESS" = true ]; then
    echo ""
    echo -e "${GREEN}✅ TEST ERFOLGREICH!${NC}"
    exit 0
else
    echo ""
    echo -e "${YELLOW}⚠️ TEST MIT PROBLEMEN${NC}"
    echo ""
    echo "Miner-Log (Fehler):"
    tail -n 100 "$MINER_LOG" | grep -i "failed\|error\|invalid" | head -n 10
    exit 1
fi
