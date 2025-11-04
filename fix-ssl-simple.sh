#!/bin/bash
# EINFACHER Fix - Minimal-Konfiguration

# Farben
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo "=== EINFACHER SSL-FIX - MINIMAL-KONFIGURATION ==="
echo ""

# 1. Stoppe nginx
echo "1. Stoppe nginx..."
sudo systemctl stop nginx
sleep 2
echo -e "${GREEN}✅ nginx gestoppt${NC}"
echo ""

# 2. Erneuere Zertifikat
echo "2. Erneuere SSL-Zertifikat..."
sudo certbot certonly --standalone -d explorer.kalon-network.com --non-interactive --agree-tos --email admin@kalon-network.com --force-renewal 2>/dev/null || sudo certbot certonly --standalone -d explorer.kalon-network.com --non-interactive --agree-tos --email admin@kalon-network.com
echo -e "${GREEN}✅ Zertifikat erneuert${NC}"
echo ""

# 3. Erstelle EINFACHE nginx-Konfiguration (minimal)
echo "3. Erstelle EINFACHE nginx-Konfiguration..."
NGINX_CONFIG="/etc/nginx/sites-available/explorer"
sudo tee "$NGINX_CONFIG" > /dev/null << 'NGINX_EOF'
# HTTP - Redirect zu HTTPS
server {
    listen 80;
    server_name explorer.kalon-network.com 185.133.249.107;
    return 301 https://$server_name$request_uri;
}

# HTTPS - EINFACH (minimal)
server {
    listen 443 ssl;
    server_name explorer.kalon-network.com 185.133.249.107;

    # Zertifikat
    ssl_certificate /etc/letsencrypt/live/explorer.kalon-network.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/explorer.kalon-network.com/privkey.pem;

    # SSL - MINIMAL
    ssl_protocols TLSv1.2 TLSv1.3;

    # Explorer
    root /var/www/explorer;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    # RPC
    location /rpc {
        proxy_pass http://127.0.0.1:16316/rpc;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Content-Type application/json;
        
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
    echo -e "${GREEN}✅ Minimale Konfiguration erstellt${NC}"
else
    echo -e "${RED}❌ Konfiguration fehlgeschlagen!${NC}"
    exit 1
fi
echo ""

# 4. Entferne alle anderen Konfigurationen
echo "4. Entferne alle anderen Konfigurationen..."
sudo rm -f /etc/nginx/sites-enabled/*
sudo rm -f /etc/nginx/sites-available/explorer.backup.*
echo -e "${GREEN}✅ Alte Konfigurationen entfernt${NC}"
echo ""

# 5. Aktiviere nur diese Konfiguration
echo "5. Aktiviere Konfiguration..."
sudo ln -s /etc/nginx/sites-available/explorer /etc/nginx/sites-enabled/explorer
echo -e "${GREEN}✅ Konfiguration aktiviert${NC}"
echo ""

# 6. Teste nginx
echo "6. Teste nginx-Konfiguration..."
if sudo nginx -t; then
    echo -e "${GREEN}✅ nginx-Konfiguration ist gültig${NC}"
else
    echo -e "${RED}❌ nginx-Konfiguration hat Fehler!${NC}"
    exit 1
fi
echo ""

# 7. Starte nginx
echo "7. Starte nginx..."
sudo systemctl start nginx
sleep 2
if systemctl is-active --quiet nginx; then
    echo -e "${GREEN}✅ nginx läuft${NC}"
else
    echo -e "${RED}❌ nginx starten fehlgeschlagen!${NC}"
    exit 1
fi
echo ""

# 8. Teste HTTPS
echo "8. Teste HTTPS..."
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
echo "WAS WURDE GEMACHT:"
echo "────────────────────────────────────────────────"
echo "1. Zertifikat erneuert"
echo "2. Minimale nginx-Konfiguration erstellt"
echo "3. Alle anderen Konfigurationen entfernt"
echo "4. Nur das Nötigste aktiviert"
echo ""
echo "JETZT TESTEN:"
echo "────────────────────────────────────────────────"
echo "1. Browser-Cache komplett leeren"
echo "2. In Incognito-Modus testen"
echo "3. Öffne: https://explorer.kalon-network.com"
echo ""
echo "Falls immer noch Fehler:"
echo "────────────────────────────────────────────────"
echo "1. Prüfe Browser-Konsole (F12)"
echo "2. Teste mit: curl -v https://explorer.kalon-network.com"
echo "3. Prüfe nginx-Logs: sudo tail -f /var/log/nginx/error.log"

