#!/bin/bash

# Kalon Miner Startup Script
# Usage: ./scripts/start-miner.sh [community-testnet|testnet|mainnet] [wallet-address] [threads]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
NETWORK=${1:-mainnet}
WALLET_ADDRESS=${2:-""}
THREADS=${3:-1}

echo -e "${BLUE}Kalon Miner Startup Script${NC}"
echo "============================="
echo ""

# Validate network type
case $NETWORK in
    community-testnet|community|ct)
        NETWORK_TYPE="community-testnet"
        NETWORK_NAME="Community Testnet"
        RPC_URL="http://localhost:16315"
        ;;
    testnet|test|t)
        NETWORK_TYPE="testnet"
        NETWORK_NAME="Testnet"
        RPC_URL="http://localhost:16316"
        ;;
    mainnet|main|m)
        NETWORK_TYPE="mainnet"
        NETWORK_NAME="Mainnet"
        RPC_URL="http://localhost:16314"
        ;;
    *)
        echo -e "${RED}Error: Invalid network type '$NETWORK'${NC}"
        echo "Usage: $0 [community-testnet|testnet|mainnet] [wallet-address] [threads]"
        echo ""
        echo "Available networks:"
        echo "  community-testnet, community, ct  - Community Testnet (tKALON)"
        echo "  testnet, test, t                  - Testnet (tKALON)"
        echo "  mainnet, main, m                  - Mainnet (KALON)"
        exit 1
        ;;
esac

echo -e "${GREEN}Starting Miner for $NETWORK_NAME...${NC}"
echo ""

# Check if binary exists
if [ ! -f "./build/kalon-miner" ]; then
    echo -e "${RED}Error: kalon-miner binary not found${NC}"
    echo "Run 'make build' first"
    exit 1
fi

# Create wallet if not provided
if [ -z "$WALLET_ADDRESS" ]; then
    echo -e "${YELLOW}No wallet address provided. Creating new wallet...${NC}"
    
    # Create wallet with empty passphrase (non-interactive)
    WALLET_OUTPUT=$(echo "" | ./build/kalon-wallet create 2>&1)
    WALLET_ADDRESS=$(echo "$WALLET_OUTPUT" | grep "Address:" | cut -d' ' -f2)
    
    if [ -z "$WALLET_ADDRESS" ]; then
        echo -e "${RED}Error: Failed to create wallet${NC}"
        echo "$WALLET_OUTPUT"
        exit 1
    fi
    
    echo -e "${GREEN}Created wallet: $WALLET_ADDRESS${NC}"
    echo ""
fi

echo -e "${YELLOW}Miner Configuration:${NC}"
echo "  Network: $NETWORK_NAME"
echo "  Wallet: $WALLET_ADDRESS"
echo "  Threads: $THREADS"
echo "  RPC URL: $RPC_URL"
echo ""

# Start the miner
echo -e "${GREEN}Starting Kalon Miner...${NC}"
echo ""

# Run the miner
exec ./build/kalon-miner \
    --wallet "$WALLET_ADDRESS" \
    --threads "$THREADS" \
    --rpc "$RPC_URL"
