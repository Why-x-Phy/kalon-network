#!/bin/bash
# Struktur-Check auf dem Server

echo "🔍 Kalon Repository Struktur-Check"
echo "===================================="
echo ""

# Prüfe alle cmd/* Verzeichnisse
echo "📁 cmd/ Verzeichnis-Inhalt:"
ls -la cmd/

echo ""
echo "📁 cmd/* Verzeichnisse im Detail:"
find cmd/ -type f -name "main.go" 2>/dev/null || echo "Keine main.go gefunden"

echo ""
echo "📁 core/ Verzeichnis-Inhalt:"
ls -la core/

echo ""
echo "📁 Gesamte Struktur (wichtige Verzeichnisse):"
echo ""
echo "cmd/:"
ls -la cmd/ 2>/dev/null || echo "cmd/ existiert nicht"
echo ""
echo "core/:"
ls -la core/ 2>/dev/null || echo "core/ existiert nicht"
echo ""
echo "rpc/:"
ls -la rpc/ 2>/dev/null || echo "rpc/ existiert nicht"
echo ""

echo "✅ Struktur-Check abgeschlossen"
