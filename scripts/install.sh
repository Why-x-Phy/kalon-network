#!/usr/bin/env bash
set -euo pipefail

# Kalon Network Installation Script
# Supports Ubuntu/Debian and Raspberry Pi (ARM64)

VERSION="1.0.0"
ARCH=""
OS=""
INSTALL_DIR="/usr/local/bin"
DATA_DIR="/var/lib/kalon"
CONFIG_DIR="/etc/kalon"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Detect system architecture
detect_arch() {
    local arch=$(uname -m)
    case $arch in
        x86_64)
            ARCH="amd64"
            ;;
        aarch64|arm64)
            ARCH="arm64"
            ;;
        armv7l)
            ARCH="armv7"
            ;;
        *)
            log_error "Unsupported architecture: $arch"
            exit 1
            ;;
    esac
    log_info "Detected architecture: $ARCH"
}

# Detect operating system
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
    else
        log_error "Cannot detect operating system"
        exit 1
    fi
    log_info "Detected OS: $OS"
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_warning "Running as root. This is not recommended for security reasons."
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Install dependencies
install_dependencies() {
    log_info "Installing dependencies..."
    
    case $OS in
        ubuntu|debian)
            sudo apt update
            sudo apt install -y \
                curl \
                wget \
                git \
                build-essential \
                ca-certificates \
                gnupg \
                lsb-release
            ;;
        *)
            log_error "Unsupported operating system: $OS"
            exit 1
            ;;
    esac
    
    log_success "Dependencies installed"
}

# Install Go
install_go() {
    if command -v go &> /dev/null; then
        local go_version=$(go version | cut -d' ' -f3 | cut -d'o' -f2)
        log_info "Go is already installed: $go_version"
        return
    fi
    
    log_info "Installing Go..."
    
    local go_version="1.22.0"
    local go_arch=""
    
    case $ARCH in
        amd64)
            go_arch="amd64"
            ;;
        arm64)
            go_arch="arm64"
            ;;
        armv7)
            go_arch="armv6l"
            ;;
    esac
    
    local go_tarball="go${go_version}.linux-${go_arch}.tar.gz"
    local go_url="https://golang.org/dl/${go_tarball}"
    
    cd /tmp
    wget -q "$go_url"
    sudo tar -C /usr/local -xzf "$go_tarball"
    rm "$go_tarball"
    
    # Add Go to PATH
    echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
    export PATH=$PATH:/usr/local/go/bin
    
    log_success "Go installed"
}

# Download and install Kalon binaries
install_kalon() {
    log_info "Installing Kalon Network..."
    
    # Create directories
    sudo mkdir -p "$INSTALL_DIR"
    sudo mkdir -p "$DATA_DIR"
    sudo mkdir -p "$CONFIG_DIR"
    
    # Set permissions
    sudo chown -R $USER:$USER "$DATA_DIR"
    
    # Build binaries
    log_info "Building Kalon binaries..."
    
    # Set Go environment
    export GOOS=linux
    export GOARCH=$ARCH
    export CGO_ENABLED=0
    
    # Build all binaries
    go build -ldflags="-s -w" -o kalon-node ./cmd/kalon-node
    go build -ldflags="-s -w" -o kalon-wallet ./cmd/kalon-wallet
    go build -ldflags="-s -w" -o kalon-miner ./cmd/kalon-miner
    
    # Install binaries
    sudo mv kalon-node "$INSTALL_DIR/"
    sudo mv kalon-wallet "$INSTALL_DIR/"
    sudo mv kalon-miner "$INSTALL_DIR/"
    
    # Set permissions
    sudo chmod +x "$INSTALL_DIR/kalon-node"
    sudo chmod +x "$INSTALL_DIR/kalon-wallet"
    sudo chmod +x "$INSTALL_DIR/kalon-miner"
    
    # Copy genesis file
    sudo cp genesis/genesis.json "$CONFIG_DIR/"
    
    log_success "Kalon Network installed"
}

# Create systemd service
create_systemd_service() {
    log_info "Creating systemd service..."
    
    cat << EOF | sudo tee /etc/systemd/system/kalon-node.service
[Unit]
Description=Kalon Network Node
After=network.target

[Service]
Type=simple
User=$USER
Group=$USER
WorkingDirectory=$DATA_DIR
ExecStart=$INSTALL_DIR/kalon-node \\
    --rpc :16314 \\
    --p2p :17333 \\
    --datadir $DATA_DIR \\
    --genesis $CONFIG_DIR/genesis.json \\
    --seednodes seed1.kalon.network:17333,seed2.kalon.network:17333
Restart=always
RestartSec=10
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable kalon-node
    
    log_success "Systemd service created"
}

# Create configuration files
create_config() {
    log_info "Creating configuration files..."
    
    # Create node config
    cat << EOF | tee "$DATA_DIR/config.json"
{
  "rpc": {
    "addr": ":16314",
    "cors": ["*"]
  },
  "p2p": {
    "addr": ":17333",
    "seednodes": [
      "seed1.kalon.network:17333",
      "seed2.kalon.network:17333",
      "seed3.kalon.network:17333"
    ]
  },
  "mining": {
    "enabled": false,
    "threads": 2
  },
  "storage": {
    "path": "$DATA_DIR/blockchain"
  }
}
EOF

    log_success "Configuration files created"
}

# Create wallet
create_wallet() {
    log_info "Creating wallet..."
    
    if [[ ! -f "$DATA_DIR/wallet.json" ]]; then
        $INSTALL_DIR/kalon-wallet create --output "$DATA_DIR/wallet.json"
        log_success "Wallet created: $DATA_DIR/wallet.json"
    else
        log_info "Wallet already exists: $DATA_DIR/wallet.json"
    fi
}

# Start services
start_services() {
    log_info "Starting Kalon Node..."
    
    sudo systemctl start kalon-node
    
    # Wait a moment for the service to start
    sleep 3
    
    # Check if service is running
    if sudo systemctl is-active --quiet kalon-node; then
        log_success "Kalon Node started successfully"
    else
        log_error "Failed to start Kalon Node"
        sudo systemctl status kalon-node
        exit 1
    fi
}

# Show status
show_status() {
    log_info "Kalon Network Status:"
    echo
    
    # Service status
    echo "Service Status:"
    sudo systemctl status kalon-node --no-pager
    echo
    
    # Node info
    echo "Node Information:"
    curl -s http://localhost:16314/health | jq . 2>/dev/null || echo "RPC not available"
    echo
    
    # Wallet info
    if [[ -f "$DATA_DIR/wallet.json" ]]; then
        echo "Wallet Information:"
        $INSTALL_DIR/kalon-wallet info --input "$DATA_DIR/wallet.json"
    fi
}

# Show usage instructions
show_usage() {
    log_success "Installation completed!"
    echo
    echo "Usage:"
    echo "  Start node:    sudo systemctl start kalon-node"
    echo "  Stop node:     sudo systemctl stop kalon-node"
    echo "  Restart node:  sudo systemctl restart kalon-node"
    echo "  View logs:     sudo journalctl -u kalon-node -f"
    echo "  Check status:  sudo systemctl status kalon-node"
    echo
    echo "Wallet commands:"
    echo "  Create wallet: $INSTALL_DIR/kalon-wallet create"
    echo "  Check balance: $INSTALL_DIR/kalon-wallet balance"
    echo "  Send funds:    $INSTALL_DIR/kalon-wallet send --to <address> --amount <amount>"
    echo
    echo "Mining commands:"
    echo "  Start mining:  $INSTALL_DIR/kalon-miner --wallet <address> --threads 2"
    echo
    echo "Data directory: $DATA_DIR"
    echo "Config directory: $CONFIG_DIR"
    echo "Logs: sudo journalctl -u kalon-node -f"
}

# Main installation function
main() {
    echo "Kalon Network Installation Script v$VERSION"
    echo "=========================================="
    echo
    
    check_root
    detect_arch
    detect_os
    install_dependencies
    install_go
    install_kalon
    create_systemd_service
    create_config
    create_wallet
    start_services
    show_status
    show_usage
}

# Run main function
main "$@"
