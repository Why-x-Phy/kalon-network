#!/bin/bash
# Script zum sauberen Fixen der nginx-Konfiguration

# Farben
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo "=== NGINX SAUBER KONFIGURIEREN ==="
echo ""

# 1. Entferne alle alten Backup-Dateien
echo "1. Entferne alte Backup-Dateien..."
sudo rm -f /etc/nginx/sites-enabled/explorer.backup.*
sudo rm -f /etc/nginx/sites-available/explorer.backup.*
echo -e "${GREEN}✅ Alte Backups entfernt${NC}"
echo ""

# 2. Entferne default nginx-Konfiguration
echo "2. Entferne default nginx-Konfiguration..."
sudo rm -f /etc/nginx/sites-enabled/default
echo -e "${GREEN}✅ Default-Konfiguration entfernt${NC}"
echo ""

# 3. Erstelle saubere nginx-Konfiguration
echo "3. Erstelle saubere nginx-Konfiguration..."
NGINX_CONFIG="/etc/nginx/sites-available/explorer"
sudo tee "$NGINX_CONFIG" > /dev/null << 'NGINX_EOF'
# HTTP Server - IP-Zugriff (redirect zu HTTPS IP)
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name 185.133.249.107;

    # Für IP-Zugriff: Redirect zu HTTPS IP (nicht Domain!)
    return 301 https://185.133.249.107$request_uri;
}

# HTTP Server - Domain-Zugriff (redirect zu HTTPS Domain)
server {
    listen 80;
    listen [::]:80;
    server_name explorer.kalon-network.com;

    # Für Domain-Zugriff: Redirect zu HTTPS Domain
    return 301 https://$server_name$request_uri;
}

# HTTPS Server - IP und Domain
server {
    listen 443 ssl http2 default_server;
    listen [::]:443 ssl http2 default_server;
    server_name explorer.kalon-network.com 185.133.249.107;

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
    echo -e "${GREEN}✅ Saubere Konfiguration erstellt${NC}"
else
    echo -e "${RED}❌ Konfiguration fehlgeschlagen!${NC}"
    exit 1
fi
echo ""

# 4. Aktiviere Konfiguration
echo "4. Aktiviere Konfiguration..."
sudo ln -sf /etc/nginx/sites-available/explorer /etc/nginx/sites-enabled/explorer
echo -e "${GREEN}✅ Konfiguration aktiviert${NC}"
echo ""

# 5. Teste nginx-Konfiguration
echo "5. Teste nginx-Konfiguration..."
if sudo nginx -t; then
    echo -e "${GREEN}✅ nginx-Konfiguration ist gültig${NC}"
else
    echo -e "${RED}❌ nginx-Konfiguration hat Fehler!${NC}"
    sudo nginx -t
    exit 1
fi
echo ""

# 6. nginx neu laden
echo "6. Lade nginx neu..."
sudo systemctl reload nginx
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ nginx neu geladen${NC}"
else
    echo -e "${RED}❌ nginx neu laden fehlgeschlagen!${NC}"
    exit 1
fi
echo ""

echo -e "${GREEN}=== NGINX SAUBER KONFIGURIERT ===${NC}"
echo ""
echo "Jetzt testen:"
echo "1. HTTP über IP: http://185.133.249.107"
echo "   → Sollte zu https://185.133.249.107 redirecten (nicht Domain!)"
echo ""
echo "2. HTTPS über IP: https://185.133.249.107"
echo "   → Funktioniert (mit Browser-Warnung, normal)"
echo ""
echo "3. HTTPS über Domain: https://explorer.kalon-network.com"
echo "   → Nach DNS-Propagierung (5-15 Min)"
echo "   → Keine Warnung ✅"

