#!/bin/bash
# Test Memory-Pressure auf Test-Server (4GB RAM + Homepage)

echo "=== MEMORY-PRESSURE-TEST ==="
echo ""

cd ~/kalon-network || {
    echo "❌ Verzeichnis nicht gefunden!"
    exit 1
}

echo "1. Aktuelle Memory-Nutzung:"
if command -v free >/dev/null 2>&1; then
    echo "   Vor Node/Miner Start:"
    free -h
    echo ""
    MEM_TOTAL=$(free -m | grep "^Mem:" | awk '{print $2}')
    MEM_AVAIL=$(free -m | grep "^Mem:" | awk '{print $7}')
    MEM_USED=$(free -m | grep "^Mem:" | awk '{print $3}')
    echo "   Total: ${MEM_TOTAL}MB"
    echo "   Verfügbar: ${MEM_AVAIL}MB"
    echo "   Genutzt: ${MEM_USED}MB"
    echo ""
    
    # Berechne Prozent
    if [ -n "$MEM_TOTAL" ] && [ "$MEM_TOTAL" -gt 0 ]; then
        MEM_PCT=$((MEM_USED * 100 / MEM_TOTAL))
        echo "   Genutzt: ${MEM_PCT}%"
        if [ "$MEM_PCT" -gt 80 ]; then
            echo "   ⚠️ WARNUNG: Mehr als 80% RAM genutzt!"
        fi
    fi
else
    echo "   free nicht verfügbar"
fi
echo ""

echo "2. Swap-Status:"
if command -v free >/dev/null 2>&1; then
    SWAP_TOTAL=$(free -m | grep "^Swap:" | awk '{print $2}')
    SWAP_USED=$(free -m | grep "^Swap:" | awk '{print $3}')
    if [ "$SWAP_TOTAL" != "0" ]; then
        echo "   Swap Total: ${SWAP_TOTAL}MB"
        echo "   Swap Genutzt: ${SWAP_USED}MB"
        if [ "$SWAP_USED" -gt 0 ]; then
            echo "   ⚠️ WARNUNG: Swap wird verwendet! (I/O wird langsamer)"
        fi
    else
        echo "   ✅ Kein Swap konfiguriert"
    fi
else
    echo "   free nicht verfügbar"
fi
echo ""

echo "3. Laufende Prozesse (größte RAM-Nutzer):"
if command -v ps >/dev/null 2>&1; then
    echo "   Top 10 RAM-Nutzer:"
    ps aux --sort=-%mem | head -n 11 | awk '{printf "   %8s %6s%% %s\n", $6, $4, $11" "$12" "$13" "$14}'
else
    echo "   ps nicht verfügbar"
fi
echo ""

echo "4. Homepage-Prozesse:"
if pgrep -f "nginx|apache|httpd|node|php-fpm" > /dev/null 2>&1; then
    echo "   ⚠️ Homepage-Prozesse gefunden:"
    ps aux | grep -E "nginx|apache|httpd|node.*homepage|php-fpm" | grep -v grep | awk '{printf "   PID %s: %s MB (%s%%)\n", $2, $6, $4}'
    
    # Berechne Homepage-RAM-Verbrauch
    HOMEPAGE_RAM=$(ps aux | grep -E "nginx|apache|httpd|node.*homepage|php-fpm" | grep -v grep | awk '{sum+=$6} END {print sum}')
    if [ -n "$HOMEPAGE_RAM" ] && [ "$HOMEPAGE_RAM" -gt 0 ]; then
        HOMEPAGE_RAM_MB=$((HOMEPAGE_RAM / 1024))
        echo "   Homepage RAM-Verbrauch: ~${HOMEPAGE_RAM_MB}MB"
    fi
else
    echo "   ✅ Keine Homepage-Prozesse gefunden"
fi
echo ""

echo "5. Kalon-Prozesse:"
if pgrep -f "kalon-node-v2|kalon-miner-v2" > /dev/null 2>&1; then
    echo "   Kalon-Prozesse:"
    ps aux | grep -E "kalon-node-v2|kalon-miner-v2" | grep -v grep | awk '{printf "   PID %s: %s MB (%s%%)\n", $2, $6, $4}'
    
    # Berechne Kalon-RAM-Verbrauch
    KALON_RAM=$(ps aux | grep -E "kalon-node-v2|kalon-miner-v2" | grep -v grep | awk '{sum+=$6} END {print sum}')
    if [ -n "$KALON_RAM" ] && [ "$KALON_RAM" -gt 0 ]; then
        KALON_RAM_MB=$((KALON_RAM / 1024))
        echo "   Kalon RAM-Verbrauch: ~${KALON_RAM_MB}MB"
    fi
else
    echo "   ⚠️ Keine Kalon-Prozesse laufen"
fi
echo ""

echo "6. System-Load:"
if [ -f /proc/loadavg ]; then
    LOAD=$(cat /proc/loadavg)
    CPU_COUNT=$(grep -c "^processor" /proc/cpuinfo 2>/dev/null || echo "4")
    LOAD_1MIN=$(echo "$LOAD" | awk '{print $1}')
    echo "   Load Average: $LOAD"
    echo "   CPU-Count: $CPU_COUNT"
    
    # Berechne Load %
    if command -v bc >/dev/null 2>&1; then
        LOAD_PCT=$(echo "scale=2; ($LOAD_1MIN / $CPU_COUNT) * 100" | bc)
        echo "   Load % (1min): ${LOAD_PCT}%"
        if (( $(echo "$LOAD_PCT > 80" | bc -l) )); then
            echo "   ⚠️ WARNUNG: Load über 80%!"
        fi
    fi
else
    echo "   Load-Info nicht verfügbar"
fi
echo ""

echo "7. Empfehlungen:"
echo ""
TOTAL_RAM=4096  # 4GB
AVAIL_RAM=$(free -m | grep "^Mem:" | awk '{print $7}')

if [ -n "$AVAIL_RAM" ] && [ "$AVAIL_RAM" -lt 1000 ]; then
    echo "   ⚠️ WARNUNG: Weniger als 1GB RAM verfügbar!"
    echo "   Empfehlung: Homepage temporär stoppen während Mining-Test"
    echo ""
    echo "   Homepage stoppen (Beispiel):"
    echo "     sudo systemctl stop nginx"
    echo "     sudo systemctl stop apache2"
    echo "     sudo systemctl stop php-fpm"
    echo ""
    echo "   Nach Test wieder starten:"
    echo "     sudo systemctl start nginx"
fi

echo ""
echo "=== TEST ABGESCHLOSSEN ==="

