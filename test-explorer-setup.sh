#!/bin/bash
# Test-Script für Explorer-Setup

echo "=== EXPLORER SETUP TEST ==="
echo ""

# 1. Prüfe nginx Status
echo "1. Prüfe nginx Status..."
if systemctl is-active --quiet nginx; then
    echo "   ✅ nginx läuft"
else
    echo "   ❌ nginx läuft NICHT!"
    exit 1
fi
echo ""

# 2. Prüfe Node Status
echo "2. Prüfe Node Status..."
if pgrep -f "kalon-node-v2" > /dev/null; then
    echo "   ✅ Node läuft"
    NODE_PID=$(pgrep -f "kalon-node-v2")
    echo "   PID: $NODE_PID"
else
    echo "   ❌ Node läuft NICHT!"
    exit 1
fi
echo ""

# 3. Prüfe Node RPC (localhost)
echo "3. Prüfe Node RPC (localhost)..."
HEIGHT=$(curl -s http://localhost:16316/rpc -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getHeight","id":1}' | grep -o '"result":[0-9]*' | cut -d: -f2)
if [ -n "$HEIGHT" ]; then
    echo "   ✅ Node RPC erreichbar (Height: $HEIGHT)"
else
    echo "   ❌ Node RPC nicht erreichbar!"
    exit 1
fi
echo ""

# 4. Prüfe nginx Explorer-Dateien
echo "4. Prüfe Explorer-Dateien..."
if [ -f "/var/www/explorer/index.html" ]; then
    echo "   ✅ Explorer-Dateien vorhanden"
else
    echo "   ❌ Explorer-Dateien nicht gefunden!"
    exit 1
fi
echo ""

# 5. Prüfe nginx RPC-Proxy
echo "5. Prüfe nginx RPC-Proxy..."
PROXY_HEIGHT=$(curl -s http://localhost/rpc -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getHeight","id":1}' | grep -o '"result":[0-9]*' | cut -d: -f2)
if [ -n "$PROXY_HEIGHT" ]; then
    echo "   ✅ nginx RPC-Proxy funktioniert (Height: $PROXY_HEIGHT)"
else
    echo "   ❌ nginx RPC-Proxy funktioniert NICHT!"
    exit 1
fi
echo ""

# 6. Prüfe HTTPS (falls Zertifikat vorhanden)
echo "6. Prüfe HTTPS..."
if [ -f "/etc/letsencrypt/live/explorer.kalon-network.com/fullchain.pem" ]; then
    echo "   ✅ Let's Encrypt Zertifikat vorhanden"
    HTTPS_HEIGHT=$(curl -s -k https://localhost/rpc -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getHeight","id":1}' | grep -o '"result":[0-9]*' | cut -d: -f2)
    if [ -n "$HTTPS_HEIGHT" ]; then
        echo "   ✅ HTTPS funktioniert (Height: $HTTPS_HEIGHT)"
    else
        echo "   ⚠️ HTTPS-Proxy prüfen (möglicherweise nginx neu laden nötig)"
    fi
else
    echo "   ⚠️ Let's Encrypt Zertifikat nicht gefunden"
fi
echo ""

# 7. Prüfe DNS
echo "7. Prüfe DNS..."
DNS_IP=$(dig +short explorer.kalon-network.com | head -1)
if [ "$DNS_IP" = "185.133.249.107" ]; then
    echo "   ✅ DNS zeigt auf korrekte IP: $DNS_IP"
else
    echo "   ⚠️ DNS zeigt auf: $DNS_IP (erwartet: 185.133.249.107)"
fi
echo ""

echo "=== TEST ABGESCHLOSSEN ==="
echo ""
echo "Nächste Schritte:"
echo "1. Öffne im Browser: https://explorer.kalon-network.com"
echo "2. Prüfe ob Explorer 'ONLINE' zeigt"
echo "3. Prüfe ob Block-Height angezeigt wird"
echo "4. Prüfe Browser-Konsole (F12) auf Fehler"

