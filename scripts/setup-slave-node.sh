#!/bin/bash

# Kalon Network Slave Node Setup Script
# Version: 1.0.2

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
KALON_VERSION="1.0.2"
INSTALL_DIR="/opt/kalon"
BIN_DIR="/usr/local/bin"
SERVICE_USER="kalon"
DATA_DIR="/var/lib/kalon"

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}  Kalon Slave Node Setup${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root${NC}"
   echo "Usage: sudo $0 <master-ip> <network> <wallet> <threads>"
   exit 1
fi

# Check arguments
if [ $# -ne 4 ]; then
    echo -e "${RED}Usage: $0 <master-ip> <network> <wallet> <threads>${NC}"
    echo "Example: $0 185.133.249.107 testnet kalon12slz9pccxhahtm0th9v7n5emm6vtkumx4pykuh 2"
    exit 1
fi

MASTER_IP="$1"
NETWORK="$2"
WALLET="$3"
THREADS="$4"

echo -e "${YELLOW}Slave Node Configuration:${NC}"
echo "  Master IP: $MASTER_IP"
echo "  Network: $NETWORK"
echo "  Wallet: $WALLET"
echo "  Threads: $THREADS"
echo ""

# Validate network
case $NETWORK in
    "community-testnet")
        GENESIS_FILE="$INSTALL_DIR/genesis/community-testnet.json"
        DATA_SUBDIR="community-testnet"
        RPC_PORT="16316"
        P2P_PORT="17335"
        ;;
    "testnet")
        GENESIS_FILE="$INSTALL_DIR/genesis/testnet.json"
        DATA_SUBDIR="testnet"
        RPC_PORT="16316"
        P2P_PORT="17335"
        ;;
    "mainnet")
        GENESIS_FILE="$INSTALL_DIR/genesis/mainnet.json"
        DATA_SUBDIR="mainnet"
        RPC_PORT="16316"
        P2P_PORT="17335"
        ;;
    *)
        echo -e "${RED}Invalid network: $NETWORK${NC}"
        echo "Valid networks: community-testnet, testnet, mainnet"
        exit 1
        ;;
esac

# Check if genesis file exists
if [ ! -f "$GENESIS_FILE" ]; then
    echo -e "${RED}Genesis file not found: $GENESIS_FILE${NC}"
    exit 1
fi

# Create data directory
echo -e "${YELLOW}Creating data directory...${NC}"
mkdir -p "$DATA_DIR/$DATA_SUBDIR"
chown -R "$SERVICE_USER:$SERVICE_USER" "$DATA_DIR/$DATA_SUBDIR"

# Create slave node service
echo -e "${YELLOW}Creating slave node service...${NC}"
cat > /etc/systemd/system/kalon-slave.service << EOF
[Unit]
Description=Kalon Network Slave Node
After=network.target

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_USER
WorkingDirectory=$INSTALL_DIR
ExecStart=$BIN_DIR/kalon-node --datadir $DATA_DIR/$DATA_SUBDIR --genesis $GENESIS_FILE --rpc :$RPC_PORT --p2p :$P2P_PORT
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Create slave miner service
echo -e "${YELLOW}Creating slave miner service...${NC}"
cat > /etc/systemd/system/kalon-slave-miner.service << EOF
[Unit]
Description=Kalon Network Slave Miner
After=network.target kalon-slave.service
Requires=kalon-slave.service

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_USER
WorkingDirectory=$INSTALL_DIR
ExecStart=$BIN_DIR/kalon-miner --wallet $WALLET --threads $THREADS --rpc http://localhost:$RPC_PORT
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Create sync service
echo -e "${YELLOW}Creating sync service...${NC}"
cat > /etc/systemd/system/kalon-slave-sync.service << EOF
[Unit]
Description=Kalon Network Slave Sync
After=network.target kalon-slave.service
Requires=kalon-slave.service

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_USER
WorkingDirectory=$INSTALL_DIR
ExecStart=/bin/bash -c 'while true; do curl -s -X POST http://$MASTER_IP:16315 -H "Content-Type: application/json" -d "{\"jsonrpc\":\"2.0\",\"method\":\"getHeight\",\"params\":{},\"id\":1}" > /dev/null; sleep 30; done'
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Create management scripts
echo -e "${YELLOW}Creating management scripts...${NC}"

cat > /usr/local/bin/kalon-slave-start << 'EOF'
#!/bin/bash
echo "Starting Kalon Slave Node..."
systemctl start kalon-slave
sleep 5
systemctl start kalon-slave-miner
systemctl start kalon-slave-sync
echo "Kalon Slave Node started!"
echo "Node: http://localhost:16316"
EOF

cat > /usr/local/bin/kalon-slave-stop << 'EOF'
#!/bin/bash
echo "Stopping Kalon Slave Node..."
systemctl stop kalon-slave-sync
systemctl stop kalon-slave-miner
systemctl stop kalon-slave
echo "Kalon Slave Node stopped!"
EOF

cat > /usr/local/bin/kalon-slave-status << 'EOF'
#!/bin/bash
echo "Kalon Slave Node Status:"
echo "========================"
systemctl status kalon-slave --no-pager
echo ""
systemctl status kalon-slave-miner --no-pager
echo ""
systemctl status kalon-slave-sync --no-pager
EOF

cat > /usr/local/bin/kalon-slave-logs << 'EOF'
#!/bin/bash
if [ "$1" = "node" ]; then
    journalctl -u kalon-slave -f
elif [ "$1" = "miner" ]; then
    journalctl -u kalon-slave-miner -f
elif [ "$1" = "sync" ]; then
    journalctl -u kalon-slave-sync -f
else
    echo "Usage: kalon-slave-logs [node|miner|sync]"
fi
EOF

cat > /usr/local/bin/kalon-slave-monitor << 'EOF'
#!/bin/bash
echo "Kalon Slave Node Monitor (Press Ctrl+C to exit)"
echo "==============================================="
while true; do
    clear
    echo "Kalon Slave Node Monitor - $(date)"
    echo "==================================="
    echo ""
    
    # Node status
    echo "Node Status:"
    systemctl is-active kalon-slave
    echo ""
    
    # Miner status
    echo "Miner Status:"
    systemctl is-active kalon-slave-miner
    echo ""
    
    # Sync status
    echo "Sync Status:"
    systemctl is-active kalon-slave-sync
    echo ""
    
    # Block height
    echo "Block Height:"
    curl -s -X POST http://localhost:16316 \
      -H "Content-Type: application/json" \
      -d '{"jsonrpc":"2.0","method":"getHeight","params":{},"id":1}' 2>/dev/null | grep -o '"result":[0-9]*' | cut -d: -f2 || echo "N/A"
    echo ""
    
    sleep 5
done
EOF

# Make scripts executable
chmod +x /usr/local/bin/kalon-slave-*

# Reload systemd
systemctl daemon-reload

# Enable services
systemctl enable kalon-slave
systemctl enable kalon-slave-miner
systemctl enable kalon-slave-sync

# Create firewall rules
echo -e "${YELLOW}Configuring firewall...${NC}"
if command -v ufw &> /dev/null; then
    ufw allow $RPC_PORT/tcp comment "Kalon RPC"
    ufw allow $P2P_PORT/tcp comment "Kalon P2P"
    echo -e "${GREEN}Firewall rules added${NC}"
fi

# Final status
echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}  Slave Node Setup Complete!${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo -e "${BLUE}Slave Node Configuration:${NC}"
echo "  Master IP: $MASTER_IP"
echo "  Network: $NETWORK"
echo "  Wallet: $WALLET"
echo "  Threads: $THREADS"
echo "  Data Directory: $DATA_DIR/$DATA_SUBDIR"
echo "  RPC Port: $RPC_PORT"
echo "  P2P Port: $P2P_PORT"
echo ""
echo -e "${YELLOW}Management Commands:${NC}"
echo "  kalon-slave-start    - Start all services"
echo "  kalon-slave-stop     - Stop all services"
echo "  kalon-slave-status   - Check service status"
echo "  kalon-slave-logs     - View service logs"
echo "  kalon-slave-monitor  - Real-time monitoring"
echo ""
echo -e "${YELLOW}Access Points:${NC}"
echo "  RPC API:    http://localhost:$RPC_PORT"
echo "  P2P Port:   $P2P_PORT"
echo ""
echo -e "${GREEN}To start the slave node, run: kalon-slave-start${NC}"
echo ""