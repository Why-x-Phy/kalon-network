# Kalon Refactoring - Schritt-für-Schritt Plan

## ✅ PHASE 1: BALANCE-BUG FIX (SOFORT!)

### Schritt 1.1: Balance auf Server testen
```bash
# Auf Ubuntu-Server ausführen:
cd ~/kalon-network
git pull origin master

# Alte builds löschen
pkill -f kalon-node; pkill -f kalon-miner
rm -rf build-v2/

# Neu kompilieren
./scripts/build-v2.sh

# Node starten
nohup ./build-v2/kalon-node-v2 --datadir data-v2/testnet --genesis genesis/testnet.json --rpc :16316 --p2p :17335 > node-v2.log 2>&1 &

# Warten
sleep 5

# Miner starten  
nohup ./build-v2/kalon-miner-v2 --wallet kalon1r9wen9um8qwfdxdyk9u5yr3sd5ym5vrj72cttt --threads 2 --rpc http://localhost:16316 > miner-v2.log 2>&1 &

# Warten bis Block gemint ist
sleep 60

# BALANCE PRÜFEN!
curl -s http://localhost:16316 -X POST -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"getBalance","params":{"address":"kalon1r9wen9um8qwfdxdyk9u5yr3sd5ym5vrj72cttt"}}' | jq
```

### Schritt 1.2: Falls Balance = 0 → Debug
```bash
# Logs prüfen
tail -100 node-v2.log | grep "UTXO\|Address"

# Adresse-Parsing testen
# Miner-Adresse sollte korrekt geparst werden
```

## 🔧 PHASE 2: CHATGPT-REFACTORING (NACH BALANCE-FIX!)

### STEP 1: Tests hinzufügen ⭐ (PRIORITÄT!)
**Ziel:** Balance-Bug soll nie wieder auftreten

**Action:**
1. Unit Tests für `core/utxo.go` erstellen
2. Test für `AddressFromString` 
3. Test für `GetBalance`
4. Test für `createBlockRewardTransaction`

**Files:**
- `core/utxo_test.go`
- `core/types_test.go`

---

### STEP 2: CI/CD Pipeline ⭐⭐
**Ziel:** Automatische Tests und Linting

**Action:**
1. `.github/workflows/ci.yml` erstellen
2. Linting mit `golangci-lint`
3. Tests automatisch laufen lassen

**Files:**
- `.github/workflows/ci.yml`

---

### STEP 3: Repository umorganisieren (internal/)
**Ziel:** Profi-Struktur nach ChatGPT-Plan

**Action:**
1. `core/` → `internal/core/`
2. `rpc/` → `internal/rpc/`
3. `crypto/` → `internal/wallet/`
4. `consensus.go` → `internal/consensus/`
5. `utxo.go` → `internal/state/`

**WICHTIG:** Nur umbenennen, keine Funktionalität ändern!

---

### STEP 4: Coinbase in separate Datei
**Ziel:** Saubere Trennung

**Action:**
1. `internal/core/coinbase.go` erstellen
2. `createBlockRewardTransaction` dort hin
3. `createCoinbaseTx` nach ChatGPT-Template

---

### STEP 5: Mempool implementieren
**Ziel:** Transaction Pool

**Action:**
1. `internal/mempool/` erstellen
2. Basic Mempool implementieren
3. Fee Policy

---

### STEP 6: P2P Networking (OPTIONAL)
**Ziel:** libp2p Integration

**Action:**
1. `internal/p2p/` erstellen
2. libp2p nutzen
3. Gossipsub

---

### STEP 7: Dokumentation
**Ziel:** Full Docs

**Action:**
1. `docs/ARCHITECTURE.md`
2. `docs/CONSENSUS.md`
3. `docs/RPC.md`
4. `docs/RUNBOOK.md`

---

## 📋 CHECKLIST:

- [ ] 1. Balance-Bug fixen
- [ ] 2. Tests hinzufügen (utxo_test.go)
- [ ] 3. CI/CD Pipeline
- [ ] 4. Repository umorganisieren
- [ ] 5. Coinbase-Datei
- [ ] 6. Mempool
- [ ] 7. P2P (optional)
- [ ] 8. Dokumentation

## 🎯 ZIEL:
Die **beste Blockchain** - Schritt für Schritt!
