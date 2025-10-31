#!/bin/bash
# Wrapper für test-quick-10min.sh mit nohup

cd ~/kalon-network || exit 1

# Cleanup first
killall -9 kalon-node-v2 kalon-miner-v2 2>/dev/null || true
pkill -9 -f test-quick 2>/dev/null || true
sleep 2

# Start with nohup to prevent termination
nohup ./test-quick-10min.sh > test-output.log 2>&1 &
TEST_PID=$!

echo "✅ Test gestartet (PID: $TEST_PID)"
echo "Monitor mit: tail -f test-output.log"
echo "Status prüfen: ./check-rpc-status.sh"
