# Kalon Network

A modern blockchain implementation in Go with a UTXO-based system, designed for scalability, security, and ease of use.

## ✨ Features

- **UTXO System**: Bitcoin-like Unspent Transaction Output model
- **Proof of Work**: CPU-based mining with adjustable difficulty
- **RPC API**: Full JSON-RPC interface for blockchain interaction
- **Wallet Management**: BIP39 mnemonic phrase support for secure key management
- **Mining**: Efficient CPU mining with configurable threads
- **Block Explorer**: Web-based explorer with real-time blockchain data
- **Testnet**: Pre-configured testnet for development and testing
- **Multiple Networks**: Testnet, Mainnet, and Community Testnet support

## 🚀 Quick Start

Get up and running in minutes:

```bash
# Clone repository
git clone https://github.com/Why-x-Phy/kalon-network.git
cd kalon-network

# Build all components
make build

# Or build individually:
go build -o build-v2/kalon-node-v2 cmd/kalon-node-v2/main.go
go build -o build-v2/kalon-miner-v2 cmd/kalon-miner-v2/main.go
go build -o build-v2/kalon-wallet cmd/kalon-wallet/main.go

# Start node
./build-v2/kalon-node-v2 -datadir data-v2/testnet -genesis genesis/testnet.json -rpc :16316 &

# Create wallet
./build-v2/kalon-wallet create

# Start mining
./build-v2/kalon-miner-v2 -wallet YOUR_ADDRESS -threads 2 -rpc http://localhost:16316 &
```

For detailed instructions, see [Quick Start Guide](docs/QUICKSTART.md).

## 📚 Documentation

### For Users
- **[User Guide](docs/USER_GUIDE.md)** - Complete guide for running nodes and mining
- **[Running a Node](docs/RUNNING_A_NODE.md)** - Detailed node setup instructions
- **[Command Reference](docs/COMMAND_REFERENCE.md)** - All available commands and examples

### For Administrators
- **[Admin Guide](docs/ADMIN_GUIDE.md)** - System administration and maintenance
- **[Installation](docs/INSTALLATION.md)** - Detailed installation guide
- **[Updates](docs/UPDATE.md)** - Update procedures

## 🏗️ Project Structure

```
kalon-network/
├── cmd/                    # Main applications
│   ├── kalon-node-v2/     # Blockchain node
│   ├── kalon-miner-v2/    # Mining software
│   └── kalon-wallet/      # Wallet manager
├── core/                   # Blockchain core
│   ├── blockchain.go      # Blockchain logic
│   ├── consensus.go       # Consensus mechanism
│   ├── types.go           # Core data types
│   └── utxo.go            # UTXO system
├── crypto/                 # Cryptography
│   ├── bech32.go          # Bech32 addresses
│   ├── bip39.go           # Mnemonic phrases
│   └── keys.go            # Key generation
├── mining/                 # Mining logic
│   ├── miner.go           # Mining algorithm
│   └── randomx.go         # Hash verification
├── rpc/                    # RPC server
│   ├── server.go          # RPC implementation
│   └── server_v2.go       # Enhanced RPC
├── explorer/              # Block explorer
│   ├── api/               # Explorer API
│   └── static/            # Web interface
├── genesis/               # Genesis configurations
│   ├── testnet.json       # Testnet config
│   ├── mainnet.json       # Mainnet config
│   └── community-testnet.json
└── docs/                  # Documentation
```

## 🔧 Requirements

- **Go**: Version 1.21 or later
- **OS**: Linux (recommended), macOS, Windows
- **RAM**: 2GB minimum (4GB+ recommended)
- **Storage**: 10GB minimum
- **CPU**: 2+ cores for mining
- **Network**: Stable internet connection

## 📖 RPC API

Kalon provides a comprehensive JSON-RPC API:

### Get Blockchain Height
```json
{
  "jsonrpc": "2.0",
  "method": "getHeight",
  "id": 1
}
```

### Get Address Balance
```json
{
  "jsonrpc": "2.0",
  "method": "getBalance",
  "params": {
    "address": "kalon1abc123..."
  },
  "id": 2
}
```

### Get Best Block
```json
{
  "jsonrpc": "2.0",
  "method": "getBestBlock",
  "id": 3
}
```

### Get Recent Blocks
```json
{
  "jsonrpc": "2.0",
  "method": "getRecentBlocks",
  "params": {
    "limit": 20
  },
  "id": 4
}
```

### Send Transaction
```json
{
  "jsonrpc": "2.0",
  "method": "sendTransaction",
  "params": {
    "from": "kalon1sender...",
    "to": "kalon1recipient...",
    "amount": 1000000
  },
  "id": 5
}
```

For complete API documentation, see [docs/API.md](docs/API.md).

## 🧪 Testnet

Kalon Network provides a testnet for development and testing:

- **Chain ID**: 7718
- **Difficulty**: 5000 (adjustable)
- **Block Reward**: 5 tKALON
- **Block Time**: ~30 seconds
- **Symbol**: tKALON

## 🌐 Networks

### Testnet
- **Purpose**: Development and testing
- **Genesis**: `genesis/testnet.json`
- **Difficulty**: Lower for faster testing
- **Wallet Prefix**: `kalon1`

### Mainnet
- **Purpose**: Production network
- **Genesis**: `genesis/mainnet.json`
- **Difficulty**: Higher for security
- **Status**: Coming soon

### Community Testnet
- **Purpose**: Community testing
- **Genesis**: `genesis/community-testnet.json`
- **Status**: Available

## 🔐 Wallet Management

### Create Wallet
```bash
./build-v2/kalon-wallet create
```

### List Wallets
```bash
./build-v2/kalon-wallet list
```

### Recover from Mnemonic
```bash
./build-v2/kalon-wallet import
```

### Check Balance
```bash
./build-v2/kalon-wallet balance --address kalon1abc123...
```

## 💰 Mining

### Start Mining
```bash
# Get wallet address
ADDRESS=$(cat wallet-miner.json | jq -r .address)

# Start mining with 4 threads
./build-v2/kalon-miner-v2 -wallet "$ADDRESS" -threads 4 -rpc http://localhost:16316
```

### Mining Rewards
- Block reward: 5 tKALON (testnet)
- Reward halves every 259,200 blocks
- Network and treasury fees collected per block

## 📊 Block Explorer

Kalon includes a built-in block explorer:

```bash
# Start explorer API
KALON_RPC_URL="http://localhost:16316" ./build-v2/explorer-api &

# Start web server
cd explorer/static
python3 -m http.server 8080 &

# Access at http://localhost:8080
```

Features:
- Real-time blockchain statistics
- Recent blocks and transactions
- Address and balance lookup
- Network metrics

## 🔧 Configuration

### Network Configuration

Edit `genesis/testnet.json` to customize:
- Initial difficulty
- Block rewards
- Halving schedule
- Treasury address
- Network fees

### Node Configuration

Command-line options:
```bash
-datadir string    Data directory (default: "data")
-genesis string    Genesis config file (required)
-rpc string        RPC endpoint (default: ":16316")
-p2p string        P2P endpoint (default: ":17335")
```

## 🛠️ Development

### Building from Source
```bash
# Clone repository
git clone https://github.com/Why-x-Phy/kalon-network.git
cd kalon-network

# Install dependencies
go mod download

# Build all binaries
make build

# Run tests
go test ./...
```

### Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## 📄 License

See [LICENSE](LICENSE) file for details.

## 🤝 Support

- **Issues**: [GitHub Issues](https://github.com/Why-x-Phy/kalon-network/issues)
- **Documentation**: Check `docs/` directory
- **Questions**: Open a discussion on GitHub

## 🗺️ Roadmap

- [ ] Mainnet launch
- [ ] Enhanced P2P networking
- [ ] Smart contract support
- [ ] Mobile wallet
- [ ] Exchange integrations
- [ ] Governance system

## 📧 Contact

- **GitHub**: [Why-x-Phy/kalon-network](https://github.com/Why-x-Phy/kalon-network)
- **Repository**: https://github.com/Why-x-Phy/kalon-network

---

**Status**: ✅ Active Development | Testnet Live | v2.0

Made with ❤️ by the Kalon Network community
