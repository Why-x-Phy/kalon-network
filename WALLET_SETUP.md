# Kalon Wallet - Setup auf anderen Server

## 🚀 Schnellstart mit Wallet

### 1. Wallet bauen (auf deinem Server)
```bash
go build -o build-v2/kalon-wallet cmd/kalon-wallet/main.go
```

### 2. Neue Wallet erstellen
```bash
./build-v2/kalon-wallet create
```

**Output:**
```
Wallet created successfully!
Address: ada68893c9c6fa324307c3964f1eb6d871253665
Public Key: 04a1b2c3d4e5f6...
Mnemonic: word1 word2 word3 ... word12
Wallet saved to: wallet.json

⚠️  IMPORTANT: Save your mnemonic phrase in a safe place!
```

### 3. Wallet Info anzeigen (um Adresse zu sehen)
```bash
./build-v2/kalon-wallet info --input wallet.json
```

**Kopiere die Adresse!** (z.B. `ada68893c9c6fa324307c3964f1eb6d871253665`)

### 4. Miner mit deiner Wallet-Adresse starten
```bash
# Deine Adresse hier einsetzen!
./build-v2/kalon-miner-v2 \
  -wallet ada68893c9c6fa324307c3964f1eb6d871253665 \
  -threads 1 \
  -rpc http://localhost:16316 > /tmp/kalon_miner.log 2>&1 &
```

### 5. Balance prüfen
```bash
./build-v2/kalon-wallet balance --address ada68893c9c6fa324307c3964f1eb6d871253665 --rpc http://localhost:16316
```

**Oder mit curl:**
```bash
curl -X POST http://localhost:16316/rpc \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"getBalance","params":{"address":"ada68893c9c6fa324307c3964f1eb6d871253665"},"id":2}' | jq -r .result
```

## 📋 Alle Wallet-Befehle

```bash
# Wallet erstellen
./build-v2/kalon-wallet create

# Wallet Info anzeigen
./build-v2/kalon-wallet info --input wallet.json

# Balance prüfen
./build-v2/kalon-wallet balance --address DEINE_ADRESSE --rpc http://localhost:16316

# Wallet importieren (mit Mnemonic)
./build-v2/kalon-wallet import --mnemonic "word1 word2 ..." --output wallet2.json

# Wallet exportieren
./build-v2/kalon-wallet export --input wallet.json

# Hilfe anzeigen
./build-v2/kalon-wallet help
```

## 🎯 Komplette Sequenz auf neuem Server

```bash
# 1. Repository
git clone https://github.com/Why-x-Phy/kalon-network.git
cd kalon-network

# 2. Alles bauen
go build -o build-v2/kalon-node-v2 cmd/kalon-node-v2/main.go
go build -o build-v2/kalon-miner-v2 cmd/kalon-miner-v2/main.go
go build -o build-v2/kalon-wallet cmd/kalon-wallet/main.go

# 3. Node starten
rm -rf data-v2/testnet && mkdir -p data-v2/testnet
./build-v2/kalon-node-v2 -datadir data-v2/testnet -genesis genesis/testnet.json -rpc :16316 > /tmp/kalon_node.log 2>&1 &

# 4. Wallet erstellen
./build-v2/kalon-wallet create
# → Kopiere die Adresse!

# 5. Wallet Info anzeigen
./build-v2/kalon-wallet info --input wallet.json

# 6. Miner mit deiner Adresse starten
./build-v2/kalon-miner-v2 -wallet DEINE_ADRESSE -threads 1 -rpc http://localhost:16316 > /tmp/kalon_miner.log 2>&1 &

# 7. Warten (einige Sekunden)
sleep 5

# 8. Balance prüfen
./build-v2/kalon-wallet balance --address DEINE_ADRESSE --rpc http://localhost:16316
```

## ⚠️ WICHTIG - Mnemonic speichern!

Nach dem `create` erscheint eine Mnemonic-Phrase (12 Wörter). 
**SPEICHERE DIESE SICHER!** Du brauchst sie, um die Wallet wiederherzustellen.

## 🛑 Alles beenden

```bash
pkill -f kalon
```

## 🔄 Wallet wiederherstellen

Falls du die Wallet verlierst, kannst du sie mit der Mnemonic-Phrase wiederherstellen:

```bash
./build-v2/kalon-wallet import --mnemonic "word1 word2 ... word12" --output wallet.json
```

