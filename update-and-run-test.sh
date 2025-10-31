#!/bin/bash
# Komplettes Update und Test-Script - macht ALLES automatisch

set -e  # Stoppt bei Fehlern

cd ~/kalon-network || {
    echo "❌ Verzeichnis ~/kalon-network nicht gefunden!"
    exit 1
}

echo "=== KOMPLETTES UPDATE UND TEST ==="
echo ""

# 1. Stoppe alle laufenden Prozesse
echo "1. Stoppe laufende Prozesse..."
killall -9 kalon-node-v2 kalon-miner-v2 2>/dev/null || true
pkill -9 -f test-quick 2>/dev/null || true
pkill -9 -f test-comprehensive 2>/dev/null || true
sleep 2
echo "✅ Prozesse gestoppt"
echo ""

# 2. Git Stash - stashe ALLE lokalen Änderungen
echo "2. Stashe lokale Änderungen..."
git stash push -m "Lokale Änderungen vor Update $(date +%Y%m%d_%H%M%S)" || true
echo "✅ Lokale Änderungen gestasht"
echo ""

# 3. Entferne lokale Binaries die Konflikte verursachen
echo "3. Entferne lokale Binaries..."
rm -f build-v2/kalon-node-v2 build-v2/kalon-miner-v2 build-v2/kalon-wallet 2>/dev/null || true
echo "✅ Lokale Binaries entfernt"
echo ""

# 4. Git Pull
echo "4. Pull Updates..."
git pull origin master || {
    echo "❌ Git pull fehlgeschlagen!"
    exit 1
}
echo "✅ Repository aktualisiert"
echo ""

# 5. Setze Ausführungsrechte für ALLE Scripts
echo "5. Setze Ausführungsrechte für Scripts..."
chmod +x *.sh 2>/dev/null || true
chmod +x scripts/*.sh 2>/dev/null || true
echo "✅ Scripts ausführbar gemacht"
echo ""

# 6. Baue Binaries
echo "6. Baue Binaries..."
go build -o build-v2/kalon-node-v2 ./cmd/kalon-node-v2 || {
    echo "❌ Node Build fehlgeschlagen!"
    exit 1
}
echo "✅ Node gebaut"

go build -o build-v2/kalon-miner-v2 ./cmd/kalon-miner-v2 || {
    echo "❌ Miner Build fehlgeschlagen!"
    exit 1
}
echo "✅ Miner gebaut"

go build -o build-v2/kalon-wallet ./cmd/kalon-wallet || {
    echo "❌ Wallet Build fehlgeschlagen!"
    exit 1
}
echo "✅ Wallet gebaut"
echo ""

# 7. Setze Ausführungsrechte für Binaries
echo "7. Setze Ausführungsrechte für Binaries..."
chmod +x build-v2/kalon-node-v2 build-v2/kalon-miner-v2 build-v2/kalon-wallet 2>/dev/null || true
echo "✅ Binaries ausführbar gemacht"
echo ""

# 8. Starte Test im Hintergrund mit nohup
echo "8. Starte Test..."
nohup ./test-quick-10min.sh > test-output.log 2>&1 &
TEST_PID=$!
sleep 3

# 9. Prüfe ob Test läuft
if ps -p $TEST_PID > /dev/null 2>&1; then
    echo "✅ Test läuft (PID: $TEST_PID)"
else
    echo "⚠️ Test-Prozess läuft nicht mehr - prüfe Logs"
    tail -n 30 test-output.log
    exit 1
fi
echo ""

echo "=== UPDATE ABGESCHLOSSEN ==="
echo ""
echo "Test läuft im Hintergrund (PID: $TEST_PID)"
echo ""
echo "Monitor-Befehle:"
echo "  tail -f test-output.log           # Live-Log"
echo "  ./check-rpc-status.sh             # Status prüfen"
echo "  ps aux | grep test-quick          # Prozess prüfen"
echo ""
echo "Test stoppen:"
echo "  killall -9 kalon-node-v2 kalon-miner-v2"
echo "  pkill -9 -f test-quick"

