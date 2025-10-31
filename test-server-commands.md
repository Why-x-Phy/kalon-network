# Befehle für Test-Server

## 1. Repository aktualisieren
```bash
cd ~/kalon-network  # oder dein Projekt-Verzeichnis
git pull origin master
```

## 2. Test-Script bereitstellen (falls nicht vorhanden)
```bash
# Script ist im Repo, aber sicherstellen dass es ausführbar ist
chmod +x test-quick-10min.sh
```

## 3. Test ausführen
```bash
# Alle Prozesse beenden (falls noch welche laufen)
killall -9 kalon-node-v2 kalon-miner-v2 2>/dev/null || true
pkill -9 -f "test-quick" 2>/dev/null || true
sleep 2

# Test starten
./test-quick-10min.sh > test-output.log 2>&1 &

# Test im Hintergrund laufen lassen
# Test dauert 10 Minuten
```

## 4. Test überwachen (optional)
```bash
# Status nach 1 Minute prüfen
sleep 60
curl -s http://localhost:16316/rpc -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getHeight","id":1}' | jq .

# Test-Output prüfen
tail -f test-output.log
```

## 5. Erwartete Ergebnisse
- ✅ Block-Höhe: Mindestens 50 Blöcke (Ziel: 100)
- ✅ Wallet Balance: > 0 (bei erfolgreichem Mining)
- ✅ Fehler: < 20
- ✅ Blöcke gemined: > 0

## 6. Test beenden (falls nötig)
```bash
killall -9 kalon-node-v2 kalon-miner-v2
pkill -9 -f test-quick
```

