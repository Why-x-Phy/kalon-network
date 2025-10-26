# Kalon Network - Updates

## Updates durchführen

### Schritt 1: Prozesse beenden

```bash
# Alle Kalon-Prozesse stoppen
pkill -f kalon

# Warten bis alle beendet sind
sleep 3
```

### Schritt 2: Updates holen

```bash
cd kalon-network
git pull origin master
```

### Schritt 3: Neu kompilieren

```bash
# Neu bauen
go build -o build-v2/kalon-node-v2 cmd/kalon-node-v2/main.go
go build -o build-v2/kalon-miner-v2 cmd/kalon-miner-v2/main.go
go build -o build-v2/kalon-wallet cmd/kalon-wallet/main.go
```

### Schritt 4: Node starten

```bash
./build-v2/kalon-node-v2 \
  -datadir data-v2/testnet \
  -genesis genesis/testnet.json \
  -rpc :16316 > /tmp/kalon_node.log 2>&1 &
```

### Schritt 5: Wallet-Adresse laden

```bash
# Aus wallet.json
cat wallet.json | grep -o '"address":"[^"]*"' | cut -d'"' -f4

# Oder manuell eingeben
WALLET_ADDRESS="DEINE_ADRESSE"
```

### Schritt 6: Miner starten

```bash
./build-v2/kalon-miner-v2 \
  -wallet "$WALLET_ADDRESS" \
  -threads 1 \
  -rpc http://localhost:16316 > /tmp/kalon_miner.log 2>&1 &
```

### Schritt 7: Verifizieren

```bash
# Warten
sleep 5

# Tests
curl -X POST http://localhost:16316/rpc -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"getHeight","params":{},"id":1}' | jq -r .result

curl -X POST http://localhost:16316/rpc -H "Content-Type: application/json" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"getBalance\",\"params\":{\"address\":\"$WALLET_ADDRESS\"},\"id\":2}" | jq -r .result
```

## Automatisches Update-Script

```bash
cd kalon-network
./UPDATE.sh
```

## Manuelle Update-Strategie

1. **Soft Update** (Daten bleiben erhalten):
   - Stoppe Prozesse
   - Git Pull
   - Neu bauen
   - Restart

2. **Hard Update** (frischer Start):
   - Stoppe Prozesse
   - `rm -rf data-v2/testnet && mkdir -p data-v2/testnet`
   - Git Pull
   - Neu bauen
   - Restart

3. **Test Update**:
   - Stoppe Prozesse
   - Backup: `cp -r data-v2/testnet data-v2/testnet.backup`
   - Git Pull
   - Neu bauen
   - Restart
   - Bei Problemen: `rm -rf data-v2/testnet && mv data-v2/testnet.backup data-v2/testnet`
