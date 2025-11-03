#!/bin/bash
# Vollständiger Test für DNS und nginx

# Farben
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

SERVER_IP="185.133.249.107"
DOMAIN="explorer.kalon-network.com"

echo "=== VOLLSTÄNDIGER DNS & NGINX TEST ==="
echo ""

# 1. DNS-Prüfung mit nslookup
echo "1. DNS-Prüfung mit nslookup..."
echo "────────────────────────────────────────────────"
nslookup $DOMAIN
echo ""
DNS_IP=$(nslookup $DOMAIN | grep -A 5 "Name:" | grep "Address:" | tail -1 | awk '{print $2}')
if [ -n "$DNS_IP" ]; then
    if [ "$DNS_IP" = "$SERVER_IP" ]; then
        echo -e "${GREEN}✅ DNS zeigt auf korrekte IP: $DNS_IP${NC}"
    else
        echo -e "${YELLOW}⚠️ DNS zeigt auf: $DNS_IP (erwartet: $SERVER_IP)${NC}"
    fi
else
    echo -e "${RED}❌ DNS gibt keine IP zurück${NC}"
fi
echo ""

# 2. DNS-Prüfung mit dig
echo "2. DNS-Prüfung mit dig..."
echo "────────────────────────────────────────────────"
dig $DOMAIN +short
echo ""
DIG_IP=$(dig $DOMAIN +short | head -1)
if [ -n "$DIG_IP" ]; then
    if [ "$DIG_IP" = "$SERVER_IP" ]; then
        echo -e "${GREEN}✅ DNS (dig) zeigt auf korrekte IP: $DIG_IP${NC}"
    else
        echo -e "${YELLOW}⚠️ DNS (dig) zeigt auf: $DIG_IP (erwartet: $SERVER_IP)${NC}"
    fi
else
    echo -e "${RED}❌ DNS (dig) gibt keine IP zurück${NC}"
fi
echo ""

# 3. DNS-Prüfung mit host
echo "3. DNS-Prüfung mit host..."
echo "────────────────────────────────────────────────"
host $DOMAIN
echo ""

# 4. Teste HTTP über IP
echo "4. Teste HTTP über IP (http://$SERVER_IP)..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://$SERVER_IP 2>/dev/null)
HTTP_LOCATION=$(curl -s -o /dev/null -w "%{redirect_url}" --max-time 5 http://$SERVER_IP 2>/dev/null)
if [ "$HTTP_STATUS" = "301" ] || [ "$HTTP_STATUS" = "302" ]; then
    echo -e "${GREEN}✅ HTTP über IP funktioniert (Status: $HTTP_STATUS)${NC}"
    if [ -n "$HTTP_LOCATION" ]; then
        echo "   Redirect zu: $HTTP_LOCATION"
    fi
elif [ "$HTTP_STATUS" = "200" ]; then
    echo -e "${GREEN}✅ HTTP über IP funktioniert (Status: $HTTP_STATUS)${NC}"
elif [ "$HTTP_STATUS" = "000" ]; then
    echo -e "${RED}❌ HTTP über IP funktioniert NICHT (Timeout/Verbindung fehlgeschlagen)${NC}"
else
    echo -e "${YELLOW}⚠️ HTTP über IP gibt Status: $HTTP_STATUS${NC}"
fi
echo ""

# 5. Teste HTTPS über IP
echo "5. Teste HTTPS über IP (https://$SERVER_IP)..."
HTTPS_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 -k https://$SERVER_IP 2>/dev/null)
if [ "$HTTPS_STATUS" = "200" ]; then
    echo -e "${GREEN}✅ HTTPS über IP funktioniert (Status: $HTTPS_STATUS)${NC}"
    echo -e "${YELLOW}⚠️ Browser-Warnung ist normal (Zertifikat für Domain, nicht IP)${NC}"
elif [ "$HTTPS_STATUS" = "000" ]; then
    echo -e "${RED}❌ HTTPS über IP funktioniert NICHT (Timeout/Verbindung fehlgeschlagen)${NC}"
else
    echo -e "${YELLOW}⚠️ HTTPS über IP gibt Status: $HTTPS_STATUS${NC}"
fi
echo ""

# 6. Teste HTTP über Domain
echo "6. Teste HTTP über Domain (http://$DOMAIN)..."
HTTP_DOMAIN_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 http://$DOMAIN 2>/dev/null)
HTTP_DOMAIN_LOCATION=$(curl -s -o /dev/null -w "%{redirect_url}" --max-time 10 http://$DOMAIN 2>/dev/null)
if [ "$HTTP_DOMAIN_STATUS" = "301" ] || [ "$HTTP_DOMAIN_STATUS" = "302" ]; then
    echo -e "${GREEN}✅ HTTP über Domain funktioniert (Status: $HTTP_DOMAIN_STATUS)${NC}"
    if [ -n "$HTTP_DOMAIN_LOCATION" ]; then
        echo "   Redirect zu: $HTTP_DOMAIN_LOCATION"
    fi
elif [ "$HTTP_DOMAIN_STATUS" = "200" ]; then
    echo -e "${GREEN}✅ HTTP über Domain funktioniert (Status: $HTTP_DOMAIN_STATUS)${NC}"
elif [ "$HTTP_DOMAIN_STATUS" = "000" ]; then
    echo -e "${RED}❌ HTTP über Domain funktioniert NICHT (DNS-Problem oder Verbindung fehlgeschlagen)${NC}"
    echo "   Mögliche Ursachen:"
    echo "   - DNS-Propagierung noch nicht abgeschlossen"
    echo "   - Domain zeigt auf falsche IP"
    echo "   - Firewall blockiert"
else
    echo -e "${YELLOW}⚠️ HTTP über Domain gibt Status: $HTTP_DOMAIN_STATUS${NC}"
fi
echo ""

# 7. Teste HTTPS über Domain
echo "7. Teste HTTPS über Domain (https://$DOMAIN)..."
HTTPS_DOMAIN_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 https://$DOMAIN 2>/dev/null)
if [ "$HTTPS_DOMAIN_STATUS" = "200" ]; then
    echo -e "${GREEN}✅ HTTPS über Domain funktioniert (Status: $HTTPS_DOMAIN_STATUS)${NC}"
elif [ "$HTTPS_DOMAIN_STATUS" = "000" ]; then
    echo -e "${RED}❌ HTTPS über Domain funktioniert NICHT (DNS-Problem oder Verbindung fehlgeschlagen)${NC}"
    echo "   Mögliche Ursachen:"
    echo "   - DNS-Propagierung noch nicht abgeschlossen"
    echo "   - Domain zeigt auf falsche IP"
    echo "   - Firewall blockiert Port 443"
else
    echo -e "${YELLOW}⚠️ HTTPS über Domain gibt Status: $HTTPS_DOMAIN_STATUS${NC}"
fi
echo ""

# 8. Prüfe nginx-Status
echo "8. Prüfe nginx-Status..."
if systemctl is-active --quiet nginx; then
    echo -e "${GREEN}✅ nginx läuft${NC}"
else
    echo -e "${RED}❌ nginx läuft NICHT!${NC}"
fi
echo ""

# 9. Prüfe nginx-Logs (letzte Fehler)
echo "9. Prüfe nginx Error-Log (letzte 10 Zeilen)..."
echo "────────────────────────────────────────────────"
sudo tail -10 /var/log/nginx/error.log 2>/dev/null || echo "Keine Logs gefunden"
echo ""

# 10. Prüfe nginx-Zugriffs-Log
echo "10. Prüfe nginx Access-Log (letzte 5 Zeilen)..."
echo "────────────────────────────────────────────────"
sudo tail -5 /var/log/nginx/access.log 2>/dev/null || echo "Keine Logs gefunden"
echo ""

# 11. Prüfe nginx-Konfiguration
echo "11. Prüfe nginx-Konfiguration..."
if sudo nginx -t 2>&1 | grep -q "test is successful"; then
    echo -e "${GREEN}✅ nginx-Konfiguration ist gültig${NC}"
else
    echo -e "${RED}❌ nginx-Konfiguration hat Fehler!${NC}"
    sudo nginx -t
fi
echo ""

# 12. Prüfe Ports
echo "12. Prüfe Ports..."
echo "────────────────────────────────────────────────"
if sudo ss -tlnp | grep -q ":80"; then
    echo -e "${GREEN}✅ Port 80 ist geöffnet${NC}"
    sudo ss -tlnp | grep ":80"
else
    echo -e "${RED}❌ Port 80 ist NICHT geöffnet${NC}"
fi
echo ""
if sudo ss -tlnp | grep -q ":443"; then
    echo -e "${GREEN}✅ Port 443 ist geöffnet${NC}"
    sudo ss -tlnp | grep ":443"
else
    echo -e "${RED}❌ Port 443 ist NICHT geöffnet${NC}"
fi
echo ""

# 13. Prüfe Firewall
echo "13. Prüfe Firewall..."
if sudo ufw status | grep -q "80/tcp"; then
    echo -e "${GREEN}✅ Port 80 ist in Firewall erlaubt${NC}"
else
    echo -e "${RED}❌ Port 80 ist NICHT in Firewall erlaubt${NC}"
fi
if sudo ufw status | grep -q "443/tcp"; then
    echo -e "${GREEN}✅ Port 443 ist in Firewall erlaubt${NC}"
else
    echo -e "${RED}❌ Port 443 ist NICHT in Firewall erlaubt${NC}"
fi
echo ""

# 14. Teste RPC über IP
echo "14. Teste RPC über IP..."
RPC_RESPONSE=$(curl -s --max-time 5 -k https://$SERVER_IP/rpc -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getHeight","id":1}' 2>/dev/null)
if echo "$RPC_RESPONSE" | grep -q '"result"'; then
    HEIGHT=$(echo "$RPC_RESPONSE" | grep -o '"result":[0-9]*' | cut -d: -f2)
    echo -e "${GREEN}✅ RPC über IP funktioniert (Height: $HEIGHT)${NC}"
else
    echo -e "${YELLOW}⚠️ RPC über IP funktioniert nicht oder Node läuft nicht${NC}"
fi
echo ""

# 15. Teste RPC über Domain
echo "15. Teste RPC über Domain..."
RPC_DOMAIN_RESPONSE=$(curl -s --max-time 10 https://$DOMAIN/rpc -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getHeight","id":1}' 2>/dev/null)
if echo "$RPC_DOMAIN_RESPONSE" | grep -q '"result"'; then
    HEIGHT=$(echo "$RPC_DOMAIN_RESPONSE" | grep -o '"result":[0-9]*' | cut -d: -f2)
    echo -e "${GREEN}✅ RPC über Domain funktioniert (Height: $HEIGHT)${NC}"
else
    echo -e "${RED}❌ RPC über Domain funktioniert NICHT${NC}"
    echo "   Mögliche Ursachen:"
    echo "   - DNS-Propagierung noch nicht abgeschlossen"
    echo "   - Domain zeigt auf falsche IP"
fi
echo ""

echo "=== TEST ABGESCHLOSSEN ==="
echo ""
echo "ZUSAMMENFASSUNG:"
echo "────────────────────────────────────────────────"
if [ "$DNS_IP" = "$SERVER_IP" ] || [ "$DIG_IP" = "$SERVER_IP" ]; then
    echo -e "${GREEN}✅ DNS ist korrekt konfiguriert${NC}"
else
    echo -e "${RED}❌ DNS zeigt NICHT auf korrekte IP${NC}"
    echo "   Aktuell: $DNS_IP oder $DIG_IP"
    echo "   Erwartet: $SERVER_IP"
    echo "   → DNS-Propagierung kann 5-15 Minuten dauern"
    echo "   → Prüfe IONOS DNS-Einstellungen"
fi

if [ "$HTTPS_STATUS" = "200" ]; then
    echo -e "${GREEN}✅ HTTPS über IP funktioniert${NC}"
else
    echo -e "${RED}❌ HTTPS über IP funktioniert NICHT${NC}"
fi

if [ "$HTTPS_DOMAIN_STATUS" = "200" ]; then
    echo -e "${GREEN}✅ HTTPS über Domain funktioniert${NC}"
else
    echo -e "${RED}❌ HTTPS über Domain funktioniert NICHT${NC}"
    echo "   → DNS-Propagierung oder nginx-Konfiguration"
fi

echo ""
echo "NÄCHSTE SCHRITTE:"
echo "────────────────────────────────────────────────"
if [ "$HTTPS_DOMAIN_STATUS" != "200" ]; then
    echo "1. Prüfe DNS-Propagierung: nslookup $DOMAIN"
    echo "2. Prüfe IONOS DNS-Einstellungen (A-Record: explorer → $SERVER_IP)"
    echo "3. Warte 5-15 Minuten auf DNS-Propagierung"
    echo "4. Prüfe nginx-Logs: sudo tail -f /var/log/nginx/error.log"
fi

