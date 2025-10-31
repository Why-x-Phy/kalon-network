#!/bin/bash
# Vollständiges Diagnose-Script für Test-Server

echo "=== VOLLSTÄNDIGE DIAGNOSE TEST-SERVER ==="
echo ""

# 1. Prüfe ob Port wirklich frei ist (alle Methoden)
echo "1. PORT 16316 STATUS (alle Methoden):"
echo "   lsof:"
lsof -i :16316 2>/dev/null || echo "      Port nicht belegt (lsof)"
echo ""
echo "   fuser:"
fuser 16316/tcp 2>/dev/null || echo "      Port nicht belegt (fuser)"
echo ""
echo "   ss:"
ss -tlnp 2>/dev/null | grep 16316 || echo "      Port nicht belegt (ss)"
echo ""
echo "   netstat:"
netstat -tlnp 2>/dev/null | grep 16316 || echo "      Port nicht belegt (netstat)"
echo ""

# 2. Prüfe Node-Log auf 'listen tcp' Fehler
echo "2. NODE-LOG - LISTEN/BIND FEHLER:"
if [ -f node-quick-test.log ]; then
    grep -i 'listen tcp\|bind\|address already in use\|error' node-quick-test.log | head -n 30
else
    echo "   node-quick-test.log nicht gefunden"
fi
echo ""

# 3. Prüfe ob Node-Prozess läuft
echo "3. NODE-PROZESS:"
ps aux | grep kalon-node | grep -v grep || echo "   Kein Node-Prozess gefunden"
echo ""

# 4. Prüfe Node-Log komplett auf RPC/Server
echo "4. NODE-LOG - RPC/SERVER MELDUNGEN:"
if [ -f node-quick-test.log ]; then
    tail -n 100 node-quick-test.log | grep -i 'rpc\|server\|starting' | tail -n 30
else
    echo "   node-quick-test.log nicht gefunden"
fi
echo ""

# 5. Prüfe Node-Log auf erste Zeilen (Startup)
echo "5. NODE-LOG - STARTUP (erste 30 Zeilen):"
if [ -f node-quick-test.log ]; then
    head -n 30 node-quick-test.log
else
    echo "   node-quick-test.log nicht gefunden"
fi
echo ""

# 6. Prüfe Node-Log auf letzte Zeilen (aktuelle Status)
echo "6. NODE-LOG - AKTUELLE STATUS (letzte 30 Zeilen):"
if [ -f node-quick-test.log ]; then
    tail -n 30 node-quick-test.log
else
    echo "   node-quick-test.log nicht gefunden"
fi
echo ""

# 7. Teste RPC-Zugriff
echo "7. RPC-ZUGRIFF TEST:"
echo "   localhost:16316:"
curl -s -w "\n   HTTP Status: %{http_code}\n" http://localhost:16316/rpc -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getHeight","id":1}' 2>&1 | head -n 5
echo ""
echo "   127.0.0.1:16316:"
curl -s -w "\n   HTTP Status: %{http_code}\n" http://127.0.0.1:16316/rpc -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getHeight","id":1}' 2>&1 | head -n 5
echo ""

# 8. Prüfe Go-Version
echo "8. GO-VERSION:"
go version 2>/dev/null || echo "   Go nicht gefunden"
echo ""

# 9. Prüfe Firewall (falls verfügbar)
echo "9. FIREWALL STATUS:"
if command -v ufw >/dev/null 2>&1; then
    ufw status | grep 16316 || echo "   Keine UFW-Regel für 16316"
elif command -v firewall-cmd >/dev/null 2>&1; then
    firewall-cmd --list-ports 2>/dev/null | grep 16316 || echo "   Keine Firewall-Regel für 16316"
else
    echo "   Keine Firewall-Tools gefunden"
fi
echo ""

# 10. Prüfe ob Binary existiert und ausführbar ist
echo "10. BINARY STATUS:"
if [ -f build-v2/kalon-node-v2 ]; then
    ls -lh build-v2/kalon-node-v2
    file build-v2/kalon-node-v2
    echo "   Ausführbar: $([ -x build-v2/kalon-node-v2 ] && echo "Ja" || echo "Nein")"
else
    echo "   Binary nicht gefunden!"
fi
echo ""

echo "=== DIAGNOSE ABGESCHLOSSEN ==="
