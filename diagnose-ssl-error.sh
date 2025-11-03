#!/bin/bash
# Detaillierte Diagnose für ERR_SSL_PROTOCOL_ERROR

DOMAIN="explorer.kalon-network.com"
SERVER_IP="185.133.249.107"

echo "=== DETAILLIERTE SSL-DIAGNOSE ==="
echo ""

echo "1. Teste SSL-Verbindung mit openssl..."
echo "────────────────────────────────────────────────"
echo | openssl s_client -servername $DOMAIN -connect $DOMAIN:443 2>&1 | grep -E "(verify|error|Alert|protocol|Cipher)" | head -10
echo ""

echo "2. Teste HTTPS mit curl (verbose)..."
echo "────────────────────────────────────────────────"
curl -v https://$DOMAIN 2>&1 | grep -E "(SSL|TLS|error|protocol|certificate)" | head -10
echo ""

echo "3. Teste HTTPS mit curl (HTTP/1.1, kein HTTP/2)..."
echo "────────────────────────────────────────────────"
curl --http1.1 -v https://$DOMAIN 2>&1 | grep -E "(SSL|TLS|error|protocol|certificate)" | head -10
echo ""

echo "4. Prüfe nginx SSL-Konfiguration..."
echo "────────────────────────────────────────────────"
sudo cat /etc/nginx/sites-enabled/explorer 2>/dev/null | grep -E "(ssl_protocols|ssl_ciphers|listen 443)" | head -10
echo ""

echo "5. Prüfe Zertifikat-Dateien..."
echo "────────────────────────────────────────────────"
CERT_PATH="/etc/letsencrypt/live/explorer.kalon-network.com/fullchain.pem"
KEY_PATH="/etc/letsencrypt/live/explorer.kalon-network.com/privkey.pem"
CHAIN_PATH="/etc/letsencrypt/live/explorer.kalon-network.com/chain.pem"

if [ -f "$CERT_PATH" ]; then
    echo "✅ fullchain.pem vorhanden"
    ls -lh "$CERT_PATH"
else
    echo "❌ fullchain.pem nicht gefunden"
fi

if [ -f "$KEY_PATH" ]; then
    echo "✅ privkey.pem vorhanden"
    ls -lh "$KEY_PATH"
else
    echo "❌ privkey.pem nicht gefunden"
fi

if [ -f "$CHAIN_PATH" ]; then
    echo "✅ chain.pem vorhanden"
    ls -lh "$CHAIN_PATH"
else
    echo "❌ chain.pem nicht gefunden"
fi
echo ""

echo "6. Prüfe nginx Error-Log (letzte 20 Zeilen)..."
echo "────────────────────────────────────────────────"
sudo tail -20 /var/log/nginx/error.log 2>/dev/null | grep -E "(SSL|TLS|error|protocol)" | head -10
echo ""

echo "7. Teste verschiedene SSL-Versionen..."
echo "────────────────────────────────────────────────"
for version in tls1_2 tls1_3; do
    echo "Teste $version..."
    echo | openssl s_client -servername $DOMAIN -connect $DOMAIN:443 -$version 2>&1 | grep -E "(verify|error|Alert)" | head -3
    echo ""
done

echo "=== DIAGNOSE ABGESCHLOSSEN ==="

