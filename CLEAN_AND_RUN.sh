#!/bin/bash
# Clean git and rebuild

cd ~/kalon-network

# Reset to latest commit
echo "🧹 Cleaning git..."
git reset --hard origin/master
git pull origin master

# Stop old processes
echo "🛑 Stopping old processes..."
pkill -f kalon-node-v2
pkill -f kalon-miner-v2
sleep 2

# Clean old binaries
echo "🧹 Cleaning old binaries..."
rm -f build-v2/kalon-node-v2 build-v2/kalon-miner-v2
rm -f kalon-node-v2 kalon-miner-v2

# Rebuild
echo "🔨 Rebuilding..."
mkdir -p build-v2
go build -o build-v2/kalon-node-v2 ./cmd/kalon-node-v2
go build -o build-v2/kalon-miner-v2 ./cmd/kalon-miner-v2

# Check if build succeeded
if [ ! -f "build-v2/kalon-node-v2" ] || [ ! -f "build-v2/kalon-miner-v2" ]; then
  echo "❌ Build failed!"
  exit 1
fi

echo "✅ Build successful!"

# Now run BALANCE_TEST.sh
./BALANCE_TEST.sh
