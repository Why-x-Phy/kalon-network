#!/bin/bash
# Vollständiger Fix für HTTPS-Problem

# Farben
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo "=== HTTPS PROBLEM - VOLLSTÄNDIGER FIX ==="
echo ""

# 1. Prüfe ob Zertifikat vorhanden
echo "1. Prüfe Let's Encrypt Zertifikat..."
CERT_PATH="/etc/letsencrypt/live/explorer.kalon-network.com/fullchain.pem"
KEY_PATH="/etc/letsencrypt/live/explorer.kalon-network.com/privkey.pem"

if [ ! -f "$CERT_PATH" ]; then
    echo -e "${YELLOW}⚠️ Zertifikat nicht gefunden. Erstelle jetzt...${NC}"
    sudo certbot certonly --standalone -d explorer.kalon-network.com --non-interactive --agree-tos --email admin@kalon-network.com
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Zertifikat-Erstellung fehlgeschlagen!${NC}"
        echo "   Prüfe ob Port 80 frei ist und nginx gestoppt ist"
        exit 1
    fi
fi

if [ -f "$CERT_PATH" ]; then
    echo -e "${GREEN}✅ Zertifikat vorhanden: $CERT_PATH${NC}"
else
    echo -e "${RED}❌ Zertifikat nicht gefunden!${NC}"
    exit 1
fi
echo ""

# 2. Öffne Firewall Ports
echo "2. Öffne Firewall Ports..."
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
echo -e "${GREEN}✅ Firewall Ports geöffnet${NC}"
echo ""

# 3. Stoppe nginx temporär (für Certbot)
echo "3. Stoppe nginx temporär (falls nötig)..."
sudo systemctl stop nginx 2>/dev/null || true
sleep 2
echo ""

# 4. Erstelle/erneuere Zertifikat mit Certbot
echo "4. Erstelle/erneuere Zertifikat mit Certbot..."
sudo certbot certonly --standalone -d explorer.kalon-network.com --non-interactive --agree-tos --email admin@kalon-network.com --force-renewal 2>/dev/null || sudo certbot certonly --standalone -d explorer.kalon-network.com --non-interactive --agree-tos --email admin@kalon-network.com

if [ -f "$CERT_PATH" ]; then
    echo -e "${GREEN}✅ Zertifikat vorhanden${NC}"
else
    echo -e "${YELLOW}⚠️ Zertifikat-Erstellung übersprungen (bereits vorhanden)${NC}"
fi
echo ""

# 5. Erstelle vollständige nginx-Konfiguration
echo "5. Erstelle vollständige nginx-Konfiguration..."
NGINX_CONFIG="/etc/nginx/sites-available/explorer"

sudo tee "$NGINX_CONFIG" > /dev/null << 'NGINX_EOF'
# HTTP Server (redirect to HTTPS)
server {
    listen 80;
    listen [::]:80;
    server_name explorer.kalon-network.com;

    # Redirect all HTTP requests to HTTPS
    return 301 https://$server_name$request_uri;
}

# HTTPS Server
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name explorer.kalon-network.com;

    # SSL Certificate (Let's Encrypt)
    ssl_certificate /etc/letsencrypt/live/explorer.kalon-network.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/explorer.kalon-network.com/privkey.pem;

    # SSL Configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384';
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Explorer-Dateien
    root /var/www/explorer;
    index index.html;

    # Explorer-Dateien
    location / {
        try_files $uri $uri/ /index.html;
    }

    # RPC Proxy zu Node (localhost)
    location /rpc {
        proxy_pass http://localhost:16316/rpc;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Wichtig für POST-Requests:
        proxy_set_header Content-Type application/json;
        
        # CORS Headers
        add_header Access-Control-Allow-Origin * always;
        add_header Access-Control-Allow-Methods "POST, GET, OPTIONS" always;
        add_header Access-Control-Allow-Headers "Content-Type" always;
    }

    # Health check
    location /health {
        proxy_pass http://localhost:16316/health;
    }
}
NGINX_EOF

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ nginx-Konfiguration erstellt${NC}"
else
    echo -e "${RED}❌ nginx-Konfiguration fehlgeschlagen!${NC}"
    exit 1
fi
echo ""

# 6. Aktiviere nginx-Konfiguration
echo "6. Aktiviere nginx-Konfiguration..."
sudo ln -sf /etc/nginx/sites-available/explorer /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true
echo -e "${GREEN}✅ nginx-Konfiguration aktiviert${NC}"
echo ""

# 7. Teste nginx-Konfiguration
echo "7. Teste nginx-Konfiguration..."
if sudo nginx -t; then
    echo -e "${GREEN}✅ nginx-Konfiguration ist gültig${NC}"
else
    echo -e "${RED}❌ nginx-Konfiguration hat Fehler!${NC}"
    exit 1
fi
echo ""

# 8. Starte nginx
echo "8. Starte nginx..."
sudo systemctl start nginx
sudo systemctl enable nginx
if systemctl is-active --quiet nginx; then
    echo -e "${GREEN}✅ nginx läuft${NC}"
else
    echo -e "${RED}❌ nginx starten fehlgeschlagen!${NC}"
    exit 1
fi
echo ""

# 9. Prüfe Ports
echo "9. Prüfe Ports..."
sleep 2
if sudo ss -tlnp | grep -q ":443"; then
    echo -e "${GREEN}✅ Port 443 ist geöffnet${NC}"
else
    echo -e "${YELLOW}⚠️ Port 443 ist nicht geöffnet${NC}"
fi

if sudo ss -tlnp | grep -q ":80"; then
    echo -e "${GREEN}✅ Port 80 ist geöffnet${NC}"
else
    echo -e "${YELLOW}⚠️ Port 80 ist nicht geöffnet${NC}"
fi
echo ""

# 10. Teste HTTPS-Verbindung
echo "10. Teste HTTPS-Verbindung..."
sleep 2
if curl -s -k https://localhost/rpc -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getHeight","id":1}' | grep -q '"result"'; then
    echo -e "${GREEN}✅ HTTPS-Verbindung funktioniert${NC}"
else
    echo -e "${YELLOW}⚠️ HTTPS-Verbindung testen (möglicherweise Node läuft nicht)${NC}"
fi
echo ""

echo -e "${GREEN}=== FIX ABGESCHLOSSEN ===${NC}"
echo ""
echo "Nächste Schritte:"
echo "1. Öffne im Browser: https://explorer.kalon-network.com"
echo "2. Prüfe ob keine Warnung mehr erscheint"
echo "3. Prüfe ob Explorer 'ONLINE' zeigt"
echo ""
echo "Falls immer noch Probleme:"
echo "1. Prüfe nginx-Logs: sudo tail -f /var/log/nginx/error.log"
echo "2. Prüfe Node-Logs: tail -f node.log"
echo "3. Prüfe Firewall: sudo ufw status"

