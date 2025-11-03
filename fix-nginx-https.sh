#!/bin/bash
# Script zum Fixen der HTTPS-Konfiguration für nginx

# Farben
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo "=== NGINX HTTPS KONFIGURATION FIX ==="
echo ""

# 1. Prüfe ob Zertifikat vorhanden
echo "1. Prüfe Let's Encrypt Zertifikat..."
if [ -f "/etc/letsencrypt/live/explorer.kalon-network.com/fullchain.pem" ]; then
    echo -e "${GREEN}✅ Zertifikat vorhanden${NC}"
    CERT_PATH="/etc/letsencrypt/live/explorer.kalon-network.com/fullchain.pem"
    KEY_PATH="/etc/letsencrypt/live/explorer.kalon-network.com/privkey.pem"
else
    echo -e "${RED}❌ Zertifikat nicht gefunden!${NC}"
    echo "   Führe zuerst aus: sudo certbot --nginx -d explorer.kalon-network.com"
    exit 1
fi
echo ""

# 2. Prüfe aktuelle nginx-Konfiguration
echo "2. Prüfe aktuelle nginx-Konfiguration..."
NGINX_CONFIG="/etc/nginx/sites-enabled/explorer"
if [ -f "$NGINX_CONFIG" ]; then
    if grep -q "listen 443" "$NGINX_CONFIG"; then
        echo -e "${GREEN}✅ HTTPS (Port 443) bereits konfiguriert${NC}"
    else
        echo -e "${YELLOW}⚠️ HTTPS nicht konfiguriert. Füge hinzu...${NC}"
        
        # Backup erstellen
        sudo cp "$NGINX_CONFIG" "$NGINX_CONFIG.backup"
        
        # Erstelle neue Konfiguration mit HTTPS
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

        echo -e "${GREEN}✅ HTTPS-Konfiguration hinzugefügt${NC}"
    fi
else
    echo -e "${RED}❌ nginx-Konfiguration nicht gefunden!${NC}"
    exit 1
fi
echo ""

# 3. Prüfe nginx-Konfiguration
echo "3. Teste nginx-Konfiguration..."
if sudo nginx -t; then
    echo -e "${GREEN}✅ nginx-Konfiguration ist gültig${NC}"
else
    echo -e "${RED}❌ nginx-Konfiguration hat Fehler!${NC}"
    echo "   Stelle Backup wieder her..."
    sudo cp "$NGINX_CONFIG.backup" "$NGINX_CONFIG"
    exit 1
fi
echo ""

# 4. nginx neu laden
echo "4. Lade nginx neu..."
sudo systemctl reload nginx
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ nginx neu geladen${NC}"
else
    echo -e "${RED}❌ nginx neu laden fehlgeschlagen!${NC}"
    exit 1
fi
echo ""

# 5. Prüfe Ports
echo "5. Prüfe Ports..."
if sudo ss -tlnp | grep -q ":443"; then
    echo -e "${GREEN}✅ Port 443 ist geöffnet${NC}"
else
    echo -e "${YELLOW}⚠️ Port 443 ist nicht geöffnet${NC}"
    echo "   Prüfe Firewall: sudo ufw status"
fi
echo ""

echo -e "${GREEN}=== HTTPS KONFIGURATION ABGESCHLOSSEN ===${NC}"
echo ""
echo "Teste jetzt:"
echo "1. Öffne im Browser: https://explorer.kalon-network.com"
echo "2. Prüfe ob keine Warnung mehr erscheint"
echo "3. Prüfe ob Explorer 'ONLINE' zeigt"

