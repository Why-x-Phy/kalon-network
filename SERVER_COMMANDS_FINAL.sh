#!/bin/bash
# Kalon Balance Test - Ubuntu Server Commands (FINAL VERSION)

echo "🚀 Kalon Balance Test - Schritt für Schritt"
echo "=========================================="
echo ""

# Schritt 1: Repository aktualisieren
echo "📥 Schritt 1: Repository aktualisieren..."
cd ~/kalon-network
git pull origin master
echo "✅ Repository aktualisiert"
echo ""

# Schritt 2: Alte Prozesse stoppen
echo "🛑 Schritt 2: Alte Prozesse stoppen..."
pkill -f kalon-node
pkill -f kalon-miner
sleep 2
echo "✅ Prozesse gestoppt"
echo ""

# Schritt 3: Prüfe cmd/ Struktur
echo "🔍 Schritt 3: Prüfe cmd/ Struktur..."
ls -la cmd/
echo ""

# Schritt 4: Alte Builds löschen
echo "🗑️ Schritt 4: Alte Builds löschen..."
rm -rf build-v2/
mkdir -p build-v2
echo "✅ Build-Verzeichnis erstellt"
echo ""

# Schritt 5: Neu kompilieren
echo "🔨 Schritt 5: Neu kompilieren..."
go build -o build-v2/kalon-node-v2 ./cmd/kalon-node 2>&1 || {
    echo "❌ FEHLER: kalon-node konnte nicht kompiliert werden!"
    echo "   Verzeichnisse in cmd/:"
    ls -la cmd/
    exit 1
}

go build -o build-v2/kalon-miner-v2 ./cmd/kalon-miner 2>&1 || {
    echo "❌ FEHLER: kalon-miner konnte nicht kompiliert werden!"
    exit 1
}

go build -o build-v2/kalon-wallet ./cmd/kalon-wallet 2>&1 || {
    echo "⚠️  WARNING: kalon-wallet konnte nicht kompiliert werden (optional)"
}

echo "✅ Kompilierung abgeschlossen"
echo ""

# Schritt 6: Prüfe ob Binaries existieren
if [ ! -f "build-v2/kalon-node-v2" ]; then
    echo "❌ FEHLER: kalon-node-v2 existiert nicht!"
    exit 1
fi

if [ ! -f "build-v2/kalon-miner-v2" ]; then
    echo "❌ FEHLER: kalon-miner-v2 existiert nicht!"
    exit 1
fi

echo "✅ Binaries gefunden"
ls -lh build-v2/
echo ""

# Schritt 7: Node starten
echo "🚀 Schritt 7: Node starten..."
nohup ./build-v2/kalon-node-v2 --datadir data-v2/testnet --genesis genesis/testnet.json --rpc :16316 --p2p :17335 > node-v2.log 2>&1 &
NODE_PID=$!
echo "✅ Node gestartet (PID: $NODE_PID)"
echo ""

# Schritt 8: Warten
echo "⏳ Schritt 8: Warten (5 Sekunden)..."
sleep 5
echo "✅ Wartezeit abgeschlossen"
echo ""

# Schritt 9: Prüfe ob Node läuft
echo "🔍 Schritt 9: Prüfe ob Node läuft..."
if ps -p $NODE_PID > /dev/null; then
    echo "✅ Node läuft (PID: $NODE_PID)"
else
    echo "❌ Node läuft NICHT! Prüfe node-v2.log"
    echo "   Letzte 20 Zeilen des Logs:"
    tail -20 node-v2.log
    exit 1
fi
echo ""

# Schritt 10: Height prüfen
echo "📊 Schritt 10: Block-Height prüfen..."
HEIGHT=$(curl -s http://localhost:16316 -X POST -H 'Content-Type: application/json' -d '{"jsonrpc":"2.0","id":1,"method":"getHeight","params":[]}' 2>/dev/null | jq -r '.result' 2>/dev/null)
if [ -z "$HEIGHT" ] || [ "$HEIGHT" = "null" ]; then
    echo "⚠️  Node antwortet nicht! Prüfe Logs..."
    tail -20 node-v2.log
else
    echo "   Height: $HEIGHT"
fi
echo ""

# Schritt 11: Miner starten
echo "⛏️ Schritt 11: Miner starten..."
nohup ./build-v2/kalon-miner-v2 --wallet kalon1r9wen9um8qwfdxdyk9u5yr3sd5ym5vrj72cttt --threads 2 --rpc http://localhost:16316 > miner-v2.log 2>&1 &
MINER_PID=$!
echo "✅ Miner gestartet (PID: $MINER_PID)"
echo ""

# Schritt 12: Warten auf Block
echo "⏳ Schritt 12: Warten auf geminten Block (60 Sekunden)..."
for i in {60..1}; do
    printf "   Verbleibend: %2ds\r" $i
    sleep 1
done
echo ""
echo "✅ Wartezeit abgeschlossen"
echo ""

# Schritt 13: Balance prüfen
echo "💰 Schritt 13: Balance prüfen..."
BALANCE=$(curl -s http://localhost:16316 -X POST -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"getBalance","params":{"address":"kalon1r9wen9um8qwfdxdyk9u5yr3sd5ym5vrj72cttt"}}' 2>/dev/null | jq -r '.result' 2>/dev/null)
echo ""

if [ -z "$BALANCE" ] || [ "$BALANCE" = "null" ]; then
    echo "⚠️  Balance-Query fehlgeschlagen!"
else
    if [ "$BALANCE" = "0" ]; then
        echo "❌ BALANCE = 0 (BUG NOCH DA!)"
    else
        echo "✅ BALANCE = $BALANCE (FUNKTIONIERT!)"
    fi
fi
echo ""

# Schritt 14: Debug-Info
echo "📊 Schritt 14: Debug-Info..."
echo "   UTXO-Logs:"
tail -100 node-v2.log | grep "UTXO\|Address" | tail -10 || echo "   Keine UTXO-Logs gefunden"
echo ""

echo "=========================================="
echo "✅ Balance-Test abgeschlossen!"
echo ""
echo "📊 Monitor:"
echo "   tail -f node-v2.log"
echo "   tail -f miner-v2.log"
echo ""
