#!/bin/bash

# Kalon Network Explorer Installation Script
# Version: 1.0.2

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}  Kalon Explorer Installer${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root${NC}"
   echo "Usage: sudo $0"
   exit 1
fi

# Configuration
INSTALL_DIR="/opt/kalon"
SERVICE_USER="kalon"

# Check if Kalon is installed
if [ ! -d "$INSTALL_DIR" ]; then
    echo -e "${RED}Kalon Network not found. Please install it first with install-ubuntu-simple.sh${NC}"
    exit 1
fi

# Install Node.js for explorer
echo -e "${YELLOW}Installing Node.js...${NC}"
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    apt install -y nodejs
else
    echo -e "${GREEN}Node.js is already installed${NC}"
fi

# Copy explorer files
echo -e "${YELLOW}Installing explorer files...${NC}"
cd /tmp
if [ -d "kalon-network" ]; then
    rm -rf "kalon-network"
fi

git clone https://github.com/Why-x-Phy/kalon-network.git
cd kalon-network

# Copy explorer
cp -r explorer "$INSTALL_DIR/"

# Install explorer UI dependencies
echo -e "${YELLOW}Installing explorer UI dependencies...${NC}"
cd "$INSTALL_DIR/explorer/ui"
sudo -u "$SERVICE_USER" npm install

# Build explorer API
echo -e "${YELLOW}Building explorer API...${NC}"
cd "$INSTALL_DIR/explorer/api"
export PATH=$PATH:/usr/local/go/bin
go mod tidy
go build -o main main.go
chown "$SERVICE_USER:$SERVICE_USER" main

# Create explorer service
echo -e "${YELLOW}Creating explorer service...${NC}"
cat > /etc/systemd/system/kalon-explorer.service << EOF
[Unit]
Description=Kalon Network Explorer
After=network.target kalon-node.service
Requires=kalon-node.service

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

# Update management scripts
echo -e "${YELLOW}Updating management scripts...${NC}"

# Update kalon-start
cat > /usr/local/bin/kalon-start << 'EOF'
#!/bin/bash
echo "Starting Kalon Network..."
systemctl start kalon-node
sleep 5
systemctl start kalon-miner
systemctl start kalon-explorer
echo "Kalon Network started!"
echo "Node: http://localhost:16315"
echo "Explorer: http://localhost:3000"
EOF

# Update kalon-stop
cat > /usr/local/bin/kalon-stop << 'EOF'
#!/bin/bash
echo "Stopping Kalon Network..."
systemctl stop kalon-explorer
systemctl stop kalon-miner
systemctl stop kalon-node
echo "Kalon Network stopped!"
EOF

# Update kalon-status
cat > /usr/local/bin/kalon-status << 'EOF'
#!/bin/bash
echo "Kalon Network Status:"
echo "====================="
systemctl status kalon-node --no-pager
echo ""
systemctl status kalon-miner --no-pager
echo ""
systemctl status kalon-explorer --no-pager
EOF

# Update kalon-logs
cat > /usr/local/bin/kalon-logs << 'EOF'
#!/bin/bash
if [ "$1" = "node" ]; then
    journalctl -u kalon-node -f
elif [ "$1" = "miner" ]; then
    journalctl -u kalon-miner -f
elif [ "$1" = "explorer" ]; then
    journalctl -u kalon-explorer -f
else
    echo "Usage: kalon-logs [node|miner|explorer]"
fi
EOF

# Make scripts executable
chmod +x /usr/local/bin/kalon-*

# Reload systemd
systemctl daemon-reload

# Enable explorer service
systemctl enable kalon-explorer

# Create firewall rules
echo -e "${YELLOW}Configuring firewall...${NC}"
if command -v ufw &> /dev/null; then
    ufw allow 3000/tcp comment "Kalon Explorer"
    echo -e "${GREEN}Firewall rules added${NC}"
fi

# Cleanup
rm -rf /tmp/kalon-network

# Final status
echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}  Explorer Installation Complete!${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo -e "${BLUE}Explorer has been installed successfully!${NC}"
echo ""
echo -e "${YELLOW}Access Points:${NC}"
echo "  RPC API:    http://localhost:16315"
echo "  Explorer:   http://localhost:3000"
echo "  P2P Port:   17334"
echo ""
echo -e "${YELLOW}Management Commands:${NC}"
echo "  kalon-start    - Start all services (including explorer)"
echo "  kalon-stop     - Stop all services"
echo "  kalon-status   - Check service status"
echo "  kalon-logs     - View service logs"
echo ""
echo -e "${GREEN}To start the network with explorer, run: kalon-start${NC}"
echo ""
