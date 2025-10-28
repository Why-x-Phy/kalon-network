# Mining Setup - Vom neuen Server

## 📋 Übersicht

Um von einem neuen Server zu minen, muss dieser Server:

1. ✅ Node starten und mit Master synchronisieren
2. ✅ Wallet erstellen
3. ✅ Miner starten (nach Sync)

## 🚀 Schritt-für-Schritt Anleitung

### Schritt 1: Node starten und mit Master verbinden

**Auf dem neuen Server:**

```bash
# 1. Cleanup
rm -rf data-new-node wallet-miner.json

# 2. Node starten mit Master-Verbindung
./build-v2/kalon-node-v2 \
  -datadir data-new-node \
  -genesis genesis/testnet.json \
  -rpc :16316 \
  -p2p :17335 \
  -seednodes "MASTER-IP:17335"
```

**Was passiert:**
- Node verbindet sich mit Master
- Lädt alle Blöcke vom Master
- Synchronisiert auf die gleiche Height
- Speichert alle Daten in LevelDB

**Synchronisierung prüfen:**
```bash
# Prüfe Height (sollte gleich wie Master sein)
curl http://localhost:16316/rpc \
  -d '{"jsonrpc":"2.0","method":"getHeight","id":1}'
```

### Schritt 2: Wallet erstellen

**Nach der Synchronisierung:**

```bash
# Wallet erstellen
./build-v2/kalon-wallet create --name miner

# Adresse anzeigen
cat wallet-miner.json | jq -r .address
```

### Schritt 3: Miner starten

**Jetzt kann der Miner gestartet werden:**

```bash
# Miner starten
WALLET=$(cat wallet-miner.json | jq -r .address)

./build-v2/kalon-miner-v2 \
  -wallet "$WALLET" \
  -threads 4 \
  -rpc http://localhost:16316
```

**Was passiert:**
- Miner verbindet mit lokaler Node (localhost:16316)
- Bekommt Block Template von lokaler Node
- Lokale Node hat bereits die aktuelle Height
- Wenn Block gefunden wird, schickt Miner ihn an lokale Node
- Lokale Node validiert und added den Block
- Block wird per P2P an Master und alle Peers broadcastet

## 📊 Visualisierung

```
Master Server                    New Server
┌──────────────┐                ┌──────────────┐
│  Master Node │                │  New Node    │
│              │◄───P2P───────►│              │
│  Height 500  │   Sync         │  Height 500  │
└──────────────┘                └──────┬───────┘
                                       │
                                  ┌────▼─────┐
                                  │   Miner  │
                                  │          │
                                  └──────────┘
```

**Ablauf:**
1. New Node verbindet per P2P mit Master
2. New Node lädt alle 500 Blöcke
3. New Node ist jetzt synchronisiert
4. Miner verbindet mit lokaler Node
5. Wenn Miner einen Block findet, wird er zur lokalen Node gesendet
6. Lokale Node sendet Block per P2P an Master und alle Peers

## ⚠️ Wichtige Punkte

### ❌ FALSCH - Miner ohne Sync starten

```bash
# Node UND Miner gleichzeitig starten - FUNKTIONIERT NICHT!
./build-v2/kalon-node-v2 -seednodes "MASTER-IP:17335" &
./build-v2/kalon-miner-v2 -wallet "$WALLET" &  # ❌ Zu früh!
```

**Problem:** Node ist noch nicht synchronisiert (Height 0), Miner bekommt alte Block Templates

### ✅ RICHTIG - Erst Sync, dann Mining

```bash
# 1. Node starten
./build-v2/kalon-node-v2 -seednodes "MASTER-IP:17335"

# 2. Warten bis Sync fertig (Height prüfen!)
curl .../getHeight  # sollte Master Height zeigen

# 3. DANACH Miner starten
./build-v2/kalon-miner-v2 -wallet "$WALLET"
```

**Vorteil:** Node hat aktuelle Height, Miner arbeitet mit korrekten Block Templates

## 🔍 Synchronisation Status prüfen

### Auf dem neuen Server

```bash
# 1. Height prüfen
HEIGHT_NEW=$(curl -s http://localhost:16316/rpc \
  -d '{"jsonrpc":"2.0","method":"getHeight","id":1}' \
  | jq -r .result)
echo "New Node Height: $HEIGHT_NEW"

# 2. Master Height prüfen (vom Master Server)
HEIGHT_MASTER=$(curl -s http://MASTER-IP:16316/rpc \
  -d '{"jsonrpc":"2.0","method":"getHeight","id":1}' \
  | jq -r .result)
echo "Master Height: $HEIGHT_MASTER"

# 3. Vergleich
if [ "$HEIGHT_NEW" = "$HEIGHT_MASTER" ]; then
  echo "✅ Synchronisiert!"
else
  echo "⏳ Noch synchronisieren..."
fi
```

## 🎯 Vollständiges Beispiel

### Auf neuem Server:

```bash
#!/bin/bash

# 1. Cleanup
rm -rf data-testnet wallet-miner.json
mkdir -p data-testnet

# 2. Node starten
echo "🚀 Starte Node und synchronisiere..."
./build-v2/kalon-node-v2 \
  -datadir data-testnet \
  -genesis genesis/testnet.json \
  -rpc :16316 \
  -p2p :17335 \
  -seednodes "192.168.1.100:17335" &  # Master IP

# 3. Warten bis Sync
echo "⏳ Warte auf Synchronisation..."
for i in {1..60}; do
  HEIGHT=$(curl -s http://localhost:16316/rpc \
    -d '{"jsonrpc":"2.0","method":"getHeight","id":1}' \
    | jq -r .result)
  
  if [ "$HEIGHT" != "0" ]; then
    echo "✅ Synchronisiert! Height: $HEIGHT"
    break
  fi
  sleep 2
done

# 4. Wallet erstellen
echo "💰 Erstelle Wallet..."
echo "" | ./build-v2/kalon-wallet create --name miner > /dev/null 2>&1
WALLET=$(cat wallet-miner.json | jq -r .address)
echo "Wallet: $WALLET"

# 5. Miner starten
echo "⛏️  Starte Miner..."
./build-v2/kalon-miner-v2 \
  -wallet "$WALLET" \
  -threads 4 \
  -rpc http://localhost:16316
```

## 📝 Zusammenfassung

**Die richtige Reihenfolge:**

1. ✅ **Node starten** mit `-seednodes MASTER-IP:17335`
2. ✅ **Warten auf Sync** bis Height = Master Height
3. ✅ **Wallet erstellen** mit `kalon-wallet create`
4. ✅ **Miner starten** mit Wallet-Adresse

**Warum diese Reihenfolge wichtig ist:**
- Node braucht die aktuelle Height für Block Templates
- Miner braucht einen synchronisierten Node
- Ohne Sync kann Miner nur alte Blöcke erstellen

## 🎉 Ready to Mine!

Nach der Synchronisation ist der neue Server bereit zum Minen!

Die gefundenen Blöcke werden:
1. Zur lokalen Node gesendet
2. Von der lokalen Node validiert
3. Per P2P an Master und alle Peers broadcastet
4. In der Blockchain gespeichert
