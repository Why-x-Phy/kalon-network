#!/bin/bash
# Vollständige Diagnose für HTTPS-Problem

# Farben
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo "=== HTTPS PROBLEM - VOLLSTÄNDIGE DIAGNOSE ==="
echo ""

# 1. Prüfe nginx Status
echo "1. Prüfe nginx Status..."
if systemctl is-active --quiet nginx; then
    echo -e "${GREEN}✅ nginx läuft${NC}"
else
    echo -e "${RED}❌ nginx läuft NICHT!${NC}"
    echo "   Starte nginx: sudo systemctl start nginx"
    exit 1
fi
echo ""

# 2. Prüfe Port 443 (HTTPS)
echo "2. Prüfe Port 443 (HTTPS)..."
if sudo ss -tlnp | grep -q ":443"; then
    echo -e "${GREEN}✅ Port 443 ist geöffnet${NC}"
    sudo ss -tlnp | grep ":443"
else
    echo -e "${RED}❌ Port 443 ist NICHT geöffnet!${NC}"
    echo "   Öffne Port: sudo ufw allow 443/tcp"
fi
echo ""

# 3. Prüfe Port 80 (HTTP)
echo "3. Prüfe Port 80 (HTTP)..."
if sudo ss -tlnp | grep -q ":80"; then
    echo -e "${GREEN}✅ Port 80 ist geöffnet${NC}"
    sudo ss -tlnp | grep ":80"
else
    echo -e "${YELLOW}⚠️ Port 80 ist nicht geöffnet${NC}"
fi
echo ""

# 4. Prüfe Let's Encrypt Zertifikat
echo "4. Prüfe Let's Encrypt Zertifikat..."
CERT_PATH="/etc/letsencrypt/live/explorer.kalon-network.com/fullchain.pem"
KEY_PATH="/etc/letsencrypt/live/explorer.kalon-network.com/privkey.pem"

if [ -f "$CERT_PATH" ]; then
    echo -e "${GREEN}✅ Zertifikat vorhanden: $CERT_PATH${NC}"
    CERT_EXPIRY=$(sudo openssl x509 -enddate -noout -in "$CERT_PATH" | cut -d= -f2)
    echo "   Ablaufdatum: $CERT_EXPIRY"
else
    echo -e "${RED}❌ Zertifikat nicht gefunden!${NC}"
    echo "   Zertifikat erstellen: sudo certbot --nginx -d explorer.kalon-network.com"
fi

if [ -f "$KEY_PATH" ]; then
    echo -e "${GREEN}✅ Private Key vorhanden: $KEY_PATH${NC}"
else
    echo -e "${RED}❌ Private Key nicht gefunden!${NC}"
fi
echo ""

# 5. Prüfe nginx-Konfiguration
echo "5. Prüfe nginx-Konfiguration..."
NGINX_CONFIG="/etc/nginx/sites-enabled/explorer"

if [ -f "$NGINX_CONFIG" ]; then
    echo -e "${GREEN}✅ nginx-Konfiguration vorhanden${NC}"
    
    # Prüfe ob HTTPS konfiguriert ist
    if grep -q "listen 443" "$NGINX_CONFIG"; then
        echo -e "${GREEN}✅ HTTPS (Port 443) ist konfiguriert${NC}"
    else
        echo -e "${RED}❌ HTTPS (Port 443) ist NICHT konfiguriert!${NC}"
        echo "   Konfiguration:"
        sudo cat "$NGINX_CONFIG" | head -20
    fi
    
    # Prüfe ob SSL-Zertifikat konfiguriert ist
    if grep -q "ssl_certificate" "$NGINX_CONFIG"; then
        echo -e "${GREEN}✅ SSL-Zertifikat ist in nginx konfiguriert${NC}"
    else
        echo -e "${RED}❌ SSL-Zertifikat ist NICHT in nginx konfiguriert!${NC}"
    fi
    
    # Prüfe ob HTTP → HTTPS Redirect vorhanden ist
    if grep -q "return 301" "$NGINX_CONFIG" || grep -q "return 302" "$NGINX_CONFIG"; then
        echo -e "${GREEN}✅ HTTP → HTTPS Redirect ist konfiguriert${NC}"
    else
        echo -e "${YELLOW}⚠️ HTTP → HTTPS Redirect ist NICHT konfiguriert${NC}"
    fi
else
    echo -e "${RED}❌ nginx-Konfiguration nicht gefunden!${NC}"
fi
echo ""

# 6. Prüfe nginx-Konfiguration auf Fehler
echo "6. Teste nginx-Konfiguration..."
if sudo nginx -t 2>&1 | grep -q "test is successful"; then
    echo -e "${GREEN}✅ nginx-Konfiguration ist gültig${NC}"
else
    echo -e "${RED}❌ nginx-Konfiguration hat Fehler!${NC}"
    sudo nginx -t
fi
echo ""

# 7. Prüfe Firewall
echo "7. Prüfe Firewall..."
if sudo ufw status | grep -q "443/tcp"; then
    echo -e "${GREEN}✅ Port 443 ist in Firewall erlaubt${NC}"
else
    echo -e "${YELLOW}⚠️ Port 443 ist NICHT in Firewall erlaubt${NC}"
    echo "   Öffne Port: sudo ufw allow 443/tcp"
fi

if sudo ufw status | grep -q "80/tcp"; then
    echo -e "${GREEN}✅ Port 80 ist in Firewall erlaubt${NC}"
else
    echo -e "${YELLOW}⚠️ Port 80 ist NICHT in Firewall erlaubt${NC}"
    echo "   Öffne Port: sudo ufw allow 80/tcp"
fi
echo ""

# 8. Teste HTTPS-Verbindung lokal
echo "8. Teste HTTPS-Verbindung lokal..."
if curl -s -k https://localhost/rpc -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getHeight","id":1}' > /dev/null 2>&1; then
    echo -e "${GREEN}✅ HTTPS-Verbindung lokal funktioniert${NC}"
else
    echo -e "${RED}❌ HTTPS-Verbindung lokal funktioniert NICHT!${NC}"
fi
echo ""

# 9. Teste HTTP-Verbindung lokal
echo "9. Teste HTTP-Verbindung lokal..."
if curl -s http://localhost/rpc -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getHeight","id":1}' > /dev/null 2>&1; then
    echo -e "${GREEN}✅ HTTP-Verbindung lokal funktioniert${NC}"
else
    echo -e "${YELLOW}⚠️ HTTP-Verbindung lokal funktioniert NICHT${NC}"
fi
echo ""

# 10. Zeige aktuelle nginx-Konfiguration
echo "10. Aktuelle nginx-Konfiguration:"
echo "────────────────────────────────────────────────"
sudo cat "$NGINX_CONFIG" 2>/dev/null | head -50
echo ""

echo "=== DIAGNOSE ABGESCHLOSSEN ==="
echo ""
echo "LÖSUNG:"
echo "────────────────────────────────────────────────"
echo "1. Falls nginx nicht läuft: sudo systemctl start nginx"
echo "2. Falls Port 443 nicht offen: sudo ufw allow 443/tcp"
echo "3. Falls HTTPS nicht konfiguriert: sudo certbot --nginx -d explorer.kalon-network.com"
echo "4. Falls nginx-Konfiguration Fehler hat: sudo nginx -t"
echo "5. nginx neu laden: sudo systemctl reload nginx"

