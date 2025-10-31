#!/bin/bash
# Komplettes Test-Script für den Test-Server (mit Git-Fix)
# Führt alle Schritte automatisch aus

set -e

echo "=== KALON BLOCKCHAIN TEST FÜR TEST-SERVER ==="
echo ""

# 1. Ins Projekt-Verzeichnis wechseln
echo "1. Ins Projekt-Verzeichnis wechseln..."
cd ~/kalon-network 2>/dev/null || cd ~/kalon 2>/dev/null || cd ~/kalon-network || (echo "❌ Projekt-Verzeichnis nicht gefunden!" && exit 1)
echo "✅ Im Projekt-Verzeichnis: $(pwd)"
echo ""

# 2. Lokale Änderungen stashen (vor allem Binaries)
echo "2. Lokale Änderungen stashen..."
git stash push -m "Lokale Binaries vor git pull" build-v2/ 2>/dev/null || true
echo "✅ Lokale Änderungen gestasht"
echo ""

# 3. Repository aktualisieren
echo "3. Repository aktualisieren..."
git pull origin master
echo "✅ Repository aktualisiert"
echo ""

# 4. Binaries bauen
echo "4. Binaries bauen..."
go build -o build-v2/kalon-node-v2 ./cmd/kalon-node-v2
go build -o build-v2/kalon-miner-v2 ./cmd/kalon-miner-v2
go build -o build-v2/kalon-wallet ./cmd/kalon-wallet
chmod +x build-v2/kalon-node-v2 build-v2/kalon-miner-v2 build-v2/kalon-wallet
echo "✅ Binaries gebaut und ausführbar gemacht"
echo ""

# 5. Test-Script ausführbar machen
echo "5. Test-Script vorbereiten..."
if [ -f test-quick-10min.sh ]; then
    chmod +x test-quick-10min.sh
    echo "✅ test-quick-10min.sh ausführbar gemacht"
else
    echo "❌ test-quick-10min.sh nicht gefunden!"
    exit 1
fi
echo ""

# 6. Alte Prozesse beenden
echo "6. Alte Prozesse beenden..."
killall -9 kalon-node-v2 kalon-miner-v2 2>/dev/null || true
pkill -9 -f "test-quick" 2>/dev/null || true
sleep 2
lsof -ti:16316 -ti:17335 2>/dev/null | xargs kill -9 2>/dev/null || true
sleep 2
echo "✅ Prozesse bereinigt"
echo ""

# 7. Test starten
echo "7. Starte 10-Minuten-Test..."
echo "   (Test läuft im Hintergrund)"
./test-quick-10min.sh > test-output.log 2>&1 &
TEST_PID=$!
echo "✅ Test gestartet (PID: $TEST_PID)"
echo ""

# 8. Warten und Status prüfen
echo "8. Warte 2 Minuten für ersten Status-Check..."
sleep 120

echo ""
echo "=== STATUS NACH 2 MINUTEN ==="
HEIGHT=$(curl -s http://localhost:16316/rpc -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getHeight","id":1}' 2>/dev/null | jq -r .result 2>/dev/null || echo "0")
BALANCE=$(curl -s http://localhost:16316/rpc -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getBalance","params":{"address":"8cc92a1d253973db54f716e0f8747988dbbe9116"},"id":1}' 2>/dev/null | jq -r .result 2>/dev/null || echo "0")

if [ "$HEIGHT" != "0" ] && [ "$HEIGHT" != "null" ] && [ "$HEIGHT" != "N/A" ]; then
    echo "✅ Blockchain läuft!"
    echo "   Block-Höhe: $HEIGHT"
    echo "   Wallet Balance: $BALANCE"
else
    echo "⚠️ Node noch nicht bereit oder Test läuft noch..."
    echo "   Prüfe Test-Output: tail -f test-output.log"
fi

echo ""
echo "=== TEST LÄUFT WEITER ==="
echo "Der Test läuft noch ~8 Minuten im Hintergrund."
echo ""
echo "Test-Output prüfen mit:"
echo "  tail -f test-output.log"
echo ""
echo "Finale Ergebnisse werden nach 10 Minuten in test-output.log angezeigt."
echo ""
echo "Test beenden mit:"
echo "  killall -9 kalon-node-v2 kalon-miner-v2"
echo "  pkill -9 -f test-quick"
