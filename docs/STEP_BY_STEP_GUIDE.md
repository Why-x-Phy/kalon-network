# Kalon Network - Schritt-für-Schritt Anleitung

## 📋 Komplette Schritt-für-Schritt Anleitung

Diese Anleitung führt dich durch die komplette Installation und den Start von Kalon Network.

---

## 🎯 SCHRITT 1: System vorbereiten

### 1.1 Go installieren

```bash
# Go Version prüfen
go version

# Falls noch nicht installiert:
wget https://go.dev/dl/go1.23.2.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.23.2.linux-amd64.tar.gz

# PATH setzen
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
source ~/.bashrc

# Nochmal prüfen
go version
```

**Erwartetes Ergebnis:** `go version go1.23.2 linux/amd64`

---

## 📦 SCHRITT 2: Repository clonen

```bash
# Repository clonen
git clone https://github.com/Why-x-Phy/kalon-network.git
cd kalon-network

# Aktueller Stand
ls -la
```

**Erwartetes Ergebnis:** Du siehst das Repository-Verzeichnis mit allen Dateien.

---

## 🔨 SCHRITT 3: Alles bauen

### 3.1 Node bauen

```bash
go build -o build-v2/kalon-node-v2 cmd/kalon-node-v2/main.go
```

**Prüfen:**
```bash
ls -lh build-v2/kalon-node-v2
```

**Erwartetes Ergebnis:** Datei existiert (~8MB)

### 3.2 Miner bauen

```bash
go build -o build-v2/kalon-miner-v2 cmd/kalon-miner-v2/main.go
```

**Prüfen:**
```bash
ls -lh build-v2/kalon-miner-v2
```

**Erwartetes Ergebnis:** Datei existiert (~8MB)

### 3.3 Wallet bauen

```bash
go build -o build-v2/kalon-wallet cmd/kalon-wallet/main.go
```

**Prüfen:**
```bash
ls -lh build-v2/kalon-wallet
```

**Erwartetes Ergebnis:** Datei existiert (~4MB)

**Finale Prüfung:**
```bash
ls -lh build-v2/
```

**Du solltest sehen:**
- kalon-node-v2 (~8MB)
- kalon-miner-v2 (~8MB)
- kalon-wallet (~4MB)

---

## 🗂 SCHRITT 4: Verzeichnis für Blockchain-Daten erstellen

```bash
rm -rf data-v2/testnet
mkdir -p data-v2/testnet
```

**Prüfen:**
```bash
ls -ld data-v2/testnet
```

**Erwartetes Ergebnis:** Verzeichnis erstellt.

---

## 🚀 SCHRITT 5: Node im Hintergrund starten

```bash
./build-v2/kalon-node-v2 -datadir data-v2/testnet -genesis genesis/testnet.json -rpc :16316 > /tmp/kalon_node.log 2>&1 &
```

**Prüfen ob Node läuft:**
```bash
sleep 3
ps aux | grep kalon-node-v2 | grep -v grep
```

**Erwartetes Ergebnis:** Process läuft (z.B. PID 12345)

**Node-Logs anzeigen:**
```bash
tail -20 /tmp/kalon_node.log
```

**Sollte enthalten:**
```
✅ Block #0 added successfully: ...
🚀 Professional RPC Server starting on :16316
```

---

## 💰 SCHRITT 6: Wallet erstellen

```bash
./build-v2/kalon-wallet create
```

**Wichtig:** Drücke ENTER für eine leere Passphrase (oder gib eine ein).

**Output wird sein:**
```
Wallet created successfully!
Address: ada68893c9c6fa324307c3964f1eb6d871253665
Public Key: ...
Mnemonic: word1 word2 word3 ... word12
Wallet saved to: wallet.json
```

**⚠️ KOPIERE DEINE ADRESSE UND MNEMONIC!**

**Beispiel:** Adresse: `ada68893c9c6fa324307c3964f1eb6d871253665`

**Wallet Info anzeigen:**
```bash
./build-v2/kalon-wallet info --input wallet.json
```

---

## ⛏ SCHRITT 7: Miner im Hintergrund starten

**Ersetze `DEINE_ADRESSE` mit der Adresse aus Schritt 6!**

```bash
./build-v2/kalon-miner-v2 \
  -wallet ada68893c9c6fa324307c3964f1eb6d871253665 \
  -threads 1 \
  -rpc http://localhost:16316 \
  > /tmp/kalon_miner.log 2>&1 &
```

**Prüfen ob Miner läuft:**
```bash
sleep 2
ps aux | grep kalon-miner-v2 | grep -v grep
```

**Erwartetes Ergebnis:** Process läuft.

**Miner-Logs anzeigen:**
```bash
tail -20 /tmp/kalon_miner.log
```

**Sollte enthalten:**
```
⛏ Mining worker 0 started
```

---

## ✅ SCHRITT 8: Blöcke prüfen

### 8.1 Aktuelle Height prüfen

```bash
curl -X POST http://localhost:16316/rpc \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"getHeight","params":{},"id":1}' | jq -r .result
```

**Erwartetes Ergebnis:** Eine Zahl (z.B. `12`)

### 8.2 Miner-Logs überwachen

**In einem neuen Terminal:**
```bash
tail -f /tmp/kalon_miner.log
```

**Oder aktuellen Status:**
```bash
cat /tmp/kalon_miner.log | grep "Block found"
```

**Erwartetes Ergebnis:** Sollte "Block found" Nachrichten zeigen!

**Beispiel:**
```
Block found by worker 0! Hash: abc123...
Block #3 submitted successfully
```

### 8.3 Best Block prüfen

```bash
curl -X POST http://localhost:16316/rpc \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"getBestBlock","params":{},"id":1}' | jq
```

**Sollte zeigen:** Aktueller Block

---

## 💰 SCHRITT 9: Balance prüfen

### 9.1 Balance mit curl prüfen

**Ersetze `DEINE_ADRESSE` mit deiner Wallet-Adresse!**

```bash
curl -X POST http://localhost:16316/rpc \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"getBalance","params":{"address":"ada68893c9c6fa324307c3964f1eb6d871253665"},"id":2}' | jq -r .result
```

**Erwartetes Ergebnis:** Eine Zahl > 0 (z.B. `5000000`)

### 9.2 Balance mit Wallet-Tool prüfen

```bash
./build-v2/kalon-wallet balance \
  --address ada68893c9c6fa324307c3964f1eb6d871253665 \
  --rpc http://localhost:16316
```

**Erwartetes Ergebnis:** JSON mit balance > 0

### 9.3 Balance überwachen (steigt langsam)

```bash
# Mehrmals ausführen und beobachten
watch -n 5 'curl -s -X POST http://localhost:16316/rpc -H "Content-Type: application/json" -d "{\"jsonrpc\":\"2.0\",\"method\":\"getBalance\",\"params\":{\"address\":\"ada68893c9c6fa324307c3964f1eb6d871253665\"},\"id\":2}" | jq -r .result'
```

**Erwartung:** Balance steigt langsam an!

---

## 🧪 SCHRITT 10: Verifizierung

### 10.1 Komplette System-Prüfung

```bash
echo "=== NODE STATUS ==="
ps aux | grep kalon-node-v2 | grep -v grep

echo ""
echo "=== MINER STATUS ==="
ps aux | grep kalon-miner-v2 | grep -v grep

echo ""
echo "=== HEIGHT ==="
curl -s -X POST http://localhost:16316/rpc \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"getHeight","params":{},"id":1}' | jq -r .result

echo ""
echo "=== BALANCE ==="
curl -s -X POST http://localhost:16316/rpc \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"getBalance","params":{"address":"DEINE_ADRESSE"},"id":2}' | jq -r .result
```

**Erwartung:**
- ✅ Node läuft
- ✅ Miner läuft
- ✅ Height > 0
- ✅ Balance > 0

---

## 🎉 FERTIG!

**Wenn alles funktioniert:**

- ✅ Node läuft im Hintergrund
- ✅ Miner mined Blöcke
- ✅ Blocks werden gefunden
- ✅ Balance steigt

**Du hast jetzt einen funktionierenden Kalon Testnet Node!**

---

## 🛑 SCHRITT 11: Alles beenden

```bash
pkill -f kalon-node-v2
pkill -f kalon-miner-v2
```

**Prüfen:**
```bash
ps aux | grep kalon | grep -v grep
```

**Erwartetes Ergebnis:** Keine Prozesse mehr.

---

## 📊 Übersicht: Was läuft wo?

```bash
# Alle Logs anzeigen
tail -20 /tmp/kalon_node.log
tail -20 /tmp/kalon_miner.log

# Height checken
curl -X POST http://localhost:16316/rpc \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"getHeight","params":{},"id":1}' | jq -r .result

# Balance checken
curl -X POST http://localhost:16316/rpc \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"getBalance","params":{"address":"DEINE_ADRESSE"},"id":2}' | jq -r .result
```

---

## 🔍 Troubleshooting

### Node startet nicht

```bash
# Logs prüfen
cat /tmp/kalon_node.log

# Port prüfen
netstat -tulpn | grep 16316
```

### Miner findet keine Blöcke

```bash
# Warte etwas (Mining braucht Zeit)
sleep 30

# Logs prüfen
tail -50 /tmp/kalon_miner.log
```

### Balance bleibt 0

```bash
# Prüfe ob Miner läuft
ps aux | grep kalon-miner-v2

# Prüfe Logs
tail -50 /tmp/kalon_miner.log | grep "submitted successfully"
```

---

## 📝 Zusammenfassung der Befehle

**Gesamte Sequenz (copy-paste):**

```bash
# 1. Repository
git clone https://github.com/Why-x-Phy/kalon-network.git
cd kalon-network

# 2. Bauen
go build -o build-v2/kalon-node-v2 cmd/kalon-node-v2/main.go
go build -o build-v2/kalon-miner-v2 cmd/kalon-miner-v2/main.go
go build -o build-v2/kalon-wallet cmd/kalon-wallet/main.go

# 3. Verzeichnisse
rm -rf data-v2/testnet && mkdir -p data-v2/testnet

# 4. Node starten
./build-v2/kalon-node-v2 -datadir data-v2/testnet -genesis genesis/testnet.json -rpc :16316 > /tmp/kalon_node.log 2>&1 &

# 5. Wallet erstellen
./build-v2/kalon-wallet create

# 6. Miner starten (MIT DEINER ADRESSE!)
./build-v2/kalon-miner-v2 -wallet DEINE_ADRESSE -threads 1 -rpc http://localhost:16316 > /tmp/kalon_miner.log 2>&1 &

# 7. Prüfen
sleep 5
curl -X POST http://localhost:16316/rpc -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getHeight","params":{},"id":1}' | jq -r .result

# 8. Balance prüfen (MIT DEINER ADRESSE!)
curl -X POST http://localhost:16316/rpc -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getBalance","params":{"address":"DEINE_ADRESSE"},"id":2}' | jq -r .result
```

**Ende!** 🎉

