#!/bin/bash
# Script zum Lösen von Git-Konflikten vor git pull

# Farben
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo "=== GIT-KONFLIKTE LÖSEN ==="
echo ""

cd ~/kalon-network || {
    echo -e "${RED}❌ Verzeichnis ~/kalon-network nicht gefunden!${NC}"
    exit 1
}

# 1. Lokale Binaries entfernen (werden neu gebaut)
echo "1. Entferne lokale Binaries..."
rm -f build-v2/kalon-node-v2 build-v2/kalon-miner-v2 build-v2/kalon-wallet 2>/dev/null || true
echo -e "${GREEN}✅ Lokale Binaries entfernt${NC}"
echo ""

# 2. Gelöschte Scripts wiederherstellen (falls lokal vorhanden)
echo "2. Entferne lokale gelöschte Scripts..."
rm -f check-rpc-status.sh check-test-status.sh clean-system.sh diagnose-rpc.sh diagnose-server-environment.sh diagnose-test-server.sh fix-test-server.sh monitor-test.sh pre-pull.sh server-test-fixed.sh server-test.sh test-block15.sh test-comprehensive-long.sh test-difficulty-fix.sh test-exact-match.sh test-pow-activation.sh test-quick-10min-nohup.sh test-quick-10min.sh test-quick-mining.sh test-server-io-performance.sh test-server-memory-pressure.sh update-and-run-test.sh update-and-test.sh 2>/dev/null || true
echo -e "${GREEN}✅ Lokale gelöschte Scripts entfernt${NC}"
echo ""

# 3. Git Status zurücksetzen
echo "3. Setze Git-Status zurück..."
git reset --hard HEAD 2>/dev/null || true
git clean -fd 2>/dev/null || true
echo -e "${GREEN}✅ Git-Status zurückgesetzt${NC}"
echo ""

# 4. Jetzt git pull
echo "4. Git Pull..."
if git pull origin master; then
    echo -e "${GREEN}✅ Git Pull erfolgreich!${NC}"
else
    echo -e "${RED}❌ Git Pull fehlgeschlagen!${NC}"
    exit 1
fi
echo ""

echo -e "${GREEN}=== KONFLIKTE GELÖST ===${NC}"
echo ""
echo "Jetzt Node neu bauen:"
echo "  go build -o build-v2/kalon-node-v2 ./cmd/kalon-node-v2"
echo "  chmod +x build-v2/kalon-node-v2"

