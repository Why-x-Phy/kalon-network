#!/bin/bash
# Kalon Balance Test - Ubuntu Server Commands (FIXED)

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

# Schritt 3: Alte Builds löschen
echo "🗑️ Schritt 3: Alte Builds löschen..."
rm -rf build-v2/
mkdir -p build-v2
echo "✅ Build-Verzeichnis erstellt"
echo ""

# Schritt 4: Neu kompilieren (manual go build)
echo "🔨 Schritt 4: Neu kompilieren..."
go build -o build-v2/kalon-node-v2 ./cmd/kalon-node-v2
go build -o build-v2/kalon-miner-v2 ./cmd/kalon-miner-v2
go build -o build-v2/kalon-wallet ./cmd/kalon-wallet
echo "✅ Kompilierung abgeschlossen"
echo ""

# Schritt 5: Prüfe ob Binaries existieren
if [ ! -f "build-v2/kalon-node-v2" ]; then
    echo "❌ FEHLER: kalon-node-v2 konnte nicht kompiliert werden!"
    echo "   Prüfe ob cmd/kalon-node-v2/main.go existiert"
    exit 1
fi

if [ ! -f "build-v2/kalon-miner-v2" ]; then
    echo "❌ FEHLER: kalon-miner-v2 konnte nicht kompiliert werden!"
    echo "   Prüfe ob cmd/kalon-miner-v2/main.go existiert"
    exit 1
fi

echo "✅ Binaries gefunden"
echo ""

# Schritt 6: Node starten
echo "🚀 Schritt 6: Node starten..."
nohup ./build-v2/kalon-node-v2 --datadir data-v2/testnet --genesis genesis/testnet.json --rpc :16316 --p2p :17335 > node-v2.log 2>&1 &
NODE_PID=$!
echo "✅ Node gestartet (PID: $NODE_PID)"
echo ""

# Schritt 7: Warten
echo "⏳ Schritt 7: Warten (5 Sekunden)..."
sleep 5
echo "✅ Wartezeit abgeschlossen"
echo ""

# Schritt 8: Prüfe ob Node läuft
echo "🔍 Schritt 8: Prüfe ob Node läuft..."
if ps -p $NODE_PID > /dev/null; then
    echo "✅ Node läuft (PID: $NODE_PID)"
else
    echo "❌ Node läuft NICHT! Prüfe node-v2.log"
    echo "   Letzte 20 Zeilen des Logs:"
    tail -20 node-v2.log
    exit 1
fi
echo ""

# Schritt 9: Height prüfen (Node muss aktiv sein)
echo "📊 Schritt 9: Block-Height prüfen..."
HEIGHT=$(curl -s http://localhost:16316 -X POST -H 'Content-Type: application/json' -d '{"jsonrpc":"2.0","id":1,"method":"getHeight","params":[]}' 2>/dev/null | jq -r '.result' 2>/dev/null)
if [ -z "$HEIGHT" ] || [ "$HEIGHT" = "null" ]; then
    echo "⚠️  Node antwortet nicht! Prüfe Logs..."
    tail -20 node-v2.log
else
    echo "   Height: $HEIGHT"
fi
echo ""

# Schritt 10: Miner starten
echo "⛏️ Schritt 10: Miner starten..."
nohup ./build-v2/kalon-miner-v2 --wallet kalon1r9wen9um8qwfdxdyk9u5yr3sd5ym5vrj72cttt --threads 2 --rpc http://localhost:16316 > miner-v2.log 2>&1 &
MINER_PID=$!
echo "✅ Miner gestartet (PID: $MINER_PID)"
echo ""

# Schritt 11: Warten bis Block gemint ist
echo "⏳ Schritt 11: Warten auf geminten Block (60 Sekunden)..."
echo "   (Du kannst mit 'tail -f miner-v2.log' minen verfolgen)"
for i in {60..1}; do
    echo -ne "   Verbleibend: ${i}s\r"
    sleep 1
done
echo ""
echo "✅ Wartezeit abgeschlossen"
echo ""

# Schritt 12: Balance prüfen
echo "💰 Schritt 12: Balance prüfen..."
BALANCE=$(curl -s http://localhost:16316 -X POST -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"getBalance","params":{"address":"kalon1r9wen9um8qwfdxdyk9u5yr3sd5ym5vrj72cttt"}}' 2>/dev/null | jq -r '.result' 2>/dev/null)
echo ""

if [ -z "$BALANCE" ] || [ "$BALANCE" = "null" ]; then
    echo "⚠️  Balance-Query fehlgeschlagen!"
    echo "   Prüfe ob Node läuft: tail -f node-v2.log"
else
    if [ "$BALANCE" = "0" ]; then
        echo "❌ BALANCE = 0 (BUG NOCH DA!)"
        echo ""
        echo "🔍 Debug-Info:"
        echo "   Prüfe node-v2.log nach UTXO-Einträgen:"
        tail -100 node-v2.log | grep "UTXO\|Address" | tail -20
    else
        echo "✅ BALANCE = $BALANCE (FUNKTIONIERT!)"
    fi
fi
echo ""

# Schritt 13: Height prüfen
echo "📊 Schritt 13: Finale Block-Height..."
FINAL_HEIGHT=$(curl -s http://localhost:16316 -X POST -H 'Content-Type: application/json' -d '{"jsonrpc":"2.0","id":1,"method":"getHeight","params":[]}' 2>/dev/null | jq -r '.result' 2>/dev/null)
echo "   Height: $FINAL_HEIGHT"
echo ""

echo "=========================================="
echo "✅ Balance-Test abgeschlossen!"
echo ""
echo "📊 Nützliche Befehle:"
echo "   tail -f node-v2.log    # Node-Logs"
echo "   tail -f miner-v2.log   # Miner-Logs"
echo "   ps aux | grep kalon    # Prozesse prüfen"
echo ""
