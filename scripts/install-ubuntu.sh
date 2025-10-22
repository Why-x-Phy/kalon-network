#!/bin/bash

# Kalon Network Installation Script for Ubuntu
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
echo -e "${BLUE}  Kalon Network v${KALON_VERSION} Installer${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root${NC}"
   echo "Usage: sudo $0"
   exit 1
fi

# Update system packages
echo -e "${YELLOW}Updating system packages...${NC}"
apt update && apt upgrade -y

# Install required dependencies
echo -e "${YELLOW}Installing dependencies...${NC}"
apt install -y \
    wget \
    curl \
    git \
    build-essential \
    software-properties-common \
    ca-certificates \
    gnupg \
    lsb-release

# Install Go
echo -e "${YELLOW}Installing Go...${NC}"
GO_VERSION="1.21.5"
GO_ARCH="linux-amd64"

if ! command -v go &> /dev/null; then
    cd /tmp
    wget "https://golang.org/dl/go${GO_VERSION}.${GO_ARCH}.tar.gz"
    tar -C /usr/local -xzf "go${GO_VERSION}.${GO_ARCH}.tar.gz"
    rm "go${GO_VERSION}.${GO_ARCH}.tar.gz"
    
    # Add Go to PATH
    echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile
    echo 'export PATH=$PATH:/usr/local/go/bin' >> /root/.bashrc
    export PATH=$PATH:/usr/local/go/bin
else
    echo -e "${GREEN}Go is already installed${NC}"
fi

# Create kalon user
echo -e "${YELLOW}Creating kalon user...${NC}"
if ! id "$SERVICE_USER" &>/dev/null; then
    useradd -r -s /bin/false -d "$DATA_DIR" -m "$SERVICE_USER"
    echo -e "${GREEN}Created user: $SERVICE_USER${NC}"
else
    echo -e "${GREEN}User $SERVICE_USER already exists${NC}"
fi

# Create directories
echo -e "${YELLOW}Creating directories...${NC}"
mkdir -p "$INSTALL_DIR"
mkdir -p "$DATA_DIR"
mkdir -p "$DATA_DIR/community-testnet"
mkdir -p "$DATA_DIR/testnet"
mkdir -p "$DATA_DIR/mainnet"
mkdir -p "/etc/kalon"

# Set permissions
chown -R "$SERVICE_USER:$SERVICE_USER" "$DATA_DIR"
chmod 755 "$DATA_DIR"

# Clone or update repository
echo -e "${YELLOW}Setting up Kalon Network...${NC}"
if [ -d "/tmp/kalon-network" ]; then
    rm -rf "/tmp/kalon-network"
fi

cd /tmp
git clone https://github.com/Why-x-Phy/kalon-network.git
cd kalon-network

# Build binaries
echo -e "${YELLOW}Building Kalon Network binaries...${NC}"
export PATH=$PATH:/usr/local/go/bin
make build

# Install binaries
echo -e "${YELLOW}Installing binaries...${NC}"
cp build/kalon-node "$BIN_DIR/"
cp build/kalon-miner "$BIN_DIR/"
cp build/kalon-wallet "$BIN_DIR/"

# Copy configuration files
echo -e "${YELLOW}Installing configuration files...${NC}"
cp -r genesis "$INSTALL_DIR/"
cp -r scripts "$INSTALL_DIR/"
cp -r explorer "$INSTALL_DIR/"

# Set permissions
chown -R "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR"
chmod +x "$BIN_DIR/kalon-"*

# Create systemd service files
echo -e "${YELLOW}Creating systemd services...${NC}"

# Node service
cat > /etc/systemd/system/kalon-node.service << EOF
[Unit]
Description=Kalon Network Node
After=network.target

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_USER
WorkingDirectory=$INSTALL_DIR
ExecStart=$BIN_DIR/kalon-node --datadir $DATA_DIR/community-testnet --genesis $INSTALL_DIR/genesis/community-testnet.json --rpc :16315 --p2p :17334
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Miner service
cat > /etc/systemd/system/kalon-miner.service << EOF
[Unit]
Description=Kalon Network Miner
After=network.target kalon-node.service
Requires=kalon-node.service

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_USER
WorkingDirectory=$INSTALL_DIR
ExecStart=$BIN_DIR/kalon-miner --wallet kalon12slz9pccxhahtm0th9v7n5emm6vtkumx4pykuh --threads 2 --rpc http://localhost:16315
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Explorer service
cat > /etc/systemd/system/kalon-explorer.service << EOF
[Unit]
Description=Kalon Network Explorer
After=network.target kalon-node.service
Requires=kalon-node.service

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_USER
WorkingDirectory=$INSTALL_DIR/explorer
ExecStart=/usr/bin/node api/main.js
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Install Node.js for explorer (if not already installed)
if ! command -v node &> /dev/null; then
    echo -e "${YELLOW}Installing Node.js...${NC}"
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    apt install -y nodejs
fi

# Install explorer dependencies
if [ -d "$INSTALL_DIR/explorer" ]; then
    echo -e "${YELLOW}Installing explorer dependencies...${NC}"
    cd "$INSTALL_DIR/explorer"
    npm install
fi

# Reload systemd
systemctl daemon-reload

# Create management scripts
echo -e "${YELLOW}Creating management scripts...${NC}"

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

cat > /usr/local/bin/kalon-stop << 'EOF'
#!/bin/bash
echo "Stopping Kalon Network..."
systemctl stop kalon-explorer
systemctl stop kalon-miner
systemctl stop kalon-node
echo "Kalon Network stopped!"
EOF

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

# Create firewall rules
echo -e "${YELLOW}Configuring firewall...${NC}"
if command -v ufw &> /dev/null; then
    ufw allow 16315/tcp comment "Kalon RPC"
    ufw allow 17334/tcp comment "Kalon P2P"
    ufw allow 3000/tcp comment "Kalon Explorer"
    echo -e "${GREEN}Firewall rules added${NC}"
fi

# Cleanup
echo -e "${YELLOW}Cleaning up...${NC}"
rm -rf /tmp/kalon-network

# Final status
echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}  Installation Complete!${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo -e "${BLUE}Kalon Network v${KALON_VERSION} has been installed successfully!${NC}"
echo ""
echo -e "${YELLOW}Management Commands:${NC}"
echo "  kalon-start    - Start all services"
echo "  kalon-stop     - Stop all services"
echo "  kalon-status   - Check service status"
echo "  kalon-logs     - View service logs"
echo ""
echo -e "${YELLOW}Service Management:${NC}"
echo "  systemctl start kalon-node     - Start node only"
echo "  systemctl start kalon-miner    - Start miner only"
echo "  systemctl start kalon-explorer - Start explorer only"
echo ""
echo -e "${YELLOW}Access Points:${NC}"
echo "  RPC API:    http://localhost:16315"
echo "  Explorer:   http://localhost:3000"
echo "  P2P Port:   17334"
echo ""
echo -e "${YELLOW}Data Directory:${NC}"
echo "  $DATA_DIR"
echo ""
echo -e "${GREEN}To start the network, run: kalon-start${NC}"
echo ""
