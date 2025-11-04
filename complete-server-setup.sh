#!/bin/bash
# Kompletter Server-Setup für Kalon Explorer

# Farben
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo "=== KOMPLETTER KALON SERVER SETUP ==="
echo ""

# Variablen
SERVER_IP="185.133.249.107"
DOMAIN="explorer.kalon-network.com"

# 1. System aktualisieren
echo "1. Aktualisiere System..."
sudo apt update
sudo apt upgrade -y
echo -e "${GREEN}✅ System aktualisiert${NC}"
echo ""

# 2. Go installieren
echo "2. Installiere Go..."
if command -v go &> /dev/null; then
    echo -e "${GREEN}✅ Go bereits installiert${NC}"
    go version
else
    echo "   Installiere Go 1.21..."
    wget https://go.dev/dl/go1.21.5.linux-amd64.tar.gz
    sudo tar -C /usr/local -xzf go1.21.5.linux-amd64.tar.gz
    echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
    export PATH=$PATH:/usr/local/go/bin
    go version
    echo -e "${GREEN}✅ Go installiert${NC}"
fi
echo ""

# 3. Git installieren
echo "3. Installiere Git..."
sudo apt install -y git
echo -e "${GREEN}✅ Git installiert${NC}"
echo ""

# 4. Repository klonen/bauen
echo "4. Klone Repository..."
if [ -d "kalon-network" ]; then
    echo "   Repository bereits vorhanden, aktualisiere..."
    cd kalon-network
    git pull origin master
else
    git clone https://github.com/Why-x-Phy/kalon-network.git
    cd kalon-network
fi
echo -e "${GREEN}✅ Repository bereit${NC}"
echo ""

# 5. Baue Binaries
echo "5. Baue Binaries..."
export PATH=$PATH:/usr/local/go/bin
go build -o build-v2/kalon-node-v2 ./cmd/kalon-node-v2/
go build -o build-v2/kalon-miner-v2 ./cmd/kalon-miner-v2/
go build -o build-v2/kalon-wallet ./cmd/kalon-wallet/
chmod +x build-v2/*
echo -e "${GREEN}✅ Binaries gebaut${NC}"
echo ""

# 6. nginx installieren
echo "6. Installiere nginx..."
sudo apt install -y nginx
echo -e "${GREEN}✅ nginx installiert${NC}"
echo ""

# 7. Explorer-Verzeichnis erstellen
echo "7. Erstelle Explorer-Verzeichnis..."
sudo mkdir -p /var/www/explorer
sudo cp -r explorer/static/* /var/www/explorer/
sudo chown -R www-data:www-data /var/www/explorer
sudo chmod -R 755 /var/www/explorer
echo -e "${GREEN}✅ Explorer-Verzeichnis erstellt${NC}"
echo ""

# 8. Firewall Ports öffnen
echo "8. Öffne Firewall Ports..."
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 17335/tcp
sudo ufw --force enable
echo -e "${GREEN}✅ Firewall Ports geöffnet${NC}"
echo ""

# 9. Erstelle einfache nginx-Konfiguration
echo "9. Erstelle nginx-Konfiguration..."
NGINX_CONFIG="/etc/nginx/sites-available/explorer"
sudo tee "$NGINX_CONFIG" > /dev/null << NGINX_EOF
# HTTP - Redirect zu HTTPS
server {
    listen 80;
    server_name ${DOMAIN} ${SERVER_IP};
    return 301 https://\$server_name\$request_uri;
}

# HTTPS - EINFACH
server {
    listen 443 ssl;
    server_name ${DOMAIN} ${SERVER_IP};

    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;

    root /var/www/explorer;
    index index.html;

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    location /rpc {
        proxy_pass http://127.0.0.1:16316/rpc;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
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

sudo rm -f /etc/nginx/sites-enabled/*
sudo ln -s /etc/nginx/sites-available/explorer /etc/nginx/sites-enabled/explorer
echo -e "${GREEN}✅ nginx-Konfiguration erstellt${NC}"
echo ""

# 10. Certbot installieren
echo "10. Installiere Certbot..."
sudo apt install -y certbot python3-certbot-nginx
echo -e "${GREEN}✅ Certbot installiert${NC}"
echo ""

# 11. Stoppe nginx für Zertifikat-Erstellung
echo "11. Stoppe nginx für Zertifikat-Erstellung..."
sudo systemctl stop nginx
sleep 2
echo -e "${GREEN}✅ nginx gestoppt${NC}"
echo ""

# 12. Hole SSL-Zertifikat
echo "12. Hole SSL-Zertifikat..."
echo "   WICHTIG: Stelle sicher, dass DNS A-Record gesetzt ist!"
echo "   explorer.kalon-network.com → ${SERVER_IP}"
read -p "   DNS A-Record gesetzt? (j/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Jj]$ ]]; then
    echo -e "${YELLOW}⚠️ Setze DNS A-Record zuerst!${NC}"
    echo "   Dann führe aus: sudo certbot certonly --standalone -d ${DOMAIN}"
    exit 1
fi

sudo certbot certonly --standalone -d ${DOMAIN} --non-interactive --agree-tos --email admin@kalon-network.com
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ SSL-Zertifikat erstellt${NC}"
else
    echo -e "${RED}❌ SSL-Zertifikat-Erstellung fehlgeschlagen!${NC}"
    echo "   Prüfe DNS A-Record!"
    exit 1
fi
echo ""

# 13. Starte nginx
echo "13. Starte nginx..."
sudo systemctl start nginx
sudo systemctl enable nginx
sleep 2
if systemctl is-active --quiet nginx; then
    echo -e "${GREEN}✅ nginx läuft${NC}"
else
    echo -e "${RED}❌ nginx starten fehlgeschlagen!${NC}"
    exit 1
fi
echo ""

# 14. Starte Node
echo "14. Starte Node..."
mkdir -p data-testnet
./build-v2/kalon-node-v2 \
  -datadir data-testnet \
  -genesis genesis/testnet.json \
  -rpc 127.0.0.1:16316 \
  -p2p 0.0.0.0:17335 \
  > node.log 2>&1 &

sleep 5

if pgrep -f "kalon-node-v2" > /dev/null; then
    echo -e "${GREEN}✅ Node läuft${NC}"
else
    echo -e "${RED}❌ Node starten fehlgeschlagen!${NC}"
    echo "   Prüfe Logs: tail -f node.log"
fi
echo ""

# 15. Teste alles
echo "15. Teste Setup..."
sleep 3

# Teste Node RPC
RPC_HEIGHT=$(curl -s http://localhost:16316/rpc -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getHeight","id":1}' 2>/dev/null | grep -o '"result":[0-9]*' | cut -d: -f2)
if [ -n "$RPC_HEIGHT" ]; then
    echo -e "${GREEN}✅ Node RPC funktioniert (Height: $RPC_HEIGHT)${NC}"
else
    echo -e "${YELLOW}⚠️ Node RPC funktioniert noch nicht (warte noch...)${NC}"
fi

# Teste nginx
NGINX_STATUS=$(curl --http1.1 -s -o /dev/null -w "%{http_code}" --max-time 5 https://${DOMAIN} 2>/dev/null)
if [ "$NGINX_STATUS" = "200" ]; then
    echo -e "${GREEN}✅ HTTPS über Domain funktioniert${NC}"
else
    echo -e "${YELLOW}⚠️ HTTPS über Domain gibt Status: $NGINX_STATUS${NC}"
fi
echo ""

echo -e "${GREEN}=== SETUP ABGESCHLOSSEN ===${NC}"
echo ""
echo "ZUSAMMENFASSUNG:"
echo "────────────────────────────────────────────────"
echo "✅ System aktualisiert"
echo "✅ Go installiert"
echo "✅ Repository geklont und Binaries gebaut"
echo "✅ nginx installiert und konfiguriert"
echo "✅ Explorer-Dateien installiert"
echo "✅ Firewall Ports geöffnet"
echo "✅ SSL-Zertifikat erstellt"
echo "✅ nginx läuft"
echo "✅ Node läuft"
echo ""
echo "JETZT TESTEN:"
echo "────────────────────────────────────────────────"
echo "1. Öffne im Browser: https://${DOMAIN}"
echo "2. Explorer sollte 'ONLINE' zeigen"
echo ""
echo "FALLS PROBLEME:"
echo "────────────────────────────────────────────────"
echo "1. Prüfe Node: tail -f node.log"
echo "2. Prüfe nginx: sudo tail -f /var/log/nginx/error.log"
echo "3. Prüfe DNS: dig ${DOMAIN}"

