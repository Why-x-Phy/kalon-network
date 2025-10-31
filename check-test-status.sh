#!/bin/bash
# Script zum Prüfen des Test-Status auf dem Server

echo "=== TEST-STATUS PRÜFEN ==="
echo ""

# 1. Prozesse prüfen
echo "1. Laufende Prozesse:"
ps aux | grep -E "kalon-node|kalon-miner|test-quick" | grep -v grep || echo "   Keine Prozesse gefunden"
echo ""

# 2. Ports prüfen
echo "2. Ports:"
netstat -tlnp 2>/dev/null | grep -E "16316|17335" || echo "   Ports 16316/17335 nicht belegt"
echo ""

# 3. Node erreichbar?
echo "3. Node erreichbar?"
HEIGHT=$(curl -s http://localhost:16316/rpc -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getHeight","id":1}' 2>/dev/null | jq -r .result 2>/dev/null || echo "N/A")
if [ "$HEIGHT" != "N/A" ] && [ "$HEIGHT" != "null" ]; then
    echo "   ✅ Node läuft (Höhe: $HEIGHT)"
else
    echo "   ❌ Node nicht erreichbar"
fi
echo ""

# 4. Node-Log prüfen
echo "4. Node-Log (letzte 20 Zeilen):"
if [ -f node-quick-test.log ]; then
    tail -n 20 node-quick-test.log
else
    echo "   Node-Log nicht gefunden"
fi
echo ""

# 5. Miner-Log prüfen
echo "5. Miner-Log - Fehler (letzte 30 Zeilen):"
if [ -f miner-quick-test.log ]; then
    tail -n 30 miner-quick-test.log | grep -E "Failed|Error|error|invalid" | tail -n 15 || tail -n 30 miner-quick-test.log | tail -n 15
else
    echo "   Miner-Log nicht gefunden"
fi
echo ""

# 6. Test-Output prüfen
echo "6. Test-Output (letzte 30 Zeilen):"
if [ -f test-output.log ]; then
    tail -n 30 test-output.log
else
    echo "   Test-Output nicht gefunden"
fi
