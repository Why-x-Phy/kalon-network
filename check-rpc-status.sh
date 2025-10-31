#!/bin/bash
# Prüft RPC-Server Status auf Test-Server

echo "=== RPC-SERVER STATUS PRÜFEN ==="
echo ""

# 1. Prüfe ob Node-Prozess läuft
echo "1. Node-Prozess:"
ps aux | grep kalon-node | grep -v grep || echo "   Node läuft nicht"
echo ""

# 2. Prüfe Port (mit ss, da netstat möglicherweise nicht installiert ist)
echo "2. Port 16316 Status:"
ss -tlnp 2>/dev/null | grep 16316 || echo "   Port nicht belegt"
echo ""

# 3. Teste RPC-Zugriff
echo "3. RPC-Zugriff Test:"
curl -s -w "\n   HTTP Status: %{http_code}\n" http://localhost:16316/rpc -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getHeight","id":1}' 2>&1 | head -n 5
echo ""

# 4. Prüfe Node-Log auf RPC-Server Meldungen
echo "4. Node-Log - RPC/Server:"
if [ -f node-quick-test.log ]; then
    tail -n 50 node-quick-test.log | grep -i "rpc\|server\|starting" | tail -n 10
else
    echo "   Node-Log nicht gefunden"
fi
echo ""

# 5. Prüfe Node-Log auf Fehler
echo "5. Node-Log - Fehler:"
if [ -f node-quick-test.log ]; then
    tail -n 100 node-quick-test.log | grep -i "error\|failed\|panic" | tail -n 10 || echo "   Keine Fehler gefunden"
else
    echo "   Node-Log nicht gefunden"
fi
echo ""

echo "=== STATUS PRÜFUNG ABGESCHLOSSEN ==="
