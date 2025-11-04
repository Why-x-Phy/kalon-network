# Kompletter Server-Setup - Schritt für Schritt

## Voraussetzungen

- Ubuntu Server (neu installiert)
- Root-Zugriff
- DNS A-Record gesetzt: `explorer.kalon-network.com` → `185.133.249.107`

## Option 1: Automatisches Setup (Empfohlen)

```bash
# 1. Repository klonen
git clone https://github.com/Why-x-Phy/kalon-network.git
cd kalon-network

# 2. Setup-Script ausführen
chmod +x complete-server-setup.sh
sudo ./complete-server-setup.sh
```

## Option 2: Manuelles Setup

### Schritt 1: System aktualisieren

```bash
sudo apt update
sudo apt upgrade -y
```

### Schritt 2: Go installieren

```bash
wget https://go.dev/dl/go1.21.5.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.21.5.linux-amd64.tar.gz
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
export PATH=$PATH:/usr/local/go/bin
go version
```

### Schritt 3: Git installieren

```bash
sudo apt install -y git
```

### Schritt 4: Repository klonen

```bash
git clone https://github.com/Why-x-Phy/kalon-network.git
cd kalon-network
```

### Schritt 5: Binaries bauen

```bash
export PATH=$PATH:/usr/local/go/bin
go build -o build-v2/kalon-node-v2 ./cmd/kalon-node-v2/
go build -o build-v2/kalon-miner-v2 ./cmd/kalon-miner-v2/
go build -o build-v2/kalon-wallet ./cmd/kalon-wallet/
chmod +x build-v2/*
```

### Schritt 6: nginx installieren

```bash
sudo apt install -y nginx
```

### Schritt 7: Explorer-Dateien installieren

```bash
sudo mkdir -p /var/www/explorer
sudo cp -r explorer/static/* /var/www/explorer/
sudo chown -R www-data:www-data /var/www/explorer
sudo chmod -R 755 /var/www/explorer
```

### Schritt 8: Firewall Ports öffnen

```bash
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 17335/tcp
sudo ufw --force enable
```

### Schritt 9: nginx konfigurieren

```bash
# Erstelle nginx-Konfiguration
sudo nano /etc/nginx/sites-available/explorer

# Oder verwende das Setup-Script
chmod +x setup-explorer-nginx.sh
sudo ./setup-explorer-nginx.sh
```

### Schritt 10: Certbot installieren

```bash
sudo apt install -y certbot python3-certbot-nginx
```

### Schritt 11: SSL-Zertifikat holen

```bash
# WICHTIG: DNS A-Record muss gesetzt sein!
# explorer.kalon-network.com → 185.133.249.107

# Stoppe nginx
sudo systemctl stop nginx

# Hole Zertifikat
sudo certbot certonly --standalone -d explorer.kalon-network.com --non-interactive --agree-tos --email admin@kalon-network.com
```

### Schritt 12: nginx starten

```bash
sudo systemctl start nginx
sudo systemctl enable nginx
```

### Schritt 13: Node starten

```bash
cd ~/kalon-network
mkdir -p data-testnet

./build-v2/kalon-node-v2 \
  -datadir data-testnet \
  -genesis genesis/testnet.json \
  -rpc 127.0.0.1:16316 \
  -p2p 0.0.0.0:17335 \
  > node.log 2>&1 &
```

### Schritt 14: Testen

```bash
# Teste Node RPC
curl http://localhost:16316/rpc -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getHeight","id":1}'

# Teste HTTPS
curl https://explorer.kalon-network.com
```

## Wichtige Befehle

### Node starten

```bash
cd ~/kalon-network
./build-v2/kalon-node-v2 \
  -datadir data-testnet \
  -genesis genesis/testnet.json \
  -rpc 127.0.0.1:16316 \
  -p2p 0.0.0.0:17335 \
  > node.log 2>&1 &
```

### Node stoppen

```bash
killall kalon-node-v2
```

### nginx neu laden

```bash
sudo systemctl reload nginx
```

### Logs prüfen

```bash
# Node-Logs
tail -f node.log

# nginx Error-Log
sudo tail -f /var/log/nginx/error.log

# nginx Access-Log
sudo tail -f /var/log/nginx/access.log
```

## Troubleshooting

### Node startet nicht

```bash
# Prüfe Logs
tail -f node.log

# Prüfe ob Port 16316 frei ist
sudo ss -tlnp | grep 16316
```

### nginx startet nicht

```bash
# Teste Konfiguration
sudo nginx -t

# Prüfe Logs
sudo tail -f /var/log/nginx/error.log
```

### SSL-Zertifikat funktioniert nicht

```bash
# Erneuere Zertifikat
sudo certbot certonly --standalone -d explorer.kalon-network.com --force-renewal

# Prüfe Zertifikat
sudo openssl x509 -in /etc/letsencrypt/live/explorer.kalon-network.com/fullchain.pem -noout -text
```

## Nach dem Setup

1. Öffne im Browser: `https://explorer.kalon-network.com`
2. Explorer sollte "ONLINE" zeigen
3. Block-Height sollte angezeigt werden

