# Kalon Network - Administrator's Guide

This guide is for system administrators who want to set up and maintain a Kalon Network master node or production infrastructure.

## Table of Contents

1. [Initial Setup](#initial-setup)
2. [Building from Source](#building-from-source)
3. [Configuration](#configuration)
4. [System Service Setup](#system-service-setup)
5. [Updates](#updates)
6. [Monitoring](#monitoring)
7. [Backup & Recovery](#backup--recovery)
8. [Troubleshooting](#troubleshooting)

## Initial Setup

### Requirements

- **OS**: Ubuntu 20.04 LTS / 22.04 LTS
- **RAM**: 4GB minimum (8GB+ recommended for production)
- **Storage**: 50GB+ SSD
- **CPU**: 2+ cores (4+ cores for production)
- **Network**: Stable connection with ports 16316 (RPC) and 17335 (P2P) open
- **Go**: Version 1.21 or later

### Installing Dependencies

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Go
wget https://go.dev/dl/go1.21.5.linux-amd64.tar.gz
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf go1.21.5.linux-amd64.tar.gz
export PATH=$PATH:/usr/local/go/bin
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc

# Install build tools
sudo apt install -y git make jq curl

# Verify
go version
```

### Repository Setup

```bash
# Clone repository
git clone https://github.com/Why-x-Phy/kalon-network.git
cd kalon-network

# Verify integrity
git remote -v
```

## Building from Source

### Build All Components

```bash
# Build everything
make build

# Or manually:
go build -o build-v2/kalon-node-v2 cmd/kalon-node-v2/main.go
go build -o build-v2/kalon-miner-v2 cmd/kalon-miner-v2/main.go
go build -o build-v2/kalon-wallet cmd/kalon-wallet/main.go
go build -o build-v2/explorer-api explorer/api/main.go

# Verify binaries
ls -lh build-v2/
```

### Build for Production

```bash
# Clean build for production
go clean -cache
go build -tags production -o build-v2/kalon-node-v2 cmd/kalon-node-v2/main.go
go build -tags production -o build-v2/kalon-miner-v2 cmd/kalon-miner-v2/main.go
```

## Configuration

### Network Types

Choose your network configuration:

#### Testnet (Development)

```bash
GENESIS=genesis/testnet.json
DATA_DIR=data-v2/testnet
```

#### Mainnet (Production)

```bash
GENESIS=genesis/mainnet.json
DATA_DIR=data-v2/mainnet
```

#### Community Testnet

```bash
GENESIS=genesis/community-testnet.json
DATA_DIR=data-v2/community-testnet
```

### Create Environment File

Create `/etc/kalon/env.sh`:

```bash
# Network Configuration
export KALON_NETWORK="testnet"
export KALON_DATA_DIR="/var/lib/kalon/data"
export KALON_GENESIS="/opt/kalon/genesis/testnet.json"

# RPC Configuration
export KALON_RPC_HOST="0.0.0.0"
export KALON_RPC_PORT="16316"

# P2P Configuration
export KALON_P2P_PORT="17335"

# Mining Configuration
export KALON_MINER_THREADS="4"
export KALON_MINER_ADDRESS=""
```

## System Service Setup

### Create Systemd Service

Create `/etc/systemd/system/kalon-node.service`:

```ini
[Unit]
Description=Kalon Network Node
After=network.target

[Service]
Type=simple
User=kalon
Group=kalon
WorkingDirectory=/opt/kalon
ExecStart=/opt/kalon/build-v2/kalon-node-v2 \
  -datadir /var/lib/kalon/data/testnet \
  -genesis /opt/kalon/genesis/testnet.json \
  -rpc :16316 \
  -p2p :17335
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

### Create Mining Service

Create `/etc/systemd/system/kalon-miner.service`:

```ini
[Unit]
Description=Kalon Network Miner
After=network.target kalon-node.service
Requires=kalon-node.service

[Service]
Type=simple
User=kalon
Group=kalon
WorkingDirectory=/opt/kalon
EnvironmentFile=-/etc/kalon/wallet.env
ExecStart=/opt/kalon/build-v2/kalon-miner-v2 \
  -wallet ${KALON_MINER_ADDRESS} \
  -threads 4 \
  -rpc http://localhost:16316
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

### Enable and Start Services

```bash
# Reload systemd
sudo systemctl daemon-reload

# Enable services
sudo systemctl enable kalon-node
sudo systemctl enable kalon-miner

# Start services
sudo systemctl start kalon-node
sudo systemctl start kalon-miner

# Check status
sudo systemctl status kalon-node
sudo systemctl status kalon-miner
```

## Updates

### Check Current Version

```bash
git rev-parse HEAD
```

### Update Procedure

```bash
cd /opt/kalon

# Backup current installation
sudo tar -czf /backup/kalon-backup-$(date +%Y%m%d).tar.gz \
  build-v2/ \
  data-v2/ \
  *.json

# Pull latest changes
git fetch origin
git pull origin master

# Rebuild binaries
make clean
make build

# Restart services
sudo systemctl restart kalon-node
sudo systemctl restart kalon-miner

# Verify
sudo systemctl status kalon-node
sudo systemctl status kalon-miner
```

### Rolling Back

```bash
# Find previous commit
git log --oneline

# Rollback to specific commit
git checkout <commit-hash>
make build

# Restart services
sudo systemctl restart kalon-node
sudo systemctl restart kalon-miner
```

## Monitoring

### Check Node Status

```bash
# Service status
sudo systemctl status kalon-node kalon-miner

# Process status
ps aux | grep kalon

# Check RPC
curl http://localhost:16316/rpc \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"getHeight","id":1}'
```

### View Logs

```bash
# Node logs
sudo journalctl -u kalon-node -f

# Miner logs
sudo journalctl -u kalon-miner -f

# Both services
sudo journalctl -u kalon-node -u kalon-miner -f

# Last 100 lines
sudo journalctl -u kalon-node -n 100
```

### Check Resources

```bash
# Disk usage
df -h /var/lib/kalon
du -sh /var/lib/kalon/data/*

# Memory usage
free -h

# CPU usage
top -p $(pgrep kalon-node)
```

### Monitor Chain Health

```bash
# Get current height
curl http://localhost:16316/rpc \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"getHeight","id":1}' | jq .

# Get best block
curl http://localhost:16316/rpc \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"getBestBlock","id":1}' | jq .

# Check wallet balance
curl http://localhost:16316/rpc \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"getBalance","params":{"address":"YOUR_ADDRESS"},"id":1}' | jq .
```

## Backup & Recovery

### Backup Strategy

```bash
# Automated backup script
cat > /usr/local/bin/kalon-backup.sh << 'EOF'
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/backup/kalon"
mkdir -p $BACKUP_DIR

# Backup blockchain data
tar -czf $BACKUP_DIR/blockchain-$DATE.tar.gz data-v2/

# Backup wallets
tar -czf $BACKUP_DIR/wallets-$DATE.tar.gz wallet-*.json

# Backup configuration
cp /etc/kalon/* $BACKUP_DIR/config-$DATE/

echo "Backup completed: $DATE"
EOF

chmod +x /usr/local/bin/kalon-backup.sh

# Add to crontab (daily at 2 AM)
(crontab -l 2>/dev/null; echo "0 2 * * * /usr/local/bin/kalon-backup.sh") | crontab -
```

### Recovery Procedure

```bash
# Stop services
sudo systemctl stop kalon-miner kalon-node

# Extract backup
tar -xzf /backup/kalon/blockchain-20250101.tar.gz
tar -xzf /backup/kalon/wallets-20250101.tar.gz

# Restart services
sudo systemctl start kalon-node
sudo systemctl start kalon-miner
```

## Troubleshooting

### Node Won't Start

```bash
# Check logs
sudo journalctl -u kalon-node -n 50

# Check permissions
ls -la /var/lib/kalon

# Check disk space
df -h

# Verify binary
file /opt/kalon/build-v2/kalon-node-v2
```

### High Memory Usage

```bash
# Check memory leaks
ps aux | grep kalon

# Restart services
sudo systemctl restart kalon-node kalon-miner
```

### Low Mining Performance

```bash
# Check miner threads
cat /etc/kalon/wallet.env

# Adjust threads
sudo systemctl edit kalon-miner
# Add: Environment="KALON_MINER_THREADS=8"
sudo systemctl restart kalon-miner
```

### Port Conflicts

```bash
# Check if ports are in use
sudo netstat -tulpn | grep -E '16316|17335'
sudo lsof -i :16316
sudo lsof -i :17335

# Kill conflicting process
sudo kill <PID>
```

### Database Corruption

```bash
# Stop node
sudo systemctl stop kalon-node kalon-miner

# Backup current data
cp -r /var/lib/kalon/data /var/lib/kalon/data.backup

# Remove corrupted data
rm -rf /var/lib/kalon/data/testnet/LOCK
rm -rf /var/lib/kalon/data/testnet/CURRENT

# Restart node (will resync)
sudo systemctl start kalon-node
```

## Security

### Firewall Configuration

```bash
# Allow RPC (local only)
sudo ufw allow from 127.0.0.1 to any port 16316 proto tcp

# Allow P2P (network)
sudo ufw allow 17335/tcp

# Deny RPC from external
sudo ufw deny 16316/tcp
```

### Secure Wallet Storage

```bash
# Set proper permissions
chmod 600 wallet-*.json

# Encrypt wallet files
gpg -c wallet-miner.json

# Store encrypted backup
cp wallet-*.json.gpg /secure/backup/
```

## Performance Tuning

### System Limits

```bash
# Increase file descriptors
echo "* soft nofile 65536" | sudo tee -a /etc/security/limits.conf
echo "* hard nofile 65536" | sudo tee -a /etc/security/limits.conf
```

### Kernel Parameters

```bash
# Add to /etc/sysctl.conf
net.core.somaxconn = 1024
net.ipv4.tcp_max_syn_backlog = 4096
net.core.netdev_max_backlog = 5000
```

## Production Checklist

- [ ] System dependencies installed
- [ ] Go 1.21+ installed and configured
- [ ] Repository cloned and verified
- [ ] Binaries built successfully
- [ ] Systemd services created
- [ ] Services enabled and running
- [ ] Firewall configured
- [ ] Backup strategy in place
- [ ] Monitoring setup
- [ ] Log rotation configured
- [ ] Security permissions set
- [ ] Network connectivity tested
- [ ] Wallet created and secured
- [ ] Mining configured
- [ ] Documentation reviewed

