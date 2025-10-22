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
MASTER_IP=${1:-"185.133.249.107"}
NETWORK=${2:-"community-testnet"}
WALLET=${3:-"kalon12slz9pccxhahtm0th9v7n5emm6vtkumx4pykuh"}
THREADS=${4:-4}

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}  Kalon Master Node Setup${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root${NC}"
   echo "Usage: sudo $0 [master_ip] [network] [wallet] [threads]"
   exit 1
fi

echo -e "${BLUE}Master Node Configuration:${NC}"
echo "  IP Address: $MASTER_IP"
echo "  Network: $NETWORK"
echo "  Wallet: $WALLET"
echo "  Threads: $THREADS"
echo ""

# Set data directory based on network
DATA_DIR="/var/lib/kalon/$NETWORK"
GENESIS_FILE="/opt/kalon/genesis/$NETWORK.json"

# Create data directory if it doesn't exist
mkdir -p "$DATA_DIR"
chown kalon:kalon "$DATA_DIR"

# Configure firewall for master node
echo -e "${YELLOW}Configuring firewall for master node...${NC}"
if command -v ufw &> /dev/null; then
    # Allow RPC connections from anywhere
    ufw allow 16315/tcp comment "Kalon RPC (Master)"
    
    # Allow P2P connections from anywhere
    ufw allow 17334/tcp comment "Kalon P2P (Master)"
    
    # Allow explorer access
    ufw allow 3000/tcp comment "Kalon Explorer (Master)"
    
    # Allow SSH (important!)
    ufw allow ssh
    
    echo -e "${GREEN}Firewall configured for master node${NC}"
else
    echo -e "${YELLOW}UFW not found, please configure firewall manually${NC}"
fi

# Create master node configuration
echo -e "${YELLOW}Creating master node configuration...${NC}"

# Node configuration
cat > /etc/kalon/master-node.conf << EOF
# Kalon Master Node Configuration
# Generated on $(date)

[network]
name = "$NETWORK"
rpc_port = 16315
p2p_port = 17334
master_ip = "$MASTER_IP"

[mining]
wallet = "$WALLET"
threads = $THREADS
enabled = true

[data]
directory = "$DATA_DIR"
genesis = "$GENESIS_FILE"

[logging]
level = "info"
file = "/var/log/kalon/master-node.log"
EOF

# Create log directory
mkdir -p /var/log/kalon
chown kalon:kalon /var/log/kalon

# Create systemd service for master node
echo -e "${YELLOW}Creating master node service...${NC}"

cat > /etc/systemd/system/kalon-master.service << EOF
[Unit]
Description=Kalon Network Master Node
After=network.target
Wants=network.target

[Service]
Type=simple
User=kalon
Group=kalon
WorkingDirectory=/opt/kalon
ExecStart=/usr/local/bin/kalon-node \\
    --datadir $DATA_DIR \\
    --genesis $GENESIS_FILE \\
    --rpc :16315 \\
    --p2p :17334 \\
    --mining \\
    --threads $THREADS \\
    --log info
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=kalon-master

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$DATA_DIR /var/log/kalon

[Install]
WantedBy=multi-user.target
EOF

# Create miner service for master node
cat > /etc/systemd/system/kalon-master-miner.service << EOF
[Unit]
Description=Kalon Network Master Miner
After=network.target kalon-master.service
Requires=kalon-master.service

[Service]
Type=simple
User=kalon
Group=kalon
WorkingDirectory=/opt/kalon
ExecStart=/usr/local/bin/kalon-miner \\
    --wallet $WALLET \\
    --threads $THREADS \\
    --rpc http://localhost:16315 \\
    --log info
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=kalon-master-miner

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$DATA_DIR /var/log/kalon

[Install]
WantedBy=multi-user.target
EOF

# Create explorer service for master node
cat > /etc/systemd/system/kalon-master-explorer.service << EOF
[Unit]
Description=Kalon Network Master Explorer
After=network.target kalon-master.service
Requires=kalon-master.service

[Service]
Type=simple
User=kalon
Group=kalon
WorkingDirectory=/opt/kalon/explorer
ExecStart=/usr/bin/node api/main.js
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=kalon-master-explorer

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/opt/kalon/explorer /var/log/kalon

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd
systemctl daemon-reload

# Create management scripts for master node
echo -e "${YELLOW}Creating master node management scripts...${NC}"

cat > /usr/local/bin/kalon-master-start << 'EOF'
#!/bin/bash
echo "Starting Kalon Master Node..."
systemctl start kalon-master
sleep 5
systemctl start kalon-master-miner
systemctl start kalon-master-explorer
echo "Kalon Master Node started!"
echo "RPC: http://$(hostname -I | awk '{print $1}'):16315"
echo "Explorer: http://$(hostname -I | awk '{print $1}'):3000"
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

# Make scripts executable
chmod +x /usr/local/bin/kalon-master-*

# Create monitoring script
cat > /usr/local/bin/kalon-master-monitor << 'EOF'
#!/bin/bash
# Kalon Master Node Monitoring Script

while true; do
    clear
    echo "=========================================="
    echo "  Kalon Master Node Monitor"
    echo "  $(date)"
    echo "=========================================="
    echo ""
    
    # Check services
    echo "Service Status:"
    systemctl is-active kalon-master >/dev/null && echo "  Node:     RUNNING" || echo "  Node:     STOPPED"
    systemctl is-active kalon-master-miner >/dev/null && echo "  Miner:    RUNNING" || echo "  Miner:    STOPPED"
    systemctl is-active kalon-master-explorer >/dev/null && echo "  Explorer: RUNNING" || echo "  Explorer: STOPPED"
    echo ""
    
    # Check RPC
    if curl -s http://localhost:16315 >/dev/null 2>&1; then
        echo "RPC Status: ONLINE"
    else
        echo "RPC Status: OFFLINE"
    fi
    echo ""
    
    # Check disk space
    echo "Disk Usage:"
    df -h /var/lib/kalon | tail -1
    echo ""
    
    # Check memory usage
    echo "Memory Usage:"
    free -h | grep Mem
    echo ""
    
    # Check recent logs
    echo "Recent Logs (last 5 lines):"
    journalctl -u kalon-master --no-pager -n 5 | tail -5
    echo ""
    
    echo "Press Ctrl+C to exit"
    sleep 10
done
EOF

chmod +x /usr/local/bin/kalon-master-monitor

# Create backup script
cat > /usr/local/bin/kalon-master-backup << 'EOF'
#!/bin/bash
# Kalon Master Node Backup Script

BACKUP_DIR="/var/backups/kalon"
DATE=$(date +%Y%m%d_%H%M%S)
NETWORK=${1:-"community-testnet"}

echo "Creating backup for $NETWORK..."

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Stop services
echo "Stopping services..."
systemctl stop kalon-master-explorer
systemctl stop kalon-master-miner
systemctl stop kalon-master

# Create backup
echo "Creating backup..."
tar -czf "$BACKUP_DIR/kalon_${NETWORK}_${DATE}.tar.gz" \
    -C /var/lib/kalon "$NETWORK" \
    -C /opt/kalon genesis scripts

# Start services
echo "Starting services..."
systemctl start kalon-master
sleep 5
systemctl start kalon-master-miner
systemctl start kalon-master-explorer

echo "Backup created: $BACKUP_DIR/kalon_${NETWORK}_${DATE}.tar.gz"
EOF

chmod +x /usr/local/bin/kalon-master-backup

# Create update script
cat > /usr/local/bin/kalon-master-update << 'EOF'
#!/bin/bash
# Kalon Master Node Update Script

echo "Updating Kalon Master Node..."

# Stop services
echo "Stopping services..."
systemctl stop kalon-master-explorer
systemctl stop kalon-master-miner
systemctl stop kalon-master

# Update from repository
echo "Updating from repository..."
cd /tmp
rm -rf kalon-network
git clone https://github.com/Why-x-Phy/kalon-network.git
cd kalon-network

# Build new binaries
echo "Building new binaries..."
export PATH=$PATH:/usr/local/go/bin
make build

# Install new binaries
echo "Installing new binaries..."
cp build/kalon-node /usr/local/bin/
cp build/kalon-miner /usr/local/bin/
cp build/kalon-wallet /usr/local/bin/

# Update configuration files
echo "Updating configuration files..."
cp -r genesis /opt/kalon/
cp -r scripts /opt/kalon/

# Set permissions
chown -R kalon:kalon /opt/kalon
chmod +x /usr/local/bin/kalon-*

# Start services
echo "Starting services..."
systemctl start kalon-master
sleep 5
systemctl start kalon-master-miner
systemctl start kalon-master-explorer

echo "Update complete!"
EOF

chmod +x /usr/local/bin/kalon-master-update

# Final status
echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}  Master Node Setup Complete!${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo -e "${BLUE}Master Node Information:${NC}"
echo "  IP Address: $MASTER_IP"
echo "  Network: $NETWORK"
echo "  Wallet: $WALLET"
echo "  Threads: $THREADS"
echo ""
echo -e "${BLUE}Access Points:${NC}"
echo "  RPC API:    http://$MASTER_IP:16315"
echo "  Explorer:   http://$MASTER_IP:3000"
echo "  P2P Port:   17334"
echo ""
echo -e "${YELLOW}Management Commands:${NC}"
echo "  kalon-master-start    - Start master node"
echo "  kalon-master-stop     - Stop master node"
echo "  kalon-master-status   - Check status"
echo "  kalon-master-logs     - View logs"
echo "  kalon-master-monitor  - Monitor in real-time"
echo "  kalon-master-backup   - Create backup"
echo "  kalon-master-update   - Update from repository"
echo ""
echo -e "${GREEN}To start the master node, run: kalon-master-start${NC}"
echo ""
