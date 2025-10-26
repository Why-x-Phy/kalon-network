#!/bin/bash
echo "🔍 Checking fixed Address parsing..."
echo "===================================="

echo ""
echo "AddressFromString Logs:"
tail -100 node-v2.log | grep "AddressFromString" | tail -10

echo ""
echo "UTXO creation:"
tail -50 node-v2.log | grep "UTXO created" | tail -5

echo ""
echo "Check if addresses match:"
tail -100 node-v2.log | grep -E "Miner address|Parsed address|UTXO created" | tail -10
