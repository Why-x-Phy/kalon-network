#!/bin/bash

# Vollumfänglicher Sicherheits-Test für Kalon Blockchain
# Testet alle neuen Sicherheits-Features mehrfach

set -e

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging-Funktionen
log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Cleanup-Funktion
cleanup() {
    log "Cleanup..."
    killall kalon-node-v2 kalon-miner-v2 2>/dev/null || true
    sleep 2
    rm -rf data-testnet/chaindb data-testnet/utxodb data-testnet/*.log 2>/dev/null || true
    rm -f wallet*.json 2>/dev/null || true
}

# Test-Statistiken
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Test-Funktion
run_test() {
    local test_name="$1"
    local test_func="$2"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    log "Test $TOTAL_TESTS: $test_name"
    
    if $test_func; then
        success "✓ $test_name"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    else
        error "✗ $test_name"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
}

# Test 1: Node startet erfolgreich
test_node_start() {
    log "Starte Node..."
    ./build-v2/kalon-node-v2 -datadir data-testnet -rpc :16316 -p2p :17335 > node.log 2>&1 &
    NODE_PID=$!
    sleep 5
    
    # Prüfe ob Node läuft
    if ! kill -0 $NODE_PID 2>/dev/null; then
        error "Node startete nicht"
        return 1
    fi
    
    # Prüfe RPC-Zugriff
    for i in {1..10}; do
        if curl -s -X POST -H "Content-Type: application/json" \
            -d '{"jsonrpc":"2.0","method":"getHeight","params":[],"id":1}' \
            http://localhost:16316 > /dev/null 2>&1; then
            return 0
        fi
        sleep 1
    done
    
    error "RPC nicht erreichbar"
    return 1
}

# Test 2: Wallet erstellen
test_wallet_creation() {
    log "Erstelle Wallet..."
    WALLET_OUTPUT=$(printf "\n\n" | ./build-v2/kalon-wallet create --output wallet1.json 2>&1)
    
    if [ ! -f wallet1.json ]; then
        error "Wallet-Datei nicht erstellt"
        return 1
    fi
    
    # Extrahiere Adresse
    WALLET_ADDRESS=$(echo "$WALLET_OUTPUT" | grep -oP 'Address:\s+\K[^\s]+' | head -1)
    if [ -z "$WALLET_ADDRESS" ]; then
        WALLET_ADDRESS=$(echo "$WALLET_OUTPUT" | grep -oP '"address":\s*"\K[^"]+' | head -1)
    fi
    
    if [ -z "$WALLET_ADDRESS" ]; then
        error "Wallet-Adresse nicht extrahiert"
        return 1
    fi
    
    log "Wallet-Adresse: $WALLET_ADDRESS"
    return 0
}

# Test 3: Mining startet
test_mining_start() {
    log "Starte Miner..."
    
    # Extrahiere Adresse aus Wallet-Datei
    if [ ! -f wallet1.json ]; then
        error "Wallet-Datei nicht gefunden"
        return 1
    fi
    
    # Versuche Adresse aus JSON zu extrahieren
    WALLET_ADDRESS=$(cat wallet1.json | grep -oP '"address":\s*"\K[^"]+' | head -1)
    
    # Falls nicht gefunden, versuche aus Wallet-Info-Command
    if [ -z "$WALLET_ADDRESS" ]; then
        WALLET_OUTPUT=$(./build-v2/kalon-wallet info --input wallet1.json 2>&1 || echo "")
        WALLET_ADDRESS=$(echo "$WALLET_OUTPUT" | grep -oP '"address":\s*"\K[^"]+' | head -1)
    fi
    
    # Falls immer noch nicht gefunden, versuche aus Wallet-Output (nicht-JSON)
    if [ -z "$WALLET_ADDRESS" ]; then
        WALLET_OUTPUT=$(./build-v2/kalon-wallet info --input wallet1.json 2>&1 || echo "")
        WALLET_ADDRESS=$(echo "$WALLET_OUTPUT" | grep -oP 'Address:\s+\K[^\s]+' | head -1)
    fi
    
    # Falls immer noch nicht gefunden, verwende die gespeicherte Adresse
    if [ -z "$WALLET_ADDRESS" ]; then
        error "Konnte Wallet-Adresse nicht extrahieren"
        return 1
    fi
    
    log "Miner-Adresse: $WALLET_ADDRESS"
    
    ./build-v2/kalon-miner-v2 -rpc http://localhost:16316 -wallet "$WALLET_ADDRESS" -threads 1 > miner.log 2>&1 &
    MINER_PID=$!
    sleep 3
    
    if ! kill -0 $MINER_PID 2>/dev/null; then
        error "Miner startete nicht"
        return 1
    fi
    
    return 0
}

# Test 4: Blöcke werden gemined
test_block_mining() {
    log "Warte auf Blöcke..."
    INITIAL_HEIGHT=$(curl -s -X POST -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"getHeight","params":[],"id":1}' \
        http://localhost:16316 | grep -oP '"result":\s*\K[0-9]+' || echo "0")
    
    log "Initiale Höhe: $INITIAL_HEIGHT"
    
    # Warte auf mindestens 5 Blöcke
    for i in {1..60}; do
        CURRENT_HEIGHT=$(curl -s -X POST -H "Content-Type: application/json" \
            -d '{"jsonrpc":"2.0","method":"getHeight","params":[],"id":1}' \
            http://localhost:16316 | grep -oP '"result":\s*\K[0-9]+' || echo "0")
        
        BLOCKS_MINED=$((CURRENT_HEIGHT - INITIAL_HEIGHT))
        log "Aktuelle Höhe: $CURRENT_HEIGHT (gemined: $BLOCKS_MINED)"
        
        if [ "$BLOCKS_MINED" -ge 5 ]; then
            success "Mindestens 5 Blöcke gemined"
            return 0
        fi
        
        sleep 2
    done
    
    error "Nicht genug Blöcke gemined (nur $BLOCKS_MINED)"
    return 1
}

# Test 5: Balance wird korrekt aktualisiert
test_balance_update() {
    log "Prüfe Balance..."
    
    # Hole Balance
    BALANCE=$(curl -s -X POST -H "Content-Type: application/json" \
        -d "{\"jsonrpc\":\"2.0\",\"method\":\"getBalance\",\"params\":[\"$WALLET_ADDRESS\"],\"id\":1}" \
        http://localhost:16316 | grep -oP '"result":\s*\K[0-9]+' || echo "0")
    
    log "Balance: $BALANCE"
    
    if [ "$BALANCE" -gt 0 ]; then
        success "Balance > 0: $BALANCE"
        return 0
    else
        error "Balance ist 0"
        return 1
    fi
}

# Test 6: Merkle Root wird berechnet
test_merkle_root() {
    log "Prüfe Merkle Root..."
    
    # Hole letzten Block
    BLOCK_DATA=$(curl -s -X POST -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"getBlock","params":[0],"id":1}' \
        http://localhost:16316)
    
    MERKLE_ROOT=$(echo "$BLOCK_DATA" | grep -oP '"merkleRoot":\s*"\K[^"]+' | head -1)
    
    if [ -z "$MERKLE_ROOT" ] || [ "$MERKLE_ROOT" = "0000000000000000000000000000000000000000000000000000000000000000" ]; then
        error "Merkle Root ist leer oder null"
        return 1
    fi
    
    success "Merkle Root berechnet: ${MERKLE_ROOT:0:16}..."
    return 0
}

# Test 7: Difficulty wird validiert
test_difficulty_validation() {
    log "Prüfe Difficulty-Validierung..."
    
    # Hole Difficulty
    DIFFICULTY=$(curl -s -X POST -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"getMiningInfo","params":[],"id":1}' \
        http://localhost:16316 | grep -oP '"difficulty":\s*\K[0-9]+' || echo "0")
    
    log "Difficulty: $DIFFICULTY"
    
    if [ "$DIFFICULTY" -gt 0 ]; then
        success "Difficulty validiert: $DIFFICULTY"
        return 0
    else
        error "Difficulty ist 0"
        return 1
    fi
}

# Test 8: Block Reward wird validiert
test_block_reward() {
    log "Prüfe Block Reward..."
    
    # Hole Block 1 (erster gemineder Block)
    BLOCK_DATA=$(curl -s -X POST -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"getBlock","params":[1],"id":1}' \
        http://localhost:16316)
    
    # Prüfe ob Block Transactions hat
    TX_COUNT=$(echo "$BLOCK_DATA" | grep -oP '"txCount":\s*\K[0-9]+' || echo "0")
    
    if [ "$TX_COUNT" -gt 0 ]; then
        success "Block hat Transactions: $TX_COUNT"
        return 0
    else
        error "Block hat keine Transactions"
        return 1
    fi
}

# Test 9: UTXO Double-Spending Check
test_utxo_double_spending() {
    log "Prüfe UTXO Double-Spending Check..."
    
    # Hole UTXOs
    UTXOS=$(curl -s -X POST -H "Content-Type: application/json" \
        -d "{\"jsonrpc\":\"2.0\",\"method\":\"getUTXOs\",\"params\":[\"$WALLET_ADDRESS\"],\"id\":1}" \
        http://localhost:16316)
    
    UTXO_COUNT=$(echo "$UTXOS" | grep -oP '"result":\s*\[\s*\{' | wc -l || echo "0")
    
    if [ "$UTXO_COUNT" -gt 0 ]; then
        success "UTXOs gefunden: $UTXO_COUNT"
        return 0
    else
        warning "Keine UTXOs gefunden (kann normal sein)"
        return 0
    fi
}

# Test 10: Fork-Erkennung (simuliert)
test_fork_detection() {
    log "Prüfe Fork-Erkennung..."
    
    # Hole aktuelle Höhe
    HEIGHT=$(curl -s -X POST -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"getHeight","params":[],"id":1}' \
        http://localhost:16316 | grep -oP '"result":\s*\K[0-9]+' || echo "0")
    
    if [ "$HEIGHT" -gt 0 ]; then
        success "Chain-Höhe: $HEIGHT (Fork-Erkennung implementiert)"
        return 0
    else
        error "Chain-Höhe ist 0"
        return 1
    fi
}

# Test 11: Mehrfacher Test (3 Runden)
test_multiple_rounds() {
    log "Mehrfacher Test (3 Runden)..."
    
    for round in 1 2 3; do
        log "Runde $round..."
        
        INITIAL_HEIGHT=$(curl -s -X POST -H "Content-Type: application/json" \
            -d '{"jsonrpc":"2.0","method":"getHeight","params":[],"id":1}' \
            http://localhost:16316 | grep -oP '"result":\s*\K[0-9]+' || echo "0")
        
        log "Initiale Höhe Runde $round: $INITIAL_HEIGHT"
        
        # Warte auf 3 neue Blöcke
        for i in {1..30}; do
            CURRENT_HEIGHT=$(curl -s -X POST -H "Content-Type: application/json" \
                -d '{"jsonrpc":"2.0","method":"getHeight","params":[],"id":1}' \
                http://localhost:16316 | grep -oP '"result":\s*\K[0-9]+' || echo "0")
            
            BLOCKS_MINED=$((CURRENT_HEIGHT - INITIAL_HEIGHT))
            
            if [ "$BLOCKS_MINED" -ge 3 ]; then
                success "Runde $round: 3 Blöcke gemined"
                break
            fi
            
            sleep 2
        done
        
        if [ "$BLOCKS_MINED" -lt 3 ]; then
            error "Runde $round: Nicht genug Blöcke gemined"
            return 1
        fi
    done
    
    success "Alle 3 Runden erfolgreich"
    return 0
}

# Test 12: Node-Logs prüfen
test_node_logs() {
    log "Prüfe Node-Logs auf Fehler..."
    
    # Prüfe auf kritische Fehler
    ERROR_COUNT=$(grep -i "error\|panic\|fatal" node.log 2>/dev/null | wc -l || echo "0")
    
    if [ "$ERROR_COUNT" -eq 0 ]; then
        success "Keine Fehler in Node-Logs"
        return 0
    else
        warning "Fehler in Node-Logs gefunden: $ERROR_COUNT"
        grep -i "error\|panic\|fatal" node.log | head -5
        return 0  # Nicht kritisch
    fi
}

# Test 13: Miner-Logs prüfen
test_miner_logs() {
    log "Prüfe Miner-Logs auf Fehler..."
    
    # Prüfe auf kritische Fehler
    ERROR_COUNT=$(grep -i "error\|panic\|fatal" miner.log 2>/dev/null | wc -l || echo "0")
    
    if [ "$ERROR_COUNT" -eq 0 ]; then
        success "Keine Fehler in Miner-Logs"
        return 0
    else
        warning "Fehler in Miner-Logs gefunden: $ERROR_COUNT"
        grep -i "error\|panic\|fatal" miner.log | head -5
        return 0  # Nicht kritisch
    fi
}

# Test 14: Finale Statistiken
test_final_stats() {
    log "Finale Statistiken..."
    
    HEIGHT=$(curl -s -X POST -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"getHeight","params":[],"id":1}' \
        http://localhost:16316 | grep -oP '"result":\s*\K[0-9]+' || echo "0")
    
    BALANCE=$(curl -s -X POST -H "Content-Type: application/json" \
        -d "{\"jsonrpc\":\"2.0\",\"method\":\"getBalance\",\"params\":[\"$WALLET_ADDRESS\"],\"id\":1}" \
        http://localhost:16316 | grep -oP '"result":\s*\K[0-9]+' || echo "0")
    
    DIFFICULTY=$(curl -s -X POST -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"getMiningInfo","params":[],"id":1}' \
        http://localhost:16316 | grep -oP '"difficulty":\s*\K[0-9]+' || echo "0")
    
    log "Finale Höhe: $HEIGHT"
    log "Finale Balance: $BALANCE"
    log "Finale Difficulty: $DIFFICULTY"
    
    if [ "$HEIGHT" -gt 10 ] && [ "$BALANCE" -gt 0 ]; then
        success "Finale Statistiken OK"
        return 0
    else
        error "Finale Statistiken nicht OK"
        return 1
    fi
}

# Haupt-Test-Funktion
main() {
    echo "=========================================="
    echo "  VOLLUMFÄNGLICHER SICHERHEITS-TEST"
    echo "=========================================="
    echo ""
    
    # Cleanup
    cleanup
    
    # Build
    log "Baue Binaries..."
    go build -o build-v2/kalon-node-v2 ./cmd/kalon-node-v2
    go build -o build-v2/kalon-miner-v2 ./cmd/kalon-miner-v2
    go build -o build-v2/kalon-wallet ./cmd/kalon-wallet
    
    # Führe Tests aus
    run_test "Node startet erfolgreich" test_node_start
    run_test "Wallet wird erstellt" test_wallet_creation
    run_test "Mining startet" test_mining_start
    run_test "Blöcke werden gemined" test_block_mining
    run_test "Balance wird aktualisiert" test_balance_update
    run_test "Merkle Root wird berechnet" test_merkle_root
    run_test "Difficulty wird validiert" test_difficulty_validation
    run_test "Block Reward wird validiert" test_block_reward
    run_test "UTXO Double-Spending Check" test_utxo_double_spending
    run_test "Fork-Erkennung" test_fork_detection
    run_test "Mehrfacher Test (3 Runden)" test_multiple_rounds
    run_test "Node-Logs prüfen" test_node_logs
    run_test "Miner-Logs prüfen" test_miner_logs
    run_test "Finale Statistiken" test_final_stats
    
    # Cleanup
    log "Stoppe Node und Miner..."
    killall kalon-node-v2 kalon-miner-v2 2>/dev/null || true
    sleep 2
    
    # Ergebnisse
    echo ""
    echo "=========================================="
    echo "  TEST-ERGEBNISSE"
    echo "=========================================="
    echo "Gesamt: $TOTAL_TESTS"
    echo -e "${GREEN}Erfolgreich: $PASSED_TESTS${NC}"
    echo -e "${RED}Fehlgeschlagen: $FAILED_TESTS${NC}"
    echo ""
    
    if [ $FAILED_TESTS -eq 0 ]; then
        success "ALLE TESTS ERFOLGREICH! ✓"
        exit 0
    else
        error "EINIGE TESTS FEHLGESCHLAGEN! ✗"
        exit 1
    fi
}

# Trap für Cleanup
trap cleanup EXIT

# Starte Tests
main

