#!/bin/bash
# Comprehensive Snapshot System Test

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

RPC_URL="http://localhost:16316"
NODE_LOG="node-snapshot-test.log"
MINER_LOG="miner-snapshot-test.log"
SNAPSHOT_FILE="snapshot-test.json"

echo -e "${GREEN}=== SNAPSHOT SYSTEM TEST ===${NC}"
echo ""

# Cleanup function
cleanup() {
    echo ""
    echo "=== CLEANUP ==="
    killall -9 kalon-node-v2 kalon-miner-v2 2>/dev/null || true
    pkill -9 -f "test-snapshot" 2>/dev/null || true
    sleep 2
    echo "✅ Prozesse beendet"
}

trap cleanup EXIT INT TERM

# 1. Cleanup
echo "1. Cleanup..."
rm -rf data/testnet snapshot-test.json 2>/dev/null || true
killall -9 kalon-node-v2 kalon-miner-v2 2>/dev/null || true
sleep 2
echo "✅ Cleanup abgeschlossen"
echo ""

# 2. Build
echo "2. Build..."
go build -o build-v2/kalon-node-v2 ./cmd/kalon-node-v2 || {
    echo -e "${RED}❌ Node Build fehlgeschlagen${NC}"
    exit 1
}
go build -o build-v2/kalon-miner-v2 ./cmd/kalon-miner-v2 || {
    echo -e "${RED}❌ Miner Build fehlgeschlagen${NC}"
    exit 1
}
go build -o build-v2/kalon-wallet ./cmd/kalon-wallet || {
    echo -e "${RED}❌ Wallet Build fehlgeschlagen${NC}"
    exit 1
}
chmod +x build-v2/kalon-node-v2 build-v2/kalon-miner-v2 build-v2/kalon-wallet
echo "✅ Build abgeschlossen"
echo ""

# 3. Start Node
echo "3. Starte Node..."
./build-v2/kalon-node-v2 -datadir data/testnet -rpc :16316 > "$NODE_LOG" 2>&1 &
NODE_PID=$!
sleep 5

if ! ps -p $NODE_PID > /dev/null 2>&1; then
    echo -e "${RED}❌ Node start fehlgeschlagen${NC}"
    tail -n 20 "$NODE_LOG"
    exit 1
fi

# Wait for RPC
echo "   Warte auf RPC..."
for i in {1..30}; do
    if timeout 2 curl -s "$RPC_URL/rpc" -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getHeight","id":1}' > /dev/null 2>&1; then
        break
    fi
    if [ $i -eq 30 ]; then
        echo -e "${RED}❌ RPC nicht erreichbar${NC}"
        tail -n 20 "$NODE_LOG"
        exit 1
    fi
    sleep 1
done
echo "✅ Node läuft (PID: $NODE_PID)"
echo ""

# 4. Create Wallet and Get Address
echo "4. Erstelle Wallet..."
WALLET_OUTPUT=$(echo -e "\n\n" | ./build-v2/kalon-wallet create 2>&1 | head -20)
WALLET_ADDRESS=$(echo "$WALLET_OUTPUT" | grep -i "address" | head -1 | awk '{print $2}' || echo "")
if [ -z "$WALLET_ADDRESS" ]; then
    WALLET_ADDRESS=$(echo "$WALLET_OUTPUT" | grep -oE "tkalon1[a-z0-9]{50,}" | head -1 || echo "")
fi
if [ -z "$WALLET_ADDRESS" ]; then
    echo -e "${YELLOW}⚠️ Konnte Wallet-Adresse nicht automatisch extrahieren${NC}"
    echo "Bitte manuell eingeben:"
    read -p "Wallet-Adresse: " WALLET_ADDRESS
fi
echo "✅ Wallet erstellt: $WALLET_ADDRESS"
echo ""

# 5. Start Miner and Mine Blocks
echo "5. Starte Miner und minen..."
./build-v2/kalon-miner-v2 -rpc "$RPC_URL" -wallet "$WALLET_ADDRESS" -threads 1 > "$MINER_LOG" 2>&1 &
MINER_PID=$!
sleep 30

# Check if blocks were mined
HEIGHT=$(curl -s "$RPC_URL/rpc" -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getHeight","id":1}' | grep -o '"result":[0-9]*' | grep -o '[0-9]*' || echo "0")
if [ "$HEIGHT" -lt 5 ]; then
    echo -e "${YELLOW}⚠️ Nur $HEIGHT Blöcke gefunden (erwartet: >= 5)${NC}"
    tail -n 10 "$MINER_LOG"
else
    echo "✅ Block Height: $HEIGHT"
fi
echo ""

# 6. Check Balance
echo "6. Prüfe Balance..."
BALANCE_JSON=$(curl -s "$RPC_URL/rpc" -H "Content-Type: application/json" -d "{\"jsonrpc\":\"2.0\",\"method\":\"getBalance\",\"params\":{\"address\":\"$WALLET_ADDRESS\"},\"id\":1}")
BALANCE=$(echo "$BALANCE_JSON" | grep -o '"result":[0-9]*' | grep -o '[0-9]*' || echo "0")
if [ "$BALANCE" -eq 0 ]; then
    echo -e "${RED}❌ Balance ist 0 (erwartet: > 0)${NC}"
    echo "Response: $BALANCE_JSON"
else
    echo "✅ Balance: $BALANCE"
fi
echo ""

# 7. Create Snapshot
echo "7. Erstelle Snapshot..."
SNAPSHOT_JSON=$(curl -s "$RPC_URL/rpc" -H "Content-Type: application/json" -d "{\"jsonrpc\":\"2.0\",\"method\":\"createSnapshot\",\"params\":{\"filename\":\"$SNAPSHOT_FILE\"},\"id\":1}")
SNAPSHOT_HEIGHT=$(echo "$SNAPSHOT_JSON" | grep -o '"height":[0-9]*' | grep -o '[0-9]*' || echo "0")
SNAPSHOT_ADDRESS_COUNT=$(echo "$SNAPSHOT_JSON" | grep -o '"addressCount":[0-9]*' | grep -o '[0-9]*' || echo "0")

if [ ! -f "$SNAPSHOT_FILE" ]; then
    echo -e "${RED}❌ Snapshot-Datei nicht erstellt${NC}"
    echo "Response: $SNAPSHOT_JSON"
    exit 1
fi

if [ "$SNAPSHOT_HEIGHT" -eq 0 ]; then
    echo -e "${RED}❌ Snapshot-Erstellung fehlgeschlagen${NC}"
    echo "Response: $SNAPSHOT_JSON"
    exit 1
fi

echo "✅ Snapshot erstellt:"
echo "   Height: $SNAPSHOT_HEIGHT"
echo "   Addresses: $SNAPSHOT_ADDRESS_COUNT"
echo "   File: $SNAPSHOT_FILE"
echo ""

# 8. Stop Node and Miner
echo "8. Stoppe Node und Miner..."
kill $NODE_PID $MINER_PID 2>/dev/null || true
sleep 3
echo "✅ Gestoppt"
echo ""

# 9. Delete Chain Data (Simulate Reset)
echo "9. Lösche Chain-Daten (Simuliere Reset)..."
rm -rf data/testnet 2>/dev/null || true
sleep 2
echo "✅ Chain-Daten gelöscht"
echo ""

# 10. Restart Node (Should restore from snapshot in genesis)
echo "10. Starte Node neu (sollte Snapshot aus Genesis laden)..."
# First, we need to create a new genesis with snapshot
# For now, we'll just test restoreSnapshot via RPC after node starts

./build-v2/kalon-node-v2 -datadir data/testnet -rpc :16316 > "$NODE_LOG" 2>&1 &
NODE_PID=$!
sleep 5

# Wait for RPC
for i in {1..30}; do
    if timeout 2 curl -s "$RPC_URL/rpc" -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getHeight","id":1}' > /dev/null 2>&1; then
        break
    fi
    sleep 1
done

# 11. Restore Snapshot
echo "11. Stelle Snapshot wieder her..."
RESTORE_JSON=$(curl -s "$RPC_URL/rpc" -H "Content-Type: application/json" -d "{\"jsonrpc\":\"2.0\",\"method\":\"restoreSnapshot\",\"params\":{\"filename\":\"$SNAPSHOT_FILE\"},\"id\":1}")
RESTORED=$(echo "$RESTORE_JSON" | grep -o '"restored":true' || echo "")

if [ -z "$RESTORED" ]; then
    echo -e "${RED}❌ Snapshot-Wiederherstellung fehlgeschlagen${NC}"
    echo "Response: $RESTORE_JSON"
    exit 1
fi

echo "✅ Snapshot wiederhergestellt"
echo ""

# 12. Check Balance After Restore
echo "12. Prüfe Balance nach Wiederherstellung..."
BALANCE_JSON=$(curl -s "$RPC_URL/rpc" -H "Content-Type: application/json" -d "{\"jsonrpc\":\"2.0\",\"method\":\"getBalance\",\"params\":{\"address\":\"$WALLET_ADDRESS\"},\"id\":1}")
BALANCE_AFTER=$(echo "$BALANCE_JSON" | grep -o '"result":[0-9]*' | grep -o '[0-9]*' || echo "0")

if [ "$BALANCE_AFTER" -eq 0 ]; then
    echo -e "${RED}❌ Balance nach Wiederherstellung ist 0 (erwartet: $BALANCE)${NC}"
    echo "Response: $BALANCE_JSON"
    exit 1
fi

if [ "$BALANCE_AFTER" -ne "$BALANCE" ]; then
    echo -e "${YELLOW}⚠️ Balance stimmt nicht überein: Vorher: $BALANCE, Nachher: $BALANCE_AFTER${NC}"
else
    echo "✅ Balance korrekt wiederhergestellt: $BALANCE_AFTER"
fi
echo ""

# 13. Final Summary
echo -e "${GREEN}=== TEST ABGESCHLOSSEN ===${NC}"
echo "✅ Snapshot-Erstellung: Erfolgreich"
echo "✅ Snapshot-Wiederherstellung: Erfolgreich"
echo "✅ Balance-Wiederherstellung: $([ "$BALANCE_AFTER" -eq "$BALANCE" ] && echo "Erfolgreich" || echo "Unterschiedlich")"
echo ""
echo "Snapshot-Datei: $SNAPSHOT_FILE"
echo "Vorherige Balance: $BALANCE"
echo "Wiederhergestellte Balance: $BALANCE_AFTER"

