#!/bin/bash
# Monitoring-Script für den Langzeit-Test

while true; do
    clear
    echo "=== TEST-MONITORING ==="
    echo "Zeit: $(date '+%H:%M:%S')"
    echo ""
    
    # Check processes
    echo "Prozesse:"
    ps aux | grep -E "kalon-node|kalon-miner" | grep -v grep | head -n 3
    echo ""
    
    # Check height
    HEIGHT=$(curl -s http://localhost:16316/rpc -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getHeight","id":1}' 2>/dev/null | jq -r .result 2>/dev/null || echo "N/A")
    echo "Aktuelle Höhe: $HEIGHT"
    
    # Check last log entries
    echo ""
    echo "Node-Log (letzte 3 Zeilen):"
    tail -n 3 node-comprehensive-test.log 2>/dev/null || echo "Kein Log"
    echo ""
    
    echo "Miner-Log (letzte 3 Zeilen):"
    tail -n 3 miner-comprehensive-test.log 2>/dev/null | grep -E "Block|Failed|submitted" | tail -n 3 || echo "Kein Log"
    echo ""
    
    sleep 30
done
