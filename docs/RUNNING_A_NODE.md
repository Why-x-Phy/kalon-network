# Running a Kalon Network Node

This guide explains how to set up and run a Kalon Network node that can sync with the network and participate in mining.

## What You'll Need

- **OS**: Ubuntu 20.04/22.04 or similar Linux distribution
- **RAM**: Minimum 2GB (4GB recommended)
- **Storage**: At least 10GB free space
- **Network**: Stable internet connection
- **Go**: Version 1.21 or later installed

## Installation

### Step 1: Clone the Repository

```bash
git clone https://github.com/Why-x-Phy/kalon-network.git
cd kalon-network
```

### Step 2: Build the Binaries

Build the node, miner, and wallet:

```bash
go build -o build-v2/kalon-node-v2 cmd/kalon-node-v2/main.go
go build -o build-v2/kalon-miner-v2 cmd/kalon-miner-v2/main.go
go build -o build-v2/kalon-wallet cmd/kalon-wallet/main.go
```

### Step 3: Create a Wallet

Create a wallet for your node:

```bash
./build-v2/kalon-wallet create
```

Follow the interactive prompts:
1. Enter a wallet name (e.g., `my-node`)
2. Optionally enter a passphrase

Your wallet will be saved as `wallet-<name>.json` (e.g., `wallet-my-node.json`).

**Important**: Save your mnemonic phrase securely! You'll need it to recover your wallet.

Example output:
```
Enter wallet name: my-node
Enter passphrase (optional): 
Wallet created successfully!
Address: kalon1abc123...
Mnemonic: word1 word2 word3 ... word24
```

## Running Your Node

### Start the Kalon Node

```bash
./build-v2/kalon-node-v2 \
  -datadir data-v2/testnet \
  -genesis genesis/testnet.json \
  -rpc :16316 \
  -p2p :17335
```

This will:
- Start the node using the testnet genesis configuration
- Create a data directory at `data-v2/testnet`
- Start the RPC server on port 16316
- Start the P2P server on port 17335
- Begin syncing with the network

### Verify Node is Running

Check if the node is responding:

```bash
curl http://localhost:16316/rpc \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"getHeight","id":1}'
```

You should see a response with the current blockchain height.

## Mining on Your Node

### Start Mining

Once your node is synced, start mining with your wallet:

```bash
# Get your wallet address
WALLET_ADDRESS=$(cat wallet-my-node.json | jq -r .address)

# Start the miner
./build-v2/kalon-miner-v2 \
  -wallet "$WALLET_ADDRESS" \
  -threads 2 \
  -rpc http://localhost:16316
```

**Parameters:**
- `-wallet`: Your wallet address
- `-threads`: Number of CPU threads to use (adjust based on your hardware)
- `-rpc`: RPC endpoint of your node

### Check Mining Status

Check your balance to see mining rewards:

```bash
curl http://localhost:16316/rpc \
  -H "Content-Type: application/json" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"getBalance\",\"params\":{\"address\":\"$WALLET_ADDRESS\"},\"id\":2}"
```

## Configuration

### Network Configuration

Your node connects to the network via P2P on port 17335. The genesis configuration determines which network you're on:

- **Testnet**: Uses `genesis/testnet.json`
- **Mainnet**: Uses `genesis/mainnet.json`
- **Community Testnet**: Uses `genesis/community-testnet.json`

### Running in the Background

To run your node as a service, use `nohup`:

```bash
# Start node in background
nohup ./build-v2/kalon-node-v2 \
  -datadir data-v2/testnet \
  -genesis genesis/testnet.json \
  -rpc :16316 \
  > /tmp/kalon-node.log 2>&1 &

# Start miner in background
WALLET_ADDRESS=$(cat wallet-my-node.json | jq -r .address)
nohup ./build-v2/kalon-miner-v2 \
  -wallet "$WALLET_ADDRESS" \
  -threads 2 \
  -rpc http://localhost:16316 \
  > /tmp/kalon-miner.log 2>&1 &
```

### Check Running Processes

```bash
ps aux | grep kalon
```

### Stop Node and Miner

```bash
pkill -f kalon-node-v2
pkill -f kalon-miner-v2
```

## Data Persistence

All blockchain data is stored in the `data-v2/testnet` directory (or whatever directory you specify with `-datadir`).

**Backup**: Regularly back up your:
- `wallet-*.json` files (wallet data)
- `data-v2/` directory (blockchain data)

## Recovery

If you lose your wallet file, you can recover it using your mnemonic phrase:

```bash
./build-v2/kalon-wallet import
```

Enter your 24-word mnemonic phrase when prompted, and your wallet will be restored.

## Troubleshooting

### Node won't start

Check the logs:
```bash
tail -f /tmp/kalon-node.log
```

### Can't connect to network

Ensure ports 16316 (RPC) and 17335 (P2P) are open and not blocked by a firewall.

### Mining not working

Verify your node is running and responding:
```bash
curl http://localhost:16316/rpc \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"getHeight","id":1}'
```

### Low mining rate

- Increase the number of threads: `-threads 4`
- Ensure you have sufficient CPU resources
- Check network latency to the blockchain

## Advanced: Running Multiple Nodes

You can run multiple nodes on the same machine using different ports:

```bash
# Node 1
./build-v2/kalon-node-v2 -datadir data-v2/node1 -rpc :16316 -p2p :17335

# Node 2
./build-v2/kalon-node-v2 -datadir data-v2/node2 -rpc :16317 -p2p :17336
```

## Support

For issues and questions:
- **GitHub**: https://github.com/Why-x-Phy/kalon-network
- **Documentation**: See `docs/` directory for additional guides

## Quick Start Script

Save this as `start-node.sh`:

```bash
#!/bin/bash

# Configuration
WALLET_NAME="my-node"
DATA_DIR="data-v2/testnet"
GENESIS="genesis/testnet.json"
RPC_PORT="16316"
P2P_PORT="17335"
MINER_THREADS=2

# Build binaries
echo "Building binaries..."
go build -o build-v2/kalon-node-v2 cmd/kalon-node-v2/main.go
go build -o build-v2/kalon-miner-v2 cmd/kalon-miner-v2/main.go

# Check if wallet exists, create if not
if [ ! -f "wallet-${WALLET_NAME}.json" ]; then
  echo "Creating wallet..."
  ./build-v2/kalon-wallet create --name "$WALLET_NAME"
fi

# Get wallet address
WALLET_ADDRESS=$(cat "wallet-${WALLET_NAME}.json" | jq -r .address)
echo "Wallet: $WALLET_ADDRESS"

# Start node
echo "Starting node..."
nohup ./build-v2/kalon-node-v2 \
  -datadir "$DATA_DIR" \
  -genesis "$GENESIS" \
  -rpc ":$RPC_PORT" \
  -p2p ":$P2P_PORT" \
  > /tmp/kalon-node.log 2>&1 &
sleep 5

# Start miner
echo "Starting miner..."
nohup ./build-v2/kalon-miner-v2 \
  -wallet "$WALLET_ADDRESS" \
  -threads $MINER_THREADS \
  -rpc "http://localhost:$RPC_PORT" \
  > /tmp/kalon-miner.log 2>&1 &

echo "✅ Node and miner started!"
echo "Check status: ps aux | grep kalon"
echo "Check logs: tail -f /tmp/kalon-node.log"
```

Make it executable and run:

```bash
chmod +x start-node.sh
./start-node.sh
```

