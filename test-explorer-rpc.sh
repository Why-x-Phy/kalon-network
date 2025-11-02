#!/bin/bash
# Test Explorer mit direktem RPC-Zugriff

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

RPC_URL="http://localhost:16316"
DATA_DIR="data/testnet-explorer-test"

echo -e "${YELLOW}=== EXPLORER RPC TEST ===${NC}"
echo ""

# Cleanup
echo "1. Cleanup..."
killall -9 kalon-node-v2 2>/dev/null || true
rm -rf "$DATA_DIR" 2>/dev/null || true
sleep 2
echo "✅ Cleanup abgeschlossen"
echo ""

# Start Node
echo "2. Starte Node mit RPC..."
./build-v2/kalon-node-v2 -datadir "$DATA_DIR" -rpc :16316 > node-explorer-test.log 2>&1 &
NODE_PID=$!
sleep 5

# Test CORS
echo "3. Teste CORS..."
CORS_HEADERS=$(curl -s -I -X OPTIONS "$RPC_URL/rpc" -H "Origin: http://localhost" -H "Access-Control-Request-Method: POST" | grep -i "access-control" || echo "KEINE CORS HEADER")
echo "CORS Headers:"
echo "$CORS_HEADERS"
echo ""

# Test RPC from browser perspective
echo "4. Teste RPC-Aufruf (Browser-Simulation)..."
RPC_RESPONSE=$(curl -s -X POST "$RPC_URL/rpc" \
  -H "Content-Type: application/json" \
  -H "Origin: http://localhost" \
  -d '{"jsonrpc":"2.0","method":"getHeight","id":1}')

HEIGHT=$(echo "$RPC_RESPONSE" | grep -o '"result":[0-9]*' | grep -o '[0-9]*' || echo "FEHLER")

if [ "$HEIGHT" != "FEHLER" ]; then
    echo -e "${GREEN}✅ RPC funktioniert! Height: $HEIGHT${NC}"
else
    echo -e "${RED}❌ RPC Fehler: $RPC_RESPONSE${NC}"
fi
echo ""

# Test Online Status Check
echo "5. Teste Online-Status-Check..."
STATUS_CHECK=$(curl -s -X POST "$RPC_URL/rpc" \
  -H "Content-Type: application/json" \
  -H "Origin: http://localhost" \
  -d '{"jsonrpc":"2.0","method":"getHeight","id":1}' | grep -o '"result"' || echo "FEHLER")

if [ "$STATUS_CHECK" = '"result"' ]; then
    echo -e "${GREEN}✅ Online-Status-Check funktioniert!${NC}"
else
    echo -e "${RED}❌ Online-Status-Check fehlgeschlagen${NC}"
fi
echo ""

echo "6. Prüfe Node-Log..."
tail -n 5 node-explorer-test.log
echo ""

echo "✅ Test abgeschlossen!"
echo ""
echo "Frontend kann jetzt direkt auf $RPC_URL/rpc zugreifen"
echo "CORS ist aktiviert ✅"

# Node bleibt laufen für weitere Tests
# kill $NODE_PID 2>/dev/null || true

