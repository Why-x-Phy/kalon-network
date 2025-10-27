# Kalon Explorer - Startanleitung

## Übersicht

Der Kalon Explorer besteht aus 2 Komponenten:
1. **API Server** (Go) - Port 8081
2. **Frontend UI** (React) - Port 3000

## Voraussetzungen

### 1. Node.js installiert
```bash
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs
```

### 2. Node läuft und ist erreichbar
Der Explorer benötigt Zugriff auf den RPC-Server (Port 16316)

## Start-Anleitung

### Schritt 1: Node & Miner starten (wenn noch nicht laufend)
```bash
# Node starten
./build-v2/kalon-node-v2 -datadir data-v2/testnet -genesis genesis/testnet.json -rpc :16316 > /tmp/node.log 2>&1 &

# Optional: Miner starten
./build-v2/kalon-miner-v2 -wallet "$(cat wallet.json | jq -r .address)" -threads 1 -rpc http://localhost:16316
```

### Schritt 2: API Server starten
```bash
cd /home/whyphyc/Kalon/kalon/explorer/api
go run main.go
```

**ODER als Build:**
```bash
cd /home/whyphyc/Kalon/kalon/explorer/api
go build -o explorer-api main.go
./explorer-api
```

Die API läuft dann auf: **http://localhost:8081**

### Schritt 3: Frontend starten
```bash
cd /home/whyphyc/Kalon/kalon/explorer/ui
npm install  # Erste Installation
npm start
```

Das Frontend läuft dann auf: **http://localhost:3000**

## URLs

- **Frontend (UI):** http://localhost:3000
- **API:** http://localhost:8081
- **Health Check:** http://localhost:8081/health
- **Stats:** http://localhost:8081/stats
- **Blocks:** http://localhost:8081/blocks

## Environment Variables

### API Server
```bash
export KALON_RPC_URL="http://localhost:16316"
export KALON_API_ADDR="8081"
```

## Alle Komponenten starten (Script)

Erstelle: `start-explorer.sh`

```bash
#!/bin/bash

echo "=== Kalon Explorer Setup ==="

# 1. Node starten
echo "Starting Node..."
./build-v2/kalon-node-v2 -datadir data-v2/testnet -genesis genesis/testnet.json -rpc :16316 > /tmp/node.log 2>&1 &
sleep 3

# 2. API starten
echo "Starting Explorer API..."
cd explorer/api
go run main.go &
API_PID=$!
cd ../..

# 3. Frontend starten
echo "Starting Explorer UI..."
cd explorer/ui
npm start &
UI_PID=$!

echo ""
echo "✅ Explorer gestartet!"
echo "Frontend: http://localhost:3000"
echo "API: http://localhost:8081"
echo ""
echo "PID zum Stoppen:"
echo "Node: $(pgrep -f kalon-node-v2)"
echo "API: $API_PID"
echo "UI: $UI_PID"
```

## Production Deployment

Für Production:

### 1. Frontend builden
```bash
cd explorer/ui
npm run build
```

### 2. Mit Nginx bereitstellen
```bash
sudo cp explorer/ui/build/* /var/www/html/
```

## Troubleshooting

### API startet nicht
- Prüfe ob Node läuft: `curl http://localhost:16316/rpc -d '{"jsonrpc":"2.0","method":"getHeight","id":1}'`
- Prüfe Port: `netstat -tulpn | grep 8081`

### Frontend startet nicht
- Prüfe ob npm installiert: `npm --version`
- Installiere Dependencies: `cd explorer/ui && npm install`

### Keine Daten angezeigt
- Prüfe ob Node läuft und gemined wird
- Prüfe API: `curl http://localhost:8081/health`
