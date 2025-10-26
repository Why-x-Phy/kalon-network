# Kalon Network (KALON)

CPU-first, fair-launch Proof-of-Work blockchain with network fee system and treasury management.

## 🪙 Features

- **CPU-only Mining**: RandomX algorithm prevents GPU/ASIC dominance
- **Fair Launch**: 48-hour protection with 8x difficulty and reduced rewards
- **Network Fee System**: 5% block fee + transaction fees to treasury
- **Progressive Halving**: 3M → 6M → 12M → yearly cycles
- **BIP-39 Wallets**: bech32 addresses (kalon1...)
- **Cross-Platform**: Linux AMD64 + ARM64 (Raspberry Pi)
- **Docker Support**: Easy deployment and scaling

## 🏗️ Architecture

```
kalon/
├─ cmd/
│  ├─ kalon-node/       # Full Node – Consensus, P2P, RPC
│  ├─ kalon-wallet/     # Wallet CLI – Create/Import/Send
│  ├─ kalon-miner/      # Miner – RandomX CPU Mining
│  └─ kalon-explorer/   # Explorer – Web Interface
├─ core/                # Core Logic (Blockchain, TX, Blocks)
├─ crypto/              # Keypairs, BIP39, bech32, Signatures
├─ rpc/                 # JSON-RPC API
├─ network/             # P2P Connections, Node Discovery
├─ storage/             # LevelDB for Chain Data
├─ explorer/
│  ├─ api/              # Indexer API (Go)
│  └─ ui/               # Web Interface (React)
├─ genesis/             # genesis.json – Network Parameters
├─ docker/              # Dockerfiles + docker-compose.yml
└─ scripts/             # build.sh, install.sh, run.sh
```

## 🚀 Quick Start

### Ubuntu/Debian
```bash
sudo apt update && sudo apt install -y git golang build-essential
git clone https://github.com/kalon-network/kalon
cd kalon
./scripts/install.sh
./kalon-node --init --genesis genesis/genesis.json
./kalon-node --rpc :16314 --p2p :17333 --seednodes seed1.kalon.network:17333,seed2.kalon.network:17333
```

### Docker
```bash
git clone https://github.com/kalon-network/kalon
cd kalon
docker-compose -f docker/docker-compose.yml up
```

### Raspberry Pi (ARM64)
```bash
# Same as Ubuntu, but uses ARM64 binaries
./scripts/install.sh --arch arm64
```

## 💰 Network Fee System

- **Block Fee**: 5% of block reward goes to treasury
- **Transaction Fee**: 0.01 KALON minimum + gas system
- **Treasury Distribution**: 80% miner / 20% treasury (TX fees)
- **Treasury Address**: `kalon1treasury00000000000000000000000`

## 🌐 Networks

| Network | Chain ID | Purpose | Seeds |
|---------|----------|---------|-------|
| CoreNet | 7716 | Internal testing | Internal only |
| Testnet | 7717 | Public testing + Airdrop | tn1/2/3.kalon.network |
| Mainnet | 7718 | Production | seed1/2/3.kalon.network |

## 🔧 Commands

### Node
```bash
./kalon-node --init --genesis genesis/genesis.json
./kalon-node --rpc :16314 --p2p :17333 --seednodes seed1.kalon.network:17333
```

### Wallet
```bash
./kalon-wallet create
./kalon-wallet balance kalon1xyz...
./kalon-wallet send kalon1abc... 10
```

### Miner
```bash
./kalon-miner --wallet kalon1xyz... --threads 2
```

### Explorer
```bash
# API runs on :8081
# UI runs on :8080
docker-compose -f docker/docker-compose.yml up explorer
```

## 📊 Treasury Dashboard

Access the treasury dashboard at `http://localhost:8080/treasury` to view:
- Total treasury balance
- Daily income (block + transaction fees)
- Miner vs treasury distribution
- Multi-sig wallet status

## 🔒 Security

- GPG-signed releases with checksums
- Reproducible builds
- Multi-sig treasury wallet (3/5)
- Height-based consensus changes

## 📈 Roadmap

- [x] Core blockchain implementation
- [x] RandomX CPU mining
- [x] Network fee system
- [x] Treasury management
- [x] P2P networking
- [x] JSON-RPC API
- [x] Explorer web interface
- [x] Docker support
- [x] Cross-compilation
- [ ] Governance system
- [ ] Mobile wallet
- [ ] Hardware wallet support

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## 📄 License

MIT License - see [LICENSE](LICENSE) for details.

## 🌍 Community

- Website: https://kalon.network
- Discord: https://discord.gg/kalon
- Twitter: @KalonNetwork
- GitHub: https://github.com/kalon-network/kalon
