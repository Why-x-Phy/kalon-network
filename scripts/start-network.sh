#!/bin/bash

# Kalon Network Startup Script
# Usage: ./scripts/start-network.sh [community-testnet|testnet|mainnet]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default network
NETWORK=${1:-mainnet}

echo -e "${BLUE}Kalon Network Startup Script${NC}"
echo "================================"
echo ""

# Validate network type
case $NETWORK in
    community-testnet|community|ct)
        NETWORK_TYPE="community-testnet"
        NETWORK_NAME="Community Testnet"
        ;;
    testnet|test|t)
        NETWORK_TYPE="testnet"
        NETWORK_NAME="Testnet"
        ;;
    mainnet|main|m)
        NETWORK_TYPE="mainnet"
        NETWORK_NAME="Mainnet"
        ;;
    *)
        echo -e "${RED}Error: Invalid network type '$NETWORK'${NC}"
        echo "Usage: $0 [community-testnet|testnet|mainnet]"
        echo ""
        echo "Available networks:"
        echo "  community-testnet, community, ct  - Community Testnet (tKALON)"
        echo "  testnet, test, t                  - Testnet (tKALON)"
        echo "  mainnet, main, m                  - Mainnet (KALON)"
        exit 1
        ;;
esac

echo -e "${GREEN}Starting $NETWORK_NAME...${NC}"
echo ""

# Check if binaries exist
if [ ! -f "./build/kalon-node" ]; then
    echo -e "${RED}Error: kalon-node binary not found${NC}"
    echo "Run 'make build' first"
    exit 1
fi

if [ ! -f "./build/kalon-wallet" ]; then
    echo -e "${RED}Error: kalon-wallet binary not found${NC}"
    echo "Run 'make build' first"
    exit 1
fi

if [ ! -f "./build/kalon-miner" ]; then
    echo -e "${RED}Error: kalon-miner binary not found${NC}"
    echo "Run 'make build' first"
    exit 1
fi

# Set network-specific configuration
case $NETWORK_TYPE in
    community-testnet)
        DATA_DIR="./data-community-testnet"
        GENESIS_FILE="./genesis/community-testnet.json"
        RPC_ADDR=":16315"
        P2P_ADDR=":17334"
        TOKEN_SYMBOL="tKALON"
        ;;
    testnet)
        DATA_DIR="./data-testnet"
        GENESIS_FILE="./genesis/testnet.json"
        RPC_ADDR=":16316"
        P2P_ADDR=":17335"
        TOKEN_SYMBOL="tKALON"
        ;;
    mainnet)
        DATA_DIR="./data-mainnet"
        GENESIS_FILE="./genesis/mainnet.json"
        RPC_ADDR=":16314"
        P2P_ADDR=":17333"
        TOKEN_SYMBOL="KALON"
        ;;
esac

echo -e "${YELLOW}Network Configuration:${NC}"
echo "  Type: $NETWORK_NAME"
echo "  Token: $TOKEN_SYMBOL"
echo "  Data Directory: $DATA_DIR"
echo "  Genesis File: $GENESIS_FILE"
echo "  RPC Address: $RPC_ADDR"
echo "  P2P Address: $P2P_ADDR"
echo ""

# Create data directory
echo -e "${BLUE}Setting up data directory...${NC}"
mkdir -p "$DATA_DIR"

# Check if genesis file exists
if [ ! -f "$GENESIS_FILE" ]; then
    echo -e "${RED}Error: Genesis file not found: $GENESIS_FILE${NC}"
    exit 1
fi

# Start the node
echo -e "${GREEN}Starting Kalon Node...${NC}"
echo ""

# Run the node
exec ./build/kalon-node \
    --datadir "$DATA_DIR" \
    --genesis "$GENESIS_FILE" \
    --rpc "$RPC_ADDR" \
    --p2p "$P2P_ADDR" \
    --mining
