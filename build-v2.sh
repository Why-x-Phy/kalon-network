#!/bin/bash

# Professional Kalon Network v2.0 Build Script
echo "🚀 Building Professional Kalon Network v2.0"

# Create build directory
mkdir -p build-v2

# Build core components
echo "📦 Building core components..."

# Build Node v2
echo "   Building kalon-node-v2..."
go build -o build-v2/kalon-node-v2 cmd/kalon-node-v2/main.go
if [ $? -ne 0 ]; then
    echo "❌ Failed to build kalon-node-v2"
    exit 1
fi

# Build Miner v2
echo "   Building kalon-miner-v2..."
go build -o build-v2/kalon-miner-v2 cmd/kalon-miner-v2/main.go
if [ $? -ne 0 ]; then
    echo "❌ Failed to build kalon-miner-v2"
    exit 1
fi

# Build Wallet (use existing)
echo "   Building kalon-wallet..."
go build -o build-v2/kalon-wallet cmd/kalon-wallet/main.go
if [ $? -ne 0 ]; then
    echo "❌ Failed to build kalon-wallet"
    exit 1
fi

# Set permissions
chmod +x build-v2/*

echo "✅ Professional Kalon Network v2.0 built successfully!"
echo "   📁 Binaries: build-v2/"
echo "   🚀 Node: build-v2/kalon-node-v2"
echo "   ⛏️  Miner: build-v2/kalon-miner-v2"
echo "   💰 Wallet: build-v2/kalon-wallet"
