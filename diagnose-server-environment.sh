#!/bin/bash
# Diagnose-Script für Server-Umgebungsunterschiede (Contabo VPS / Raspberry Pi)

echo "=== SERVER-UMGEBUNGS-DIAGNOSE ==="
echo ""

echo "1. System-Informationen:"
echo "   OS: $(uname -a)"
echo "   Kernel: $(uname -r)"
echo "   Architektur: $(uname -m)"
echo ""

echo "2. CPU-Informationen:"
if [ -f /proc/cpuinfo ]; then
    CPU_COUNT=$(grep -c "^processor" /proc/cpuinfo)
    CPU_MODEL=$(grep "model name" /proc/cpuinfo | head -n 1 | cut -d: -f2 | sed 's/^[[:space:]]*//')
    echo "   CPUs: $CPU_COUNT"
    echo "   Modell: $CPU_MODEL"
    CPU_FREQ=$(grep "cpu MHz" /proc/cpuinfo | head -n 1 | cut -d: -f2 | sed 's/^[[:space:]]*//' | cut -d. -f1)
    if [ -n "$CPU_FREQ" ]; then
        echo "   Frequenz: ${CPU_FREQ} MHz"
    fi
else
    echo "   CPU-Info nicht verfügbar"
fi
echo ""

echo "3. Speicher-Informationen:"
if command -v free >/dev/null 2>&1; then
    MEM_INFO=$(free -h | grep "^Mem:")
    TOTAL_RAM=$(echo "$MEM_INFO" | awk '{print $2}')
    AVAIL_RAM=$(echo "$MEM_INFO" | awk '{print $7}')
    echo "   Total RAM: $TOTAL_RAM"
    echo "   Verfügbar: $AVAIL_RAM"
else
    echo "   Speicher-Info nicht verfügbar"
fi
echo ""

echo "4. Go-Version:"
if command -v go >/dev/null 2>&1; then
    GO_VERSION=$(go version)
    echo "   $GO_VERSION"
    GO_ROOT=$(go env GOROOT 2>/dev/null || echo "Nicht gefunden")
    echo "   GOROOT: $GO_ROOT"
else
    echo "   ❌ Go nicht installiert oder nicht im PATH"
fi
echo ""

echo "5. Storage-Informationen:"
if command -v df >/dev/null 2>&1; then
    echo "   Mount-Punkte:"
    df -h | grep -E "^/dev/" | head -n 5 | awk '{print "     " $1 " -> " $6 " (" $4 " verfügbar)"}'
    
    # Prüfe ob SSD oder HDD
    if [ -d /sys/block ]; then
        echo ""
        echo "   Storage-Typen:"
        for disk in /sys/block/*/queue/rotational; do
            if [ -f "$disk" ]; then
                disk_name=$(echo "$disk" | cut -d/ -f4)
                is_rotational=$(cat "$disk")
                if [ "$is_rotational" = "0" ]; then
                    echo "     $disk_name: SSD"
                else
                    echo "     $disk_name: HDD"
                fi
            fi
        done
    fi
else
    echo "   Storage-Info nicht verfügbar"
fi
echo ""

echo "6. Prozess-Limits:"
if command -v ulimit >/dev/null 2>&1; then
    echo "   Max offene Dateien: $(ulimit -n)"
    echo "   Max Prozesse: $(ulimit -u)"
    echo "   Max virtueller Speicher: $(ulimit -v 2>/dev/null || echo 'unbegrenzt')"
else
    echo "   ulimit nicht verfügbar"
fi
echo ""

echo "7. Port-Status:"
if command -v ss >/dev/null 2>&1; then
    echo "   Port 16316 (RPC):"
    ss -tlnp 2>/dev/null | grep 16316 || echo "     Nicht belegt"
    echo "   Port 17335 (P2P):"
    ss -tlnp 2>/dev/null | grep 17335 || echo "     Nicht belegt"
elif command -v netstat >/dev/null 2>&1; then
    echo "   Port 16316 (RPC):"
    netstat -tlnp 2>/dev/null | grep 16316 || echo "     Nicht belegt"
    echo "   Port 17335 (P2P):"
    netstat -tlnp 2>/dev/null | grep 17335 || echo "     Nicht belegt"
else
    echo "   Port-Check-Tools nicht verfügbar"
fi
echo ""

echo "8. Firewall-Status:"
if command -v ufw >/dev/null 2>&1; then
    echo "   UFW Status:"
    ufw status | head -n 5
elif command -v firewall-cmd >/dev/null 2>&1; then
    echo "   firewalld Status:"
    firewall-cmd --state 2>/dev/null || echo "     Nicht aktiv"
elif [ -f /etc/iptables/rules.v4 ] || [ -f /etc/iptables/rules.v6 ]; then
    echo "   iptables aktiv"
else
    echo "   Keine Firewall-Tools gefunden"
fi
echo ""

echo "9. Laufende Kalon-Prozesse:"
if pgrep -f "kalon-node-v2|kalon-miner-v2" > /dev/null 2>&1; then
    ps aux | grep -E "kalon-node-v2|kalon-miner-v2" | grep -v grep | awk '{print "   PID " $2 ": " $11 " " $12 " " $13 " " $14 " (CPU: " $3 "%, MEM: " $4 "%)"}'
else
    echo "   Keine Kalon-Prozesse laufen"
fi
echo ""

echo "10. Load Average:"
if [ -f /proc/loadavg ]; then
    LOAD=$(cat /proc/loadavg)
    echo "   $LOAD"
    LOAD_1MIN=$(echo "$LOAD" | awk '{print $1}')
    CPU_COUNT=$(grep -c "^processor" /proc/cpuinfo 2>/dev/null || echo "1")
    if [ -n "$CPU_COUNT" ] && [ -n "$LOAD_1MIN" ]; then
        LOAD_PCT=$(echo "scale=2; ($LOAD_1MIN / $CPU_COUNT) * 100" | bc 2>/dev/null || echo "N/A")
        echo "   Load % (1min): $LOAD_PCT%"
    fi
else
    echo "   Load-Info nicht verfügbar"
fi
echo ""

echo "11. Disk I/O:"
if command -v iostat >/dev/null 2>&1; then
    iostat -x 1 2 | tail -n +4 | head -n 10
elif [ -f /proc/diskstats ]; then
    echo "   /proc/diskstats vorhanden"
    echo "   (Installiere sysstat für detaillierte I/O-Statistiken: apt install sysstat)"
else
    echo "   I/O-Statistiken nicht verfügbar"
fi
echo ""

echo "=== DIAGNOSE ABGESCHLOSSEN ==="
echo ""
echo "Nächste Schritte:"
echo "  - Prüfe CPU-Last während Mining"
echo "  - Prüfe Speicher-Verbrauch"
echo "  - Prüfe Disk I/O während LevelDB-Operationen"
echo "  - Prüfe ob Ports erreichbar sind"
echo "  - Vergleiche Go-Version mit lokalem System"

