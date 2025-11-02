#!/bin/bash
# Interaktives Staging-Script für Mainnet/Testnet Chain-Reset mit Difficulty-Änderung

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

RPC_URL="http://localhost:16316"
GENESIS_DIR="genesis"
DATA_DIR="data/mainnet"
SNAPSHOT_DIR="snapshots"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  KALON STAGING: CHAIN-RESET TOOL${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 1. Abfrage: Welche Chain?
echo -e "${YELLOW}=== SCHRITT 1: CHAIN AUSWÄHLEN ===${NC}"
echo ""
echo "Welche Chain soll zurückgesetzt werden?"
echo "  1) Mainnet"
echo "  2) Testnet"
echo "  3) Community Testnet"
read -p "Wahl (1-3): " CHAIN_CHOICE

case $CHAIN_CHOICE in
    1)
        CHAIN_NAME="mainnet"
        GENESIS_FILE="$GENESIS_DIR/mainnet.json"
        DATA_DIR="data/mainnet"
        ;;
    2)
        CHAIN_NAME="testnet"
        GENESIS_FILE="$GENESIS_DIR/testnet.json"
        DATA_DIR="data/testnet"
        ;;
    3)
        CHAIN_NAME="community-testnet"
        GENESIS_FILE="$GENESIS_DIR/community-testnet.json"
        DATA_DIR="data-community-testnet"
        ;;
    *)
        echo -e "${RED}❌ Ungültige Wahl!${NC}"
        exit 1
        ;;
esac

echo -e "${GREEN}✅ Chain ausgewählt: $CHAIN_NAME${NC}"
echo ""

# 2. Prüfe ob Node läuft
echo -e "${YELLOW}=== SCHRITT 2: NODE-STATUS PRÜFEN ===${NC}"
echo ""

if pgrep -f "kalon-node-v2" > /dev/null; then
    NODE_PID=$(pgrep -f "kalon-node-v2" | head -1)
    echo -e "${GREEN}✅ Node läuft (PID: $NODE_PID)${NC}"
    
    # Prüfe RPC
    if curl -s "$RPC_URL/rpc" -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getHeight","id":1}' > /dev/null 2>&1; then
        CURRENT_HEIGHT=$(curl -s "$RPC_URL/rpc" -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getHeight","id":1}' | grep -o '"result":[0-9]*' | grep -o '[0-9]*' || echo "0")
        echo -e "${GREEN}✅ RPC erreichbar (Height: $CURRENT_HEIGHT)${NC}"
    else
        echo -e "${YELLOW}⚠️ RPC nicht erreichbar, aber Node läuft${NC}"
        CURRENT_HEIGHT="?"
    fi
else
    echo -e "${RED}❌ Node läuft nicht!${NC}"
    echo "Bitte Node zuerst starten und dann dieses Script erneut ausführen."
    exit 1
fi
echo ""

# 3. Prüfe ob Miner läuft
echo -e "${YELLOW}=== SCHRITT 3: MINER-STATUS PRÜFEN ===${NC}"
echo ""

if pgrep -f "kalon-miner-v2" > /dev/null; then
    MINER_PID=$(pgrep -f "kalon-miner-v2" | head -1)
    echo -e "${YELLOW}⚠️ Miner läuft (PID: $MINER_PID)${NC}"
    echo "Miner wird automatisch gestoppt."
else
    echo -e "${GREEN}✅ Miner läuft nicht${NC}"
fi
echo ""

# 4. Bestätigung
echo -e "${RED}⚠️  WICHTIGER HINWEIS ⚠️${NC}"
echo "Dieses Script wird:"
echo "  1. Node und Miner stoppen"
echo "  2. Snapshot erstellen"
echo "  3. Chain-Daten löschen (RESET!)"
echo "  4. Neue Genesis erstellen"
echo "  5. Node mit neuer Genesis starten"
echo ""
echo -e "${RED}Aktuelle Chain: $CHAIN_NAME${NC}"
echo -e "${RED}Aktuelle Height: $CURRENT_HEIGHT${NC}"
echo ""
read -p "Fortfahren? (ja/nein): " CONFIRM

if [ "$CONFIRM" != "ja" ] && [ "$CONFIRM" != "Ja" ] && [ "$CONFIRM" != "JA" ]; then
    echo "Abgebrochen."
    exit 0
fi
echo ""

# 5. Stoppe Node und Miner
echo -e "${YELLOW}=== SCHRITT 4: NODE UND MINER STOPPEN ===${NC}"
echo ""

killall -9 kalon-node-v2 kalon-miner-v2 2>/dev/null || true
sleep 3

if pgrep -f "kalon-node-v2\|kalon-miner-v2" > /dev/null; then
    echo -e "${RED}❌ Prozesse laufen noch!${NC}"
    echo "Bitte manuell beenden."
    exit 1
fi

echo -e "${GREEN}✅ Node und Miner gestoppt${NC}"
echo ""

# 6. Starte Node kurz für Snapshot
echo -e "${YELLOW}=== SCHRITT 5: NODE FÜR SNAPSHOT STARTEN ===${NC}"
echo ""

# Starte Node im Hintergrund
./build-v2/kalon-node-v2 -datadir "$DATA_DIR" -rpc :16316 > node-staging-temp.log 2>&1 &
NODE_PID=$!
sleep 5

# Warte auf RPC
echo "   Warte auf RPC..."
for i in {1..30}; do
    if timeout 2 curl -s "$RPC_URL/rpc" -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getHeight","id":1}' > /dev/null 2>&1; then
        break
    fi
    if [ $i -eq 30 ]; then
        echo -e "${RED}❌ RPC nicht erreichbar${NC}"
        kill $NODE_PID 2>/dev/null || true
        exit 1
    fi
    sleep 1
done

CURRENT_HEIGHT=$(curl -s "$RPC_URL/rpc" -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getHeight","id":1}' | grep -o '"result":[0-9]*' | grep -o '[0-9]*' || echo "0")
echo -e "${GREEN}✅ Node läuft (Height: $CURRENT_HEIGHT)${NC}"
echo ""

# 7. Erstelle Snapshot
echo -e "${YELLOW}=== SCHRITT 6: SNAPSHOT ERSTELLEN ===${NC}"
echo ""

# Erstelle Snapshot-Verzeichnis
mkdir -p "$SNAPSHOT_DIR"

# Timestamp für Snapshot-Dateiname
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SNAPSHOT_FILENAME="$SNAPSHOT_DIR/snapshot-${CHAIN_NAME}-stage-end-${TIMESTAMP}.json"

echo "Erstelle Snapshot..."
SNAPSHOT_JSON=$(curl -s "$RPC_URL/rpc" -H "Content-Type: application/json" -d "{\"jsonrpc\":\"2.0\",\"method\":\"createSnapshot\",\"params\":{\"filename\":\"$SNAPSHOT_FILENAME\"},\"id\":1}")

# Prüfe ob Snapshot erstellt wurde
if [ ! -f "$SNAPSHOT_FILENAME" ]; then
    echo -e "${RED}❌ Snapshot-Datei nicht erstellt!${NC}"
    echo "Response: $SNAPSHOT_JSON"
    kill $NODE_PID 2>/dev/null || true
    exit 1
fi

SNAPSHOT_HEIGHT=$(echo "$SNAPSHOT_JSON" | grep -o '"height":[0-9]*' | grep -o '[0-9]*' || echo "0")
SNAPSHOT_ADDRESSES=$(echo "$SNAPSHOT_JSON" | grep -o '"addressCount":[0-9]*' | grep -o '[0-9]*' || echo "0")
SNAPSHOT_SUPPLY=$(echo "$SNAPSHOT_JSON" | grep -o '"totalSupply":[0-9]*' | grep -o '[0-9]*' || echo "0")

echo -e "${GREEN}✅ Snapshot erstellt:${NC}"
echo "   Datei: $SNAPSHOT_FILENAME"
echo "   Height: $SNAPSHOT_HEIGHT"
echo "   Addresses: $SNAPSHOT_ADDRESSES"
echo "   Total Supply: $SNAPSHOT_SUPPLY"
echo ""

# 8. Node wieder stoppen
echo -e "${YELLOW}=== SCHRITT 7: NODE STOPPEN ===${NC}"
echo ""

kill $NODE_PID 2>/dev/null || true
sleep 2
echo -e "${GREEN}✅ Node gestoppt${NC}"
echo ""

# 9. Neue Difficulty abfragen
echo -e "${YELLOW}=== SCHRITT 8: NEUE DIFFICULTY EINGEBEN ===${NC}"
echo ""

# Lade aktuelle Difficulty aus Genesis
CURRENT_DIFFICULTY=$(grep -A 2 '"difficulty"' "$GENESIS_FILE" | grep '"initialDifficulty"' | grep -o '[0-9]*' || echo "23")
echo "Aktuelle Difficulty: $CURRENT_DIFFICULTY"
read -p "Neue Difficulty eingeben: " NEW_DIFFICULTY

if ! [[ "$NEW_DIFFICULTY" =~ ^[0-9]+$ ]] || [ "$NEW_DIFFICULTY" -lt 1 ]; then
    echo -e "${RED}❌ Ungültige Difficulty! Muss eine positive Zahl sein.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Neue Difficulty: $NEW_DIFFICULTY${NC}"
echo ""

# 10. Neue Genesis-Datei erstellen
echo -e "${YELLOW}=== SCHRITT 9: NEUE GENESIS ERSTELLEN ===${NC}"
echo ""

# Lade Snapshot-Daten
SNAPSHOT_DATA=$(cat "$SNAPSHOT_FILENAME")

# Extrahiere Balances aus Snapshot
SNAPSHOT_BALANCES=$(echo "$SNAPSHOT_DATA" | grep -A 1000 '"balances"' | head -1001 | grep -v '"totalSupply"' | grep -v '"chainId"' | grep -v '"timestamp"' | grep -v '"blockHash"' | head -n -1 || echo "")

# Neue Genesis-Datei generieren
NEW_GENESIS_FILE="$GENESIS_DIR/${CHAIN_NAME}-stage2.json"

echo "Erstelle neue Genesis-Datei..."

# Prüfe ob jq verfügbar ist
if command -v jq > /dev/null 2>&1; then
    # Verwende jq für JSON-Verarbeitung
    jq --arg newDifficulty "$NEW_DIFFICULTY" \
       --arg chainName "${CHAIN_NAME^} Stage 2" \
       --argjson snapshot "$(cat "$SNAPSHOT_FILENAME")" \
       '.difficulty.initialDifficulty = ($newDifficulty | tonumber) |
        .name = $chainName |
        .snapshot = {
          enabled: true,
          height: $snapshot.height,
          balances: $snapshot.balances
        }' "$GENESIS_FILE" > "$NEW_GENESIS_FILE"
else
    # Fallback: Verwende Python
    python3 << EOF
import json
import sys

# Lade aktuelle Genesis
with open("$GENESIS_FILE", "r") as f:
    genesis = json.load(f)

# Lade Snapshot
with open("$SNAPSHOT_FILENAME", "r") as f:
    snapshot = json.load(f)

# Update Difficulty
genesis["difficulty"]["initialDifficulty"] = int("$NEW_DIFFICULTY")

# Füge Snapshot hinzu
genesis["snapshot"] = {
    "enabled": True,
    "height": snapshot["height"],
    "balances": snapshot["balances"]
}

# Update Chain Name
genesis["name"] = "${CHAIN_NAME^} Stage 2"

# Speichere neue Genesis
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

# 11. Chain-Daten löschen
echo -e "${YELLOW}=== SCHRITT 10: CHAIN-DATEN LÖSCHEN (RESET) ===${NC}"
echo ""

read -p "Chain-Daten löschen und zurücksetzen? (ja/nein): " RESET_CONFIRM

if [ "$RESET_CONFIRM" != "ja" ] && [ "$RESET_CONFIRM" != "Ja" ] && [ "$RESET_CONFIRM" != "JA" ]; then
    echo "Abgebrochen. Chain-Daten bleiben erhalten."
    echo "Sie können die neue Genesis manuell verwenden."
    exit 0
fi

echo "Lösche Chain-Daten..."
rm -rf "$DATA_DIR/chaindb" "$DATA_DIR/utxodb" "$DATA_DIR"/*.log 2>/dev/null || true
echo -e "${GREEN}✅ Chain-Daten gelöscht${NC}"
echo ""

# 12. Finale Bestätigung
echo -e "${RED}=== FINALE BESTÄTIGUNG ===${NC}"
echo ""
echo "Es wird jetzt:"
echo "  ✅ Node mit neuer Genesis starten ($NEW_GENESIS_FILE)"
echo "  ✅ Snapshot wird automatisch geladen"
echo "  ✅ Balances werden wiederhergestellt"
echo "  ✅ Neue Difficulty: $NEW_DIFFICULTY"
echo "  ✅ Chain startet bei Height 0"
echo ""
echo -e "${BLUE}Snapshot-Datei: $SNAPSHOT_FILENAME${NC}"
echo -e "${BLUE}Neue Genesis: $NEW_GENESIS_FILE${NC}"
echo ""
read -p "Node mit neuer Genesis starten? (ja/nein): " START_CONFIRM

if [ "$START_CONFIRM" != "ja" ] && [ "$START_CONFIRM" != "Ja" ] && [ "$START_CONFIRM" != "JA" ]; then
    echo "Abgebrochen."
    echo ""
    echo "Sie können später manuell starten mit:"
    echo "  ./build-v2/kalon-node-v2 -datadir $DATA_DIR -genesis $NEW_GENESIS_FILE -rpc :16316"
    exit 0
fi
echo ""

# 13. Node mit neuer Genesis starten
echo -e "${YELLOW}=== SCHRITT 11: NODE MIT NEUER GENESIS STARTEN ===${NC}"
echo ""

# Backup der alten Genesis
BACKUP_GENESIS="${GENESIS_FILE}.backup-${TIMESTAMP}"
cp "$GENESIS_FILE" "$BACKUP_GENESIS"
echo -e "${GREEN}✅ Backup der alten Genesis: $BACKUP_GENESIS${NC}"
echo ""

# Verwende neue Genesis-Datei direkt
# Node unterstützt -genesis Flag (siehe cmd/kalon-node-v2/main.go:39)

echo "Starte Node mit neuer Genesis..."
./build-v2/kalon-node-v2 -datadir "$DATA_DIR" -genesis "$NEW_GENESIS_FILE" -rpc :16316 > node-staging.log 2>&1 &
NODE_PID=$!
sleep 5

# Warte auf RPC
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

# 14. Verifizierung
echo -e "${YELLOW}=== SCHRITT 12: VERIFIZIERUNG ===${NC}"
echo ""

sleep 2

# Prüfe Height
NEW_HEIGHT=$(curl -s "$RPC_URL/rpc" -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getHeight","id":1}' | grep -o '"result":[0-9]*' | grep -o '[0-9]*' || echo "0")
echo "Height: $NEW_HEIGHT"

# Prüfe Difficulty
MINING_INFO=$(curl -s "$RPC_URL/rpc" -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getMiningInfo","id":1}')
NEW_DIFFICULTY_ACTUAL=$(echo "$MINING_INFO" | grep -o '"difficulty":[0-9]*' | grep -o '[0-9]*' || echo "0")
echo "Difficulty: $NEW_DIFFICULTY_ACTUAL"

# Prüfe Balance (erste Adresse aus Snapshot)
FIRST_ADDRESS=$(echo "$SNAPSHOT_DATA" | grep -o '"balances"[^}]*' | grep -o '"[a-f0-9]\{40\}"' | head -1 | tr -d '"' || echo "")
if [ ! -z "$FIRST_ADDRESS" ]; then
    BALANCE_JSON=$(curl -s "$RPC_URL/rpc" -H "Content-Type: application/json" -d "{\"jsonrpc\":\"2.0\",\"method\":\"getBalance\",\"params\":{\"address\":\"$FIRST_ADDRESS\"},\"id\":1}")
    BALANCE_AFTER=$(echo "$BALANCE_JSON" | grep -o '"result":[0-9]*' | grep -o '[0-9]*' || echo "0")
    EXPECTED_BALANCE=$(echo "$SNAPSHOT_DATA" | grep -o "\"$FIRST_ADDRESS\":[0-9]*" | grep -o '[0-9]*' || echo "0")
    
    if [ "$BALANCE_AFTER" -eq "$EXPECTED_BALANCE" ] && [ "$BALANCE_AFTER" -gt 0 ]; then
        echo -e "${GREEN}✅ Balance wiederhergestellt: $BALANCE_AFTER (erwartet: $EXPECTED_BALANCE)${NC}"
    else
        echo -e "${YELLOW}⚠️ Balance: $BALANCE_AFTER (erwartet: $EXPECTED_BALANCE)${NC}"
    fi
fi

echo ""

# 15. Snapshot sichern
echo -e "${YELLOW}=== SCHRITT 13: SNAPSHOT SICHERN ===${NC}"
echo ""

# Verschiebe Snapshot in Backup-Verzeichnis
ARCHIVE_DIR="$SNAPSHOT_DIR/archive"
mkdir -p "$ARCHIVE_DIR"

ARCHIVED_SNAPSHOT="$ARCHIVE_DIR/snapshot-${CHAIN_NAME}-stage-end-${TIMESTAMP}.json"
mv "$SNAPSHOT_FILENAME" "$ARCHIVED_SNAPSHOT" 2>/dev/null || cp "$SNAPSHOT_FILENAME" "$ARCHIVED_SNAPSHOT"

echo -e "${GREEN}✅ Snapshot gesichert:${NC}"
echo "   Original: $SNAPSHOT_FILENAME"
echo "   Archiv: $ARCHIVED_SNAPSHOT"
echo ""
echo -e "${YELLOW}⚠️ WICHTIG: Sichern Sie diese Datei an einem sicheren Ort!${NC}"
echo ""

# 16. Zusammenfassung
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  STAGING ABGESCHLOSSEN!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}Zusammenfassung:${NC}"
echo "  ✅ Chain: $CHAIN_NAME"
echo "  ✅ Vorherige Height: $CURRENT_HEIGHT"
echo "  ✅ Neue Height: $NEW_HEIGHT"
echo "  ✅ Vorherige Difficulty: $CURRENT_DIFFICULTY"
echo "  ✅ Neue Difficulty: $NEW_DIFFICULTY_ACTUAL"
echo "  ✅ Snapshot: $ARCHIVED_SNAPSHOT"
echo "  ✅ Neue Genesis: $NEW_GENESIS_FILE"
echo "  ✅ Node läuft: PID $NODE_PID"
echo ""
echo -e "${YELLOW}Nächste Schritte:${NC}"
echo "  1. Verifizieren Sie Balances und Difficulty"
echo "  2. Sichern Sie Snapshot-Datei an sicherer Stelle"
echo "  3. Aktualisieren Sie Slave-Nodes mit neuer Genesis"
echo "  4. Starten Sie Mining (wenn gewünscht)"
echo ""
echo -e "${BLUE}Node-Log: node-staging.log${NC}"
echo -e "${BLUE}Backup Genesis: $BACKUP_GENESIS${NC}"
echo ""

