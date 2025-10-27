#!/bin/bash

echo "=== Kalon Explorer Setup ==="
echo ""

# Prüfe ob Node läuft
if ! pgrep -f kalon-node-v2 > /dev/null; then
    echo "⚠️  Node läuft nicht. Starte Node..."
    ./build-v2/kalon-node-v2 -datadir data-v2/testnet -genesis genesis/testnet.json -rpc :16316 > /tmp/node.log 2>&1 &
    sleep 3
    echo "✅ Node gestartet"
else
    echo "✅ Node läuft bereits"
fi

# Prüfe ob API läuft
if ! pgrep -f explorer-api > /dev/null; then
    echo ""
    echo "Starting Explorer API..."
    cd explorer/api
    go build -o explorer-api main.go
    ./explorer-api > /tmp/explorer-api.log 2>&1 &
    cd ../..
    sleep 2
    echo "✅ API gestartet (Port 8081)"
else
    echo "✅ API läuft bereits"
fi

echo ""
echo "🚀 Explorer bereit!"
echo ""
echo "URLs:"
echo "  Frontend: http://localhost:3000"
echo "  API: http://localhost:8081"
echo ""
echo "Nächste Schritte:"
echo "  1. Terminal 2 öffnen"
echo "  2. cd explorer/ui"
echo "  3. npm install  # Falls erste Installation"
echo "  4. npm start"
echo ""
echo "Health Check:"
echo "  curl http://localhost:8081/health"
