# Kalon Refactoring Plan - Produktionsreif

## ✅ Phase 1: Code-Bereinigung (ABGESCHLOSSEN)
- ✅ V1-Code komplett entfernt
- ✅ blockchain_v2.go → blockchain.go
- ✅ kalon-miner enthält jetzt V2-Code
- ⚠️ kalon-node muss auf Server restauriert werden

## 🚀 NÄCHSTER SCHRITT: Server-Bereinigung

**Führe diese Befehle auf dem Ubuntu-Server aus:**

```bash
# 1. Repository holen und v2 aufräumen
cd ~/kalon-network
git pull origin master

# 2. V2 zu final umbenennen (node & miner)
cp -r cmd/kalon-node-v2 cmd/kalon-node-temp
rm -rf cmd/kalon-node-v2
mkdir -p cmd/kalon-node
cp cmd/kalon-node-temp/*.go cmd/kalon-node/
rm -rf cmd/kalon-node-temp

cp -r cmd/kalon-miner-v2 cmd/kalon-miner-temp  
rm -rf cmd/kalon-miner-v2
mkdir -p cmd/kalon-miner
cp cmd/kalon-miner-temp/*.go cmd/kalon-miner/
rm -rf cmd/kalon-miner-temp

# 3. Neubuild
./scripts/build-v2.sh

# 4. Test
./build-v2/kalon-node-v2 --datadir data-v2/testnet --genesis genesis/testnet.json --rpc :16316 --p2p :17335
```

## 📋 Phase 2: Balance-Bug Fix (PRIORITÄT!)
- ⚠️ Wallet-Balance zeigt 0 trotz 17 gemineter Blöcke
- 🔍 Address-Parsing muss funktionieren

## 📋 Phase 3: ChatGPT-Struktur (FRÜHER GEPLANT)
- Code in `internal/` organisieren
- Tests hinzufügen
- CI/CD Pipeline
- Dokumentation

## 🎯 ZIEL: Beste Blockchain
Produktionsreif, professionell, funktioniert perfekt!
