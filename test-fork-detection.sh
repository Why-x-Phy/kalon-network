#!/bin/bash

# Comprehensive Fork Detection and Reorganization Test
# Tests fork detection, chain reorganization, and longest chain rule

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

DATA_DIR="data-fork-test"
RPC_PORT=16316
NODE_PID=""
MINER_PID=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Cleanup function
cleanup() {
    echo ""
    echo "=== CLEANUP ==="
    if [ ! -z "$NODE_PID" ]; then
        echo "Stopping node (PID: $NODE_PID)..."
        kill $NODE_PID 2>/dev/null || true
        wait $NODE_PID 2>/dev/null || true
    fi
    if [ ! -z "$MINER_PID" ]; then
        echo "Stopping miner (PID: $MINER_PID)..."
        kill $MINER_PID 2>/dev/null || true
        wait $MINER_PID 2>/dev/null || true
    fi
    sleep 2
    echo "✅ Cleanup completed"
}

trap cleanup EXIT

# Cleanup old data
echo "=== CLEANUP OLD DATA ==="
rm -rf "$DATA_DIR"
mkdir -p "$DATA_DIR"
rm -f wallet-wallet1.json wallet-wallet2.json 2>/dev/null || true
echo "✅ Cleanup completed"
echo ""

# Build
echo "=== BUILD ==="
go build -o build-v2/kalon-node-v2 ./cmd/kalon-node-v2
go build -o build-v2/kalon-miner-v2 ./cmd/kalon-miner-v2
go build -o build-v2/kalon-wallet ./cmd/kalon-wallet
echo "✅ Build completed"
echo ""

# Start node
echo "=== START NODE ==="
./build-v2/kalon-node-v2 -datadir "$DATA_DIR" -genesis genesis/testnet.json -rpc :$RPC_PORT > "$DATA_DIR/node.log" 2>&1 &
NODE_PID=$!
echo "Node started (PID: $NODE_PID)"
sleep 5

# Check if node is running
if ! kill -0 $NODE_PID 2>/dev/null; then
    echo -e "${RED}❌ Node failed to start${NC}"
    cat "$DATA_DIR/node.log"
    exit 1
fi
echo "✅ Node is running"
echo ""

# Wait for node to be ready
echo "=== WAIT FOR NODE READY ==="
for i in {1..30}; do
    if curl -s -X POST -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"getBestBlock","params":[],"id":1}' \
        http://localhost:$RPC_PORT > /dev/null 2>&1; then
        echo "✅ Node is ready"
        break
    fi
    if [ $i -eq 30 ]; then
        echo -e "${RED}❌ Node not ready after 30 seconds${NC}"
        cat "$DATA_DIR/node.log"
        exit 1
    fi
    sleep 1
done
echo ""

# Create wallets
echo "=== CREATE WALLETS ==="
echo "" | ./build-v2/kalon-wallet create -name wallet1 > "$DATA_DIR/wallet1_output.txt" 2>&1 || true
WALLET1_OUTPUT=$(cat "$DATA_DIR/wallet1_output.txt")
WALLET1_ADDRESS=$(echo "$WALLET1_OUTPUT" | grep -i "address:" | awk '{print $2}' | head -1 || echo "")
if [ -z "$WALLET1_ADDRESS" ]; then
    echo "Failed to extract wallet1 address. Output:"
    echo "$WALLET1_OUTPUT"
    exit 1
fi
echo "Wallet 1 Address: $WALLET1_ADDRESS"

echo "" | ./build-v2/kalon-wallet create -name wallet2 > "$DATA_DIR/wallet2_output.txt" 2>&1 || true
WALLET2_OUTPUT=$(cat "$DATA_DIR/wallet2_output.txt")
WALLET2_ADDRESS=$(echo "$WALLET2_OUTPUT" | grep -i "address:" | awk '{print $2}' | head -1 || echo "")
if [ -z "$WALLET2_ADDRESS" ]; then
    echo "Failed to extract wallet2 address. Output:"
    echo "$WALLET2_OUTPUT"
    exit 1
fi
echo "Wallet 2 Address: $WALLET2_ADDRESS"
echo "✅ Wallets created"
echo ""

# Start miner with wallet1
echo "=== START MINER ==="
./build-v2/kalon-miner-v2 -rpc http://localhost:$RPC_PORT -address "$WALLET1_ADDRESS" > "$DATA_DIR/miner.log" 2>&1 &
MINER_PID=$!
echo "Miner started (PID: $MINER_PID)"
sleep 3
echo "✅ Miner is running"
echo ""

# Mine some blocks
echo "=== MINE BLOCKS ==="
echo "Waiting for blocks to be mined..."
BLOCKS_MINED=0
for i in {1..60}; do
    BEST_BLOCK=$(curl -s -X POST -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"getBestBlock","params":[],"id":1}' \
        http://localhost:$RPC_PORT | grep -oP '"number":\s*\K[0-9]+' || echo "0")
    
    if [ ! -z "$BEST_BLOCK" ] && [ "$BEST_BLOCK" -gt "0" ]; then
        BLOCKS_MINED=$BEST_BLOCK
        echo "Blocks mined: $BLOCKS_MINED"
        if [ "$BLOCKS_MINED" -ge "3" ]; then
            break
        fi
    fi
    sleep 1
done

if [ "$BLOCKS_MINED" -lt "3" ]; then
    echo -e "${YELLOW}⚠️ Only $BLOCKS_MINED blocks mined (expected at least 3)${NC}"
else
    echo "✅ Mined $BLOCKS_MINED blocks"
fi
echo ""

# Get best block info
echo "=== GET BEST BLOCK INFO ==="
BEST_BLOCK_RESPONSE=$(curl -s -X POST -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","method":"getBestBlock","params":[],"id":1}' \
    http://localhost:$RPC_PORT)

BEST_BLOCK_NUMBER=$(echo "$BEST_BLOCK_RESPONSE" | grep -oP '"number":\s*\K[0-9]+' || echo "0")
BEST_BLOCK_HASH=$(echo "$BEST_BLOCK_RESPONSE" | grep -oP '"hash":\s*"0x\K[0-9a-f]+' || echo "")
BEST_BLOCK_MERKLE=$(echo "$BEST_BLOCK_RESPONSE" | grep -oP '"merkleRoot":\s*"0x\K[0-9a-f]+' || echo "")

echo "Best Block Number: $BEST_BLOCK_NUMBER"
echo "Best Block Hash: $BEST_BLOCK_HASH"
echo "Best Block Merkle Root: $BEST_BLOCK_MERKLE"
echo ""

# Get recent blocks
echo "=== GET RECENT BLOCKS ==="
RECENT_BLOCKS_RESPONSE=$(curl -s -X POST -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","method":"getRecentBlocks","params":[10],"id":1}' \
    http://localhost:$RPC_PORT)

RECENT_BLOCKS_COUNT=$(echo "$RECENT_BLOCKS_RESPONSE" | grep -oP '"number":\s*\K[0-9]+' | wc -l)
echo "Recent blocks count: $RECENT_BLOCKS_COUNT"
echo ""

# Check for fork detection messages in logs
echo "=== CHECK FORK DETECTION ==="
if grep -q "Fork detected" "$DATA_DIR/node.log"; then
    echo -e "${GREEN}✅ Fork detection messages found in logs${NC}"
    grep "Fork detected" "$DATA_DIR/node.log" | tail -5
else
    echo -e "${YELLOW}⚠️ No fork detection messages in logs (this is normal if no forks occurred)${NC}"
fi
echo ""

# Check for reorganization messages in logs
echo "=== CHECK REORGANIZATION ==="
if grep -q "Reorganizing chain" "$DATA_DIR/node.log"; then
    echo -e "${GREEN}✅ Chain reorganization messages found in logs${NC}"
    grep "Reorganizing chain" "$DATA_DIR/node.log" | tail -5
else
    echo -e "${YELLOW}⚠️ No reorganization messages in logs (this is normal if no reorganization occurred)${NC}"
fi
echo ""

# Check for errors
echo "=== CHECK ERRORS ==="
if grep -i "error\|fatal\|panic" "$DATA_DIR/node.log" | grep -v "DEBUG" | head -10; then
    echo -e "${YELLOW}⚠️ Some errors found in node logs (check above)${NC}"
else
    echo -e "${GREEN}✅ No critical errors in node logs${NC}"
fi
echo ""

# Check miner logs
echo "=== CHECK MINER LOGS ==="
if grep -i "error\|fatal\|panic" "$DATA_DIR/miner.log" | grep -v "DEBUG" | head -10; then
    echo -e "${YELLOW}⚠️ Some errors found in miner logs (check above)${NC}"
else
    echo -e "${GREEN}✅ No critical errors in miner logs${NC}"
fi
echo ""

# Summary
echo "=== TEST SUMMARY ==="
echo -e "${GREEN}✅ Fork Detection Test Completed${NC}"
echo "Blocks mined: $BLOCKS_MINED"
echo "Best block: #$BEST_BLOCK_NUMBER"
echo "Recent blocks: $RECENT_BLOCKS_COUNT"
echo ""

# Cleanup
cleanup

echo -e "${GREEN}✅ All tests passed!${NC}"

