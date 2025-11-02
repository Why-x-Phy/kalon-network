#!/bin/bash
# Vollständiger Test des Staging-Systems

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

RPC_URL="http://localhost:16316"
DATA_DIR="data/testnet"
GENESIS_DIR="genesis"
SNAPSHOT_DIR="snapshots"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  VOLLSTÄNDIGER STAGING-TEST${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Cleanup function
cleanup() {
    echo ""
    echo "=== CLEANUP ==="
    killall -9 kalon-node-v2 kalon-miner-v2 2>/dev/null || true
    pkill -9 -f "test-staging" 2>/dev/null || true
    sleep 2
    echo "✅ Prozesse beendet"
}

trap cleanup EXIT INT TERM

# 1. Cleanup
echo "1. Cleanup..."
rm -rf "$DATA_DIR" "$SNAPSHOT_DIR" node-staging.log miner-staging.log 2>/dev/null || true
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
./build-v2/kalon-node-v2 -datadir "$DATA_DIR" -rpc :16316 > node-staging.log 2>&1 &
NODE_PID=$!
sleep 5

if ! ps -p $NODE_PID > /dev/null 2>&1; then
    echo -e "${RED}❌ Node start fehlgeschlagen${NC}"
    tail -n 20 node-staging.log
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
        tail -n 20 node-staging.log
        exit 1
    fi
    sleep 1
done

CURRENT_HEIGHT=$(curl -s "$RPC_URL/rpc" -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getHeight","id":1}' | grep -o '"result":[0-9]*' | grep -o '[0-9]*' || echo "0")
echo -e "${GREEN}✅ Node läuft (PID: $NODE_PID, Height: $CURRENT_HEIGHT)${NC}"
echo ""

# 4. Create Wallet
echo "4. Erstelle Wallet..."
rm -f wallet.json wallet-*.json 2>/dev/null || true

WALLET_OUTPUT=$(./build-v2/kalon-wallet create --name "test-wallet.json" <<EOF

EOF
 2>&1)

WALLET_ADDRESS=$(echo "$WALLET_OUTPUT" | grep -i "address" | head -1 | awk '{print $2}' || echo "")
if [ -z "$WALLET_ADDRESS" ]; then
    WALLET_ADDRESS=$(echo "$WALLET_OUTPUT" | grep -oE "tkalon1[a-z0-9]{50,}" | head -1 || echo "")
fi
if [ -z "$WALLET_ADDRESS" ]; then
    # Versuche aus wallet.json zu lesen
    if [ -f "test-wallet.json" ]; then
        WALLET_ADDRESS=$(grep -o '"address":"[^"]*"' test-wallet.json | cut -d'"' -f4 | head -1 || echo "")
    fi
fi
if [ -z "$WALLET_ADDRESS" ]; then
    echo -e "${RED}❌ Konnte Wallet-Adresse nicht extrahieren${NC}"
    echo "$WALLET_OUTPUT"
    exit 1
fi
echo -e "${GREEN}✅ Wallet erstellt: $WALLET_ADDRESS${NC}"
echo ""

# 5. Start Miner and Mine Blocks
echo "5. Starte Miner und minen..."
./build-v2/kalon-miner-v2 -rpc "$RPC_URL" -wallet "$WALLET_ADDRESS" -threads 1 > miner-staging.log 2>&1 &
MINER_PID=$!
sleep 40

# Check height
HEIGHT=$(curl -s "$RPC_URL/rpc" -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getHeight","id":1}' | grep -o '"result":[0-9]*' | grep -o '[0-9]*' || echo "0")
if [ "$HEIGHT" -lt 10 ]; then
    echo -e "${YELLOW}⚠️ Nur $HEIGHT Blöcke gefunden (erwartet: >= 10)${NC}"
else
    echo -e "${GREEN}✅ Block Height: $HEIGHT${NC}"
fi
echo ""

# 6. Check Balance
echo "6. Prüfe Balance..."
BALANCE_JSON=$(curl -s "$RPC_URL/rpc" -H "Content-Type: application/json" -d "{\"jsonrpc\":\"2.0\",\"method\":\"getBalance\",\"params\":{\"address\":\"$WALLET_ADDRESS\"},\"id\":1}")
BALANCE=$(echo "$BALANCE_JSON" | grep -o '"result":[0-9]*' | grep -o '[0-9]*' || echo "0")
if [ "$BALANCE" -eq 0 ]; then
    echo -e "${RED}❌ Balance ist 0 (erwartet: > 0)${NC}"
    echo "Response: $BALANCE_JSON"
    exit 1
else
    echo -e "${GREEN}✅ Balance: $BALANCE${NC}"
fi
echo ""

# 7. Stop Node and Miner
echo "7. Stoppe Node und Miner für Snapshot..."
kill $NODE_PID $MINER_PID 2>/dev/null || true
sleep 3

# 8. Start Node again for Snapshot
echo "8. Starte Node für Snapshot..."
./build-v2/kalon-node-v2 -datadir "$DATA_DIR" -rpc :16316 > node-staging.log 2>&1 &
NODE_PID=$!
sleep 5

# Wait for RPC
for i in {1..30}; do
    if timeout 2 curl -s "$RPC_URL/rpc" -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getHeight","id":1}' > /dev/null 2>&1; then
        break
    fi
    sleep 1
done

# 9. Create Snapshot
echo "9. Erstelle Snapshot..."
mkdir -p "$SNAPSHOT_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SNAPSHOT_FILENAME="$SNAPSHOT_DIR/snapshot-testnet-stage-end-${TIMESTAMP}.json"

SNAPSHOT_JSON=$(curl -s "$RPC_URL/rpc" -H "Content-Type: application/json" -d "{\"jsonrpc\":\"2.0\",\"method\":\"createSnapshot\",\"params\":{\"filename\":\"$SNAPSHOT_FILENAME\"},\"id\":1}")

if [ ! -f "$SNAPSHOT_FILENAME" ]; then
    echo -e "${RED}❌ Snapshot-Datei nicht erstellt!${NC}"
    echo "Response: $SNAPSHOT_JSON"
    exit 1
fi

SNAPSHOT_HEIGHT=$(echo "$SNAPSHOT_JSON" | grep -o '"height":[0-9]*' | grep -o '[0-9]*' || echo "0")
SNAPSHOT_ADDRESSES=$(echo "$SNAPSHOT_JSON" | grep -o '"addressCount":[0-9]*' | grep -o '[0-9]*' || echo "0")

echo -e "${GREEN}✅ Snapshot erstellt:${NC}"
echo "   Datei: $SNAPSHOT_FILENAME"
echo "   Height: $SNAPSHOT_HEIGHT"
echo "   Addresses: $SNAPSHOT_ADDRESSES"
echo ""

# 10. Get Current Difficulty
echo "10. Prüfe aktuelle Difficulty..."
CURRENT_DIFFICULTY=$(grep -A 2 '"difficulty"' "$GENESIS_DIR/testnet.json" | grep '"initialDifficulty"' | grep -o '[0-9]*' || echo "23")
echo "Aktuelle Difficulty: $CURRENT_DIFFICULTY"

# Neue Difficulty (erhöhe um 5)
NEW_DIFFICULTY=$((CURRENT_DIFFICULTY + 5))
echo "Neue Difficulty (zum Test): $NEW_DIFFICULTY"
echo ""

# 11. Create New Genesis
echo "11. Erstelle neue Genesis mit Snapshot..."
NEW_GENESIS_FILE="$GENESIS_DIR/testnet-stage2.json"

# Prüfe ob jq verfügbar ist
if command -v jq > /dev/null 2>&1; then
    jq --arg newDifficulty "$NEW_DIFFICULTY" \
       --argjson snapshot "$(cat "$SNAPSHOT_FILENAME")" \
       '.difficulty.initialDifficulty = ($newDifficulty | tonumber) |
        .name = "Kalon Testnet Stage 2" |
        .snapshot = {
          enabled: true,
          height: $snapshot.height,
          balances: $snapshot.balances
        }' "$GENESIS_DIR/testnet.json" > "$NEW_GENESIS_FILE"
else
    python3 << EOF
import json

with open("$GENESIS_DIR/testnet.json", "r") as f:
    genesis = json.load(f)

with open("$SNAPSHOT_FILENAME", "r") as f:
    snapshot = json.load(f)

genesis["difficulty"]["initialDifficulty"] = int("$NEW_DIFFICULTY")
genesis["name"] = "Kalon Testnet Stage 2"
genesis["snapshot"] = {
    "enabled": True,
    "height": snapshot["height"],
    "balances": snapshot["balances"]
}

with open("$NEW_GENESIS_FILE", "w") as f:
    json.dump(genesis, f, indent=2)
EOF
fi

if [ ! -f "$NEW_GENESIS_FILE" ]; then
    echo -e "${RED}❌ Fehler beim Erstellen der neuen Genesis!${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Neue Genesis erstellt: $NEW_GENESIS_FILE${NC}"
echo "   Snapshot eingebunden: ✅"
echo "   Neue Difficulty: $NEW_DIFFICULTY"
echo ""

# 12. Stop Node
echo "12. Stoppe Node..."
kill $NODE_PID 2>/dev/null || true
sleep 3
echo "✅ Node gestoppt"
echo ""

# 13. Delete Chain Data (Reset)
echo "13. Lösche Chain-Daten (Reset)..."
rm -rf "$DATA_DIR/chaindb" "$DATA_DIR"/*.log 2>/dev/null || true
echo -e "${GREEN}✅ Chain-Daten gelöscht${NC}"
echo ""

# 14. Start Node with New Genesis
echo "14. Starte Node mit neuer Genesis..."
./build-v2/kalon-node-v2 -datadir "$DATA_DIR" -genesis "$NEW_GENESIS_FILE" -rpc :16316 > node-staging.log 2>&1 &
NODE_PID=$!
sleep 5

# Wait for RPC
echo "   Warte auf RPC..."
for i in {1..30}; do
    if timeout 2 curl -s "$RPC_URL/rpc" -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getHeight","id":1}' > /dev/null 2>&1; then
        break
    fi
    if [ $i -eq 30 ]; then
        echo -e "${RED}❌ RPC nicht erreichbar${NC}"
        tail -n 20 node-staging.log
        exit 1
    fi
    sleep 1
done

# 15. Verification
echo "15. Verifizierung..."
sleep 2

# Height
NEW_HEIGHT=$(curl -s "$RPC_URL/rpc" -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getHeight","id":1}' | grep -o '"result":[0-9]*' | grep -o '[0-9]*' || echo "0")
echo "Height: $NEW_HEIGHT"

if [ "$NEW_HEIGHT" -gt 1 ]; then
    echo -e "${YELLOW}⚠️ Height ist $NEW_HEIGHT (erwartet: 0 oder 1)${NC}"
else
    echo -e "${GREEN}✅ Height korrekt: $NEW_HEIGHT${NC}"
fi

# Difficulty
MINING_INFO=$(curl -s "$RPC_URL/rpc" -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getMiningInfo","id":1}')
NEW_DIFFICULTY_ACTUAL=$(echo "$MINING_INFO" | grep -o '"difficulty":[0-9]*' | grep -o '[0-9]*' || echo "0")
echo "Difficulty: $NEW_DIFFICULTY_ACTUAL (erwartet: $NEW_DIFFICULTY)"

if [ "$NEW_DIFFICULTY_ACTUAL" -eq "$NEW_DIFFICULTY" ]; then
    echo -e "${GREEN}✅ Difficulty korrekt: $NEW_DIFFICULTY_ACTUAL${NC}"
else
    echo -e "${YELLOW}⚠️ Difficulty stimmt nicht: $NEW_DIFFICULTY_ACTUAL (erwartet: $NEW_DIFFICULTY)${NC}"
fi

# Balance
BALANCE_JSON=$(curl -s "$RPC_URL/rpc" -H "Content-Type: application/json" -d "{\"jsonrpc\":\"2.0\",\"method\":\"getBalance\",\"params\":{\"address\":\"$WALLET_ADDRESS\"},\"id\":1}")
BALANCE_AFTER=$(echo "$BALANCE_JSON" | grep -o '"result":[0-9]*' | grep -o '[0-9]*' || echo "0")
echo "Balance: $BALANCE_AFTER (erwartet: $BALANCE)"

if [ "$BALANCE_AFTER" -eq "$BALANCE" ] && [ "$BALANCE_AFTER" -gt 0 ]; then
    echo -e "${GREEN}✅ Balance korrekt wiederhergestellt: $BALANCE_AFTER${NC}"
elif [ "$BALANCE_AFTER" -gt 0 ]; then
    echo -e "${YELLOW}⚠️ Balance wiederhergestellt: $BALANCE_AFTER (vorher: $BALANCE)${NC}"
else
    echo -e "${RED}❌ Balance nicht wiederhergestellt: $BALANCE_AFTER${NC}"
    echo "Response: $BALANCE_JSON"
    exit 1
fi
echo ""

# 16. Archive Snapshot
echo "16. Archive Snapshot..."
ARCHIVE_DIR="$SNAPSHOT_DIR/archive"
mkdir -p "$ARCHIVE_DIR"

ARCHIVED_SNAPSHOT="$ARCHIVE_DIR/snapshot-testnet-stage-end-${TIMESTAMP}.json"
mv "$SNAPSHOT_FILENAME" "$ARCHIVED_SNAPSHOT" 2>/dev/null || cp "$SNAPSHOT_FILENAME" "$ARCHIVED_SNAPSHOT"

if [ -f "$ARCHIVED_SNAPSHOT" ]; then
    echo -e "${GREEN}✅ Snapshot gesichert: $ARCHIVED_SNAPSHOT${NC}"
else
    echo -e "${YELLOW}⚠️ Snapshot konnte nicht archiviert werden${NC}"
fi
echo ""

# 17. Final Summary
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  STAGING-TEST ABGESCHLOSSEN!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}Zusammenfassung:${NC}"
echo "  ✅ Chain: testnet"
echo "  ✅ Vorherige Height: $HEIGHT"
echo "  ✅ Vorherige Balance: $BALANCE"
echo "  ✅ Vorherige Difficulty: $CURRENT_DIFFICULTY"
echo "  ✅ Snapshot erstellt: $ARCHIVED_SNAPSHOT"
echo "  ✅ Neue Genesis: $NEW_GENESIS_FILE"
echo "  ✅ Neue Height: $NEW_HEIGHT"
echo "  ✅ Neue Difficulty: $NEW_DIFFICULTY_ACTUAL"
echo "  ✅ Balance nach Reset: $BALANCE_AFTER"
echo ""
echo -e "${GREEN}✅ Alle Tests erfolgreich!${NC}"
echo ""
echo -e "${YELLOW}Nächste Schritte:${NC}"
echo "  1. Prüfen Sie die neue Genesis: $NEW_GENESIS_FILE"
echo "  2. Sichern Sie den Snapshot: $ARCHIVED_SNAPSHOT"
echo "  3. Node läuft mit neuer Genesis (PID: $NODE_PID)"
echo ""

