# Kalon Network

Eine moderne Blockchain-Implementierung in Go mit UTXO-basiertem System.

## ✨ Features

- **UTXO-System**: Bitcoin-ähnliches UTXO-Model
- **PoW-Mining**: Proof-of-Work Konsensmechanismus
- **RPC API**: JSON-RPC Schnittstelle
- **Wallet**: Unterstützung für Mnemonic-Phrases (BIP39)
- **Mining**: CPU-basierte Block-Generierung
- **Testnet**: Vorkonfiguriertes Testnet für Entwicklung

## 🚀 Quick Start

```bash
# Repository clonen
git clone https://github.com/Why-x-Phy/kalon-network.git
cd kalon-network

# Alles bauen
go build -o build-v2/kalon-node-v2 cmd/kalon-node-v2/main.go
go build -o build-v2/kalon-miner-v2 cmd/kalon-miner-v2/main.go
go build -o build-v2/kalon-wallet cmd/kalon-wallet/main.go

# Node starten
./build-v2/kalon-node-v2 -datadir data-v2/testnet -genesis genesis/testnet.json -rpc :16316 &

# Wallet erstellen
./build-v2/kalon-wallet create

# Miner starten
./build-v2/kalon-miner-v2 -wallet DEINE_ADRESSE -threads 1 -rpc http://localhost:16316 &
```

Vollständige Anleitung: [docs/QUICKSTART.md](docs/QUICKSTART.md)

## 📚 Dokumentation

- [Quick Start](docs/QUICKSTART.md) - Schnelle Installation
- [Installation](docs/INSTALLATION.md) - Detaillierte Installation
- [Updates](docs/UPDATE.md) - Updates durchführen
- [Server Deployment](SERVER_DEPLOYMENT.md) - Server-Deployment
- [Wallet Setup](WALLET_SETUP.md) - Wallet-Einrichtung

## 🏗 Projekt-Struktur

```
kalon-network/
├── cmd/                 # Haupt-Anwendungen
│   ├── kalon-node-v2/  # Blockchain-Node
│   ├── kalon-miner-v2/ # Mining-Software
│   └── kalon-wallet/   # Wallet-Manager
├── core/               # Blockchain-Kern
│   ├── blockchain.go   # Blockchain-Logik
│   ├── consensus.go    # Konsensmechanismus
│   └── utxo.go         # UTXO-System
├── crypto/             # Kryptographie
│   ├── bech32.go       # Bech32-Adressen
│   ├── bip39.go        # Mnemonic-Phrases
│   └── keys.go         # Schlüsselgenerierung
├── mining/             # Mining-Logik
├── rpc/                 # RPC-Server
├── genesis/             # Genesis-Konfiguration
└── docs/                # Dokumentation
```

## 🔧 Voraussetzungen

- **Go**: Version 1.21+
- **OS**: Linux, macOS, Windows
- **RAM**: Mindestens 512MB
- **Disk**: ~100MB

## 📖 RPC API

### getHeight
```json
{"jsonrpc":"2.0","method":"getHeight","params":{},"id":1}
```

### getBalance
```json
{"jsonrpc":"2.0","method":"getBalance","params":{"address":"..."},"id":2}
```

### getBestBlock
```json
{"jsonrpc":"2.0","method":"getBestBlock","params":{},"id":3}
```

## 🧪 Testnet

Kalon läuft standardmäßig im Testnet-Modus:
- **Chain ID**: 7718
- **Difficulty**: 1 (sehr einfach)
- **Block Reward**: 5 tKALON
- **Block Time**: ~30 Sekunden

## 📄 Lizenz

Siehe [LICENSE](LICENSE) Datei.

## 🤝 Beitragen

Beiträge sind willkommen! Öffne ein Issue oder sende einen Pull Request.

## 📧 Kontakt

- **GitHub**: https://github.com/Why-x-Phy/kalon-network
- **Issues**: https://github.com/Why-x-Phy/kalon-network/issues

---

**Status**: ✅ Funktionierend | Testnet | v2.0
