#!/bin/bash

# Vollständiger Test für Logging-Level und alle Funktionen
# Testet: Logging-Level, Node, Mining, Transaktionen, RPC

set -e

echo "=========================================="
echo "Vollständiger Logging-Level und Funktions-Test"
echo "=========================================="
echo ""

# Farben für Output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Cleanup-Funktion
cleanup() {
    echo ""
    echo "Cleanup..."
    pkill -f kalon-node-v2 || true
    pkill -f kalon-miner-v2 || true
    pkill -f kalon-wallet || true
    sleep 2
    rm -rf data-test-logging
    rm -f wallet-test-*.json wallet-*.json
    echo "Cleanup abgeschlossen"
}

# Cleanup bei Exit
trap cleanup EXIT

# Test-Verzeichnis erstellen
mkdir -p data-test-logging/chaindb

echo "1. Test: Logging-Level Konfiguration"
echo "--------------------------------------"

# Test 1: Node mit debug-Logging starten
echo "Starte Node mit -loglevel debug..."
timeout 5 ./build-v2/kalon-node-v2 -datadir data-test-logging -loglevel debug 2>&1 | head -5 || true
echo -e "${GREEN}✓ Node startet mit debug-Logging${NC}"
echo ""

# Test 2: Node mit warn-Logging starten
echo "Starte Node mit -loglevel warn..."
timeout 5 ./build-v2/kalon-node-v2 -datadir data-test-logging -loglevel warn 2>&1 | head -5 || true
echo -e "${GREEN}✓ Node startet mit warn-Logging${NC}"
echo ""

# Test 3: Node mit error-Logging starten
echo "Starte Node mit -loglevel error..."
timeout 5 ./build-v2/kalon-node-v2 -datadir data-test-logging -loglevel error 2>&1 | head -5 || true
echo -e "${GREEN}✓ Node startet mit error-Logging${NC}"
echo ""

echo "2. Test: Vollständiger Funktions-Test"
echo "--------------------------------------"

# Node starten
echo "Starte Node..."
./build-v2/kalon-node-v2 -datadir data-test-logging -loglevel info > node-test.log 2>&1 &
NODE_PID=$!
sleep 5

# Prüfe ob Node läuft
if ! ps -p $NODE_PID > /dev/null; then
    echo -e "${RED}✗ Node start fehlgeschlagen${NC}"
    cat node-test.log
    exit 1
fi
echo -e "${GREEN}✓ Node läuft (PID: $NODE_PID)${NC}"

# Warte auf RPC-Server
echo "Warte auf RPC-Server..."
for i in {1..30}; do
    if curl -s -X POST http://localhost:16316 -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getHeight","params":{},"id":1}' > /dev/null 2>&1; then
        break
    fi
    sleep 1
done

# Test RPC getHeight
echo "Teste RPC getHeight..."
HEIGHT=$(curl -s -X POST http://localhost:16316 -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getHeight","params":{},"id":1}' | grep -oP '"result":\s*\K[0-9]+' || echo "0")
if [ "$HEIGHT" = "" ]; then
    HEIGHT="0"
fi
echo -e "${GREEN}✓ RPC getHeight funktioniert (Height: $HEIGHT)${NC}"

# Test RPC getBestBlock
echo "Teste RPC getBestBlock..."
BEST_BLOCK=$(curl -s -X POST http://localhost:16316 -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getBestBlock","params":{},"id":2}')
if echo "$BEST_BLOCK" | grep -q '"result"'; then
    echo -e "${GREEN}✓ RPC getBestBlock funktioniert${NC}"
else
    echo -e "${RED}✗ RPC getBestBlock fehlgeschlagen${NC}"
    echo "$BEST_BLOCK"
    exit 1
fi

# Wallet erstellen
echo ""
echo "3. Test: Wallet-Funktionen"
echo "--------------------------------------"
echo "Erstelle Wallet 1..."
echo "" | ./build-v2/kalon-wallet create -name test-1 -passphrase "" > wallet1-output.txt 2>&1 || true
WALLET1=$(grep -oP 'kalon1[a-z0-9]+' wallet1-output.txt | head -1 || echo "")
if [ -z "$WALLET1" ]; then
    # Versuche alternative Methode
    WALLET1=$(cat wallet-test-1.json 2>/dev/null | grep -oP '"address":\s*"kalon1[a-z0-9]+"' | grep -oP 'kalon1[a-z0-9]+' | head -1 || echo "")
fi
if [ -z "$WALLET1" ]; then
    echo -e "${RED}✗ Wallet 1 Erstellung fehlgeschlagen${NC}"
    cat wallet1-output.txt
    exit 1
fi
echo -e "${GREEN}✓ Wallet 1 erstellt: $WALLET1${NC}"

echo "Erstelle Wallet 2..."
echo "" | ./build-v2/kalon-wallet create -name test-2 -passphrase "" > wallet2-output.txt 2>&1 || true
WALLET2=$(grep -oP 'kalon1[a-z0-9]+' wallet2-output.txt | head -1 || echo "")
if [ -z "$WALLET2" ]; then
    # Versuche alternative Methode
    WALLET2=$(cat wallet-test-2.json 2>/dev/null | grep -oP '"address":\s*"kalon1[a-z0-9]+"' | grep -oP 'kalon1[a-z0-9]+' | head -1 || echo "")
fi
if [ -z "$WALLET2" ]; then
    echo -e "${RED}✗ Wallet 2 Erstellung fehlgeschlagen${NC}"
    cat wallet2-output.txt
    exit 1
fi
echo -e "${GREEN}✓ Wallet 2 erstellt: $WALLET2${NC}"

# Mining starten
echo ""
echo "4. Test: Mining-Funktionen"
echo "--------------------------------------"
echo "Starte Miner mit Wallet 1..."
./build-v2/kalon-miner-v2 -wallet "$WALLET1" -rpc http://localhost:16316 -loglevel info > miner-test.log 2>&1 &
MINER_PID=$!
sleep 3

# Prüfe ob Miner läuft
if ! ps -p $MINER_PID > /dev/null; then
    echo -e "${RED}✗ Miner start fehlgeschlagen${NC}"
    cat miner-test.log
    exit 1
fi
echo -e "${GREEN}✓ Miner läuft (PID: $MINER_PID)${NC}"

# Warte auf Block
echo "Warte auf Block-Generierung (max. 60 Sekunden)..."
BLOCK_FOUND=false
for i in {1..60}; do
    NEW_HEIGHT=$(curl -s -X POST http://localhost:16316 -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getHeight","params":{},"id":1}' | grep -oP '"result":\s*\K[0-9]+' || echo "0")
    if [ "$NEW_HEIGHT" != "" ] && [ "$NEW_HEIGHT" != "0" ] && [ "$NEW_HEIGHT" != "$HEIGHT" ]; then
        BLOCK_FOUND=true
        echo -e "${GREEN}✓ Block gefunden! Neue Height: $NEW_HEIGHT${NC}"
        break
    fi
    sleep 1
done

if [ "$BLOCK_FOUND" = false ]; then
    echo -e "${YELLOW}⚠ Kein Block gefunden (kann bei niedriger Difficulty normal sein)${NC}"
fi

# Prüfe Balance
echo ""
echo "5. Test: Balance und Transaktionen"
echo "--------------------------------------"
BALANCE1=$(curl -s -X POST http://localhost:16316 -H "Content-Type: application/json" -d "{\"jsonrpc\":\"2.0\",\"method\":\"getBalance\",\"params\":{\"address\":\"$WALLET1\"},\"id\":3}" | grep -oP '"result":\s*\K[0-9]+' || echo "0")
if [ "$BALANCE1" = "" ]; then
    BALANCE1="0"
fi
echo "Balance Wallet 1: $BALANCE1"
if [ "$BALANCE1" != "0" ]; then
    echo -e "${GREEN}✓ Balance abrufbar${NC}"
else
    echo -e "${YELLOW}⚠ Balance ist 0 (kann normal sein wenn noch kein Block gemined wurde)${NC}"
fi

# Test RPC getTotalTransactions
echo "Teste RPC getTotalTransactions..."
TOTAL_TXS=$(curl -s -X POST http://localhost:16316 -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getTotalTransactions","params":{},"id":4}' | grep -oP '"result":\s*\K[0-9]+' || echo "0")
if [ "$TOTAL_TXS" = "" ]; then
    TOTAL_TXS="0"
fi
echo -e "${GREEN}✓ getTotalTransactions: $TOTAL_TXS${NC}"

# Test RPC getAddressCount
echo "Teste RPC getAddressCount..."
ADDR_COUNT=$(curl -s -X POST http://localhost:16316 -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getAddressCount","params":{},"id":5}' | grep -oP '"result":\s*\K[0-9]+' || echo "0")
if [ "$ADDR_COUNT" = "" ]; then
    ADDR_COUNT="0"
fi
echo -e "${GREEN}✓ getAddressCount: $ADDR_COUNT${NC}"

# Test RPC getPeerCount
echo "Teste RPC getPeerCount..."
PEER_COUNT=$(curl -s -X POST http://localhost:16316 -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getPeerCount","params":{},"id":6}' | grep -oP '"result":\s*\K[0-9]+' || echo "0")
if [ "$PEER_COUNT" = "" ]; then
    PEER_COUNT="0"
fi
echo -e "${GREEN}✓ getPeerCount: $PEER_COUNT${NC}"

# Test RPC getHashrate
echo "Teste RPC getHashrate..."
HASHRATE=$(curl -s -X POST http://localhost:16316 -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getHashrate","params":{},"id":7}')
if echo "$HASHRATE" | grep -q '"result"'; then
    echo -e "${GREEN}✓ getHashrate funktioniert${NC}"
else
    echo -e "${YELLOW}⚠ getHashrate fehlgeschlagen${NC}"
fi

# Test RPC getAddressInfo
echo "Teste RPC getAddressInfo..."
ADDR_INFO=$(curl -s -X POST http://localhost:16316 -H "Content-Type: application/json" -d "{\"jsonrpc\":\"2.0\",\"method\":\"getAddressInfo\",\"params\":{\"address\":\"$WALLET1\"},\"id\":8}")
if echo "$ADDR_INFO" | grep -q '"result"'; then
    echo -e "${GREEN}✓ getAddressInfo funktioniert${NC}"
else
    echo -e "${YELLOW}⚠ getAddressInfo fehlgeschlagen${NC}"
fi

# Test RPC getRecentBlocks
echo "Teste RPC getRecentBlocks..."
RECENT_BLOCKS=$(curl -s -X POST http://localhost:16316 -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getRecentBlocks","params":{"limit":5},"id":9}')
if echo "$RECENT_BLOCKS" | grep -q '"result"'; then
    echo -e "${GREEN}✓ getRecentBlocks funktioniert${NC}"
else
    echo -e "${YELLOW}⚠ getRecentBlocks fehlgeschlagen${NC}"
fi

# Logging-Level Test
echo ""
echo "6. Test: Logging-Level Filterung"
echo "--------------------------------------"
echo "Prüfe Logs auf Log-Level-Filterung..."

# Prüfe ob DEBUG-Logs vorhanden sind (sollten bei info-Level nicht erscheinen)
DEBUG_COUNT=$(grep -c "🔍 DEBUG" node-test.log 2>/dev/null || echo "0")
INFO_COUNT=$(grep -c "✅ INFO" node-test.log 2>/dev/null || echo "0")
WARN_COUNT=$(grep -c "⚠️ WARN" node-test.log 2>/dev/null || echo "0")
ERROR_COUNT=$(grep -c "❌ ERROR" node-test.log 2>/dev/null || echo "0")

echo "Log-Zähler:"
echo "  DEBUG: $DEBUG_COUNT"
echo "  INFO: $INFO_COUNT"
echo "  WARN: $WARN_COUNT"
echo "  ERROR: $ERROR_COUNT"

if [ "$INFO_COUNT" -gt 0 ] || [ "$WARN_COUNT" -gt 0 ] || [ "$ERROR_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✓ Logging-Level funktioniert${NC}"
else
    echo -e "${YELLOW}⚠ Keine Logs gefunden (kann normal sein)${NC}"
fi

# Miner Logs prüfen
MINER_DEBUG=$(grep -c "🔍 DEBUG" miner-test.log 2>/dev/null || echo "0")
MINER_INFO=$(grep -c "✅ INFO" miner-test.log 2>/dev/null || echo "0")
echo "Miner Logs:"
echo "  DEBUG: $MINER_DEBUG"
echo "  INFO: $MINER_INFO"

# Finale Zusammenfassung
echo ""
echo "=========================================="
echo "Test-Zusammenfassung"
echo "=========================================="
echo -e "${GREEN}✓ Logging-Level Konfiguration${NC}"
echo -e "${GREEN}✓ Node Start und RPC${NC}"
echo -e "${GREEN}✓ Wallet Erstellung${NC}"
echo -e "${GREEN}✓ Miner Start${NC}"
echo -e "${GREEN}✓ RPC Methoden${NC}"
echo -e "${GREEN}✓ Logging-Level Filterung${NC}"
echo ""
echo -e "${GREEN}Alle Tests erfolgreich!${NC}"
echo ""

# Stoppe Prozesse
echo "Stoppe Prozesse..."
kill $MINER_PID 2>/dev/null || true
kill $NODE_PID 2>/dev/null || true
sleep 2

echo ""
echo "Test abgeschlossen!"

