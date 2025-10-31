# Test-Server Update Anleitung

## Erste Verwendung (wenn Scripts noch nicht existieren)

Wenn `pre-pull.sh` noch nicht auf dem Server ist:

```bash
cd ~/kalon-network

# 1. Entferne lokale Binaries
rm -f build-v2/kalon-node-v2 build-v2/kalon-miner-v2 build-v2/kalon-wallet

# 2. Stashe lokale Änderungen
git stash push -m "Lokale Änderungen" || true

# 3. Pull Updates
git pull origin master

# 4. Setze Ausführungsrechte
chmod +x pre-pull.sh fix-test-server.sh test-quick-10min.sh

# 5. Führe fix-test-server.sh aus
./fix-test-server.sh
```

## Ab dann (wenn pre-pull.sh existiert)

```bash
cd ~/kalon-network

# 1. Setze Ausführungsrechte (falls nötig)
chmod +x pre-pull.sh fix-test-server.sh

# 2. Führe pre-pull.sh aus (bereinigt alles)
./pre-pull.sh

# 3. Pull Updates
git pull origin master

# 4. Führe fix-test-server.sh aus (baut alles neu)
./fix-test-server.sh
```

## Test starten

Nach `./fix-test-server.sh`:

```bash
./test-quick-10min.sh > test-output.log 2>&1 &
```

## Status prüfen

```bash
./check-rpc-status.sh
```

oder

```bash
tail -f test-output.log
```

