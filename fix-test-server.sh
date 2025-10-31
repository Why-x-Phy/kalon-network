#!/bin/bash
# Fix für Test-Server (behandelt Git-Konflikte)

echo "=== FIX FÜR TEST-SERVER ==="
echo ""

cd ~/kalon-network

# 1. Stoppe laufende Prozesse
echo "1. Stoppe laufende Prozesse..."
killall -9 kalon-node-v2 kalon-miner-v2 2>/dev/null || true
pkill -9 -f test-quick 2>/dev/null || true
sleep 2

# 2. Entferne lokale Binaries (werden neu gebaut)
echo "2. Entferne lokale Binaries..."
rm -f build-v2/kalon-node-v2 build-v2/kalon-miner-v2 build-v2/kalon-wallet 2>/dev/null || true
echo "✅ Lokale Binaries entfernt"
echo ""

# 3. Git Pull
echo "3. Git Pull..."
git pull origin master || {
    echo "❌ Git pull fehlgeschlagen"
    exit 1
}
echo "✅ Repository aktualisiert"
echo ""

# 4. Setze Ausführungsrechte für Scripts
echo "4. Setze Ausführungsrechte für Scripts..."
chmod +x test-quick-10min.sh check-rpc-status.sh fix-test-server.sh update-and-test.sh 2>/dev/null || true
echo "✅ Scripts ausführbar gemacht"
echo ""

# 5. Baue Binaries
echo "5. Baue Binaries..."
go build -o build-v2/kalon-node-v2 ./cmd/kalon-node-v2 || {
    echo "❌ Node Build fehlgeschlagen"
    exit 1
}
echo "✅ Node gebaut"

go build -o build-v2/kalon-miner-v2 ./cmd/kalon-miner-v2 || {
    echo "❌ Miner Build fehlgeschlagen"
    exit 1
}
echo "✅ Miner gebaut"

go build -o build-v2/kalon-wallet ./cmd/kalon-wallet || {
    echo "❌ Wallet Build fehlgeschlagen"
    exit 1
}
echo "✅ Wallet gebaut"
echo ""

# 6. Setze Ausführungsrechte für Binaries
echo "6. Setze Ausführungsrechte für Binaries..."
chmod +x build-v2/kalon-node-v2 build-v2/kalon-miner-v2 build-v2/kalon-wallet 2>/dev/null || true
echo "✅ Binaries ausführbar gemacht"
echo ""

echo "✅ Fix abgeschlossen!"
echo ""
echo "Jetzt Test starten:"
echo "  ./test-quick-10min.sh > test-output.log 2>&1 &"
echo ""
echo "Status prüfen:"
echo "  ./check-rpc-status.sh"
