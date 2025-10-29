# Befehlsreihenfolge für Tests

## 1. SCHNELLER TEST (Difficulty 10, ~60 Sekunden)
```bash
# Auf deinem Server ausführen:
cd ~/kalon
git pull
./test-quick-mining.sh
```

**Was macht dieser Test:**
- Setzt Difficulty auf 10 für schnelles Mining
- Startet Node und Miner
- Läuft 60 Sekunden
- Sollte bis Block 15+ minen können

---

## 2. AUSFÜHRLICHER TEST (Difficulty 5000, 10 Minuten)
```bash
# Auf deinem Server ausführen:
cd ~/kalon
git pull
./test-block15.sh
```

**Was macht dieser Test:**
- Verwendet echte Difficulty aus testnet.json (5000)
- Startet Node und Miner
- Läuft 10 Minuten
- Überwacht speziell Block 15 Problem

---

## 3. MANUELLER TEST (Schritt für Schritt)

### Schritt 1: Cleanup
```bash
cd ~/kalon
pkill -f kalon-node-v2 kalon-miner-v2
rm -rf data-block15-test data-quick-test
```

### Schritt 2: Pull & Build
```bash
git pull
go build -o build-v2/kalon-node-v2 ./cmd/kalon-node-v2
go build -o build-v2/kalon-miner-v2 ./cmd/kalon-miner-v2
go build -o build-v2/kalon-wallet ./cmd/kalon-wallet
```

### Schritt 3: Node starten
```bash
./build-v2/kalon-node-v2 -datadir data/testnet -genesis genesis/testnet.json -rpc :16316 -p2p :17335 > node.log 2>&1 &
sleep 5
```

### Schritt 4: Node prüfen
```bash
curl -s http://localhost:16316/rpc -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getHeight","id":1}' | jq
```

### Schritt 5: Wallet erstellen/abrufen
```bash
# Neue Wallet erstellen:
./build-v2/kalon-wallet create

# Oder existierende Wallet laden:
./build-v2/kalon-wallet list
```

### Schritt 6: Miner starten
```bash
# Wallet-Adresse verwenden (z.B. von Wallet create/list):
WALLET="deine_wallet_adresse_hier"
./build-v2/kalon-miner-v2 -wallet "$WALLET" -threads 1 -rpc http://localhost:16316 > miner.log 2>&1 &
```

### Schritt 7: Monitoring
```bash
# Höhe prüfen:
watch -n 2 'curl -s http://localhost:16316/rpc -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getHeight","id":1}' | jq .result'

# Miner-Logs:
tail -f miner.log

# Node-Logs:
tail -f node.log
```

### Schritt 8: Balance prüfen
```bash
# Mit Wallet-Adresse:
curl -s http://localhost:16316/rpc -H "Content-Type: application/json" -d "{\"jsonrpc\":\"2.0\",\"method\":\"getBalance\",\"params\":{\"address\":\"$WALLET\"},\"id\":1}" | jq
```

### Schritt 9: Cleanup
```bash
pkill -f kalon-node-v2 kalon-miner-v2
```

---

## WICHTIGE HINWEISE

### Flags für kalon-node-v2:
- `-datadir` (NICHT `-data`!) - Datenverzeichnis
- `-genesis` - Genesis-Datei
- `-rpc` - RPC Port (Standard: :16316)
- `-p2p` - P2P Port (Standard: :17335)

### Troubleshooting:

**Node startet nicht:**
```bash
# Prüfe Logs:
cat node.log

# Prüfe ob Port belegt:
netstat -tlnp | grep 16316
```

**Miner findet keine Blöcke:**
```bash
# Prüfe Difficulty:
curl -s http://localhost:16316/rpc -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getMiningInfo","id":1}' | jq

# Prüfe Miner-Logs:
tail -n 50 miner.log | grep -i "error\|failed"
```

**Balance bleibt 0:**
```bash
# Prüfe UTXOs:
curl -s http://localhost:16316/rpc -H "Content-Type: application/json" -d "{\"jsonrpc\":\"2.0\",\"method\":\"getUTXOs\",\"params\":{\"address\":\"$WALLET\"},\"id\":1}" | jq
```

---

## Empfohlene Reihenfolge für Tests:

1. **Zuerst:** `./test-quick-mining.sh` - Schneller Test
2. **Dann:** `./test-block15.sh` - Ausführlicher Test
3. **Bei Problemen:** Manueller Test (Schritt für Schritt)

