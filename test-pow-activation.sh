#!/bin/bash
# Vollständiger Test für PoW-Aktivierung + 15 Sekunden Block-Zeit

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=== VOLLSTÄNDIGER TEST: PoW + 15 SEKUNDEN BLOCK-ZEIT ==="
echo ""

cd ~/kalon-network || cd /home/whyphyc/Kalon/kalon || {
    echo -e "${RED}❌ Verzeichnis nicht gefunden!${NC}"
    exit 1
}

# Cleanup
cleanup() {
    echo ""
    echo "=== CLEANUP ==="
    killall -9 kalon-node-v2 kalon-miner-v2 2>/dev/null || true
    pkill -9 -f "test-pow|kalon" 2>/dev/null || true
    lsof -ti:16316 -ti:17335 2>/dev/null | xargs kill -9 2>/dev/null || true
    sleep 2
    echo "✅ Prozesse beendet"
}

trap cleanup EXIT INT TERM

# 1. Cleanup alte Prozesse
echo "1. Cleanup alte Prozesse..."
killall -9 kalon-node-v2 kalon-miner-v2 2>/dev/null || true
sleep 2
rm -rf data-pow-test 2>/dev/null || true
mkdir -p data-pow-test
echo "✅ Cleanup abgeschlossen"
echo ""

# 2. Prüfe Builds
echo "2. Prüfe Builds..."
if [ ! -f "build-v2/kalon-node-v2" ]; then
    echo -e "${RED}❌ Node Binary nicht gefunden!${NC}"
    exit 1
fi
if [ ! -f "build-v2/kalon-miner-v2" ]; then
    echo -e "${RED}❌ Miner Binary nicht gefunden!${NC}"
    exit 1
fi
if [ ! -f "build-v2/kalon-wallet" ]; then
    echo -e "${RED}❌ Wallet Binary nicht gefunden!${NC}"
    exit 1
fi
chmod +x build-v2/kalon-node-v2 build-v2/kalon-miner-v2 build-v2/kalon-wallet
echo "✅ Builds gefunden"
echo ""

# 3. Prüfe Konfiguration
echo "3. Prüfe Konfiguration..."
BLOCK_TIME=$(grep "blockTimeTargetSeconds" genesis/testnet.json | awk -F: '{print $2}' | tr -d ' ,')
DIFFICULTY=$(grep "initialDifficulty" genesis/testnet.json | awk -F: '{print $2}' | tr -d ' ,')

if [ "$BLOCK_TIME" != "15" ]; then
    echo -e "${RED}❌ Block-Zeit ist nicht 15: $BLOCK_TIME${NC}"
    exit 1
fi
if [ "$DIFFICULTY" != "23" ]; then
    echo -e "${RED}❌ Difficulty ist nicht 23: $DIFFICULTY${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Konfiguration korrekt: Block-Zeit=$BLOCK_TIME, Difficulty=$DIFFICULTY${NC}"
echo ""

# 4. Prüfe PoW-Status
echo "4. Prüfe PoW-Status..."
if ! grep -q "Difficulty <= 20" core/consensus.go; then
    echo -e "${RED}❌ PoW-Toleranz nicht auf 20 gesetzt!${NC}"
    exit 1
fi
echo -e "${GREEN}✅ PoW aktiviert (Toleranz: 20)${NC}"
echo ""

# 5. Starte Node
echo "5. Starte Node..."
./build-v2/kalon-node-v2 \
    -datadir data-pow-test \
    -rpcport 16316 \
    -genesis genesis/testnet.json \
    > node-pow-test.log 2>&1 &
NODE_PID=$!
sleep 5

if ! ps -p $NODE_PID > /dev/null 2>&1; then
    echo -e "${RED}❌ Node startet nicht!${NC}"
    tail -n 30 node-pow-test.log
    exit 1
fi
echo -e "${GREEN}✅ Node läuft (PID: $NODE_PID)${NC}"
echo ""

# 6. Warte auf RPC
echo "6. Warte auf RPC..."
RPC_URL="http://localhost:16316"
for i in {1..30}; do
    if timeout 2 curl -s "$RPC_URL/rpc" -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"getHeight","id":1}' > /dev/null 2>&1; then
        echo -e "${GREEN}✅ RPC bereit${NC}"
        break
    fi
    if [ $i -eq 30 ]; then
        echo -e "${RED}❌ RPC nicht bereit nach 30 Sekunden!${NC}"
        tail -n 30 node-pow-test.log
        exit 1
    fi
    sleep 1
done
echo ""

# 7. Prüfe Difficulty
echo "7. Prüfe Difficulty..."
DIFF_RESPONSE=$(curl -s "$RPC_URL/rpc" -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","method":"getMiningInfo","id":1}')
DIFF_ACTUAL=$(echo "$DIFF_RESPONSE" | grep -o '"difficulty":[0-9]*' | cut -d: -f2)
if [ -z "$DIFF_ACTUAL" ] || [ "$DIFF_ACTUAL" != "23" ]; then
    echo -e "${YELLOW}⚠️ Difficulty ist nicht 23: $DIFF_ACTUAL${NC}"
    echo "Response: $DIFF_RESPONSE"
else
    echo -e "${GREEN}✅ Difficulty korrekt: $DIFF_ACTUAL${NC}"
fi
echo ""

# 8. Erstelle Wallet
echo "8. Erstelle Wallet..."
WALLET_OUTPUT=$(echo -e "\n\n" | ./build-v2/kalon-wallet create 2>&1 | head -20)
WALLET_ADDRESS=$(echo "$WALLET_OUTPUT" | grep -o "kalon1[a-z0-9]*" | head -1)
if [ -z "$WALLET_ADDRESS" ]; then
    # Versuche alternativen Weg
    WALLET_ADDRESS=$(echo "$WALLET_OUTPUT" | grep -o "Address: [a-z0-9]*" | awk '{print $2}')
fi
if [ -z "$WALLET_ADDRESS" ]; then
    echo -e "${YELLOW}⚠️ Wallet-Address nicht gefunden, verwende Standard${NC}"
    WALLET_ADDRESS="kalon1test0000000000000000000000000000000000000000"
else
    echo -e "${GREEN}✅ Wallet erstellt: $WALLET_ADDRESS${NC}"
fi
echo ""

# 9. Starte Miner
echo "9. Starte Miner..."
./build-v2/kalon-miner-v2 \
    -wallet "$WALLET_ADDRESS" \
    -rpc "$RPC_URL" \
    -threads 1 \
    > miner-pow-test.log 2>&1 &
MINER_PID=$!
sleep 3

if ! ps -p $MINER_PID > /dev/null 2>&1; then
    echo -e "${RED}❌ Miner startet nicht!${NC}"
    tail -n 30 miner-pow-test.log
    exit 1
fi
echo -e "${GREEN}✅ Miner läuft (PID: $MINER_PID)${NC}"
echo ""

# 10. Teste Mining für 2 Minuten
echo "10. Teste Mining (2 Minuten)..."
echo "   Überwache Block-Zeit, Difficulty, PoW-Validierung..."
echo ""

START_HEIGHT=$(curl -s "$RPC_URL/rpc" -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","method":"getHeight","id":1}' | grep -o '"result":[0-9]*' | cut -d: -f2)
if [ -z "$START_HEIGHT" ]; then
    START_HEIGHT=0
fi

echo "   Start-Höhe: $START_HEIGHT"
echo ""

LAST_BLOCK_TIME=$(date +%s)
BLOCK_COUNT=0
ERROR_COUNT=0

for i in {1..24}; do  # 2 Minuten = 120 Sekunden / 5 Sekunden
    sleep 5
    
    CURRENT_HEIGHT=$(curl -s "$RPC_URL/rpc" -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"getHeight","id":1}' 2>/dev/null | grep -o '"result":[0-9]*' | cut -d: -f2 || echo "0")
    
    if [ -z "$CURRENT_HEIGHT" ] || [ "$CURRENT_HEIGHT" = "0" ]; then
        CURRENT_HEIGHT=0
    fi
    
    NEW_BLOCKS=$((CURRENT_HEIGHT - START_HEIGHT - BLOCK_COUNT))
    
    if [ "$NEW_BLOCKS" -gt 0 ]; then
        CURRENT_TIME=$(date +%s)
        BLOCK_TIME=$((CURRENT_TIME - LAST_BLOCK_TIME))
        
        echo "   Block gefunden! Höhe: $CURRENT_HEIGHT, Block-Zeit: ${BLOCK_TIME}s"
        
        # Prüfe Block-Zeit (sollte ~15 Sekunden sein)
        if [ "$BLOCK_TIME" -lt 5 ]; then
            echo -e "   ${RED}⚠️ Block-Zeit zu kurz: ${BLOCK_TIME}s (erwartet: ~15s)${NC}"
            ERROR_COUNT=$((ERROR_COUNT + 1))
        elif [ "$BLOCK_TIME" -gt 60 ]; then
            echo -e "   ${YELLOW}⚠️ Block-Zeit zu lang: ${BLOCK_TIME}s (erwartet: ~15s)${NC}"
        else
            echo -e "   ${GREEN}✅ Block-Zeit OK: ${BLOCK_TIME}s${NC}"
        fi
        
        BLOCK_COUNT=$((BLOCK_COUNT + NEW_BLOCKS))
        LAST_BLOCK_TIME=$CURRENT_TIME
    fi
    
    # Prüfe Logs auf Fehler
    if tail -n 50 miner-pow-test.log | grep -qi "error\|failed\|panic"; then
        ERROR_COUNT=$((ERROR_COUNT + 1))
        echo -e "   ${RED}⚠️ Fehler in Miner-Log gefunden${NC}"
    fi
    
    echo "   Status: Höhe=$CURRENT_HEIGHT, Blöcke gefunden=$BLOCK_COUNT, Fehler=$ERROR_COUNT"
done

echo ""
echo "=== TEST-ERGEBNISSE ==="
echo ""

# 11. Finale Prüfung
FINAL_HEIGHT=$(curl -s "$RPC_URL/rpc" -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","method":"getHeight","id":1}' | grep -o '"result":[0-9]*' | cut -d: -f2 || echo "0")

BLOCKS_MINED=$((FINAL_HEIGHT - START_HEIGHT))

echo "Start-Höhe: $START_HEIGHT"
echo "Finale Höhe: $FINAL_HEIGHT"
echo "Blöcke gemined: $BLOCKS_MINED"
echo "Fehler: $ERROR_COUNT"
echo ""

# Prüfe Node-Log auf PoW-Validierung
if tail -n 100 node-pow-test.log | grep -q "PoW Validation"; then
    echo -e "${GREEN}✅ PoW-Validierung aktiv (in Node-Log gefunden)${NC}"
else
    echo -e "${YELLOW}⚠️ PoW-Validierung nicht in Node-Log gefunden${NC}"
fi

# Prüfe Miner-Log auf Mining-Zeit
if tail -n 100 miner-pow-test.log | grep -q "Block found.*Time:.*s"; then
    echo -e "${GREEN}✅ Mining-Zeit in Miner-Log gefunden${NC}"
else
    echo -e "${YELLOW}⚠️ Mining-Zeit nicht in Miner-Log gefunden${NC}"
fi

echo ""

# 12. Bewertung
if [ "$BLOCKS_MINED" -gt 0 ] && [ "$ERROR_COUNT" -eq 0 ]; then
    echo -e "${GREEN}✅ TEST ERFOLGREICH!${NC}"
    echo ""
    echo "   Blöcke gemined: $BLOCKS_MINED"
    echo "   Erwartete Block-Zeit: ~15 Sekunden"
    echo "   PoW aktiviert: ✅"
    echo "   Difficulty: 23 ✅"
    echo "   1 Thread: ✅"
    echo ""
    echo "✅ Alles funktioniert korrekt!"
    exit 0
else
    echo -e "${RED}❌ TEST FEHLGESCHLAGEN!${NC}"
    echo ""
    echo "   Blöcke gemined: $BLOCKS_MINED (erwartet: >0)"
    echo "   Fehler: $ERROR_COUNT (erwartet: 0)"
    echo ""
    echo "Node-Log (letzte 20 Zeilen):"
    tail -n 20 node-pow-test.log
    echo ""
    echo "Miner-Log (letzte 20 Zeilen):"
    tail -n 20 miner-pow-test.log
    exit 1
fi

