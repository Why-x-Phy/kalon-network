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
MASTER_IP=${1:-"185.133.249.107"}
NETWORK=${2:-"community-testnet"}
WALLET=${3:-""}
THREADS=${4:-2}

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}  Kalon Slave Node Setup${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root${NC}"
   echo "Usage: sudo $0 [master_ip] [network] [wallet] [threads]"
   exit 1
fi

# Generate wallet if not provided
if [ -z "$WALLET" ]; then
    echo -e "${YELLOW}Generating new wallet...${NC}"
    WALLET=$(kalon-wallet create | grep "Address:" | awk '{print $2}')
    if [ -z "$WALLET" ]; then
        echo -e "${RED}Failed to generate wallet${NC}"
        exit 1
    fi
    echo -e "${GREEN}Generated wallet: $WALLET${NC}"
fi

echo -e "${BLUE}Slave Node Configuration:${NC}"
echo "  Master IP: $MASTER_IP"
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

# Configure firewall for slave node
echo -e "${YELLOW}Configuring firewall for slave node...${NC}"
if command -v ufw &> /dev/null; then
    # Allow RPC connections from master only
    ufw allow from $MASTER_IP to any port 16315 comment "Kalon RPC (Master)"
    
    # Allow P2P connections from master only
    ufw allow from $MASTER_IP to any port 17334 comment "Kalon P2P (Master)"
    
    # Allow local RPC access
    ufw allow from 127.0.0.1 to any port 16315 comment "Kalon RPC (Local)"
    
    # Allow local P2P access
    ufw allow from 127.0.0.1 to any port 17334 comment "Kalon P2P (Local)"
    
    # Allow SSH (important!)
    ufw allow ssh
    
    echo -e "${GREEN}Firewall configured for slave node${NC}"
else
    echo -e "${YELLOW}UFW not found, please configure firewall manually${NC}"
fi

# Create slave node configuration
echo -e "${YELLOW}Creating slave node configuration...${NC}"

cat > /etc/kalon/slave-node.conf << EOF
# Kalon Slave Node Configuration
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
file = "/var/log/kalon/slave-node.log"
EOF

# Create log directory
mkdir -p /var/log/kalon
chown kalon:kalon /var/log/kalon

# Create systemd service for slave node
echo -e "${YELLOW}Creating slave node service...${NC}"

cat > /etc/systemd/system/kalon-slave.service << EOF
[Unit]
Description=Kalon Network Slave Node
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
    --log info
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=kalon-slave

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$DATA_DIR /var/log/kalon

[Install]
WantedBy=multi-user.target
EOF

# Create miner service for slave node
cat > /etc/systemd/system/kalon-slave-miner.service << EOF
[Unit]
Description=Kalon Network Slave Miner
After=network.target kalon-slave.service
Requires=kalon-slave.service

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
SyslogIdentifier=kalon-slave-miner

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$DATA_DIR /var/log/kalon

[Install]
WantedBy=multi-user.target
EOF

# Create sync service for slave node
cat > /etc/systemd/system/kalon-slave-sync.service << EOF
[Unit]
Description=Kalon Network Slave Sync
After=network.target kalon-slave.service
Requires=kalon-slave.service

[Service]
Type=simple
User=kalon
Group=kalon
WorkingDirectory=/opt/kalon
ExecStart=/usr/local/bin/kalon-sync \\
    --master $MASTER_IP:16315 \\
    --local localhost:16315 \\
    --interval 30s
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=kalon-slave-sync

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$DATA_DIR /var/log/kalon

[Install]
WantedBy=multi-user.target
EOF

# Create sync script
cat > /usr/local/bin/kalon-sync << 'EOF'
#!/bin/bash
# Kalon Network Sync Script

MASTER_IP=${1:-"185.133.249.107"}
MASTER_PORT=${2:-16315}
LOCAL_IP=${3:-"localhost"}
LOCAL_PORT=${4:-16315}
SYNC_INTERVAL=${5:-30}

MASTER_URL="http://$MASTER_IP:$MASTER_PORT"
LOCAL_URL="http://$LOCAL_IP:$LOCAL_PORT"

echo "Starting Kalon Sync..."
echo "Master: $MASTER_URL"
echo "Local: $LOCAL_URL"
echo "Interval: ${SYNC_INTERVAL}s"
echo ""

while true; do
    # Get master block height
    MASTER_HEIGHT=$(curl -s "$MASTER_URL" -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getHeight","params":{},"id":1}' | jq -r '.result // 0' 2>/dev/null || echo "0")
    
    # Get local block height
    LOCAL_HEIGHT=$(curl -s "$LOCAL_URL" -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getHeight","params":{},"id":1}' | jq -r '.result // 0' 2>/dev/null || echo "0")
    
    if [ "$MASTER_HEIGHT" -gt "$LOCAL_HEIGHT" ]; then
        echo "$(date): Syncing... Master: $MASTER_HEIGHT, Local: $LOCAL_HEIGHT"
        
        # Get blocks from master
        for ((i=$LOCAL_HEIGHT+1; i<=$MASTER_HEIGHT; i++)); do
            BLOCK=$(curl -s "$MASTER_URL" -H "Content-Type: application/json" -d "{\"jsonrpc\":\"2.0\",\"method\":\"getBlockByNumber\",\"params\":{\"number\":$i},\"id\":1}" | jq -r '.result' 2>/dev/null)
            
            if [ "$BLOCK" != "null" ] && [ "$BLOCK" != "" ]; then
                # Submit block to local node
                curl -s "$LOCAL_URL" -H "Content-Type: application/json" -d "{\"jsonrpc\":\"2.0\",\"method\":\"submitBlock\",\"params\":{\"block\":$BLOCK},\"id\":1}" >/dev/null
                echo "  Synced block $i"
            fi
        done
        
        echo "  Sync complete! Local height: $LOCAL_HEIGHT -> $MASTER_HEIGHT"
    else
        echo "$(date): In sync. Master: $MASTER_HEIGHT, Local: $LOCAL_HEIGHT"
    fi
    
    sleep $SYNC_INTERVAL
done
EOF

chmod +x /usr/local/bin/kalon-sync

# Reload systemd
systemctl daemon-reload

# Create management scripts for slave node
echo -e "${YELLOW}Creating slave node management scripts...${NC}"

cat > /usr/local/bin/kalon-slave-start << 'EOF'
#!/bin/bash
echo "Starting Kalon Slave Node..."
systemctl start kalon-slave
sleep 5
systemctl start kalon-slave-miner
systemctl start kalon-slave-sync
echo "Kalon Slave Node started!"
echo "RPC: http://localhost:16315"
echo "Syncing with master node..."
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

# Make scripts executable
chmod +x /usr/local/bin/kalon-slave-*

# Create monitoring script
cat > /usr/local/bin/kalon-slave-monitor << 'EOF'
#!/bin/bash
# Kalon Slave Node Monitoring Script

MASTER_IP=${1:-"185.133.249.107"}
MASTER_URL="http://$MASTER_IP:16315"
LOCAL_URL="http://localhost:16315"

while true; do
    clear
    echo "=========================================="
    echo "  Kalon Slave Node Monitor"
    echo "  $(date)"
    echo "=========================================="
    echo ""
    
    # Check services
    echo "Service Status:"
    systemctl is-active kalon-slave >/dev/null && echo "  Node:     RUNNING" || echo "  Node:     STOPPED"
    systemctl is-active kalon-slave-miner >/dev/null && echo "  Miner:    RUNNING" || echo "  Miner:    STOPPED"
    systemctl is-active kalon-slave-sync >/dev/null && echo "  Sync:     RUNNING" || echo "  Sync:     STOPPED"
    echo ""
    
    # Check RPC
    if curl -s $LOCAL_URL >/dev/null 2>&1; then
        echo "Local RPC:  ONLINE"
    else
        echo "Local RPC:  OFFLINE"
    fi
    
    if curl -s $MASTER_URL >/dev/null 2>&1; then
        echo "Master RPC: ONLINE"
    else
        echo "Master RPC: OFFLINE"
    fi
    echo ""
    
    # Check sync status
    MASTER_HEIGHT=$(curl -s "$MASTER_URL" -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getHeight","params":{},"id":1}' | jq -r '.result // 0' 2>/dev/null || echo "0")
    LOCAL_HEIGHT=$(curl -s "$LOCAL_URL" -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getHeight","params":{},"id":1}' | jq -r '.result // 0' 2>/dev/null || echo "0")
    
    echo "Sync Status:"
    echo "  Master Height: $MASTER_HEIGHT"
    echo "  Local Height:  $LOCAL_HEIGHT"
    
    if [ "$MASTER_HEIGHT" -eq "$LOCAL_HEIGHT" ]; then
        echo "  Status:        IN SYNC"
    else
        echo "  Status:        SYNCING"
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
    journalctl -u kalon-slave --no-pager -n 5 | tail -5
    echo ""
    
    echo "Press Ctrl+C to exit"
    sleep 10
done
EOF

chmod +x /usr/local/bin/kalon-slave-monitor

# Final status
echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}  Slave Node Setup Complete!${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo -e "${BLUE}Slave Node Information:${NC}"
echo "  Master IP: $MASTER_IP"
echo "  Network: $NETWORK"
echo "  Wallet: $WALLET"
echo "  Threads: $THREADS"
echo ""
echo -e "${BLUE}Access Points:${NC}"
echo "  Local RPC:  http://localhost:16315"
echo "  P2P Port:   17334"
echo ""
echo -e "${YELLOW}Management Commands:${NC}"
echo "  kalon-slave-start    - Start slave node"
echo "  kalon-slave-stop     - Stop slave node"
echo "  kalon-slave-status   - Check status"
echo "  kalon-slave-logs     - View logs"
echo "  kalon-slave-monitor  - Monitor in real-time"
echo ""
echo -e "${GREEN}To start the slave node, run: kalon-slave-start${NC}"
echo ""
