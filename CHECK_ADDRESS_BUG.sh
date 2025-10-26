#!/bin/bash
echo "🔍 Checking Address Bug..."
echo "========================="

echo ""
echo "📊 Latest UTXO Addresses:"
tail -100 ~/kalon-network/node-v2.log | grep "UTXO created" | tail -3

echo ""
echo "📊 Latest Parsed Addresses:"
tail -100 ~/kalon-network/node-v2.log | grep "Perfect 20-byte\|after copy" | tail -5

echo ""
echo "📊 Check what balance query receives:"
tail -20 ~/kalon-network/node-v2.log | grep "Balance query"

echo ""
echo "📊 All Address logs:"
tail -150 ~/kalon-network/node-v2.log | grep -E "Address.*=|Miner address|Parsed address" | tail -15
