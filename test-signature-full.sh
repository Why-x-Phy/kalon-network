#!/bin/bash

# Comprehensive Transaction Signature Validation Test
# Tests: Wallet creation, mining, balance checking, transaction creation, signing, and validation

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

BUILD_DIR="$SCRIPT_DIR/build"
NODE_RPC_URL="http://localhost:16316"
WALLET_FILE_1="wallet-test1.json"
WALLET_FILE_2="wallet-test2.json"
TX_AMOUNT=10000000  # 10 KALON
TX_FEE=1000000      # 1 KALON

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Cleanup function
cleanup() {
    log "Cleaning up..."
    pkill -f "kalon-node" || true
    pkill -f "kalon-miner" || true
    sleep 2
}

trap cleanup EXIT

# Always rebuild binaries to ensure latest code
log "Baue Binaries..."
go build -a -o "$BUILD_DIR/kalon-node" ./cmd/kalon-node-v2 || error "Node Build fehlgeschlagen"
go build -a -o "$BUILD_DIR/kalon-miner" ./cmd/kalon-miner-v2 || error "Miner Build fehlgeschlagen"
go build -a -o "$BUILD_DIR/kalon-wallet" ./cmd/kalon-wallet || error "Wallet Build fehlgeschlagen"
chmod +x "$BUILD_DIR/kalon-node" "$BUILD_DIR/kalon-miner" "$BUILD_DIR/kalon-wallet"

log "Starting Node..."
"$BUILD_DIR/kalon-node" -rpc :16316 -p2p :16317 > /tmp/kalon-node.log 2>&1 &
NODE_PID=$!
sleep 5

# Check if node is running
if ! kill -0 $NODE_PID 2>/dev/null; then
    error "Node failed to start. Check /tmp/kalon-node.log"
    exit 1
fi

log "Node started (PID: $NODE_PID)"

# Wait for node to be ready
log "Waiting for node to be ready..."
for i in {1..30}; do
    if curl -s "$NODE_RPC_URL" -X POST -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getHeight","params":{},"id":1}' > /dev/null 2>&1; then
        log "Node is ready"
        break
    fi
    if [ $i -eq 30 ]; then
        error "Node did not become ready"
        exit 1
    fi
    sleep 1
done

# Create wallets
log "Creating Wallet 1..."
echo "" | "$BUILD_DIR/kalon-wallet" create --name test1 --output "$WALLET_FILE_1" > /dev/null 2>&1 || true
WALLET_ADDRESS_1=$(cat "$WALLET_FILE_1" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d['address'])" 2>/dev/null || echo "")

if [ -z "$WALLET_ADDRESS_1" ]; then
    error "Failed to create Wallet 1"
    exit 1
fi

log "Wallet 1 created: $WALLET_ADDRESS_1"

log "Creating Wallet 2..."
echo "" | "$BUILD_DIR/kalon-wallet" create --name test2 --output "$WALLET_FILE_2" > /dev/null 2>&1 || true
WALLET_ADDRESS_2=$(cat "$WALLET_FILE_2" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d['address'])" 2>/dev/null || echo "")

if [ -z "$WALLET_ADDRESS_2" ]; then
    error "Failed to create Wallet 2"
    exit 1
fi

log "Wallet 2 created: $WALLET_ADDRESS_2"

# Start miner with Wallet 1
log "Starting Miner with Wallet 1..."
"$BUILD_DIR/kalon-miner" --rpc "$NODE_RPC_URL" --address "$WALLET_ADDRESS_1" --threads 2 > /tmp/kalon-miner.log 2>&1 &
MINER_PID=$!
sleep 2

log "Miner started (PID: $MINER_PID)"

# Wait for blocks to be mined
log "Waiting for blocks to be mined (target: 10 blocks)..."
BLOCKS_MINED=0
for i in {1..120}; do
    HEIGHT=$(curl -s "$NODE_RPC_URL" -X POST -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getHeight","params":{},"id":1}' 2>/dev/null | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('result', 0))" 2>/dev/null || echo "0")
    if [ "$HEIGHT" -ge 10 ]; then
        BLOCKS_MINED=$HEIGHT
        log "Mined $BLOCKS_MINED blocks"
        break
    fi
    sleep 1
done

if [ "$BLOCKS_MINED" -lt 10 ]; then
    warn "Only $BLOCKS_MINED blocks mined (target: 10)"
fi

# Check balance of Wallet 1
log "Checking balance of Wallet 1..."
BALANCE_1=$(curl -s "$NODE_RPC_URL" -X POST -H "Content-Type: application/json" -d "{\"jsonrpc\":\"2.0\",\"method\":\"getBalance\",\"params\":{\"address\":\"$WALLET_ADDRESS_1\"},\"id\":1}" 2>/dev/null | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('result', 0))" 2>/dev/null || echo "0")
log "Wallet 1 Balance: $BALANCE_1"

if [ "$BALANCE_1" -eq 0 ]; then
    error "Wallet 1 has no balance. Mining may have failed."
    exit 1
fi

# Send transaction from Wallet 1 to Wallet 2
if [ "$BALANCE_1" -ge $((TX_AMOUNT + TX_FEE)) ]; then
    log "Sending transaction from Wallet 1 to Wallet 2..."
    log "Amount: $TX_AMOUNT, Fee: $TX_FEE"
    
    WALLET_SEND_OUTPUT=$("$BUILD_DIR/kalon-wallet" send --input "$WALLET_FILE_1" --to "$WALLET_ADDRESS_2" --amount "$TX_AMOUNT" --fee "$TX_FEE" --rpc "$NODE_RPC_URL" 2>&1) || true
    echo "Wallet Output: $WALLET_SEND_OUTPUT"
    
    if echo "$WALLET_SEND_OUTPUT" | grep -qi "error\|failed"; then
        error "Transaction could not be sent"
        echo "Full output: $WALLET_SEND_OUTPUT"
        exit 1
    else
        log "Transaction sent successfully"
    fi
    
    # Extract transaction hash
    TX_HASH=$(echo "$WALLET_SEND_OUTPUT" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('hash', ''))" 2>/dev/null || echo "")
    if [ -n "$TX_HASH" ]; then
        log "Transaction Hash: $TX_HASH"
    fi
    
    log "Waiting 45 seconds for transaction to be included in a block..."
    sleep 45
    
    # Check balance of Wallet 2
    log "Checking balance of Wallet 2..."
    BALANCE_2=$(curl -s "$NODE_RPC_URL" -X POST -H "Content-Type: application/json" -d "{\"jsonrpc\":\"2.0\",\"method\":\"getBalance\",\"params\":{\"address\":\"$WALLET_ADDRESS_2\"},\"id\":1}" 2>/dev/null | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('result', 0))" 2>/dev/null || echo "0")
    log "Wallet 2 Balance: $BALANCE_2"
    
    if [ "$BALANCE_2" -ge "$TX_AMOUNT" ]; then
        log "✓ Transaction successfully processed (Balance: $BALANCE_2)"
    else
        error "Transaction may not have been processed (Balance: $BALANCE_2, Expected: >= $TX_AMOUNT)"
        exit 1
    fi
else
    error "Wallet 1 has insufficient balance ($BALANCE_1 < $((TX_AMOUNT + TX_FEE)))"
    log "Waiting additional 60 seconds for more blocks..."
    sleep 60
    BALANCE_1=$(curl -s "$NODE_RPC_URL" -X POST -H "Content-Type: application/json" -d "{\"jsonrpc\":\"2.0\",\"method\":\"getBalance\",\"params\":{\"address\":\"$WALLET_ADDRESS_1\"},\"id\":1}" 2>/dev/null | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('result', 0))" 2>/dev/null || echo "0")
    log "New Balance: $BALANCE_1"
    
    if [ "$BALANCE_1" -ge $((TX_AMOUNT + TX_FEE)) ]; then
        log "Retrying transaction..."
        WALLET_SEND_OUTPUT=$("$BUILD_DIR/kalon-wallet" send --input "$WALLET_FILE_1" --to "$WALLET_ADDRESS_2" --amount "$TX_AMOUNT" --fee "$TX_FEE" --rpc "$NODE_RPC_URL" 2>&1) || true
        if echo "$WALLET_SEND_OUTPUT" | grep -qi "error\|failed"; then
            error "Transaction failed on retry"
            exit 1
        else
            log "Transaction sent successfully on retry"
        fi
        sleep 45
        BALANCE_2=$(curl -s "$NODE_RPC_URL" -X POST -H "Content-Type: application/json" -d "{\"jsonrpc\":\"2.0\",\"method\":\"getBalance\",\"params\":{\"address\":\"$WALLET_ADDRESS_2\"},\"id\":1}" 2>/dev/null | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('result', 0))" 2>/dev/null || echo "0")
        if [ "$BALANCE_2" -ge "$TX_AMOUNT" ]; then
            log "✓ Transaction successfully processed after retry (Balance: $BALANCE_2)"
        else
            error "Transaction not processed after retry (Balance: $BALANCE_2)"
            exit 1
        fi
    else
        error "Still insufficient balance after waiting"
        exit 1
    fi
fi

log "✓ All tests passed!"
log "Final Status:"
log "  - Blocks Mined: $BLOCKS_MINED"
log "  - Wallet 1 Balance: $BALANCE_1"
log "  - Wallet 2 Balance: $BALANCE_2"
log "  - Transaction Amount: $TX_AMOUNT"
log "  - Transaction Fee: $TX_FEE"

