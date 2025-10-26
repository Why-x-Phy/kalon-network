# Balance-Bug Troubleshooting

## Problem: Balance bleibt 0

### Schnell-Check auf deinem Server:

```bash
# 1. Ist Node aktuell?
git pull origin master
go build -o build-v2/kalon-node-v2 cmd/kalon-node-v2/main.go
go build -o build-v2/kalon-miner-v2 cmd/kalon-miner-v2/main.go

# 2. Alte Prozesse beenden
pkill -f kalon

# 3. Fresh Start
rm -rf data-v2/testnet && mkdir -p data-v2/testnet
```

### Node neu starten:
```bash
./build-v2/kalon-node-v2 -datadir data-v2/testnet -genesis genesis/testnet.json -rpc :16316 > /tmp/kalon_node.log 2>&1 &
sleep 3
```

### Wallet-Info prüfen:
```bash
./build-v2/kalon-wallet info --input wallet.json
# → Kopiere die Adresse!
```

### Miner mit korrekter Adresse starten:
```bash
# Ersetze MIT DEINER ADRESSE!
./build-v2/kalon-miner-v2 -wallet DEINE_ADRESSE -threads 1 -rpc http://localhost:16316 > /tmp/kalon_miner.log 2>&1 &
```

### Diagnose:
```bash
# 1. Height prüfen
curl -s -X POST http://localhost:16316/rpc -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getHeight","params":{},"id":1}' | jq -r .result

# 2. Blocks gefunden?
tail -50 /tmp/kalon_miner.log | grep -i "submitted successfully"

# 3. UTXOs erstellt?
tail -100 /tmp/kalon_node.log | grep -i "UTXO created"

# 4. Welche Adresse?
tail -100 /tmp/kalon_node.log | grep -i "address"
```

