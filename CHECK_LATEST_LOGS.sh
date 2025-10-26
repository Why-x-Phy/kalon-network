#!/bin/bash
echo "📊 Latest Address Debug Logs:"
echo "=============================="

echo ""
echo "AddressFromString calls:"
tail -200 node-v2.log | grep "AddressFromString" | tail -10

echo ""
echo "Miner string parsing:"
tail -200 node-v2.log | grep "Miner string\|Parsed address" | tail -15

echo ""
echo "UTXO creation:"
tail -100 node-v2.log | grep "UTXO created" | tail -3
