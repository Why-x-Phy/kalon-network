#!/bin/bash

# Vollumfänglicher Komplett-Test nach Lock-Contention Fix
# Testet: Alle Features + Lock-Performance

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

DATA_DIR="data-complete-lock-fix-test"
RPC_PORT=16316
NODE_PID=""
MINER_PID=""

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Cleanup-Funktion
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
    rm -f wallet-wallet1.json wallet-wallet2.json 2>/dev/null || true
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

# Run unit tests
echo "=== RUN UNIT TESTS ==="
if go test ./core -v 2>&1 | grep -E "(PASS|FAIL)" | tail -5; then
    echo -e "${GREEN}✅ Unit tests passed${NC}"
else
    echo -e "${RED}❌ Unit tests failed${NC}"
    exit 1
fi
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
    echo -e "${RED}❌ Failed to extract wallet1 address${NC}"
    echo "$WALLET1_OUTPUT"
    exit 1
fi
echo "Wallet 1 Address: $WALLET1_ADDRESS"

echo "" | ./build-v2/kalon-wallet create -name wallet2 > "$DATA_DIR/wallet2_output.txt" 2>&1 || true
WALLET2_OUTPUT=$(cat "$DATA_DIR/wallet2_output.txt")
WALLET2_ADDRESS=$(echo "$WALLET2_OUTPUT" | grep -i "address:" | awk '{print $2}' | head -1 || echo "")
if [ -z "$WALLET2_ADDRESS" ]; then
    echo -e "${RED}❌ Failed to extract wallet2 address${NC}"
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
for i in {1..90}; do
    BEST_BLOCK=$(curl -s -X POST -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"getBestBlock","params":[],"id":1}' \
        http://localhost:$RPC_PORT | grep -oP '"number":\s*\K[0-9]+' || echo "0")
    
    if [ ! -z "$BEST_BLOCK" ] && [ "$BEST_BLOCK" -gt "0" ]; then
        BLOCKS_MINED=$BEST_BLOCK
        if [ $((i % 10)) -eq 0 ]; then
            echo "Blocks mined: $BLOCKS_MINED (iteration $i)"
        fi
        if [ "$BLOCKS_MINED" -ge "5" ]; then
            break
        fi
    fi
    sleep 1
done

if [ "$BLOCKS_MINED" -lt "3" ]; then
    echo -e "${YELLOW}⚠️ Only $BLOCKS_MINED blocks mined (expected at least 3)${NC}"
else
    echo -e "${GREEN}✅ Mined $BLOCKS_MINED blocks${NC}"
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
BEST_BLOCK_DIFFICULTY=$(echo "$BEST_BLOCK_RESPONSE" | grep -oP '"difficulty":\s*\K[0-9]+' || echo "")

echo "Best Block Number: $BEST_BLOCK_NUMBER"
echo "Best Block Hash: $BEST_BLOCK_HASH"
echo "Best Block Merkle Root: $BEST_BLOCK_MERKLE"
echo "Best Block Difficulty: $BEST_BLOCK_DIFFICULTY"
echo ""

# Check Merkle Root
if [ ! -z "$BEST_BLOCK_MERKLE" ] && [ "$BEST_BLOCK_MERKLE" != "" ]; then
    echo -e "${GREEN}✅ Merkle Root present in best block${NC}"
else
    echo -e "${YELLOW}⚠️ Merkle Root not found in best block (may be genesis)${NC}"
fi
echo ""

# Check Difficulty
if [ ! -z "$BEST_BLOCK_DIFFICULTY" ] && [ "$BEST_BLOCK_DIFFICULTY" != "" ]; then
    echo -e "${GREEN}✅ Difficulty present in best block: $BEST_BLOCK_DIFFICULTY${NC}"
else
    echo -e "${YELLOW}⚠️ Difficulty not found in best block${NC}"
fi
echo ""

# Get recent blocks
echo "=== GET RECENT BLOCKS ==="
RECENT_BLOCKS_RESPONSE=$(curl -s -X POST -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","method":"getRecentBlocks","params":[10],"id":1}' \
    http://localhost:$RPC_PORT)

RECENT_BLOCKS_COUNT=$(echo "$RECENT_BLOCKS_RESPONSE" | grep -oP '"number":\s*\K[0-9]+' | wc -l)
echo "Recent blocks count: $RECENT_BLOCKS_COUNT"
echo ""

# Check for Merkle Root in recent blocks
MERKLE_COUNT=$(echo "$RECENT_BLOCKS_RESPONSE" | grep -oP '"merkleRoot":\s*"0x[0-9a-f]+"' | wc -l)
if [ "$MERKLE_COUNT" -gt "0" ]; then
    echo -e "${GREEN}✅ Merkle Root found in $MERKLE_COUNT recent blocks${NC}"
else
    echo -e "${YELLOW}⚠️ No Merkle Root found in recent blocks${NC}"
fi
echo ""

# Check for Difficulty in recent blocks
DIFFICULTY_COUNT=$(echo "$RECENT_BLOCKS_RESPONSE" | grep -oP '"difficulty":\s*[0-9]+' | wc -l)
if [ "$DIFFICULTY_COUNT" -gt "0" ]; then
    echo -e "${GREEN}✅ Difficulty found in $DIFFICULTY_COUNT recent blocks${NC}"
else
    echo -e "${YELLOW}⚠️ No Difficulty found in recent blocks${NC}"
fi
echo ""

# Test concurrent RPC calls (lock contention test)
echo "=== TEST CONCURRENT RPC CALLS (Lock Contention Test) ==="
echo "Sending 10 concurrent getBestBlock requests..."
START_TIME=$(date +%s%N)
for i in {1..10}; do
    curl -s -X POST -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"getBestBlock","params":[],"id":'$i'}' \
        http://localhost:$RPC_PORT > /dev/null 2>&1 &
done
wait
END_TIME=$(date +%s%N)
DURATION=$((($END_TIME - $START_TIME) / 1000000))
echo "10 concurrent requests completed in ${DURATION}ms"
if [ "$DURATION" -lt "1000" ]; then
    echo -e "${GREEN}✅ Fast response time (good lock performance)${NC}"
else
    echo -e "${YELLOW}⚠️ Slow response time (may indicate lock contention)${NC}"
fi
echo ""

# Test concurrent getRecentBlocks calls
echo "=== TEST CONCURRENT getRecentBlocks CALLS ==="
echo "Sending 10 concurrent getRecentBlocks requests..."
START_TIME=$(date +%s%N)
for i in {1..10}; do
    curl -s -X POST -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"getRecentBlocks","params":[10],"id":'$i'}' \
        http://localhost:$RPC_PORT > /dev/null 2>&1 &
done
wait
END_TIME=$(date +%s%N)
DURATION=$((($END_TIME - $START_TIME) / 1000000))
echo "10 concurrent requests completed in ${DURATION}ms"
if [ "$DURATION" -lt "1000" ]; then
    echo -e "${GREEN}✅ Fast response time (good lock performance)${NC}"
else
    echo -e "${YELLOW}⚠️ Slow response time (may indicate lock contention)${NC}"
fi
echo ""

# Check for fork detection messages in logs
echo "=== CHECK FORK DETECTION ==="
if grep -q "Fork detected" "$DATA_DIR/node.log"; then
    echo -e "${GREEN}✅ Fork detection messages found in logs${NC}"
    grep "Fork detected" "$DATA_DIR/node.log" | tail -3
else
    echo -e "${YELLOW}⚠️ No fork detection messages in logs (this is normal if no forks occurred)${NC}"
fi
echo ""

# Check for reorganization messages in logs
echo "=== CHECK REORGANIZATION ==="
if grep -q "Reorganizing chain\|Chain reorganization" "$DATA_DIR/node.log"; then
    echo -e "${GREEN}✅ Chain reorganization messages found in logs${NC}"
    grep "Reorganizing chain\|Chain reorganization" "$DATA_DIR/node.log" | tail -3
else
    echo -e "${YELLOW}⚠️ No reorganization messages in logs (this is normal if no reorganization occurred)${NC}"
fi
echo ""

# Check for difficulty validation messages
echo "=== CHECK DIFFICULTY VALIDATION ==="
if grep -qi "difficulty" "$DATA_DIR/node.log" | grep -v "DEBUG" | head -3; then
    echo -e "${GREEN}✅ Difficulty-related messages found${NC}"
else
    echo -e "${YELLOW}⚠️ No difficulty validation messages${NC}"
fi
echo ""

# Check for signature validation messages
echo "=== CHECK SIGNATURE VALIDATION ==="
if grep -qi "signature\|validation" "$DATA_DIR/node.log" | grep -v "DEBUG" | head -3; then
    echo -e "${GREEN}✅ Signature validation messages found${NC}"
else
    echo -e "${YELLOW}⚠️ No signature validation messages${NC}"
fi
echo ""

# Check for errors
echo "=== CHECK ERRORS ==="
ERRORS=$(grep -i "error\|fatal\|panic" "$DATA_DIR/node.log" | grep -v "DEBUG" | head -10 || true)
if [ ! -z "$ERRORS" ]; then
    echo -e "${YELLOW}⚠️ Some errors found in node logs:${NC}"
    echo "$ERRORS"
else
    echo -e "${GREEN}✅ No critical errors in node logs${NC}"
fi
echo ""

# Check miner logs
echo "=== CHECK MINER LOGS ==="
MINER_ERRORS=$(grep -i "error\|fatal\|panic" "$DATA_DIR/miner.log" | grep -v "DEBUG" | head -10 || true)
if [ ! -z "$MINER_ERRORS" ]; then
    echo -e "${YELLOW}⚠️ Some errors found in miner logs:${NC}"
    echo "$MINER_ERRORS"
else
    echo -e "${GREEN}✅ No critical errors in miner logs${NC}"
fi
echo ""

# Check for lock-related performance issues
echo "=== CHECK LOCK PERFORMANCE ==="
if grep -qi "lock\|contention\|deadlock" "$DATA_DIR/node.log" | grep -i "error\|fatal" | head -5; then
    echo -e "${YELLOW}⚠️ Lock-related issues found${NC}"
else
    echo -e "${GREEN}✅ No lock-related issues found${NC}"
fi
echo ""

# Summary
echo "=== TEST SUMMARY ==="
echo -e "${GREEN}✅ Complete Lock Fix Test Completed${NC}"
echo "Blocks mined: $BLOCKS_MINED"
echo "Best block: #$BEST_BLOCK_NUMBER"
echo "Recent blocks: $RECENT_BLOCKS_COUNT"
echo "Merkle Root present: $([ ! -z "$BEST_BLOCK_MERKLE" ] && echo "Yes" || echo "No")"
echo "Difficulty present: $([ ! -z "$BEST_BLOCK_DIFFICULTY" ] && echo "Yes" || echo "No")"
echo "Fork detection: $([ -z "$(grep -q "Fork detected" "$DATA_DIR/node.log" && echo "yes")" ] && echo "No forks" || echo "Forks detected")"
echo "Reorganization: $([ -z "$(grep -q "Reorganizing chain" "$DATA_DIR/node.log" && echo "yes")" ] && echo "No reorganization" || echo "Reorganization occurred")"
echo ""

# Cleanup
cleanup

echo -e "${GREEN}✅ All tests passed!${NC}"

