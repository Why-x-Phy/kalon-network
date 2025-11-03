#!/bin/bash
# Script zum Öffnen der Firewall-Ports für HTTPS

# Farben
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo "=== FIREWALL PORTS FÜR HTTPS ÖFFNEN ==="
echo ""

# 1. Prüfe Firewall Status
echo "1. Prüfe Firewall Status..."
if sudo ufw status | grep -q "Status: active"; then
    echo -e "${GREEN}✅ Firewall ist aktiv${NC}"
else
    echo -e "${YELLOW}⚠️ Firewall ist nicht aktiv${NC}"
    echo "   Aktiviere Firewall..."
    sudo ufw --force enable
fi
echo ""

# 2. Öffne Port 80 (HTTP)
echo "2. Öffne Port 80 (HTTP)..."
if sudo ufw status | grep -q "80/tcp"; then
    echo -e "${GREEN}✅ Port 80 ist bereits geöffnet${NC}"
else
    sudo ufw allow 80/tcp
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Port 80 geöffnet${NC}"
    else
        echo -e "${RED}❌ Port 80 öffnen fehlgeschlagen!${NC}"
        exit 1
    fi
fi
echo ""

# 3. Öffne Port 443 (HTTPS)
echo "3. Öffne Port 443 (HTTPS)..."
if sudo ufw status | grep -q "443/tcp"; then
    echo -e "${GREEN}✅ Port 443 ist bereits geöffnet${NC}"
else
    sudo ufw allow 443/tcp
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Port 443 geöffnet${NC}"
    else
        echo -e "${RED}❌ Port 443 öffnen fehlgeschlagen!${NC}"
        exit 1
    fi
fi
echo ""

# 4. Firewall neu laden
echo "4. Lade Firewall neu..."
sudo ufw reload
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Firewall neu geladen${NC}"
else
    echo -e "${YELLOW}⚠️ Firewall neu laden fehlgeschlagen (möglicherweise nicht nötig)${NC}"
fi
echo ""

# 5. Zeige Firewall Status
echo "5. Aktueller Firewall Status:"
echo "────────────────────────────────────────────────"
sudo ufw status | grep -E "(80/tcp|443/tcp)"
echo ""

# 6. Teste Ports von außen
echo "6. Teste Ports..."
sleep 2

# Teste Port 80
if timeout 3 bash -c "echo > /dev/tcp/185.133.249.107/80" 2>/dev/null; then
    echo -e "${GREEN}✅ Port 80 ist von außen erreichbar${NC}"
else
    echo -e "${YELLOW}⚠️ Port 80 ist möglicherweise nicht von außen erreichbar${NC}"
    echo "   Prüfe ob Firewall korrekt konfiguriert ist"
fi

# Teste Port 443
if timeout 3 bash -c "echo > /dev/tcp/185.133.249.107/443" 2>/dev/null; then
    echo -e "${GREEN}✅ Port 443 ist von außen erreichbar${NC}"
else
    echo -e "${YELLOW}⚠️ Port 443 ist möglicherweise nicht von außen erreichbar${NC}"
    echo "   Prüfe ob Firewall korrekt konfiguriert ist"
fi
echo ""

echo -e "${GREEN}=== FIREWALL KONFIGURATION ABGESCHLOSSEN ===${NC}"
echo ""
echo "Nächste Schritte:"
echo "1. Öffne im Browser: https://explorer.kalon-network.com"
echo "2. Prüfe ob keine Warnung mehr erscheint"
echo "3. Prüfe ob Explorer 'ONLINE' zeigt"
echo ""
echo "Falls immer noch Probleme:"
echo "1. Prüfe ob Provider (Contabo) Firewall auch Ports öffnen muss"
echo "2. Prüfe ob VPS Firewall korrekt konfiguriert ist"
echo "3. Teste mit: curl -I https://explorer.kalon-network.com"

