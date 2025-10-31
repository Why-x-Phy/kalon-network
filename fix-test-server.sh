#!/bin/bash
# Fix für Test-Server (behandelt Git-Konflikte)

echo "=== FIX FÜR TEST-SERVER ==="
echo ""

cd ~/kalon-network

# 1. Stashe lokale Binary-Änderungen
echo "1. Stashe lokale Binary-Änderungen..."
git stash push -m "Lokale Binary vor git pull" build-v2/kalon-node-v2 2>/dev/null || true
echo "✅ Gestasht"
echo ""

# 2. Git Pull
echo "2. Git Pull..."
git pull origin master
echo "✅ Repository aktualisiert"
echo ""

# 3. Node neu bauen
echo "3. Node neu bauen..."
go build -o build-v2/kalon-node-v2 ./cmd/kalon-node-v2
if [ $? -ne 0 ]; then
    echo "❌ Build fehlgeschlagen!"
    exit 1
fi
echo "✅ Node gebaut"
echo ""

# 4. Ausführbar machen
echo "4. Ausführbar machen..."
chmod +x build-v2/kalon-node-v2
chmod +x test-quick-10min.sh
echo "✅ Ausführbar gemacht"
echo ""

# 5. Alte Prozesse beenden
echo "5. Alte Prozesse beenden..."
killall -9 kalon-node-v2 kalon-miner-v2 2>/dev/null || true
pkill -9 -f test-quick 2>/dev/null || true
sleep 2
echo "✅ Prozesse bereinigt"
echo ""

# 6. Test starten
echo "6. Test starten..."
./test-quick-10min.sh > test-output.log 2>&1 &
TEST_PID=$!
echo "✅ Test gestartet (PID: $TEST_PID)"
echo ""

echo "Test läuft im Hintergrund."
echo "Prüfe Status mit: tail -f test-output.log"
