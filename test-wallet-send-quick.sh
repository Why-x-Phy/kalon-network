#!/bin/bash
# Schneller Test für Wallet-Send-Funktionalität
# Prüft nur ob das Binary korrekt gebaut wurde und das --input Flag erkennt

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

BUILD_DIR="$SCRIPT_DIR/build"

echo "=== SCHNELLER WALLET-SEND TEST ==="
echo ""

# 1. Prüfe ob Binary existiert
if [ ! -f "$BUILD_DIR/kalon-wallet" ]; then
    echo "❌ Binary nicht gefunden. Baue..."
    go build -o "$BUILD_DIR/kalon-wallet" ./cmd/kalon-wallet
fi

# 2. Prüfe ob --input Flag erkannt wird
echo "1. Prüfe --input Flag..."
if ./build/kalon-wallet send --help 2>&1 | grep -q "\-input"; then
    echo "✓ --input Flag wird erkannt"
else
    echo "❌ --input Flag wird NICHT erkannt!"
    echo "   Verfügbare Flags:"
    ./build/kalon-wallet send --help 2>&1 | grep -A 10 "Usage of send"
    exit 1
fi

# 3. Prüfe ob Binary kompiliert wurde
echo "2. Prüfe Binary-Kompilierung..."
if go build -o "$BUILD_DIR/kalon-wallet" ./cmd/kalon-wallet 2>&1 | grep -q "error"; then
    echo "❌ Kompilierungsfehler!"
    go build -o "$BUILD_DIR/kalon-wallet" ./cmd/kalon-wallet 2>&1
    exit 1
else
    echo "✓ Binary kompiliert erfolgreich"
fi

# 4. Prüfe ob Funktionen vorhanden sind
echo "3. Prüfe ob Funktionen im Code vorhanden sind..."
if grep -q "^func createUnsignedTransaction" cmd/kalon-wallet/main.go && \
   grep -q "^func sendSignedTransaction" cmd/kalon-wallet/main.go; then
    echo "✓ Funktionen im Code vorhanden"
else
    echo "❌ Funktionen fehlen im Code!"
    echo "   createUnsignedTransaction: $(grep -c 'func createUnsignedTransaction' cmd/kalon-wallet/main.go || echo 0)"
    echo "   sendSignedTransaction: $(grep -c 'func sendSignedTransaction' cmd/kalon-wallet/main.go || echo 0)"
    exit 1
fi

echo ""
echo "=== ALLE TESTS BESTANDEN ==="
echo "✓ Binary erkennt --input Flag"
echo "✓ Binary kompiliert ohne Fehler"
echo "✓ Alle Funktionen vorhanden"



