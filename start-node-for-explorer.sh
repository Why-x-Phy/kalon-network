#!/bin/bash
# Script zum Starten des Nodes für Explorer

# Farben
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo "=== NODE FÜR EXPLORER STARTEN ==="
echo ""

# 1. Prüfe ob Node bereits läuft
echo "1. Prüfe ob Node bereits läuft..."
if pgrep -f "kalon-node-v2" > /dev/null; then
    NODE_PID=$(pgrep -f "kalon-node-v2")
    echo -e "${YELLOW}⚠️ Node läuft bereits (PID: $NODE_PID)${NC}"
    echo "   Prüfe ob Node korrekt läuft..."
    
    # Teste RPC
    HEIGHT=$(curl -s http://localhost:16316/rpc -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getHeight","id":1}' 2>/dev/null | grep -o '"result":[0-9]*' | cut -d: -f2)
    if [ -n "$HEIGHT" ]; then
        echo -e "${GREEN}✅ Node RPC funktioniert (Height: $HEIGHT)${NC}"
        echo ""
        echo "Node läuft bereits und funktioniert!"
        exit 0
    else
        echo -e "${RED}❌ Node läuft, aber RPC funktioniert nicht${NC}"
        echo "   Stoppe alten Node..."
        killall kalon-node-v2
        sleep 2
    fi
else
    echo -e "${YELLOW}⚠️ Node läuft nicht${NC}"
fi
echo ""

# 2. Prüfe ob Binary vorhanden ist
echo "2. Prüfe ob Binary vorhanden ist..."
if [ -f "./build-v2/kalon-node-v2" ]; then
    echo -e "${GREEN}✅ Binary vorhanden${NC}"
else
    echo -e "${RED}❌ Binary nicht gefunden!${NC}"
    echo "   Baue Node: go build -o build-v2/kalon-node-v2 ./cmd/kalon-node-v2/"
    exit 1
fi
echo ""

# 3. Prüfe ob Daten-Verzeichnis vorhanden ist
echo "3. Prüfe Daten-Verzeichnis..."
if [ -d "data-testnet" ]; then
    echo -e "${GREEN}✅ Daten-Verzeichnis vorhanden${NC}"
else
    echo -e "${YELLOW}⚠️ Daten-Verzeichnis nicht vorhanden, erstelle es...${NC}"
    mkdir -p data-testnet
fi
echo ""

# 4. Starte Node
echo "4. Starte Node..."
./build-v2/kalon-node-v2 \
  -datadir data-testnet \
  -genesis genesis/testnet.json \
  -rpc 127.0.0.1:16316 \
  -p2p 0.0.0.0:17335 \
  > node.log 2>&1 &

NODE_PID=$!
echo "   Node gestartet (PID: $NODE_PID)"
echo ""

# 5. Warte auf Node-Start
echo "5. Warte auf Node-Start..."
sleep 5

# 6. Teste Node RPC
echo "6. Teste Node RPC..."
MAX_RETRIES=10
RETRY=0
while [ $RETRY -lt $MAX_RETRIES ]; do
    HEIGHT=$(curl -s http://localhost:16316/rpc -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getHeight","id":1}' 2>/dev/null | grep -o '"result":[0-9]*' | cut -d: -f2)
    if [ -n "$HEIGHT" ]; then
        echo -e "${GREEN}✅ Node RPC funktioniert (Height: $HEIGHT)${NC}"
        break
    else
        RETRY=$((RETRY + 1))
        echo "   Versuch $RETRY/$MAX_RETRIES... (warte 2 Sekunden)"
        sleep 2
    fi
done

if [ -z "$HEIGHT" ]; then
    echo -e "${RED}❌ Node RPC funktioniert nicht nach $MAX_RETRIES Versuchen${NC}"
    echo "   Prüfe Logs: tail -f node.log"
    exit 1
fi
echo ""

# 7. Teste nginx RPC-Proxy
echo "7. Teste nginx RPC-Proxy..."
PROXY_HEIGHT=$(curl -s http://localhost/rpc -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getHeight","id":1}' 2>/dev/null | grep -o '"result":[0-9]*' | cut -d: -f2)
if [ -n "$PROXY_HEIGHT" ]; then
    echo -e "${GREEN}✅ nginx RPC-Proxy funktioniert (Height: $PROXY_HEIGHT)${NC}"
else
    echo -e "${YELLOW}⚠️ nginx RPC-Proxy funktioniert nicht${NC}"
    echo "   Prüfe nginx-Logs: sudo tail -f /var/log/nginx/error.log"
fi
echo ""

echo -e "${GREEN}=== NODE GESTARTET ===${NC}"
echo ""
echo "Node Status:"
echo "────────────────────────────────────────────────"
echo "PID: $NODE_PID"
echo "Height: $HEIGHT"
echo "RPC: http://localhost:16316"
echo "Logs: tail -f node.log"
echo ""
echo "Jetzt testen:"
echo "1. HTTP über IP: http://185.133.249.107"
echo "2. HTTPS über IP: https://185.133.249.107"
echo "3. HTTPS über Domain: https://explorer.kalon-network.com"
echo ""
echo "Explorer sollte jetzt 'ONLINE' zeigen!"

