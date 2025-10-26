# Kalon Network Docker Setup

This directory contains Docker configurations for running the Kalon Network.

## Quick Start

### Minimal Setup (Recommended for Development)

```bash
# Start the minimal setup
docker-compose -f docker/docker-compose.minimal.yml up -d

# Check status
docker-compose -f docker/docker-compose.minimal.yml ps

# View logs
docker-compose -f docker/docker-compose.minimal.yml logs -f
```

### Full Setup (Production)

```bash
# Start all services including monitoring
docker-compose -f docker/docker-compose.yml up -d

# Check status
docker-compose -f docker/docker-compose.yml ps

# View logs
docker-compose -f docker/docker-compose.yml logs -f
```

## Services

### Core Services

- **kalon-node**: The main blockchain node
  - RPC API: http://localhost:16314
  - P2P Port: 17333
  - Health Check: http://localhost:16314/health

- **kalon-explorer-api**: Explorer backend API
  - API: http://localhost:8081
  - Health Check: http://localhost:8081/health

- **kalon-explorer**: Web interface
  - Web UI: http://localhost:8080
  - Health Check: http://localhost:8080/

### Optional Services (Full Setup Only)

- **redis**: Caching layer
  - Port: 6379

- **prometheus**: Metrics collection
  - Web UI: http://localhost:9090

- **grafana**: Metrics visualization
  - Web UI: http://localhost:3000
  - Default login: admin/admin

## Configuration

### Environment Variables

You can customize the setup using environment variables:

```bash
# Create a .env file
cat > .env << EOF
KALON_RPC_ADDR=:16314
KALON_P2P_ADDR=:17333
KALON_DATA_DIR=/app/data
KALON_GENESIS_FILE=/app/genesis.json
KALON_SEED_NODES=seed1.kalon.network:17333,seed2.kalon.network:17333
EOF

# Use with docker-compose
docker-compose --env-file .env up -d
```

### Volumes

- `kalon-data`: Blockchain data and wallet files
- `kalon-redis-data`: Redis data (full setup only)
- `kalon-prometheus-data`: Prometheus metrics (full setup only)
- `kalon-grafana-data`: Grafana dashboards (full setup only)

## Commands

### Basic Operations

```bash
# Start services
docker-compose up -d

# Stop services
docker-compose down

# Restart services
docker-compose restart

# View logs
docker-compose logs -f [service-name]

# Execute commands in containers
docker-compose exec kalon-node kalon-wallet create
docker-compose exec kalon-node kalon-wallet balance
docker-compose exec kalon-node kalon-miner --wallet <address> --threads 2
```

### Maintenance

```bash
# Update images
docker-compose pull
docker-compose up -d

# Rebuild images
docker-compose build --no-cache
docker-compose up -d

# Clean up
docker-compose down -v
docker system prune -f
```

### Monitoring

```bash
# View container stats
docker stats

# View resource usage
docker-compose top

# Check health status
docker-compose ps
```

## Troubleshooting

### Common Issues

1. **Port conflicts**: Make sure ports 16314, 17333, 8080, 8081 are available
2. **Permission issues**: Ensure Docker has proper permissions
3. **Memory issues**: Increase Docker memory limit if needed

### Debugging

```bash
# View detailed logs
docker-compose logs --tail=100 -f kalon-node

# Check container health
docker inspect kalon-node | grep -A 10 Health

# Access container shell
docker-compose exec kalon-node sh
```

### Reset Everything

```bash
# Stop and remove everything
docker-compose down -v
docker system prune -a -f

# Remove volumes
docker volume prune -f

# Start fresh
docker-compose up -d
```

## Production Deployment

For production deployment, consider:

1. **Security**: Use proper secrets management
2. **Monitoring**: Enable all monitoring services
3. **Backup**: Regular backup of volumes
4. **Updates**: Regular security updates
5. **Scaling**: Use Docker Swarm or Kubernetes

### Example Production Override

```yaml
# docker-compose.prod.yml
version: '3.8'
services:
  kalon-node:
    restart: always
    deploy:
      resources:
        limits:
          memory: 2G
          cpus: '1.0'
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
```

Use with: `docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d`
