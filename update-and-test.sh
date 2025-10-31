#!/bin/bash
# Komplettes Update und Test auf Test-Server

echo "=== UPDATE UND TEST ==="
echo ""

# 1. Stop processes
echo "1. Stoppe laufende Prozesse..."
killall -9 kalon-node-v2 kalon-miner-v2 2>/dev/null || true
pkill -9 -f test-quick 2>/dev/null || true
sleep 2

# 2. Remove local binaries (they will be rebuilt)
echo "2. Entferne lokale Binaries..."
rm -f build-v2/kalon-node-v2 build-v2/kalon-miner-v2 build-v2/kalon-wallet 2>/dev/null || true

# 3. Pull updates
echo "3. Pull Updates..."
git pull origin master || {
    echo "❌ Git pull fehlgeschlagen"
    exit 1
}

# 4. Set execute permissions for scripts
echo "4. Setze Ausführungsrechte für Scripts..."
chmod +x test-quick-10min.sh check-rpc-status.sh fix-test-server.sh update-and-test.sh 2>/dev/null || true

# 5. Build binaries
echo "5. Baue Binaries..."
go build -o build-v2/kalon-node-v2 ./cmd/kalon-node-v2 || {
    echo "❌ Node Build fehlgeschlagen"
    exit 1
}

go build -o build-v2/kalon-miner-v2 ./cmd/kalon-miner-v2 || {
    echo "❌ Miner Build fehlgeschlagen"
    exit 1
}

go build -o build-v2/kalon-wallet ./cmd/kalon-wallet || {
    echo "❌ Wallet Build fehlgeschlagen"
    exit 1
}

# 6. Set execute permissions for binaries
echo "6. Setze Ausführungsrechte für Binaries..."
chmod +x build-v2/kalon-node-v2 build-v2/kalon-miner-v2 build-v2/kalon-wallet 2>/dev/null || true

echo ""
echo "✅ Update abgeschlossen!"
echo ""

# 7. Start test
echo "7. Starte Test..."
./test-quick-10min.sh > test-output.log 2>&1 &

echo ""
echo "Test läuft im Hintergrund (PID: $!)"
echo "Monitor mit: tail -f test-output.log"
echo "Status prüfen: ./check-rpc-status.sh"

