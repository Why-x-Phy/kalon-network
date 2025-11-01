#!/bin/bash
# Test I/O-Performance auf Test-Server während Mining

echo "=== I/O-PERFORMANCE-TEST ==="
echo ""

cd ~/kalon-network || {
    echo "❌ Verzeichnis nicht gefunden!"
    exit 1
}

echo "1. Storage-Typ prüfen:"
if command -v lsblk >/dev/null 2>&1; then
    lsblk -d -o name,rota,type,size | grep -E "NAME|^[a-z]"
    echo ""
    echo "   rota=0 = SSD, rota=1 = HDD"
else
    echo "   lsblk nicht verfügbar"
fi
echo ""

echo "2. I/O-Statistiken (vor Mining):"
if command -v iostat >/dev/null 2>&1; then
    iostat -x 1 3 | tail -n +4
else
    echo "   iostat nicht verfügbar (installiere: apt install sysstat)"
fi
echo ""

echo "3. System-Load:"
if [ -f /proc/loadavg ]; then
    LOAD=$(cat /proc/loadavg)
    echo "   Load Average: $LOAD"
    CPU_COUNT=$(grep -c "^processor" /proc/cpuinfo 2>/dev/null || echo "1")
    echo "   CPU-Count: $CPU_COUNT"
else
    echo "   Load-Info nicht verfügbar"
fi
echo ""

echo "4. Memory:"
if command -v free >/dev/null 2>&1; then
    free -h | grep "^Mem:"
    echo ""
    echo "   Swap:"
    free -h | grep "^Swap:"
else
    echo "   free nicht verfügbar"
fi
echo ""

echo "5. Während Mining - Starte Monitoring:"
echo "   Führe dies AUS, während Mining läuft:"
echo ""
echo "   # Terminal 1: I/O-Monitor"
echo "   sudo iotop -ao -d 1 -t"
echo ""
echo "   # Terminal 2: CPU/Memory-Monitor"
echo "   watch -n 1 'ps aux | grep kalon | grep -v grep'"
echo ""
echo "   # Terminal 3: Load-Monitor"
echo "   watch -n 1 'uptime && free -h'"
echo ""

echo "6. LevelDB-Verzeichnis-Größe:"
if [ -d data-quick-test/chaindb ]; then
    du -sh data-quick-test/chaindb
    echo "   Dateien:"
    ls -lh data-quick-test/chaindb/ | head -n 10
else
    echo "   LevelDB-Verzeichnis nicht gefunden"
fi
echo ""

echo "=== TEST ABGESCHLOSSEN ==="

