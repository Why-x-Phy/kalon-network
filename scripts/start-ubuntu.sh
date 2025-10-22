#!/bin/bash

# Kalon Network Start Script for Ubuntu
# Version: 1.0.2

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NETWORK=${1:-"community-testnet"}
WALLET=${2:-"kalon12slz9pccxhahtm0th9v7n5emm6vtkumx4pykuh"}
THREADS=${3:-2}
RPC_PORT=${4:-16315}
P2P_PORT=${5:-17334}

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}  Kalon Network v1.0.2 Startup${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root${NC}"
   echo "Usage: sudo $0 [network] [wallet] [threads] [rpc_port] [p2p_port]"
   exit 1
fi

# Validate network
case $NETWORK in
    "community-testnet"|"testnet"|"mainnet")
        echo -e "${GREEN}Using network: $NETWORK${NC}"
        ;;
    *)
        echo -e "${RED}Invalid network: $NETWORK${NC}"
        echo "Valid networks: community-testnet, testnet, mainnet"
        exit 1
        ;;
esac

# Set data directory based on network
DATA_DIR="/var/lib/kalon/$NETWORK"
GENESIS_FILE="/opt/kalon/genesis/$NETWORK.json"

# Check if genesis file exists
if [ ! -f "$GENESIS_FILE" ]; then
    echo -e "${RED}Genesis file not found: $GENESIS_FILE${NC}"
    exit 1
fi

# Create data directory if it doesn't exist
mkdir -p "$DATA_DIR"
chown kalon:kalon "$DATA_DIR"

echo -e "${YELLOW}Starting Kalon Network...${NC}"
echo -e "${BLUE}Configuration:${NC}"
echo "  Network: $NETWORK"
echo "  Wallet: $WALLET"
echo "  Threads: $THREADS"
echo "  RPC Port: $RPC_PORT"
echo "  P2P Port: $P2P_PORT"
echo "  Data Dir: $DATA_DIR"
echo "  Genesis: $GENESIS_FILE"
echo ""

# Stop existing services
echo -e "${YELLOW}Stopping existing services...${NC}"
systemctl stop kalon-explorer 2>/dev/null || true
systemctl stop kalon-miner 2>/dev/null || true
systemctl stop kalon-node 2>/dev/null || true

# Wait a moment
sleep 2

# Start node
echo -e "${YELLOW}Starting Kalon Node...${NC}"
kalon-node \
    --datadir "$DATA_DIR" \
    --genesis "$GENESIS_FILE" \
    --rpc ":$RPC_PORT" \
    --p2p ":$P2P_PORT" \
    --log info &

NODE_PID=$!
echo "Node PID: $NODE_PID"

# Wait for node to start
echo -e "${YELLOW}Waiting for node to start...${NC}"
sleep 10

# Check if node is running
if ! kill -0 $NODE_PID 2>/dev/null; then
    echo -e "${RED}Node failed to start!${NC}"
    exit 1
fi

# Test RPC connection
echo -e "${YELLOW}Testing RPC connection...${NC}"
for i in {1..30}; do
    if curl -s "http://localhost:$RPC_PORT" >/dev/null 2>&1; then
        echo -e "${GREEN}RPC connection successful!${NC}"
        break
    fi
    if [ $i -eq 30 ]; then
        echo -e "${RED}RPC connection failed after 30 attempts${NC}"
        kill $NODE_PID 2>/dev/null || true
        exit 1
    fi
    sleep 1
done

# Start miner
echo -e "${YELLOW}Starting Kalon Miner...${NC}"
kalon-miner \
    --wallet "$WALLET" \
    --threads "$THREADS" \
    --rpc "http://localhost:$RPC_PORT" \
    --log info &

MINER_PID=$!
echo "Miner PID: $MINER_PID"

# Start explorer (if available)
if [ -f "/opt/kalon/explorer/api/main.js" ]; then
    echo -e "${YELLOW}Starting Kalon Explorer...${NC}"
    cd /opt/kalon/explorer
    node api/main.js &
    EXPLORER_PID=$!
    echo "Explorer PID: $EXPLORER_PID"
fi

# Wait a moment
sleep 5

echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}  Kalon Network Started!${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo -e "${BLUE}Network Information:${NC}"
echo "  Network: $NETWORK"
echo "  Wallet: $WALLET"
echo "  Threads: $THREADS"
echo ""
echo -e "${BLUE}Access Points:${NC}"
echo "  RPC API:    http://localhost:$RPC_PORT"
echo "  P2P Port:   $P2P_PORT"
if [ ! -z "$EXPLORER_PID" ]; then
    echo "  Explorer:   http://localhost:3000"
fi
echo ""
echo -e "${BLUE}Process IDs:${NC}"
echo "  Node: $NODE_PID"
echo "  Miner: $MINER_PID"
if [ ! -z "$EXPLORER_PID" ]; then
    echo "  Explorer: $EXPLORER_PID"
fi
echo ""
echo -e "${YELLOW}To stop the network, press Ctrl+C${NC}"
echo ""

# Function to cleanup on exit
cleanup() {
    echo ""
    echo -e "${YELLOW}Stopping Kalon Network...${NC}"
    
    if [ ! -z "$EXPLORER_PID" ]; then
        kill $EXPLORER_PID 2>/dev/null || true
        echo "Explorer stopped"
    fi
    
    kill $MINER_PID 2>/dev/null || true
    echo "Miner stopped"
    
    kill $NODE_PID 2>/dev/null || true
    echo "Node stopped"
    
    echo -e "${GREEN}Kalon Network stopped!${NC}"
    exit 0
}

# Set trap for cleanup
trap cleanup SIGINT SIGTERM

# Keep script running
while true; do
    # Check if processes are still running
    if ! kill -0 $NODE_PID 2>/dev/null; then
        echo -e "${RED}Node process died!${NC}"
        cleanup
    fi
    
    if ! kill -0 $MINER_PID 2>/dev/null; then
        echo -e "${RED}Miner process died!${NC}"
        cleanup
    fi
    
    sleep 10
done
