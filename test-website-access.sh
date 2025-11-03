#!/bin/bash
# Test-Script für Website-Zugriff (IP und Domain)

# Farben
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

SERVER_IP="185.133.249.107"
DOMAIN="explorer.kalon-network.com"

echo "=== WEBSITE ZUGRIFF TEST ==="
echo ""

# 1. Prüfe nginx Status
echo "1. Prüfe nginx Status..."
if systemctl is-active --quiet nginx; then
    echo -e "${GREEN}✅ nginx läuft${NC}"
else
    echo -e "${RED}❌ nginx läuft NICHT!${NC}"
    echo "   Starte nginx: sudo systemctl start nginx"
fi
echo ""

# 2. Prüfe Node Status
echo "2. Prüfe Node Status..."
if pgrep -f "kalon-node-v2" > /dev/null; then
    echo -e "${GREEN}✅ Node läuft${NC}"
    NODE_PID=$(pgrep -f "kalon-node-v2")
    echo "   PID: $NODE_PID"
else
    echo -e "${YELLOW}⚠️ Node läuft NICHT${NC}"
    echo "   Starte Node: ./build-v2/kalon-node-v2 -datadir data-testnet -genesis genesis/testnet.json -rpc 127.0.0.1:16316 -p2p 0.0.0.0:17335 > node.log 2>&1 &"
fi
echo ""

# 3. Teste HTTP über IP
echo "3. Teste HTTP über IP (http://$SERVER_IP)..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://$SERVER_IP 2>/dev/null)
if [ "$HTTP_STATUS" = "301" ] || [ "$HTTP_STATUS" = "200" ]; then
    echo -e "${GREEN}✅ HTTP über IP funktioniert (Status: $HTTP_STATUS)${NC}"
elif [ "$HTTP_STATUS" = "000" ]; then
    echo -e "${RED}❌ HTTP über IP funktioniert NICHT (Timeout/Verbindung fehlgeschlagen)${NC}"
else
    echo -e "${YELLOW}⚠️ HTTP über IP gibt Status: $HTTP_STATUS${NC}"
fi
echo ""

# 4. Teste HTTPS über IP
echo "4. Teste HTTPS über IP (https://$SERVER_IP)..."
HTTPS_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 -k https://$SERVER_IP 2>/dev/null)
if [ "$HTTPS_STATUS" = "200" ]; then
    echo -e "${GREEN}✅ HTTPS über IP funktioniert (Status: $HTTPS_STATUS)${NC}"
elif [ "$HTTPS_STATUS" = "000" ]; then
    echo -e "${RED}❌ HTTPS über IP funktioniert NICHT (Timeout/Verbindung fehlgeschlagen)${NC}"
else
    echo -e "${YELLOW}⚠️ HTTPS über IP gibt Status: $HTTPS_STATUS${NC}"
fi
echo ""

# 5. Teste HTTP über Domain
echo "5. Teste HTTP über Domain (http://$DOMAIN)..."
HTTP_DOMAIN_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://$DOMAIN 2>/dev/null)
if [ "$HTTP_DOMAIN_STATUS" = "301" ] || [ "$HTTP_DOMAIN_STATUS" = "200" ]; then
    echo -e "${GREEN}✅ HTTP über Domain funktioniert (Status: $HTTP_DOMAIN_STATUS)${NC}"
elif [ "$HTTP_DOMAIN_STATUS" = "000" ]; then
    echo -e "${RED}❌ HTTP über Domain funktioniert NICHT (DNS-Problem oder Verbindung fehlgeschlagen)${NC}"
else
    echo -e "${YELLOW}⚠️ HTTP über Domain gibt Status: $HTTP_DOMAIN_STATUS${NC}"
fi
echo ""

# 6. Teste HTTPS über Domain
echo "6. Teste HTTPS über Domain (https://$DOMAIN)..."
HTTPS_DOMAIN_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 https://$DOMAIN 2>/dev/null)
if [ "$HTTPS_DOMAIN_STATUS" = "200" ]; then
    echo -e "${GREEN}✅ HTTPS über Domain funktioniert (Status: $HTTPS_DOMAIN_STATUS)${NC}"
elif [ "$HTTPS_DOMAIN_STATUS" = "000" ]; then
    echo -e "${RED}❌ HTTPS über Domain funktioniert NICHT (DNS-Problem oder Verbindung fehlgeschlagen)${NC}"
else
    echo -e "${YELLOW}⚠️ HTTPS über Domain gibt Status: $HTTPS_DOMAIN_STATUS${NC}"
fi
echo ""

# 7. Prüfe DNS-Propagierung
echo "7. Prüfe DNS-Propagierung..."
DNS_IP=$(dig +short $DOMAIN | head -1)
if [ "$DNS_IP" = "$SERVER_IP" ]; then
    echo -e "${GREEN}✅ DNS zeigt auf korrekte IP: $DNS_IP${NC}"
elif [ -n "$DNS_IP" ]; then
    echo -e "${YELLOW}⚠️ DNS zeigt auf: $DNS_IP (erwartet: $SERVER_IP)${NC}"
    echo "   DNS-Propagierung kann 5-15 Minuten dauern (manchmal bis zu 48 Stunden)"
else
    echo -e "${RED}❌ DNS gibt keine IP zurück${NC}"
    echo "   DNS-Propagierung kann 5-15 Minuten dauern"
fi
echo ""

# 8. Prüfe Firewall
echo "8. Prüfe Firewall..."
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

# 9. Prüfe Ports (lokal)
echo "9. Prüfe Ports (lokal)..."
if sudo ss -tlnp | grep -q ":80"; then
    echo -e "${GREEN}✅ Port 80 ist geöffnet (nginx hört darauf)${NC}"
else
    echo -e "${RED}❌ Port 80 ist NICHT geöffnet${NC}"
fi

if sudo ss -tlnp | grep -q ":443"; then
    echo -e "${GREEN}✅ Port 443 ist geöffnet (nginx hört darauf)${NC}"
else
    echo -e "${RED}❌ Port 443 ist NICHT geöffnet${NC}"
fi
echo ""

# 10. Teste RPC über IP
echo "10. Teste RPC über IP (http://$SERVER_IP/rpc)..."
RPC_RESPONSE=$(curl -s --max-time 5 http://$SERVER_IP/rpc -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getHeight","id":1}' 2>/dev/null)
if echo "$RPC_RESPONSE" | grep -q '"result"'; then
    HEIGHT=$(echo "$RPC_RESPONSE" | grep -o '"result":[0-9]*' | cut -d: -f2)
    echo -e "${GREEN}✅ RPC über IP funktioniert (Height: $HEIGHT)${NC}"
else
    echo -e "${YELLOW}⚠️ RPC über IP funktioniert nicht oder Node läuft nicht${NC}"
fi
echo ""

echo "=== TEST ABGESCHLOSSEN ==="
echo ""
echo "ANTWORTEN AUF DEINE FRAGEN:"
echo "────────────────────────────────────────────────"
echo "1. Website über IP erreichbar?"
echo "   → Ja, sollte über IP erreichbar sein (wenn nginx läuft)"
echo "   → Teste: http://$SERVER_IP oder https://$SERVER_IP"
echo ""
echo "2. Muss Node laufen?"
echo "   → Ja, Node muss laufen für Explorer RPC-Calls"
echo "   → Ohne Node: Explorer zeigt 'OFFLINE'"
echo ""
echo "3. DNS-Propagierung?"
echo "   → Normal: 5-15 Minuten"
echo "   → Maximum: bis zu 48 Stunden"
echo "   → Aktuell: DNS zeigt auf $DNS_IP"
echo ""
echo "NÄCHSTE SCHRITTE:"
echo "────────────────────────────────────────────────"
echo "1. Falls nginx nicht läuft: sudo systemctl start nginx"
echo "2. Falls Node nicht läuft: Starte Node (siehe oben)"
echo "3. Falls Website über IP nicht geht: Prüfe nginx-Logs: sudo tail -f /var/log/nginx/error.log"
echo "4. Teste im Browser: https://$SERVER_IP (mit Browser-Warnung für selbst-signiertes Zertifikat)"
echo "5. Warte auf DNS-Propagierung (5-15 Min) für https://$DOMAIN"

