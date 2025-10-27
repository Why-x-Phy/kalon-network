# Kalon Network - User Guide

Welcome to Kalon Network! This guide will help you set up and run your own node, create a wallet, and start mining.

## Table of Contents

1. [Quick Start](#quick-start)
2. [Installing Kalon](#installing-kalon)
3. [Creating a Wallet](#creating-a-wallet)
4. [Running a Node](#running-a-node)
5. [Mining](#mining)
6. [Basic Operations](#basic-operations)
7. [Troubleshooting](#troubleshooting)

## Quick Start

Get up and running in 5 minutes:

```bash
# 1. Clone repository
git clone https://github.com/Why-x-Phy/kalon-network.git
cd kalon-network

# 2. Build binaries
make build

# 3. Create wallet
./build-v2/kalon-wallet create
# Enter wallet name, copy your address

# 4. Start node
./build-v2/kalon-node-v2 -datadir data-v2/testnet -genesis genesis/testnet.json -rpc :16316 &
sleep 5

# 5. Start mining
./build-v2/kalon-miner-v2 -wallet YOUR_ADDRESS -threads 2 -rpc http://localhost:16316 &
```

## Installing Kalon

### System Requirements

- **Operating System**: Linux (Ubuntu 20.04+ recommended)
- **RAM**: 2GB minimum
- **Storage**: 10GB free space
- **CPU**: 2+ cores
- **Go**: Version 1.21 or later

### Installing Go

```bash
# Download Go
wget https://go.dev/dl/go1.21.5.linux-amd64.tar.gz

# Install
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf go1.21.5.linux-amd64.tar.gz
export PATH=$PATH:/usr/local/go/bin

# Add to PATH permanently
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
source ~/.bashrc

# Verify
go version
```

### Building Kalon

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
```

## Creating a Wallet

### Create New Wallet

```bash
./build-v2/kalon-wallet create
```

You'll be prompted for:
1. **Wallet name** (optional, default: `wallet`)
2. **Passphrase** (optional, for encryption)

**Important**: Save your **mnemonic phrase** (24 words) securely! You'll need it to recover your wallet.

Example:
```
Enter wallet name: my-miner
Enter passphrase (optional): 
Wallet created successfully!
Address: kalon1abc123def456...
Mnemonic: word1 word2 word3 ... word24
Wallet saved to: wallet-my-miner.json
```

### List Your Wallets

```bash
./build-v2/kalon-wallet list
```

Output:
```
Available wallets:
  📄 wallet-my-miner.json
     Address: kalon1abc123def456...
     Public Key: xyz789...

  📄 wallet-backup.json
     Address: kalon1xyz789abc123...
     Public Key: def456...
```

### View Wallet Info

```bash
./build-v2/kalon-wallet info --input wallet-my-miner.json
```

### Recover Wallet from Mnemonic

If you lose your wallet file, you can recover it:

```bash
./build-v2/kalon-wallet import
```

You'll be prompted for:
1. **Mnemonic phrase** (24 words)
2. **Wallet name** (optional)
3. **Passphrase** (optional)

## Running a Node

### Start Node

```bash
./build-v2/kalon-node-v2 \
  -datadir data-v2/testnet \
  -genesis genesis/testnet.json \
  -rpc :16316
```

This will:
- Create blockchain data in `data-v2/testnet`
- Connect to the testnet network
- Start accepting connections on port 16316
- Begin syncing blocks from the network

### Start Node in Background

```bash
nohup ./build-v2/kalon-node-v2 \
  -datadir data-v2/testnet \
  -genesis genesis/testnet.json \
  -rpc :16316 > /tmp/kalon-node.log 2>&1 &
```

### Check Node Status

```bash
# Check if node is responding
curl http://localhost:16316/rpc \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"getHeight","id":1}'

# Check process
ps aux | grep kalon-node
```

## Mining

### Start Mining

```bash
# Get your wallet address
ADDRESS=$(cat wallet-my-miner.json | jq -r .address)

# Start miner
./build-v2/kalon-miner-v2 \
  -wallet "$ADDRESS" \
  -threads 2 \
  -rpc http://localhost:16316
```

**Parameters:**
- `-wallet`: Your wallet address
- `-threads`: Number of CPU threads (more threads = faster mining)
- `-rpc`: Node RPC endpoint

### Start Mining in Background

```bash
nohup ./build-v2/kalon-miner-v2 \
  -wallet "$ADDRESS" \
  -threads 4 \
  -rpc http://localhost:16316 > /tmp/kalon-miner.log 2>&1 &
```

### Check Mining Status

```bash
# View miner logs
tail -f /tmp/kalon-miner.log

# Check balance
curl http://localhost:16316/rpc \
  -H "Content-Type: application/json" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"getBalance\",\"params\":{\"address\":\"$ADDRESS\"},\"id\":1}" | jq .
```

## Basic Operations

### Check Balance

```bash
# Get your address
ADDRESS=$(cat wallet-my-miner.json | jq -r .address)

# Check balance
curl http://localhost:16316/rpc \
  -H "Content-Type: application/json" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"getBalance\",\"params\":{\"address\":\"$ADDRESS\"},\"id\":1}" | jq .

# Or use wallet command
./build-v2/kalon-wallet balance --address "$ADDRESS"
```

### Get Blockchain Height

```bash
curl http://localhost:16316/rpc \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"getHeight","id":1}' | jq .
```

### Get Best Block Info

```bash
curl http://localhost:16316/rpc \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"getBestBlock","id":1}' | jq .
```

### Stop Node and Miner

```bash
# Stop all Kalon processes
pkill -f kalon-node
pkill -f kalon-miner

# Or stop specifically
kill $(pgrep -f kalon-node-v2)
kill $(pgrep -f kalon-miner-v2)
```

## Troubleshooting

### Node Won't Start

**Problem**: Port already in use

```bash
# Check what's using the port
sudo lsof -i :16316

# Kill the process or use a different port
./build-v2/kalon-node-v2 -rpc :16317
```

**Problem**: Permission denied

```bash
# Give execute permission
chmod +x build-v2/kalon-node-v2
```

### Mining Not Working

**Problem**: Miner can't connect to node

```bash
# Make sure node is running
ps aux | grep kalon-node

# Check RPC endpoint
curl http://localhost:16316/rpc \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"getHeight","id":1}'
```

**Problem**: No rewards

- Wait for blocks to be mined
- Check node is synced (height should be increasing)
- Verify wallet address is correct

### Wallet Issues

**Problem**: Can't find wallet file

```bash
# List wallets
./build-v2/kalon-wallet list

# Check current directory
ls -la wallet-*.json
```

**Problem**: Wrong password

If you set a passphrase, use the same one when importing.

## Getting Help

- **Documentation**: Check `docs/` directory
- **Issues**: [GitHub Issues](https://github.com/Why-x-Phy/kalon-network/issues)
- **Community**: Join our Discord

## Advanced Topics

### Running Multiple Wallets

You can run multiple miners with different wallets:

```bash
# Miner 1
./build-v2/kalon-miner-v2 -wallet "$(cat wallet-1.json | jq -r .address)" -threads 2 -rpc http://localhost:16316 &

# Miner 2
./build-v2/kalon-miner-v2 -wallet "$(cat wallet-2.json | jq -r .address)" -threads 2 -rpc http://localhost:16316 &
```

### Optimizing Mining Performance

```bash
# Use more CPU threads
./build-v2/kalon-miner-v2 -wallet "$ADDRESS" -threads 8 -rpc http://localhost:16316

# Monitor CPU usage
top -p $(pgrep -f kalon-miner)
```

### Backup Your Wallet

```bash
# Backup wallet file
cp wallet-my-miner.json /secure/backup/wallet-my-miner-backup.json

# Or just save the mnemonic (more secure)
# Your mnemonic phrase is all you need to recover your wallet
```

## Security Best Practices

1. **Keep your mnemonic phrase secret and secure**
2. **Don't share your private keys**
3. **Backup wallet files regularly**
4. **Use strong passwords for encrypted wallets**
5. **Keep software updated**

