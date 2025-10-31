#!/bin/bash
# Prüft Test-Status auf Test-Server

echo "=== TEST-STATUS PRÜFEN ==="
echo ""

cd ~/kalon-network || {
    echo "❌ Verzeichnis ~/kalon-network nicht gefunden!"
    exit 1
}

# 1. Prüfe ob Test-Prozess läuft
echo "1. Test-Prozess Status:"
TEST_PID=$(pgrep -f "test-quick-10min.sh" | head -n 1)
if [ -n "$TEST_PID" ]; then
    echo "   ✅ Test läuft (PID: $TEST_PID)"
else
    echo "   ❌ Test läuft nicht"
fi
echo ""

# 2. Prüfe Node-Prozess
echo "2. Node-Prozess Status:"
NODE_PID=$(pgrep -f "kalon-node-v2" | head -n 1)
if [ -n "$NODE_PID" ]; then
    echo "   ✅ Node läuft (PID: $NODE_PID)"
else
    echo "   ❌ Node läuft nicht"
fi
echo ""

# 3. Prüfe Miner-Prozess
echo "3. Miner-Prozess Status:"
MINER_PID=$(pgrep -f "kalon-miner-v2" | head -n 1)
if [ -n "$MINER_PID" ]; then
    echo "   ✅ Miner läuft (PID: $MINER_PID)"
else
    echo "   ❌ Miner läuft nicht"
fi
echo ""

# 4. Prüfe Test-Output-Log
echo "4. Test-Output-Log (letzte 30 Zeilen):"
if [ -f test-output.log ]; then
    tail -n 30 test-output.log
else
    echo "   ❌ test-output.log nicht gefunden"
fi
echo ""

# 5. Prüfe Node-Log auf Fehler
echo "5. Node-Log - Fehler (letzte 20 Zeilen):"
if [ -f node-quick-test.log ]; then
    tail -n 20 node-quick-test.log | grep -i "error\|failed\|panic" || echo "   Keine Fehler gefunden"
else
    echo "   ❌ node-quick-test.log nicht gefunden"
fi
echo ""

# 6. Prüfe ob Port belegt ist
echo "6. Port 16316 Status:"
if command -v ss >/dev/null 2>&1; then
    ss -tlnp 2>/dev/null | grep 16316 || echo "   ❌ Port 16316 nicht belegt"
elif command -v netstat >/dev/null 2>&1; then
    netstat -tlnp 2>/dev/null | grep 16316 || echo "   ❌ Port 16316 nicht belegt"
else
    echo "   ⚠️ Kein Tool zum Prüfen von Ports gefunden"
fi
echo ""

echo "=== STATUS PRÜFUNG ABGESCHLOSSEN ==="
