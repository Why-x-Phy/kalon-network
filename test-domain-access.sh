#!/bin/bash
# Einfacher Test für Domain-Zugriff vom Browser aus

SERVER_IP="185.133.249.107"
DOMAIN="explorer.kalon-network.com"

echo "=== DOMAIN ZUGRIFF TEST ==="
echo ""

echo "1. DNS-Prüfung..."
DNS_IP=$(dig +short $DOMAIN | head -1)
if [ "$DNS_IP" = "$SERVER_IP" ]; then
    echo "✅ DNS zeigt auf korrekte IP: $DNS_IP"
else
    echo "❌ DNS zeigt auf: $DNS_IP (erwartet: $SERVER_IP)"
fi
echo ""

echo "2. HTTP-Test..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 http://$DOMAIN 2>/dev/null)
if [ "$HTTP_STATUS" = "301" ] || [ "$HTTP_STATUS" = "200" ]; then
    echo "✅ HTTP funktioniert (Status: $HTTP_STATUS)"
else
    echo "❌ HTTP funktioniert nicht (Status: $HTTP_STATUS)"
fi
echo ""

echo "3. HTTPS-Test..."
HTTPS_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 https://$DOMAIN 2>/dev/null)
if [ "$HTTPS_STATUS" = "200" ]; then
    echo "✅ HTTPS funktioniert (Status: $HTTPS_STATUS)"
else
    echo "❌ HTTPS funktioniert nicht (Status: $HTTPS_STATUS)"
fi
echo ""

echo "4. SSL-Zertifikat-Prüfung..."
SSL_INFO=$(echo | openssl s_client -servername $DOMAIN -connect $DOMAIN:443 2>/dev/null | openssl x509 -noout -subject -dates 2>/dev/null)
if [ -n "$SSL_INFO" ]; then
    echo "✅ SSL-Zertifikat vorhanden"
    echo "$SSL_INFO" | head -2
else
    echo "❌ SSL-Zertifikat nicht gefunden"
fi
echo ""

echo "=== TEST ABGESCHLOSSEN ==="
echo ""
echo "WICHTIG:"
echo "────────────────────────────────────────────────"
echo "⚠️ Browser-Warnung bei IP-Zugriff ist NORMAL!"
echo "   → Zertifikat ist für Domain (explorer.kalon-network.com)"
echo "   → Nicht für IP (185.133.249.107)"
echo "   → Das ist korrekt und erwartet!"
echo ""
echo "✅ Wenn HTTPS über Domain Status 200 gibt, funktioniert es!"
echo "   → Browser-Cache leeren (Strg+Shift+R oder Cmd+Shift+R)"
echo "   → In Incognito-Modus testen"
echo "   → Anderen Browser testen"

