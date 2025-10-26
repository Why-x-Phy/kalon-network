#!/bin/bash
# Kalon Balance Test - Ubuntu Server Commands

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
echo "✅ Builds gelöscht"
echo ""

# Schritt 4: Neu kompilieren
echo "🔨 Schritt 4: Neu kompilieren..."
./scripts/build-v2.sh
echo "✅ Kompilierung abgeschlossen"
echo ""

# Schritt 5: Node starten
echo "🚀 Schritt 5: Node starten..."
nohup ./build-v2/kalon-node-v2 --datadir data-v2/testnet --genesis genesis/testnet.json --rpc :16316 --p2p :17335 > node-v2.log 2>&1 &
NODE_PID=$!
echo "✅ Node gestartet (PID: $NODE_PID)"
echo ""

# Schritt 6: Warten
echo "⏳ Schritt 6: Warten (5 Sekunden)..."
sleep 5
echo "✅ Wartezeit abgeschlossen"
echo ""

# Schritt 7: Miner starten
echo "⛏️ Schritt 7: Miner starten..."
nohup ./build-v2/kalon-miner-v2 --wallet kalon1r9wen9um8qwfdxdyk9u5yr3sd5ym5vrj72cttt --threads 2 --rpc http://localhost:16316 > miner-v2.log 2>&1 &
MINER_PID=$!
echo "✅ Miner gestartet (PID: $MINER_PID)"
echo ""

# Schritt 8: Warten bis Block gemint ist
echo "⏳ Schritt 8: Warten auf geminten Block (60 Sekunden)..."
echo "   (Miner log kann mit 'tail -f miner-v2.log' verfolgt werden)"
sleep 60
echo "✅ Wartezeit abgeschlossen"
echo ""

# Schritt 9: Balance prüfen
echo "💰 Schritt 9: Balance prüfen..."
echo ""
curl -s http://localhost:16316 -X POST -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"getBalance","params":{"address":"kalon1r9wen9um8qwfdxdyk9u5yr3sd5ym5vrj72cttt"}}' | jq
echo ""

# Schritt 10: Height prüfen
echo "📊 Schritt 10: Block-Height prüfen..."
HEIGHT=$(curl -s http://localhost:16316 -X POST -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"getHeight","params":[]}' | jq -r '.result')
echo "   Height: $HEIGHT"
echo ""

# Schritt 11: Logs prüfen
echo "📝 Schritt 11: UTXO-Logs prüfen..."
echo "   (Letzte 20 UTXO-Einträge)"
tail -100 node-v2.log | grep "UTXO\|Address" | tail -20
echo ""

echo "=========================================="
echo "✅ Balance-Test abgeschlossen!"
echo ""
echo "🔍 Wenn Balance = 0:"
echo "   - Prüfe 'node-v2.log' für UTXO-Erstellung"
echo "   - Prüfe 'miner-v2.log' für Mining-Activity"
echo ""
echo "📊 Monitor-Befehle:"
echo "   tail -f node-v2.log    # Node-Logs"
echo "   tail -f miner-v2.log   # Miner-Logs"
echo ""
