# Kalon Network - Command Reference

Complete reference for all Kalon Network commands.

## Table of Contents

1. [Node Commands](#node-commands)
2. [Miner Commands](#miner-commands)
3. [Wallet Commands](#wallet-commands)
4. [RPC API Commands](#rpc-api-commands)
5. [Utility Commands](#utility-commands)

## Node Commands

### Start Node

```bash
# Basic start
./build-v2/kalon-node-v2 -datadir data-v2/testnet -genesis genesis/testnet.json -rpc :16316

# With specific ports
./build-v2/kalon-node-v2 -datadir data-v2/testnet -genesis genesis/testnet.json -rpc :16316 -p2p :17335

# Background mode
nohup ./build-v2/kalon-node-v2 -datadir data-v2/testnet -genesis genesis/testnet.json -rpc :16316 > /tmp/node.log 2>&1 &

# Check if running
ps aux | grep kalon-node-v2
```

### Node Options

```
-datadir string    Data directory (default: "data")
-genesis string    Genesis config file (required)
-rpc string        RPC endpoint (default: ":16316")
-p2p string        P2P endpoint (default: ":17335")
```

### Stop Node

```bash
pkill -f kalon-node-v2
```

## Miner Commands

### Start Mining

```bash
# Basic mining
./build-v2/kalon-miner-v2 -wallet ADDRESS -threads 2 -rpc http://localhost:16316

# With more threads
./build-v2/kalon-miner-v2 -wallet ADDRESS -threads 4 -rpc http://localhost:16316

# Background mode
nohup ./build-v2/kalon-miner-v2 -wallet ADDRESS -threads 2 -rpc http://localhost:16316 > /tmp/miner.log 2>&1 &
```

### Miner Options

```
-wallet string     Wallet address (required)
-threads int       Number of CPU threads (default: 1)
-rpc string        RPC server URL (default: "http://localhost:16316")
```

### Stop Miner

```bash
pkill -f kalon-miner-v2
```

## Wallet Commands

### Create Wallet

```bash
# Interactive mode
./build-v2/kalon-wallet create

# With name
./build-v2/kalon-wallet create --name mywallet

# With output file
./build-v2/kalon-wallet create --output wallet-custom.json

# With passphrase (from command line)
./build-v2/kalon-wallet create --name mywallet --passphrase "mypass123"
```

### List Wallets

```bash
./build-v2/kalon-wallet list
```

### View Wallet Info

```bash
# View specific wallet
./build-v2/kalon-wallet info --input wallet-miner.json

# Extract address
cat wallet-miner.json | jq -r .address

# Extract public key
cat wallet-miner.json | jq -r .publicKey

# Extract mnemonic
cat wallet-miner.json | jq -r .mnemonic
```

### Import Wallet

```bash
# Interactive mode (prompts for mnemonic)
./build-v2/kalon-wallet import

# With mnemonic from command line
./build-v2/kalon-wallet import --mnemonic "word1 word2 ... word24" --name restored

# Specify output file
./build-v2/kalon-wallet import --mnemonic "word1 word2 ... word24" --output wallet-restored.json
```

### Check Balance

```bash
# Using wallet command
./build-v2/kalon-wallet balance --address kalon1abc123...

# Using RPC
curl http://localhost:16316/rpc \
  -H "Content-Type: application/json" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"getBalance\",\"params\":{\"address\":\"kalon1abc123...\"},\"id\":1}"
```

### Export Wallet

```bash
# Export public info
./build-v2/kalon-wallet export --input wallet-miner.json
```

### Wallet Options

```
create:
  --name string        Wallet name
  --output string      Output filename
  --passphrase string  Encryption passphrase

import:
  --mnemonic string    Mnemonic phrase
  --name string        Wallet name
  --output string      Output filename
  --passphrase string  Encryption passphrase

info:
  --input string       Wallet file path

balance:
  --address string     Wallet address

export:
  --input string       Wallet file path
```

## RPC API Commands

### Get Height

```bash
curl http://localhost:16316/rpc \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"getHeight","id":1}'
```

### Get Best Block

```bash
curl http://localhost:16316/rpc \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"getBestBlock","id":1}'
```

### Get Recent Blocks

```bash
# Get last 20 blocks
curl http://localhost:16316/rpc \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"getRecentBlocks","params":{"limit":20},"id":1}'

# Get last 5 blocks
curl http://localhost:16316/rpc \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"getRecentBlocks","params":{"limit":5},"id":1}'
```

### Get Balance

```bash
curl http://localhost:16316/rpc \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"getBalance","params":{"address":"kalon1abc123..."},"id":1}'
```

### Get Mining Info

```bash
curl http://localhost:16316/rpc \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"getMiningInfo","id":1}'
```

### Get Treasury Balance

```bash
curl http://localhost:16316/rpc \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"getTreasuryBalance","id":1}'
```

### Send Transaction

```bash
curl http://localhost:16316/rpc \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc":"2.0",
    "method":"sendTransaction",
    "params":{
      "from":"kalon1sender...",
      "to":"kalon1recipient...",
      "amount":1000000
    },
    "id":1
  }'
```

### RPC Endpoints Reference

| Method | Description | Parameters |
|--------|-------------|------------|
| `getHeight` | Get current blockchain height | None |
| `getBestBlock` | Get best block info | None |
| `getRecentBlocks` | Get recent blocks | `limit` (int) |
| `getBalance` | Get address balance | `address` (string) |
| `getMiningInfo` | Get mining information | None |
| `getTreasuryBalance` | Get treasury balance | None |
| `sendTransaction` | Send a transaction | `from`, `to`, `amount` |

## Utility Commands

### Check Process Status

```bash
# Check if node is running
ps aux | grep kalon-node-v2

# Check if miner is running
ps aux | grep kalon-miner-v2

# Check all Kalon processes
ps aux | grep kalon

# Count processes
pgrep -c kalon-node-v2
pgrep -c kalon-miner-v2
```

### View Logs

```bash
# Node logs
tail -f /tmp/node.log

# Miner logs
tail -f /tmp/miner.log

# Last 50 lines
tail -n 50 /tmp/node.log

# Search in logs
grep "error" /tmp/node.log
grep "Block" /tmp/miner.log
```

### Network Status

```bash
# Check if RPC is responding
curl http://localhost:16316/rpc \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"getHeight","id":1}'

# Test connectivity
ping -c 4 google.com

# Check open ports
netstat -tuln | grep -E '16316|17335'
sudo lsof -i :16316
```

### Clean Data

```bash
# Remove blockchain data (careful!)
rm -rf data-v2/testnet

# Remove all data
rm -rf data-v2/*

# Keep wallets, remove chain
rm -rf data-v2/testnet
mkdir -p data-v2/testnet
```

### Backup

```bash
# Backup wallet
cp wallet-miner.json wallet-miner-backup.json

# Backup all wallets
tar -czf wallets-backup.tar.gz wallet-*.json

# Backup blockchain data
tar -czf blockchain-backup.tar.gz data-v2/

# Backup everything
tar -czf kalon-backup-$(date +%Y%m%d).tar.gz \
  wallet-*.json data-v2/
```

### Quick Status Check

```bash
# One-liner status
echo "Height: $(curl -s http://localhost:16316/rpc -H 'Content-Type: application/json' -d '{"jsonrpc":"2.0","method":"getHeight","id":1}' | jq -r .result)"
echo "Node: $(pgrep -c kalon-node-v2) process"
echo "Miner: $(pgrep -c kalon-miner-v2) process"
```

### Build Commands

```bash
# Build all
make build

# Build specific
go build -o build-v2/kalon-node-v2 cmd/kalon-node-v2/main.go
go build -o build-v2/kalon-miner-v2 cmd/kalon-miner-v2/main.go
go build -o build-v2/kalon-wallet cmd/kalon-wallet/main.go

# Clean build
go clean -cache
make build

# Quick rebuild
make clean && make build
```

## Common Workflows

### Starting Fresh

```bash
# 1. Build
make build

# 2. Clean data
rm -rf data-v2/testnet
mkdir -p data-v2/testnet

# 3. Create wallet
./build-v2/kalon-wallet create

# 4. Start node
nohup ./build-v2/kalon-node-v2 -datadir data-v2/testnet -genesis genesis/testnet.json -rpc :16316 &

# 5. Wait for sync
sleep 5

# 6. Start mining
ADDRESS=$(cat wallet-*.json | jq -r .address | head -1)
nohup ./build-v2/kalon-miner-v2 -wallet "$ADDRESS" -threads 2 -rpc http://localhost:16316 &
```

### Check Everything

```bash
#!/bin/bash
echo "=== Kalon Network Status ==="
echo ""
echo "Node processes: $(pgrep -c kalon-node-v2)"
echo "Miner processes: $(pgrep -c kalon-miner-v2)"
echo ""
echo "Blockchain height: $(curl -s http://localhost:16316/rpc -H 'Content-Type: application/json' -d '{"jsonrpc":"2.0","method":"getHeight","id":1}' | jq -r .result)"
echo ""
echo "Wallets:"
./build-v2/kalon-wallet list
```

### Daily Mining Session

```bash
#!/bin/bash
# Start mining session

# Start node
nohup ./build-v2/kalon-node-v2 -datadir data-v2/testnet -genesis genesis/testnet.json -rpc :16316 > /tmp/node.log 2>&1 &
sleep 5

# Get wallet address
ADDRESS=$(cat wallet-miner.json | jq -r .address)

# Start miner
nohup ./build-v2/kalon-miner-v2 -wallet "$ADDRESS" -threads 4 -rpc http://localhost:16316 > /tmp/miner.log 2>&1 &

echo "Mining started. Wallet: $ADDRESS"
echo "Check logs: tail -f /tmp/miner.log"
```

### Stop Everything

```bash
#!/bin/bash
# Stop all Kalon processes

pkill -f kalon-node-v2
pkill -f kalon-miner-v2

echo "All Kalon processes stopped"
```

