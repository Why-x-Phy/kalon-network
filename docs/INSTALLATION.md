# Kalon Network - Installation

## Systemvoraussetzungen

- Ubuntu 20.04+ / Debian 11+ oder ähnliches
- Go 1.21 oder neuer
- Git
- Build-Essentials (`gcc`, `make`)

## Vollständige Installation

### Schritt 1: Go installieren

```bash
# Go 1.23.2 installieren
wget https://go.dev/dl/go1.23.2.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.23.2.linux-amd64.tar.gz

# PATH setzen
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
source ~/.bashrc

# Verifizieren
go version
```

### Schritt 2: Repository clonen

```bash
git clone https://github.com/Why-x-Phy/kalon-network.git
cd kalon-network
```

### Schritt 3: Kompilieren

```bash
# Alles auf einmal bauen
go build -o build-v2/kalon-node-v2 cmd/kalon-node-v2/main.go
go build -o build-v2/kalon-miner-v2 cmd/kalon-miner-v2/main.go
go build -o build-v2/kalon-wallet cmd/kalon-wallet/main.go
```

### Schritt 4: Konfiguration

```bash
# Data-Verzeichnis erstellen
mkdir -p data-v2/testnet
```

### Schritt 5: Wallet erstellen

```bash
./build-v2/kalon-wallet create
```

**Output:**
```
Wallet created successfully!
Address: ada68893c9c6fa324307c3964f1eb6d871253665
Mnemonic: word1 word2 ... word12
Wallet saved to: wallet.json
```

**⚠️ WICHTIG:** Speichere die Mnemonic-Phrase sicher!

### Schritt 6: Node starten

```bash
./build-v2/kalon-node-v2 \
  -datadir data-v2/testnet \
  -genesis genesis/testnet.json \
  -rpc :16316 \
  > /tmp/kalon_node.log 2>&1 &
```

### Schritt 7: Miner starten

```bash
./build-v2/kalon-miner-v2 \
  -wallet DEINE_ADRESSE \
  -threads 1 \
  -rpc http://localhost:16316 \
  > /tmp/kalon_miner.log 2>&1 &
```

### Schritt 8: Verifizieren

```bash
# Height prüfen
curl -X POST http://localhost:16316/rpc \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"getHeight","params":{},"id":1}' | jq -r .result

# Balance prüfen
curl -X POST http://localhost:16316/rpc \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"getBalance","params":{"address":"DEINE_ADRESSE"},"id":2}' | jq -r .result
```

## Logs anzeigen

```bash
# Node Logs
tail -f /tmp/kalon_node.log

# Miner Logs
tail -f /tmp/kalon_miner.log
```

## Prozesse beenden

```bash
# Alle Kalon-Prozesse stoppen
pkill -f kalon

# Oder spezifisch
pkill -f kalon-node-v2
pkill -f kalon-miner-v2
```

## Troubleshooting

### Node startet nicht

```bash
# Port bereits belegt?
netstat -tulpn | grep 16316

# Logs prüfen
cat /tmp/kalon_node.log
```

### Balance bleibt 0

```bash
# Miner läuft?
ps aux | grep kalon-miner

# Miner Logs prüfen
tail -f /tmp/kalon_miner.log
```

### Weitere Hilfe

Siehe [Quick Start](QUICKSTART.md) oder öffne ein Issue auf GitHub.
