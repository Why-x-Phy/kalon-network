# Contabo VPS Optimierung (4GB RAM + Homepage)

## Server-Spezifikation

- **CPU:** 4 Cores
- **RAM:** 4 GB
- **Storage:** 200 GB SSD (100% SSD)
- **Network:** 200 Mbit/s
- **Zusätzlich:** Homepage läuft auf demselben Server

## Problem-Analyse

### Warum könnte Block 15 Problem auftreten?

**Mit 4GB RAM und Homepage:**

1. **Memory-Pressure:**
   - Homepage (nginx/apache + PHP/Node) braucht: ~200-500MB
   - Node braucht: ~50-100MB
   - Miner braucht: ~20-50MB
   - System braucht: ~500-800MB
   - **Total: ~800-1450MB** (OK bei 4GB, aber eng!)

2. **Swap-Aktivierung:**
   - Wenn RAM voll → Swap wird aktiviert
   - **Auch auf SSD** → Swap auf SSD ist langsamer als RAM
   - LevelDB I/O wird langsamer → Lock-Contention verschärft

3. **Memory-Cache-Pressure:**
   - Linux verwendet freien RAM als Cache
   - Weniger freier RAM → Weniger Cache → Mehr Disk-I/O
   - **Auch auf SSD** kann Cache-Pressure I/O beeinflussen

4. **OOM-Killer:**
   - Bei extremem Memory-Pressure könnte der OOM-Killer Prozesse beenden
   - Miner oder Node könnten gekillt werden

## Empfehlungen

### 1. Homepage temporär stoppen während Mining-Test

**Warum?**
- Mehr verfügbarer RAM für Node/Miner
- Weniger Memory-Pressure
- Weniger Swap-Nutzung
- Stabileres Mining

**Wie?**
```bash
# Homepage stoppen (Beispiel):
sudo systemctl stop nginx
sudo systemctl stop apache2
# oder
sudo systemctl stop php-fpm

# Prüfe ob gestoppt:
ps aux | grep -E "nginx|apache|php-fpm" | grep -v grep

# Nach Test wieder starten:
sudo systemctl start nginx
sudo systemctl start apache2
```

### 2. Swap-Größe prüfen

**Zu wenig Swap:**
```bash
free -h
# Prüfe Swap-Größe
```

**Zu viel Swap aktiviert:**
- Wenn Swap > 0 MB genutzt wird → Memory-Pressure
- Homepage stoppen → Swap sollte sich leeren

### 3. Mining mit weniger Ressourcen

**Für Contabo VPS optimiert:**
- Node: Normal (braucht wenig)
- Miner: 1 Thread (bereits so)
- Homepage: **STOPPEN** während Mining

### 4. Monitoring während Test

**In separatem Terminal während Mining:**
```bash
# Memory-Monitor:
watch -n 1 'free -h && echo "" && ps aux | grep -E "kalon|nginx|apache" | grep -v grep'

# Oder:
watch -n 1 'free -m && echo "" && ps aux --sort=-%mem | head -n 10'
```

## Nächste Schritte

1. **Homepage stoppen:**
   ```bash
   sudo systemctl stop nginx  # oder apache2
   ```

2. **Memory prüfen:**
   ```bash
   free -h
   ```

3. **Test durchführen:**
   ```bash
   ./test-quick-10min.sh > test-output.log 2>&1 &
   ```

4. **Während Test überwachen:**
   ```bash
   watch -n 1 'free -h'
   ```

5. **Nach Test Homepage wieder starten:**
   ```bash
   sudo systemctl start nginx
   ```

## Erwartete Verbesserung

**Mit Homepage gestoppt:**
- +200-500MB verfügbarer RAM
- Weniger Swap-Nutzung
- Weniger Memory-Pressure
- Stabileres Mining
- **Block 15 Problem sollte behoben sein**

