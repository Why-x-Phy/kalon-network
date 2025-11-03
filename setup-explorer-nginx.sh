#!/bin/bash
# Script zum Setup des Explorers auf dem Node-Server mit nginx

# Farben
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo "=== EXPLORER AUF NODE-SERVER SETUP ==="
echo ""

# 1. nginx installieren
echo "1. Prüfe nginx Installation..."
if ! command -v nginx &> /dev/null; then
    echo "   nginx nicht gefunden. Installiere nginx..."
    sudo apt update
    sudo apt install -y nginx
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ nginx installiert${NC}"
    else
        echo -e "${RED}❌ nginx Installation fehlgeschlagen!${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✅ nginx bereits installiert${NC}"
fi
echo ""

# 2. Explorer-Verzeichnis erstellen
echo "2. Erstelle Explorer-Verzeichnis..."
EXPLORER_DIR="/var/www/explorer"
sudo mkdir -p "$EXPLORER_DIR"
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Verzeichnis erstellt: $EXPLORER_DIR${NC}"
else
    echo -e "${RED}❌ Verzeichnis-Erstellung fehlgeschlagen!${NC}"
    exit 1
fi
echo ""

# 3. Explorer-Dateien kopieren
echo "3. Kopiere Explorer-Dateien..."
CURRENT_DIR=$(pwd)
if [ -d "$CURRENT_DIR/explorer/static" ]; then
    sudo cp -r "$CURRENT_DIR/explorer/static"/* "$EXPLORER_DIR/"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Explorer-Dateien kopiert${NC}"
    else
        echo -e "${RED}❌ Kopieren fehlgeschlagen!${NC}"
        exit 1
    fi
else
    echo -e "${RED}❌ explorer/static Verzeichnis nicht gefunden!${NC}"
    echo "   Stelle sicher, dass du im kalon-network Verzeichnis bist"
    exit 1
fi
echo ""

# 4. Berechtigungen setzen
echo "4. Setze Berechtigungen..."
sudo chown -R www-data:www-data "$EXPLORER_DIR"
sudo chmod -R 755 "$EXPLORER_DIR"
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Berechtigungen gesetzt${NC}"
else
    echo -e "${RED}❌ Berechtigungen setzen fehlgeschlagen!${NC}"
    exit 1
fi
echo ""

# 5. nginx-Konfiguration erstellen
echo "5. Erstelle nginx-Konfiguration..."
NGINX_CONFIG="/etc/nginx/sites-available/explorer"
sudo tee "$NGINX_CONFIG" > /dev/null << 'NGINX_EOF'
server {
    listen 80;
    server_name explorer.kalon-network.com;

    # Explorer-Dateien
    root /var/www/explorer;
    index index.html;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

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

# 6. nginx-Konfiguration aktivieren
echo "6. Aktiviere nginx-Konfiguration..."
sudo ln -sf /etc/nginx/sites-available/explorer /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ nginx-Konfiguration aktiviert${NC}"
else
    echo -e "${RED}❌ Aktivierung fehlgeschlagen!${NC}"
    exit 1
fi
echo ""

# 7. nginx-Konfiguration testen
echo "7. Teste nginx-Konfiguration..."
if sudo nginx -t; then
    echo -e "${GREEN}✅ nginx-Konfiguration ist gültig${NC}"
else
    echo -e "${RED}❌ nginx-Konfiguration hat Fehler!${NC}"
    exit 1
fi
echo ""

# 8. nginx starten/neu laden
echo "8. Starte/neu lade nginx..."
sudo systemctl reload nginx
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ nginx neu geladen${NC}"
else
    echo -e "${YELLOW}⚠️ Versuche nginx zu starten...${NC}"
    sudo systemctl start nginx
    sudo systemctl enable nginx
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ nginx gestartet${NC}"
    else
        echo -e "${RED}❌ nginx starten fehlgeschlagen!${NC}"
        exit 1
    fi
fi
echo ""

# 9. Firewall Ports prüfen
echo "9. Prüfe Firewall Ports..."
if sudo ufw status | grep -q "80/tcp"; then
    echo -e "${GREEN}✅ Port 80 ist bereits geöffnet${NC}"
else
    echo -e "${YELLOW}⚠️ Port 80 ist nicht geöffnet. Öffne jetzt...${NC}"
    sudo ufw allow 80/tcp
fi

if sudo ufw status | grep -q "443/tcp"; then
    echo -e "${GREEN}✅ Port 443 ist bereits geöffnet${NC}"
else
    echo -e "${YELLOW}⚠️ Port 443 ist nicht geöffnet. Öffne jetzt...${NC}"
    sudo ufw allow 443/tcp
fi
echo ""

echo -e "${GREEN}=== SETUP ABGESCHLOSSEN ===${NC}"
echo ""
echo "Nächste Schritte:"
echo "1. DNS A-Record ändern: explorer.kalon-network.com → 185.133.249.107"
echo "2. Warte 5-15 Minuten bis DNS propagiert ist"
echo "3. Certbot installieren und Zertifikat holen:"
echo "   sudo apt install certbot python3-certbot-nginx"
echo "   sudo certbot --nginx -d explorer.kalon-network.com"
echo "4. Node starten (nur HTTP, localhost):"
echo "   ./build-v2/kalon-node-v2 -datadir data-testnet -genesis genesis/testnet.json -rpc 127.0.0.1:16316 -p2p 0.0.0.0:17335 > node.log 2>&1 &"
echo "5. Testen: https://explorer.kalon-network.com"

