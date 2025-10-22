# Kalon Network Ubuntu Installation Guide

## Version 1.0.2

This guide will help you install and configure the Kalon Network on Ubuntu Server.

## Prerequisites

- Ubuntu 20.04 LTS or newer
- Root access (sudo)
- Internet connection
- At least 2GB RAM
- At least 10GB free disk space

## Quick Installation

### 1. Master Node Setup

For the master node (185.133.249.107):

```bash
# Download and run the installation script
wget https://raw.githubusercontent.com/Why-x-Phy/kalon-network/master/scripts/install-ubuntu.sh
chmod +x install-ubuntu.sh
sudo ./install-ubuntu.sh

# Setup as master node
sudo ./scripts/setup-master-node.sh 185.133.249.107 community-testnet kalon12slz9pccxhahtm0th9v7n5emm6vtkumx4pykuh 4

# Start the master node
sudo kalon-master-start
```

### 2. Slave Node Setup

For slave nodes:

```bash
# Download and run the installation script
wget https://raw.githubusercontent.com/Why-x-Phy/kalon-network/master/scripts/install-ubuntu.sh
chmod +x install-ubuntu.sh
sudo ./install-ubuntu.sh

# Setup as slave node
sudo ./scripts/setup-slave-node.sh 185.133.249.107 community-testnet

# Start the slave node
sudo kalon-slave-start
```

## Manual Installation

### 1. System Preparation

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install dependencies
sudo apt install -y wget curl git build-essential software-properties-common ca-certificates gnupg lsb-release

# Install Go
cd /tmp
wget https://golang.org/dl/go1.21.5.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.21.5.linux-amd64.tar.gz
echo 'export PATH=$PATH:/usr/local/go/bin' | sudo tee -a /etc/profile
export PATH=$PATH:/usr/local/go/bin
```

### 2. Build Kalon Network

```bash
# Clone repository
git clone https://github.com/Why-x-Phy/kalon-network.git
cd kalon-network

# Build binaries
make build

# Install binaries
sudo cp build/kalon-* /usr/local/bin/
sudo chmod +x /usr/local/bin/kalon-*
```

### 3. Create User and Directories

```bash
# Create kalon user
sudo useradd -r -s /bin/false -d /var/lib/kalon -m kalon

# Create directories
sudo mkdir -p /var/lib/kalon/community-testnet
sudo mkdir -p /opt/kalon
sudo mkdir -p /etc/kalon

# Set permissions
sudo chown -R kalon:kalon /var/lib/kalon
sudo chown -R kalon:kalon /opt/kalon
```

### 4. Copy Configuration Files

```bash
# Copy genesis and scripts
sudo cp -r genesis /opt/kalon/
sudo cp -r scripts /opt/kalon/
sudo chown -R kalon:kalon /opt/kalon
```

## Network Configuration

### Master Node (185.133.249.107)

The master node serves as the primary node for the network:

- **RPC Port**: 16315 (accessible from anywhere)
- **P2P Port**: 17334 (accessible from anywhere)
- **Explorer**: Port 3000 (accessible from anywhere)
- **Mining**: Enabled with 4 threads
- **Wallet**: kalon12slz9pccxhahtm0th9v7n5emm6vtkumx4pykuh

### Slave Nodes

Slave nodes connect to the master node:

- **RPC Port**: 16315 (local access only)
- **P2P Port**: 17334 (local access only)
- **Mining**: Enabled with 2 threads
- **Wallet**: Auto-generated or specified
- **Sync**: Automatic sync with master node

## Service Management

### Master Node Commands

```bash
# Start master node
sudo kalon-master-start

# Stop master node
sudo kalon-master-stop

# Check status
sudo kalon-master-status

# View logs
sudo kalon-master-logs [node|miner|explorer]

# Monitor in real-time
sudo kalon-master-monitor

# Create backup
sudo kalon-master-backup [network]

# Update from repository
sudo kalon-master-update
```

### Slave Node Commands

```bash
# Start slave node
sudo kalon-slave-start

# Stop slave node
sudo kalon-slave-stop

# Check status
sudo kalon-slave-status

# View logs
sudo kalon-slave-logs [node|miner|sync]

# Monitor in real-time
sudo kalon-slave-monitor
```

## Network Access

### Master Node Access

- **RPC API**: http://185.133.249.107:16315
- **Explorer**: http://185.133.249.107:3000
- **P2P**: 185.133.249.107:17334

### Slave Node Access

- **Local RPC**: http://localhost:16315
- **P2P**: localhost:17334

## Firewall Configuration

### Master Node Firewall

```bash
# Allow RPC from anywhere
sudo ufw allow 16315/tcp

# Allow P2P from anywhere
sudo ufw allow 17334/tcp

# Allow explorer from anywhere
sudo ufw allow 3000/tcp

# Allow SSH
sudo ufw allow ssh

# Enable firewall
sudo ufw enable
```

### Slave Node Firewall

```bash
# Allow RPC from master only
sudo ufw allow from 185.133.249.107 to any port 16315

# Allow P2P from master only
sudo ufw allow from 185.133.249.107 to any port 17334

# Allow local access
sudo ufw allow from 127.0.0.1 to any port 16315
sudo ufw allow from 127.0.0.1 to any port 17334

# Allow SSH
sudo ufw allow ssh

# Enable firewall
sudo ufw enable
```

## Monitoring

### Real-time Monitoring

```bash
# Master node monitoring
sudo kalon-master-monitor

# Slave node monitoring
sudo kalon-slave-monitor
```

### Log Monitoring

```bash
# View all logs
sudo journalctl -u kalon-* -f

# View specific service logs
sudo journalctl -u kalon-master -f
sudo journalctl -u kalon-slave -f
```

### System Monitoring

```bash
# Check disk usage
df -h /var/lib/kalon

# Check memory usage
free -h

# Check process status
ps aux | grep kalon
```

## Troubleshooting

### Common Issues

1. **Service won't start**
   ```bash
   # Check logs
   sudo journalctl -u kalon-master -n 50
   
   # Check permissions
   sudo chown -R kalon:kalon /var/lib/kalon
   sudo chown -R kalon:kalon /opt/kalon
   ```

2. **RPC connection failed**
   ```bash
   # Check if service is running
   sudo systemctl status kalon-master
   
   # Check if port is open
   sudo netstat -tlnp | grep 16315
   
   # Check firewall
   sudo ufw status
   ```

3. **Sync issues**
   ```bash
   # Check master node connectivity
   curl http://185.133.249.107:16315
   
   # Check sync service
   sudo systemctl status kalon-slave-sync
   
   # Restart sync service
   sudo systemctl restart kalon-slave-sync
   ```

### Log Locations

- **System logs**: `/var/log/syslog`
- **Service logs**: `journalctl -u kalon-*`
- **Application logs**: `/var/log/kalon/`

## Security Considerations

1. **Firewall**: Configure UFW to only allow necessary ports
2. **User permissions**: Run services as non-root user
3. **Data encryption**: Consider encrypting data directories
4. **Backup**: Regular backups of blockchain data
5. **Updates**: Keep system and application updated

## Backup and Recovery

### Create Backup

```bash
# Create backup
sudo kalon-master-backup community-testnet

# Backup location
ls -la /var/backups/kalon/
```

### Restore Backup

```bash
# Stop services
sudo kalon-master-stop

# Restore from backup
sudo tar -xzf /var/backups/kalon/kalon_community-testnet_YYYYMMDD_HHMMSS.tar.gz -C /

# Start services
sudo kalon-master-start
```

## Updates

### Update from Repository

```bash
# Update master node
sudo kalon-master-update

# Update slave node
sudo kalon-slave-update
```

### Manual Update

```bash
# Stop services
sudo systemctl stop kalon-*

# Update from repository
cd /tmp
git clone https://github.com/Why-x-Phy/kalon-network.git
cd kalon-network

# Build new binaries
make build

# Install new binaries
sudo cp build/kalon-* /usr/local/bin/

# Start services
sudo systemctl start kalon-*
```

## Support

For support and questions:

- **GitHub Issues**: https://github.com/Why-x-Phy/kalon-network/issues
- **Documentation**: https://github.com/Why-x-Phy/kalon-network/docs
- **Community**: Join our Discord server

## License

This project is licensed under the MIT License - see the LICENSE file for details.
