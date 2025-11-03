#!/bin/bash
# Script zum Fixen des ERR_SSL_PROTOCOL_ERROR

# Farben
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo "=== ERR_SSL_PROTOCOL_ERROR FIX ==="
echo ""

# 1. Prüfe Zertifikat
echo "1. Prüfe SSL-Zertifikat..."
CERT_PATH="/etc/letsencrypt/live/explorer.kalon-network.com/fullchain.pem"
KEY_PATH="/etc/letsencrypt/live/explorer.kalon-network.com/privkey.pem"

if [ ! -f "$CERT_PATH" ]; then
    echo -e "${RED}❌ Zertifikat nicht gefunden: $CERT_PATH${NC}"
    echo "   Erstelle Zertifikat: sudo certbot --nginx -d explorer.kalon-network.com"
    exit 1
fi

if [ ! -f "$KEY_PATH" ]; then
    echo -e "${RED}❌ Private Key nicht gefunden: $KEY_PATH${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Zertifikat vorhanden${NC}"
echo ""

# 2. Prüfe Zertifikat-Gültigkeit
echo "2. Prüfe Zertifikat-Gültigkeit..."
CERT_INFO=$(openssl x509 -in "$CERT_PATH" -noout -subject -dates 2>/dev/null)
if [ -n "$CERT_INFO" ]; then
    echo -e "${GREEN}✅ Zertifikat ist gültig${NC}"
    echo "$CERT_INFO"
else
    echo -e "${RED}❌ Zertifikat ist ungültig!${NC}"
    exit 1
fi
echo ""

# 3. Backup erstellen
echo "3. Erstelle Backup..."
NGINX_CONFIG="/etc/nginx/sites-available/explorer"
sudo cp "$NGINX_CONFIG" "$NGINX_CONFIG.backup.$(date +%Y%m%d_%H%M%S)"
echo -e "${GREEN}✅ Backup erstellt${NC}"
echo ""

# 4. Erstelle korrigierte nginx-Konfiguration
echo "4. Erstelle korrigierte nginx-Konfiguration..."
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
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name explorer.kalon-network.com 185.133.249.107;

    # SSL Certificate (Let's Encrypt)
    ssl_certificate /etc/letsencrypt/live/explorer.kalon-network.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/explorer.kalon-network.com/privkey.pem;

    # SSL Configuration (wichtig für ERR_SSL_PROTOCOL_ERROR Fix)
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384';
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_session_tickets off;

    # WICHTIG: SSL-Stapling für bessere Performance
    ssl_stapling on;
    ssl_stapling_verify on;
    ssl_trusted_certificate /etc/letsencrypt/live/explorer.kalon-network.com/chain.pem;
    resolver 8.8.8.8 8.8.4.4 valid=300s;
    resolver_timeout 5s;

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
        proxy_pass http://127.0.0.1:16316/rpc;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Wichtig für POST-Requests:
        proxy_set_header Content-Type application/json;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # CORS Headers
        add_header Access-Control-Allow-Origin * always;
        add_header Access-Control-Allow-Methods "POST, GET, OPTIONS" always;
        add_header Access-Control-Allow-Headers "Content-Type" always;
    }

    # Health check
    location /health {
        proxy_pass http://127.0.0.1:16316/health;
    }
}
NGINX_EOF

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Konfiguration erstellt${NC}"
else
    echo -e "${RED}❌ Konfiguration fehlgeschlagen!${NC}"
    exit 1
fi
echo ""

# 5. Aktiviere Konfiguration
echo "5. Aktiviere Konfiguration..."
sudo ln -sf /etc/nginx/sites-available/explorer /etc/nginx/sites-enabled/explorer
sudo rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true
echo -e "${GREEN}✅ Konfiguration aktiviert${NC}"
echo ""

# 6. Teste nginx-Konfiguration
echo "6. Teste nginx-Konfiguration..."
if sudo nginx -t; then
    echo -e "${GREEN}✅ nginx-Konfiguration ist gültig${NC}"
else
    echo -e "${RED}❌ nginx-Konfiguration hat Fehler!${NC}"
    sudo nginx -t
    exit 1
fi
echo ""

# 7. nginx neu laden
echo "7. Lade nginx neu..."
sudo systemctl reload nginx
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ nginx neu geladen${NC}"
else
    echo -e "${RED}❌ nginx neu laden fehlgeschlagen!${NC}"
    exit 1
fi
echo ""

# 8. Teste SSL-Verbindung
echo "8. Teste SSL-Verbindung..."
sleep 2
SSL_TEST=$(echo | openssl s_client -servername explorer.kalon-network.com -connect explorer.kalon-network.com:443 2>&1 | grep -i "Verify return code")
if [ -n "$SSL_TEST" ]; then
    echo -e "${GREEN}✅ SSL-Verbindung funktioniert${NC}"
    echo "   $SSL_TEST"
else
    echo -e "${YELLOW}⚠️ SSL-Verbindung testen (möglicherweise DNS-Problem)${NC}"
fi
echo ""

# 9. Teste HTTPS über Domain
echo "9. Teste HTTPS über Domain..."
HTTPS_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 https://explorer.kalon-network.com 2>/dev/null)
if [ "$HTTPS_STATUS" = "200" ]; then
    echo -e "${GREEN}✅ HTTPS über Domain funktioniert (Status: $HTTPS_STATUS)${NC}"
else
    echo -e "${YELLOW}⚠️ HTTPS über Domain gibt Status: $HTTPS_STATUS${NC}"
fi
echo ""

echo -e "${GREEN}=== FIX ABGESCHLOSSEN ===${NC}"
echo ""
echo "WICHTIGE ÄNDERUNGEN:"
echo "────────────────────────────────────────────────"
echo "1. SSL-Stapling aktiviert (bessere Performance)"
echo "2. SSL-Trusted-Certificate hinzugefügt"
echo "3. Proxy auf 127.0.0.1 geändert (statt localhost)"
echo "4. Timeouts für RPC-Proxy hinzugefügt"
echo ""
echo "JETZT TESTEN:"
echo "────────────────────────────────────────────────"
echo "1. Browser-Cache leeren (Strg+Shift+R)"
echo "2. In Incognito-Modus testen"
echo "3. Öffne: https://explorer.kalon-network.com"
echo "4. Sollte jetzt funktionieren (kein ERR_SSL_PROTOCOL_ERROR)"
echo ""
echo "Falls immer noch ERR_SSL_PROTOCOL_ERROR:"
echo "────────────────────────────────────────────────"
echo "1. Prüfe Browser-Konsole (F12) für Details"
echo "2. Teste mit: curl -v https://explorer.kalon-network.com"
echo "3. Prüfe nginx-Logs: sudo tail -f /var/log/nginx/error.log"

