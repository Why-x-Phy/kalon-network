#!/bin/bash
# Test-Script für Remote-Zugriff auf Master Node

# Farben
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

NODE_IP="185.133.249.107"
RPC_PORT="16316"
RPC_URL="http://${NODE_IP}:${RPC_PORT}"

echo "=== MASTER NODE REMOTE TEST ==="
echo ""
echo "Node IP: ${NODE_IP}"
echo "RPC Port: ${RPC_PORT}"
echo ""

# Test 1: Port ist offen?
echo "1. Teste ob Port ${RPC_PORT} offen ist..."
if command -v nc >/dev/null 2>&1; then
    if nc -zv -w 5 ${NODE_IP} ${RPC_PORT} 2>&1 | grep -q "succeeded"; then
        echo -e "${GREEN}✅ Port ${RPC_PORT} ist offen${NC}"
    else
        echo -e "${RED}❌ Port ${RPC_PORT} ist NICHT erreichbar${NC}"
    fi
elif command -v telnet >/dev/null 2>&1; then
    timeout 3 telnet ${NODE_IP} ${RPC_PORT} 2>&1 | grep -q "Connected" && echo -e "${GREEN}✅ Port ${RPC_PORT} ist offen${NC}" || echo -e "${RED}❌ Port ${RPC_PORT} ist NICHT erreichbar${NC}"
else
    echo -e "${YELLOW}⚠️ nc oder telnet nicht verfügbar, überspringe Port-Test${NC}"
fi
echo ""

# Test 2: RPC getHeight
echo "2. Teste RPC getHeight..."
HEIGHT_RESPONSE=$(curl -s -m 5 "${RPC_URL}/rpc" -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getHeight","id":1}')
if [ $? -eq 0 ] && echo "$HEIGHT_RESPONSE" | grep -q "result"; then
    HEIGHT=$(echo "$HEIGHT_RESPONSE" | grep -o '"result":[0-9]*' | grep -o '[0-9]*')
    echo -e "${GREEN}✅ RPC funktioniert! Height: ${HEIGHT}${NC}"
    echo "   Response: $HEIGHT_RESPONSE"
else
    echo -e "${RED}❌ RPC funktioniert NICHT${NC}"
    echo "   Response: $HEIGHT_RESPONSE"
fi
echo ""

# Test 3: RPC getMiningInfo
echo "3. Teste RPC getMiningInfo..."
MINING_INFO=$(curl -s -m 5 "${RPC_URL}/rpc" -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getMiningInfo","id":1}')
if [ $? -eq 0 ] && echo "$MINING_INFO" | grep -q "result"; then
    echo -e "${GREEN}✅ getMiningInfo funktioniert!${NC}"
    echo "   Response: $MINING_INFO"
else
    echo -e "${RED}❌ getMiningInfo funktioniert NICHT${NC}"
    echo "   Response: $MINING_INFO"
fi
echo ""

# Test 4: CORS Headers
echo "4. Teste CORS Headers..."
CORS_HEADERS=$(curl -s -I -X OPTIONS "${RPC_URL}/rpc" -H "Origin: http://example.com" -H "Access-Control-Request-Method: POST")
if echo "$CORS_HEADERS" | grep -q "Access-Control-Allow-Origin"; then
    echo -e "${GREEN}✅ CORS Headers sind korrekt gesetzt${NC}"
    echo "$CORS_HEADERS" | grep -i "access-control"
else
    echo -e "${RED}❌ CORS Headers fehlen oder sind falsch${NC}"
fi
echo ""

# Test 5: Browser-Zugriff simulieren
echo "5. Simuliere Browser-Zugriff (mit Origin Header)..."
BROWSER_TEST=$(curl -s -m 5 "${RPC_URL}/rpc" \
    -H "Content-Type: application/json" \
    -H "Origin: http://your-webspace-domain.com" \
    -d '{"jsonrpc":"2.0","method":"getHeight","id":1}')
if [ $? -eq 0 ] && echo "$BROWSER_TEST" | grep -q "result"; then
    echo -e "${GREEN}✅ Browser-Zugriff funktioniert!${NC}"
    echo "   Response: $BROWSER_TEST"
else
    echo -e "${RED}❌ Browser-Zugriff funktioniert NICHT${NC}"
    echo "   Response: $BROWSER_TEST"
fi
echo ""

echo "=== TEST ABGESCHLOSSEN ==="
echo ""
echo "Falls alle Tests grün sind:"
echo -e "${GREEN}✅ Master Node ist öffentlich erreichbar${NC}"
echo -e "${GREEN}✅ Explorer sollte funktionieren${NC}"
echo -e "${GREEN}✅ Slave Nodes können sich verbinden${NC}"
echo ""

