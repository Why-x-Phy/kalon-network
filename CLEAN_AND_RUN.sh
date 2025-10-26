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

# Run test directly
echo ""
echo "🚀 Starte Node..."
pkill -f kalon-node-v2
nohup ./build-v2/kalon-node-v2 --datadir data-v2/testnet --genesis genesis/testnet.json --rpc :16316 --p2p :17335 > node-v2.log 2>&1 &
echo "⏳ Warte 5 Sekunden..."
sleep 5

echo "⛏️ Starte Miner..."
pkill -f kalon-miner-v2
nohup ./build-v2/kalon-miner-v2 --wallet kalon1r9wen9um8qwfdxdyk9u5yr3sd5ym5vrj72cttt --threads 2 --rpc http://localhost:16316 > miner-v2.log 2>&1 &
echo "⏳ Warte 60 Sekunden auf geminten Block..."
sleep 60

echo "💰 Prüfe Balance..."
curl -s http://localhost:16316 -X POST -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"getBalance","params":{"address":"kalon1r9wen9um8qwfdxdyk9u5yr3sd5ym5vrj72cttt"}}' | jq
