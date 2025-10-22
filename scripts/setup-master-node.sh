#!/bin/bash

# Kalon Network Master Node Setup Script
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
echo -e "${BLUE}  Kalon Master Node Setup${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root${NC}"
   echo "Usage: sudo $0 <IP> <network> <wallet> <threads>"
   exit 1
fi

# Check arguments
if [ $# -ne 4 ]; then
    echo -e "${RED}Usage: $0 <IP> <network> <wallet> <threads>${NC}"
    echo "Example: $0 185.133.249.107 testnet kalon12slz9pccxhahtm0th9v7n5emm6vtkumx4pykuh 4"
    exit 1
fi

MASTER_IP="$1"
NETWORK="$2"
WALLET="$3"
THREADS="$4"

echo -e "${YELLOW}Master Node Configuration:${NC}"
echo "  IP: $MASTER_IP"
echo "  Network: $NETWORK"
echo "  Wallet: $WALLET"
echo "  Threads: $THREADS"
echo ""

# Validate network
case $NETWORK in
    "community-testnet")
        GENESIS_FILE="$INSTALL_DIR/genesis/community-testnet.json"
        DATA_SUBDIR="community-testnet"
        RPC_PORT="16315"
        P2P_PORT="17334"
        ;;
    "testnet")
        GENESIS_FILE="$INSTALL_DIR/genesis/testnet.json"
        DATA_SUBDIR="testnet"
        RPC_PORT="16315"
        P2P_PORT="17334"
        ;;
    "mainnet")
        GENESIS_FILE="$INSTALL_DIR/genesis/mainnet.json"
        DATA_SUBDIR="mainnet"
        RPC_PORT="16315"
        P2P_PORT="17334"
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

# Create master node service
echo -e "${YELLOW}Creating master node service...${NC}"
cat > /etc/systemd/system/kalon-master.service << EOF
[Unit]
Description=Kalon Network Master Node
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

# Create master miner service
echo -e "${YELLOW}Creating master miner service...${NC}"
cat > /etc/systemd/system/kalon-master-miner.service << EOF
[Unit]
Description=Kalon Network Master Miner
After=network.target kalon-master.service
Requires=kalon-master.service

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

# Create master explorer service
echo -e "${YELLOW}Creating master explorer service...${NC}"
cat > /etc/systemd/system/kalon-master-explorer.service << EOF
[Unit]
Description=Kalon Network Master Explorer
After=network.target kalon-master.service
Requires=kalon-master.service

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_USER
WorkingDirectory=$INSTALL_DIR/explorer/api
ExecStart=$INSTALL_DIR/explorer/api/main
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Create management scripts
echo -e "${YELLOW}Creating management scripts...${NC}"

cat > /usr/local/bin/kalon-master-start << 'EOF'
#!/bin/bash
echo "Starting Kalon Master Node..."
systemctl start kalon-master
sleep 5
systemctl start kalon-master-miner
systemctl start kalon-master-explorer
echo "Kalon Master Node started!"
echo "Node: http://localhost:16315"
echo "Explorer: http://localhost:3000"
EOF

cat > /usr/local/bin/kalon-master-stop << 'EOF'
#!/bin/bash
echo "Stopping Kalon Master Node..."
systemctl stop kalon-master-explorer
systemctl stop kalon-master-miner
systemctl stop kalon-master
echo "Kalon Master Node stopped!"
EOF

cat > /usr/local/bin/kalon-master-status << 'EOF'
#!/bin/bash
echo "Kalon Master Node Status:"
echo "========================="
systemctl status kalon-master --no-pager
echo ""
systemctl status kalon-master-miner --no-pager
echo ""
systemctl status kalon-master-explorer --no-pager
EOF

cat > /usr/local/bin/kalon-master-logs << 'EOF'
#!/bin/bash
if [ "$1" = "node" ]; then
    journalctl -u kalon-master -f
elif [ "$1" = "miner" ]; then
    journalctl -u kalon-master-miner -f
elif [ "$1" = "explorer" ]; then
    journalctl -u kalon-master-explorer -f
else
    echo "Usage: kalon-master-logs [node|miner|explorer]"
fi
EOF

cat > /usr/local/bin/kalon-master-monitor << 'EOF'
#!/bin/bash
echo "Kalon Master Node Monitor (Press Ctrl+C to exit)"
echo "================================================"
while true; do
    clear
    echo "Kalon Master Node Monitor - $(date)"
    echo "====================================="
    echo ""
    
    # Node status
    echo "Node Status:"
    systemctl is-active kalon-master
    echo ""
    
    # Miner status
    echo "Miner Status:"
    systemctl is-active kalon-master-miner
    echo ""
    
    # Explorer status
    echo "Explorer Status:"
    systemctl is-active kalon-master-explorer
    echo ""
    
    # Block height
    echo "Block Height:"
    curl -s -X POST http://localhost:16315 \
      -H "Content-Type: application/json" \
      -d '{"jsonrpc":"2.0","method":"getHeight","params":{},"id":1}' 2>/dev/null | grep -o '"result":[0-9]*' | cut -d: -f2 || echo "N/A"
    echo ""
    
    sleep 5
done
EOF

# Make scripts executable
chmod +x /usr/local/bin/kalon-master-*

# Reload systemd
systemctl daemon-reload

# Enable services
systemctl enable kalon-master
systemctl enable kalon-master-miner
systemctl enable kalon-master-explorer

# Create firewall rules
echo -e "${YELLOW}Configuring firewall...${NC}"
if command -v ufw &> /dev/null; then
    ufw allow $RPC_PORT/tcp comment "Kalon RPC"
    ufw allow $P2P_PORT/tcp comment "Kalon P2P"
    ufw allow 3000/tcp comment "Kalon Explorer"
    echo -e "${GREEN}Firewall rules added${NC}"
fi

# Final status
echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}  Master Node Setup Complete!${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo -e "${BLUE}Master Node Configuration:${NC}"
echo "  IP: $MASTER_IP"
echo "  Network: $NETWORK"
echo "  Wallet: $WALLET"
echo "  Threads: $THREADS"
echo "  Data Directory: $DATA_DIR/$DATA_SUBDIR"
echo "  RPC Port: $RPC_PORT"
echo "  P2P Port: $P2P_PORT"
echo ""
echo -e "${YELLOW}Management Commands:${NC}"
echo "  kalon-master-start    - Start all services"
echo "  kalon-master-stop     - Stop all services"
echo "  kalon-master-status   - Check service status"
echo "  kalon-master-logs     - View service logs"
echo "  kalon-master-monitor  - Real-time monitoring"
echo ""
echo -e "${YELLOW}Access Points:${NC}"
echo "  RPC API:    http://$MASTER_IP:$RPC_PORT"
echo "  Explorer:   http://$MASTER_IP:3000"
echo "  P2P Port:   $P2P_PORT"
echo ""
echo -e "${GREEN}To start the master node, run: kalon-master-start${NC}"
echo ""