#!/bin/bash
# Diagnose-Script für RPC-Server Problem

echo "=== RPC-SERVER DIAGNOSE ==="
echo ""

# 1. Prüfe ob Port belegt ist (mit allen Methoden)
echo "1. Port 16316 Status:"
echo "   netstat:"
netstat -tlnp 2>/dev/null | grep 16316 || echo "      Nicht gefunden"
echo "   ss:"
ss -tlnp 2>/dev/null | grep 16316 || echo "      Nicht gefunden"
echo "   lsof:"
lsof -i :16316 2>/dev/null || echo "      Nicht gefunden"
echo ""

# 2. Prüfe Node-Log auf RPC-Fehler
echo "2. Node-Log - RPC-Server Meldungen:"
if [ -f node-quick-test.log ]; then
    grep -i "rpc\|server" node-quick-test.log | grep -v "DEBUG\|🔍" | tail -n 20
else
    echo "   Node-Log nicht gefunden"
fi
echo ""

# 3. Teste RPC-Zugriff
echo "3. RPC-Zugriff testen:"
echo "   localhost:"
curl -s -w "\n   Status: %{http_code}\n" http://localhost:16316/rpc -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getHeight","id":1}' 2>&1 | head -n 5
echo ""
echo "   127.0.0.1:"
curl -s -w "\n   Status: %{http_code}\n" http://127.0.0.1:16316/rpc -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getHeight","id":1}' 2>&1 | head -n 5
echo ""

# 4. Prüfe Node-Prozess
echo "4. Node-Prozess:"
ps aux | grep kalon-node | grep -v grep | head -n 2
echo ""

# 5. Prüfe letzte Node-Log Zeilen
echo "5. Letzte Node-Log Zeilen:"
tail -n 10 node-quick-test.log 2>/dev/null || echo "   Node-Log nicht gefunden"
