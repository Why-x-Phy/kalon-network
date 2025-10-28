#!/bin/bash

echo "=== KALON SYSTEM BEREINIGUNG ==="
echo ""

# 1. Alle laufenden Prozesse stoppen
echo "1. Stoppe alle Kalon-Prozesse..."
pkill -9 -f kalon 2>/dev/null || echo "   Keine Kalon-Prozesse gefunden"
sleep 2

# 2. Alle Test-Datenverzeichnisse löschen
echo "2. Lösche alle Test-Datenverzeichnisse..."
rm -rf data-* 2>/dev/null || echo "   Keine Test-Datenverzeichnisse gefunden"

# 3. Alle Log-Dateien löschen
echo "3. Lösche alle Log-Dateien..."
rm -f *.log 2>/dev/null || echo "   Keine Log-Dateien gefunden"

# 4. Alle Builds neu kompilieren
echo "4. Kompiliere alle Binaries neu..."
rm -rf build-v2/*
go build -o build-v2/kalon-node-v2 cmd/kalon-node-v2/main.go
go build -o build-v2/kalon-miner-v2 cmd/kalon-miner-v2/main.go
go build -o build-v2/kalon-wallet cmd/kalon-wallet/main.go

# 5. Ausführungsrechte setzen
echo "5. Setze Ausführungsrechte..."
chmod +x build-v2/*

# 6. Status prüfen
echo ""
echo "6. System-Status:"
echo "   Verzeichnisse:"
ls -la | grep -E "(data|build)" || echo "   Keine relevanten Verzeichnisse"
echo ""
echo "   Prozesse:"
ps aux | grep kalon | grep -v grep || echo "   Keine Kalon-Prozesse aktiv"
echo ""
echo "✅ System ist bereinigt und bereit!"
echo ""
echo "Für frischen Start:"
echo "  ./build-v2/kalon-node-v2 -datadir data-fresh -genesis genesis/testnet.json -rpc :16316 -p2p :17335"
