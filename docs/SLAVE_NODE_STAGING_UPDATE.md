# Slave Node: Update nach Staging

## Übersicht

Wenn auf dem **Master Node** ein Staging (Chain-Reset mit Difficulty-Änderung) durchgeführt wurde, müssen **alle Slave Nodes** aktualisiert werden, damit sie:
1. Die neue Genesis-Datei verwenden
2. Die Chain-Daten zurücksetzen
3. Das Snapshot aus der neuen Genesis laden
4. Die neue Difficulty übernehmen

## Was passiert beim Staging auf dem Master?

1. **Master Node stoppt** (Node + Miner)
2. **Snapshot wird erstellt** (alle aktuellen Balances)
3. **Neue Genesis-Datei wird erstellt** (`genesis/{chain}-stage2.json`)
   - Neue Difficulty wird gesetzt
   - Snapshot wird eingebunden (`snapshot.enabled: true`)
   - Snapshot enthält alle Balances vom Zeitpunkt des Resets
4. **Chain-Daten werden gelöscht** (Reset)
5. **Master Node startet mit neuer Genesis**
   - Snapshot wird automatisch geladen
   - Balances werden wiederhergestellt
   - Chain startet bei Height 0 mit neuer Difficulty

## Was müssen Slave Nodes tun?

### Schritt 1: Master Node benachrichtigen

Der Master Node Admin muss den Slave Nodes mitteilen:
- **Neue Genesis-Datei**: `genesis/{chain}-stage2.json`
- **Snapshot-Datei** (optional, zur Verifizierung): `snapshots/archive/snapshot-{chain}-stage-end-{timestamp}.json`
- **Neue Difficulty**: z.B. von 23 auf 28
- **Staging-Datum**: Wann das Staging durchgeführt wurde

### Schritt 2: Slave Node stoppen

```bash
# Stoppe Node und Miner
killall kalon-node-v2 kalon-miner-v2
# Oder:
pkill -f kalon-node-v2
pkill -f kalon-miner-v2
```

### Schritt 3: Neue Genesis-Datei erhalten

**Option A: Via Git (empfohlen)**
```bash
cd ~/kalon-network
git pull origin master
# Prüfe ob neue Genesis-Datei vorhanden ist
ls -la genesis/{chain}-stage2.json
```

**Option B: Manuell kopieren**
```bash
# Kopiere neue Genesis vom Master Node
scp user@master-node:/path/to/kalon/genesis/{chain}-stage2.json ./genesis/
```

**Option C: Vom Repository herunterladen**
```bash
# Falls im Git Repository
wget https://github.com/kalon-network/kalon/raw/master/genesis/{chain}-stage2.json -O genesis/{chain}-stage2.json
```

### Schritt 4: Chain-Daten löschen (RESET)

⚠️ **WICHTIG**: Chain-Daten **MÜSSEN** gelöscht werden, sonst startet die Node mit der alten Chain!

```bash
# Für Testnet:
rm -rf data/testnet/chaindb data/testnet/utxodb data/testnet/*.log

# Für Mainnet:
rm -rf data/mainnet/chaindb data/mainnet/utxodb data/mainnet/*.log

# Für Community Testnet:
rm -rf data-community-testnet/chaindb data-community-testnet/utxodb data-community-testnet/*.log
```

### Schritt 5: Node mit neuer Genesis starten

```bash
# Für Testnet:
./build-v2/kalon-node-v2 \
  -datadir data/testnet \
  -genesis genesis/testnet-stage2.json \
  -rpc :16316

# Für Mainnet:
./build-v2/kalon-node-v2 \
  -datadir data/mainnet \
  -genesis genesis/mainnet-stage2.json \
  -rpc :16316
```

### Schritt 6: Verifizierung

Prüfe ob alles korrekt funktioniert:

```bash
# 1. Prüfe Height (sollte 0 oder 1 sein)
curl -X POST http://localhost:16316/rpc \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"getHeight","id":1}'

# Erwartet: {"result": 0} oder {"result": 1}

# 2. Prüfe Difficulty (sollte neue Difficulty sein)
curl -X POST http://localhost:16316/rpc \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"getMiningInfo","id":1}'

# Erwartet: {"result": {"difficulty": 28, ...}} (neue Difficulty)

# 3. Prüfe Balance (sollte wiederhergestellt sein)
curl -X POST http://localhost:16316/rpc \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"getBalance","params":{"address":"IhreWalletAdresse"},"id":1}'

# Erwartet: Vorherige Balance (wiederhergestellt)
```

### Schritt 7: Mit Master synchronisieren

Die Slave Node sollte sich jetzt automatisch mit dem Master synchronisieren:

```bash
# Prüfe ob Node mit Master synchronisiert
# (abhängig von P2P-Konfiguration)
```

## Was passiert, wenn Slave Nodes NICHT aktualisiert werden?

### Problem 1: Fork
- Slave Node läuft weiterhin mit alter Genesis
- Master Node läuft mit neuer Genesis
- Unterschiedliche Chain-IDs oder Difficulty
- **Ergebnis**: Fork - Slave und Master sind inkompatibel

### Problem 2: Synchronisierung schlägt fehl
- Slave Node versucht mit Master zu synchronisieren
- Master sendet Blocks mit neuer Difficulty
- Slave validiert Blocks mit alter Difficulty
- **Ergebnis**: Blocks werden abgelehnt, Synchronisierung schlägt fehl

### Problem 3: Alte Balances
- Slave Node hat alte Chain-Daten (Height 100, Difficulty 23)
- Master Node hat neue Chain-Daten (Height 0, Difficulty 28)
- **Ergebnis**: Inkonsistente Balances, falsche Anzeigen

## Automatisierter Update-Prozess (Optional)

### Script für Slave Node Update

```bash
#!/bin/bash
# update-slave-node.sh

CHAIN="testnet"  # Oder: mainnet, community-testnet
GENESIS_FILE="genesis/${CHAIN}-stage2.json"
DATA_DIR="data/${CHAIN}"

echo "=== SLAVE NODE UPDATE ==="
echo ""

# 1. Stoppe Node und Miner
echo "1. Stoppe Node und Miner..."
killall kalon-node-v2 kalon-miner-v2 2>/dev/null || true
sleep 2
echo "✅ Gestoppt"
echo ""

# 2. Git Pull
echo "2. Hole Updates vom Repository..."
git pull origin master
echo "✅ Repository aktualisiert"
echo ""

# 3. Prüfe ob neue Genesis vorhanden
if [ ! -f "$GENESIS_FILE" ]; then
    echo "❌ Neue Genesis-Datei nicht gefunden: $GENESIS_FILE"
    exit 1
fi
echo "✅ Neue Genesis gefunden: $GENESIS_FILE"
echo ""

# 4. Chain-Daten löschen
echo "3. Lösche Chain-Daten (Reset)..."
read -p "Chain-Daten löschen? (ja/nein): " CONFIRM
if [ "$CONFIRM" = "ja" ]; then
    rm -rf "$DATA_DIR/chaindb" "$DATA_DIR/utxodb" "$DATA_DIR"/*.log 2>/dev/null || true
    echo "✅ Chain-Daten gelöscht"
else
    echo "⚠️ Chain-Daten bleiben erhalten (kann zu Problemen führen)"
fi
echo ""

# 5. Node mit neuer Genesis starten
echo "4. Starte Node mit neuer Genesis..."
./build-v2/kalon-node-v2 -datadir "$DATA_DIR" -genesis "$GENESIS_FILE" -rpc :16316 &
NODE_PID=$!
sleep 3
echo "✅ Node gestartet (PID: $NODE_PID)"
echo ""

# 6. Verifizierung
echo "5. Verifizierung..."
sleep 2

HEIGHT=$(curl -s http://localhost:16316/rpc -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getHeight","id":1}' | grep -o '"result":[0-9]*' | grep -o '[0-9]*' || echo "?")
DIFFICULTY=$(curl -s http://localhost:16316/rpc -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getMiningInfo","id":1}' | grep -o '"difficulty":[0-9]*' | grep -o '[0-9]*' || echo "?")

echo "Height: $HEIGHT"
echo "Difficulty: $DIFFICULTY"
echo ""

if [ "$HEIGHT" = "0" ] || [ "$HEIGHT" = "1" ]; then
    echo "✅ Height korrekt"
else
    echo "⚠️ Height ist $HEIGHT (erwartet: 0 oder 1)"
fi

echo ""
echo "=== UPDATE ABGESCHLOSSEN ==="
```

## Checkliste für Slave Node Admin

- [ ] Master Node hat Staging durchgeführt
- [ ] Neue Genesis-Datei wurde bereitgestellt (`{chain}-stage2.json`)
- [ ] Slave Node gestoppt
- [ ] Neue Genesis-Datei kopiert/gepullt
- [ ] Chain-Daten gelöscht (`chaindb`, `utxodb`)
- [ ] Node mit neuer Genesis gestartet (`-genesis {chain}-stage2.json`)
- [ ] Height verifiziert (0 oder 1)
- [ ] Difficulty verifiziert (neue Difficulty)
- [ ] Balance verifiziert (wiederhergestellt)
- [ ] Synchronisierung mit Master prüfen

## Wichtige Hinweise

1. **Chain-Daten MÜSSEN gelöscht werden**: Ohne Löschung startet die Node mit der alten Chain
2. **Genesis-Datei MUSS identisch sein**: Alle Nodes müssen die gleiche Genesis-Datei verwenden
3. **Timing**: Alle Slave Nodes sollten zeitnah aktualisiert werden (innerhalb weniger Stunden)
4. **Backup**: Vor dem Löschen der Chain-Daten sollte ein Backup erstellt werden (falls nötig)
5. **Kommunikation**: Master Node Admin sollte alle Slave Node Admins rechtzeitig informieren

## Zusammenfassung

**Slave Nodes müssen nach Staging:**
1. ✅ Node stoppen
2. ✅ Neue Genesis-Datei erhalten (`{chain}-stage2.json`)
3. ✅ Chain-Daten löschen (Reset)
4. ✅ Node mit neuer Genesis starten
5. ✅ Verifizierung durchführen

**Ergebnis:**
- ✅ Alle Nodes verwenden neue Genesis
- ✅ Alle Nodes haben gleiche Difficulty
- ✅ Alle Nodes starten bei Height 0
- ✅ Alle Balances sind wiederhergestellt
- ✅ Netzwerk ist konsistent

