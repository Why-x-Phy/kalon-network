#!/bin/bash
# Fix für Browser ERR_SSL_PROTOCOL_ERROR (HTTP/2 Problem)

# Farben
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo "=== FIX FÜR BROWSER ERR_SSL_PROTOCOL_ERROR ==="
echo ""

# 1. Backup erstellen
echo "1. Erstelle Backup..."
NGINX_CONFIG="/etc/nginx/sites-available/explorer"
sudo cp "$NGINX_CONFIG" "$NGINX_CONFIG.backup.$(date +%Y%m%d_%H%M%S)"
echo -e "${GREEN}✅ Backup erstellt${NC}"
echo ""

# 2. Erstelle nginx-Konfiguration OHNE HTTP/2 (für Browser-Kompatibilität)
echo "2. Erstelle nginx-Konfiguration OHNE HTTP/2..."
sudo tee "$NGINX_CONFIG" > /dev/null << 'NGINX_EOF'
# HTTP Server - IP-Zugriff (redirect zu HTTPS IP)
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name 185.133.249.107;

    return 301 https://185.133.249.107$request_uri;
}

# HTTP Server - Domain-Zugriff (redirect zu HTTPS Domain)
server {
    listen 80;
    listen [::]:80;
    server_name explorer.kalon-network.com;

    return 301 https://$server_name$request_uri;
}

# HTTPS Server - OHNE HTTP/2 (für Browser-Kompatibilität)
server {
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name explorer.kalon-network.com 185.133.249.107;

    # SSL Certificate
    ssl_certificate /etc/letsencrypt/live/explorer.kalon-network.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/explorer.kalon-network.com/privkey.pem;

    # SSL Configuration (konservativ für Browser-Kompatibilität)
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:!aNULL:!MD5:!DSS';
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_session_tickets off;

    # SSL-Stapling (deaktiviert wenn Probleme)
    # ssl_stapling on;
    # ssl_stapling_verify on;
    # ssl_trusted_certificate /etc/letsencrypt/live/explorer.kalon-network.com/chain.pem;

    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Explorer-Dateien
    root /var/www/explorer;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    # RPC Proxy zu Node
    location /rpc {
        proxy_pass http://127.0.0.1:16316/rpc;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Content-Type application/json;
        
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        add_header Access-Control-Allow-Origin * always;
        add_header Access-Control-Allow-Methods "POST, GET, OPTIONS" always;
        add_header Access-Control-Allow-Headers "Content-Type" always;
    }

    location /health {
        proxy_pass http://127.0.0.1:16316/health;
    }
}
NGINX_EOF

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Konfiguration erstellt (OHNE HTTP/2)${NC}"
else
    echo -e "${RED}❌ Konfiguration fehlgeschlagen!${NC}"
    exit 1
fi
echo ""

# 3. Aktiviere Konfiguration
echo "3. Aktiviere Konfiguration..."
sudo ln -sf /etc/nginx/sites-available/explorer /etc/nginx/sites-enabled/explorer
echo -e "${GREEN}✅ Konfiguration aktiviert${NC}"
echo ""

# 4. Teste nginx-Konfiguration
echo "4. Teste nginx-Konfiguration..."
if sudo nginx -t; then
    echo -e "${GREEN}✅ nginx-Konfiguration ist gültig${NC}"
else
    echo -e "${RED}❌ nginx-Konfiguration hat Fehler!${NC}"
    exit 1
fi
echo ""

# 5. nginx neu laden
echo "5. Lade nginx neu..."
sudo systemctl reload nginx
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ nginx neu geladen${NC}"
else
    echo -e "${RED}❌ nginx neu laden fehlgeschlagen!${NC}"
    exit 1
fi
echo ""

# 6. Teste HTTPS (HTTP/1.1)
echo "6. Teste HTTPS (HTTP/1.1, ohne HTTP/2)..."
sleep 2
HTTPS_STATUS=$(curl --http1.1 -s -o /dev/null -w "%{http_code}" --max-time 10 https://explorer.kalon-network.com 2>/dev/null)
if [ "$HTTPS_STATUS" = "200" ]; then
    echo -e "${GREEN}✅ HTTPS funktioniert (Status: $HTTPS_STATUS)${NC}"
else
    echo -e "${YELLOW}⚠️ HTTPS gibt Status: $HTTPS_STATUS${NC}"
fi
echo ""

echo -e "${GREEN}=== FIX ABGESCHLOSSEN ===${NC}"
echo ""
echo "WICHTIGE ÄNDERUNGEN:"
echo "────────────────────────────────────────────────"
echo "1. HTTP/2 deaktiviert (für Browser-Kompatibilität)"
echo "2. SSL-Stapling deaktiviert (falls Problem)"
echo "3. Konservative Cipher-Suites"
echo "4. ssl_prefer_server_ciphers aktiviert"
echo ""
echo "JETZT TESTEN:"
echo "────────────────────────────────────────────────"
echo "1. Browser-Cache leeren (Strg+Shift+R)"
echo "2. In Incognito-Modus testen"
echo "3. Öffne: https://explorer.kalon-network.com"
echo "4. Sollte jetzt funktionieren!"
echo ""
echo "Falls immer noch ERR_SSL_PROTOCOL_ERROR:"
echo "────────────────────────────────────────────────"
echo "1. Prüfe Browser-Konsole (F12) für Details"
echo "2. Teste mit: curl --http1.1 https://explorer.kalon-network.com"
echo "3. Prüfe nginx-Logs: sudo tail -f /var/log/nginx/error.log"
echo "4. Möglicherweise: Browser-Zertifikat-Cache leeren"

