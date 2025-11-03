#!/bin/bash
# Script zum Konfigurieren von nginx für IP-Zugriff

# Farben
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo "=== NGINX FÜR IP-ZUGRIFF KONFIGURIEREN ==="
echo ""

# 1. Backup erstellen
echo "1. Erstelle Backup..."
NGINX_CONFIG="/etc/nginx/sites-enabled/explorer"
sudo cp "$NGINX_CONFIG" "$NGINX_CONFIG.backup.$(date +%Y%m%d_%H%M%S)"
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Backup erstellt${NC}"
else
    echo -e "${RED}❌ Backup fehlgeschlagen!${NC}"
    exit 1
fi
echo ""

# 2. Prüfe aktuelle Konfiguration
echo "2. Prüfe aktuelle Konfiguration..."
if grep -q "server_name explorer.kalon-network.com" "$NGINX_CONFIG"; then
    echo -e "${GREEN}✅ Domain-Konfiguration gefunden${NC}"
else
    echo -e "${YELLOW}⚠️ Domain-Konfiguration nicht gefunden${NC}"
fi
echo ""

# 3. Erstelle neue Konfiguration mit IP-Zugriff
echo "3. Erstelle neue Konfiguration mit IP-Zugriff..."
sudo tee "$NGINX_CONFIG" > /dev/null << 'NGINX_EOF'
# HTTP Server (redirect to HTTPS)
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name explorer.kalon-network.com 185.133.249.107;

    # Redirect all HTTP requests to HTTPS
    return 301 https://$server_name$request_uri;
}

# HTTPS Server
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
    echo -e "${GREEN}✅ Neue Konfiguration erstellt${NC}"
else
    echo -e "${RED}❌ Konfiguration fehlgeschlagen!${NC}"
    exit 1
fi
echo ""

# 4. Teste nginx-Konfiguration
echo "4. Teste nginx-Konfiguration..."
if sudo nginx -t; then
    echo -e "${GREEN}✅ nginx-Konfiguration ist gültig${NC}"
else
    echo -e "${RED}❌ nginx-Konfiguration hat Fehler!${NC}"
    echo "   Stelle Backup wieder her..."
    sudo cp "$NGINX_CONFIG.backup."* "$NGINX_CONFIG" 2>/dev/null || true
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

echo -e "${GREEN}=== NGINX FÜR IP-ZUGRIFF KONFIGURIERT ===${NC}"
echo ""
echo "Jetzt testen:"
echo "1. HTTP über IP: http://185.133.249.107 (sollte zu HTTPS redirecten)"
echo "2. HTTPS über IP: https://185.133.249.107 (funktioniert, aber mit Warnung)"
echo "3. HTTPS über Domain: https://explorer.kalon-network.com (nach DNS-Propagierung, keine Warnung)"
echo ""
echo "WICHTIG:"
echo "────────────────────────────────────────────────"
echo "⚠️ Browser-Warnung bei IP-Zugriff ist normal!"
echo "   → Zertifikat ist für Domain (explorer.kalon-network.com)"
echo "   → Nicht für IP (185.133.249.107)"
echo "   → Nach DNS-Propagierung über Domain: keine Warnung!"

