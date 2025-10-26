#!/bin/bash
# Check the latest logs for debug information

echo "📊 Latest Debug Logs:"
echo "====================="
echo ""
echo "🔍 Searching for Address parsing logs:"
tail -200 ~/kalon-network/node-v2.log | grep -E "DEBUG.*Address|before copy|after copy|Perfect 20-byte" | tail -20

echo ""
echo "💰 Searching for UTXO creation:"
tail -200 ~/kalon-network/node-v2.log | grep "UTXO created" | tail -5

echo ""
echo "🔍 Searching for Decoded hex:"
tail -200 ~/kalon-network/node-v2.log | grep -E "Decoded hex|Perfect 20-byte" | tail -10
