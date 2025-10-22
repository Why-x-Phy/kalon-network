# Kalon Network Makefile
# Builds and manages the Kalon Network project

.PHONY: all build clean test install run help

# Variables
VERSION := 1.0.2
BUILD_DIR := build
DIST_DIR := dist
BINARIES := kalon-node kalon-wallet kalon-miner
GO_VERSION := 1.22

# Default target
all: build

# Build all binaries
build:
	@echo "Building Kalon Network binaries..."
	@mkdir -p $(BUILD_DIR)
	@for binary in $(BINARIES); do \
		echo "Building $$binary..."; \
		go build -ldflags="-s -w -X main.version=$(VERSION)" -o $(BUILD_DIR)/$$binary ./cmd/$$binary; \
	done
	@echo "Build completed successfully!"

# Build for specific platform
build-linux-amd64:
	@echo "Building for Linux AMD64..."
	@GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -ldflags="-s -w -X main.version=$(VERSION)" -o $(BUILD_DIR)/kalon-node-linux-amd64 ./cmd/kalon-node
	@GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -ldflags="-s -w -X main.version=$(VERSION)" -o $(BUILD_DIR)/kalon-wallet-linux-amd64 ./cmd/kalon-wallet
	@GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -ldflags="-s -w -X main.version=$(VERSION)" -o $(BUILD_DIR)/kalon-miner-linux-amd64 ./cmd/kalon-miner

# Build for Raspberry Pi (ARM64)
build-linux-arm64:
	@echo "Building for Linux ARM64 (Raspberry Pi)..."
	@GOOS=linux GOARCH=arm64 CGO_ENABLED=0 go build -ldflags="-s -w -X main.version=$(VERSION)" -o $(BUILD_DIR)/kalon-node-linux-arm64 ./cmd/kalon-node
	@GOOS=linux GOARCH=arm64 CGO_ENABLED=0 go build -ldflags="-s -w -X main.version=$(VERSION)" -o $(BUILD_DIR)/kalon-wallet-linux-arm64 ./cmd/kalon-wallet
	@GOOS=linux GOARCH=arm64 CGO_ENABLED=0 go build -ldflags="-s -w -X main.version=$(VERSION)" -o $(BUILD_DIR)/kalon-miner-linux-arm64 ./cmd/kalon-miner

# Build for all platforms
build-all: build-linux-amd64 build-linux-arm64
	@echo "Building for all platforms completed!"

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	@rm -rf $(BUILD_DIR)
	@rm -rf $(DIST_DIR)
	@go clean -cache
	@echo "Clean completed!"

# Run tests
test:
	@echo "Running tests..."
	@go test -v ./...

# Run tests with coverage
test-coverage:
	@echo "Running tests with coverage..."
	@go test -v -coverprofile=coverage.out ./...
	@go tool cover -html=coverage.out -o coverage.html
	@echo "Coverage report generated: coverage.html"

# Install dependencies
deps:
	@echo "Installing dependencies..."
	@go mod download
	@go mod tidy

# Format code
fmt:
	@echo "Formatting code..."
	@go fmt ./...

# Lint code
lint:
	@echo "Linting code..."
	@if command -v golangci-lint >/dev/null 2>&1; then \
		golangci-lint run; \
	else \
		echo "golangci-lint not found, skipping linting"; \
	fi

# Run the node
run:
	@echo "Running Kalon Node..."
	@./scripts/run.sh

# Run the node with mining
run-mining:
	@echo "Running Kalon Node with mining..."
	@./scripts/run.sh --mining --threads 2

# Install the project
install:
	@echo "Installing Kalon Network..."
	@./scripts/install.sh

# Create release packages
release:
	@echo "Creating release packages..."
	@./scripts/build.sh --all --version $(VERSION)
	@echo "Release packages created in $(DIST_DIR)/"

# Docker build
docker-build:
	@echo "Building Docker images..."
	@docker build -t kalon-network:$(VERSION) -f docker/Dockerfile.node .
	@docker build -t kalon-explorer-api:$(VERSION) -f docker/Dockerfile.api .
	@echo "Docker images built successfully!"

# Docker run
docker-run:
	@echo "Running with Docker Compose..."
	@docker-compose -f docker/docker-compose.yml up

# Docker stop
docker-stop:
	@echo "Stopping Docker containers..."
	@docker-compose -f docker/docker-compose.yml down

# Generate documentation
docs:
	@echo "Generating documentation..."
	@go doc -all ./... > docs/api.md
	@echo "Documentation generated: docs/api.md"

# Check Go version
check-go:
	@echo "Checking Go version..."
	@go version
	@if ! go version | grep -q "go$(GO_VERSION)"; then \
		echo "Warning: Go version $(GO_VERSION) is recommended"; \
	fi

# Setup development environment
dev-setup: check-go deps
	@echo "Setting up development environment..."
	@mkdir -p data
	@mkdir -p logs
	@echo "Development environment ready!"

# Run development server
dev: dev-setup
	@echo "Starting development server..."
	@./scripts/run.sh --datadir ./data

# Create wallet
wallet-create:
	@echo "Creating wallet..."
	@./$(BUILD_DIR)/kalon-wallet create

# Check wallet balance
wallet-balance:
	@echo "Checking wallet balance..."
	@./$(BUILD_DIR)/kalon-wallet balance

# Start mining
mining-start:
	@echo "Starting mining..."
	@./$(BUILD_DIR)/kalon-miner --wallet $(WALLET_ADDRESS) --threads 2

# Show help
help:
	@echo "Kalon Network Makefile"
	@echo "======================"
	@echo ""
	@echo "Available targets:"
	@echo "  build              Build all binaries"
	@echo "  build-linux-amd64  Build for Linux AMD64"
	@echo "  build-linux-arm64  Build for Linux ARM64 (Raspberry Pi)"
	@echo "  build-all          Build for all platforms"
	@echo "  clean              Clean build artifacts"
	@echo "  test               Run tests"
	@echo "  test-coverage      Run tests with coverage"
	@echo "  deps               Install dependencies"
	@echo "  fmt                Format code"
	@echo "  lint               Lint code"
	@echo "  run                Run the node"
	@echo "  run-mining         Run the node with mining"
	@echo "  install            Install the project"
	@echo "  release            Create release packages"
	@echo "  docker-build       Build Docker images"
	@echo "  docker-run         Run with Docker Compose"
	@echo "  docker-stop        Stop Docker containers"
	@echo "  docs               Generate documentation"
	@echo "  check-go           Check Go version"
	@echo "  dev-setup          Setup development environment"
	@echo "  dev                Run development server"
	@echo "  wallet-create      Create wallet"
	@echo "  wallet-balance     Check wallet balance"
	@echo "  mining-start       Start mining"
	@echo "  help               Show this help message"
	@echo ""
	@echo "Examples:"
	@echo "  make build                    # Build all binaries"
	@echo "  make build-linux-arm64        # Build for Raspberry Pi"
	@echo "  make run                      # Run the node"
	@echo "  make run-mining               # Run with mining"
	@echo "  make WALLET_ADDRESS=addr mining-start  # Start mining with specific wallet"
