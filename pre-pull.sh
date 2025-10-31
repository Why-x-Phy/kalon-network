#!/bin/bash
# Entfernt lokale Dateien die Git-Konflikte verursachen
# Dieses Script muss VOR dem ersten git pull ausgeführt werden

echo "=== VORBEREITUNG FÜR GIT PULL ==="
echo ""

cd ~/kalon-network 2>/dev/null || {
    echo "❌ Verzeichnis ~/kalon-network nicht gefunden!"
    exit 1
}

# 1. Stoppe laufende Prozesse
echo "1. Stoppe laufende Prozesse..."
killall -9 kalon-node-v2 kalon-miner-v2 2>/dev/null || true
pkill -9 -f test-quick 2>/dev/null || true
sleep 1
echo "✅ Prozesse gestoppt"
echo ""

# 2. Entferne lokale Binaries die Konflikte verursachen
echo "2. Entferne lokale Binaries..."
rm -f build-v2/kalon-node-v2 build-v2/kalon-miner-v2 build-v2/kalon-wallet 2>/dev/null || true
echo "✅ Lokale Binaries entfernt"
echo ""

# 3. Entferne lokale Script-Änderungen die Konflikte verursachen
echo "3. Entferne lokale Script-Änderungen..."
git checkout -- test-quick-10min.sh 2>/dev/null || true
git checkout -- fix-test-server.sh 2>/dev/null || true
git checkout -- check-rpc-status.sh 2>/dev/null || true
git checkout -- update-and-test.sh 2>/dev/null || true
echo "✅ Lokale Script-Änderungen entfernt"
echo ""

# 4. ODER: Stashe alle lokalen Änderungen (falls git checkout nicht funktioniert)
echo "4. Stashe lokale Änderungen (falls vorhanden)..."
git stash push -m "Lokale Änderungen vor git pull" 2>/dev/null || true
echo "✅ Lokale Änderungen gestasht"
echo ""

echo "✅ VORBEREITUNG ABGESCHLOSSEN!"
echo ""
echo "Jetzt kann git pull ausgeführt werden:"
echo "  git pull origin master"
echo ""
echo "Dann fix-test-server.sh ausführen:"
echo "  chmod +x fix-test-server.sh"
echo "  ./fix-test-server.sh"

