# Kalon Network - Quick Start

## 🚀 Schnellinstallation (5 Minuten)

### Voraussetzungen
- Go 1.21+
- Git
- Internet-Verbindung

### Installation

```bash
# 1. Repository clonen
git clone https://github.com/Why-x-Phy/kalon-network.git
cd kalon-network

# 2. Alles bauen
make build

# Oder manuell:
# go build -o build-v2/kalon-node-v2 cmd/kalon-node-v2/main.go
# go build -o build-v2/kalon-miner-v2 cmd/kalon-miner-v2/main.go
# go build -o build-v2/kalon-wallet cmd/kalon-wallet/main.go
```

### Start

```bash
# Node starten
./build-v2/kalon-node-v2 -datadir data-v2/testnet -genesis genesis/testnet.json -rpc :16316 > /tmp/kalon_node.log 2>&1 &

# Wallet erstellen
./build-v2/kalon-wallet create
# → Kopiere die Adresse!

# Miner starten
./build-v2/kalon-miner-v2 -wallet DEINE_ADRESSE -threads 1 -rpc http://localhost:16316 > /tmp/kalon_miner.log 2>&1 &
```

### Balance prüfen

```bash
curl -X POST http://localhost:16316/rpc -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"getBalance","params":{"address":"DEINE_ADRESSE"},"id":2}' | jq -r .result
```

### Beenden

```bash
pkill -f kalon
```

## 📚 Vollständige Dokumentation

### For Users
- [User Guide](USER_GUIDE.md) - Complete user guide for running nodes and mining
- [Running a Node](RUNNING_A_NODE.md) - Detailed node setup instructions
- [Command Reference](COMMAND_REFERENCE.md) - All available commands

### For Administrators
- [Admin Guide](ADMIN_GUIDE.md) - System administration and maintenance
- [Installation](INSTALLATION.md) - Detailed installation guide
- [Update](UPDATE.md) - Update procedures
- [API](API.md) - RPC API documentation

