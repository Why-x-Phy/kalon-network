# Kalon Network - Architektur und Konfiguration

## 📋 Überblick

Die Kalon Blockchain ist eine **dezentrale Peer-to-Peer Blockchain** mit folgenden Komponenten:

### Kern-Komponenten

1. **Kalon Node** (`kalon-node-v2`)
   - Blockchain-Kern mit LevelDB-Persistenz
   - RPC-Server auf Port `:16316` für JSON-RPC API
   - P2P-Netzwerk auf Port `:17335` für Peer-Kommunikation

2. **Kalon Miner** (`kalon-miner-v2`)
   - Mining von neuen Blöcken
   - Verbindung zum RPC-Server
   - Belohnungen (Block Rewards)

3. **Kalon Wallet** (`kalon-wallet`)
   - Wallet-Verwaltung
   - Transaktionen erstellen
   - Balance-Abfragen

4. **Block Explorer** (`explorer-api`)
   - REST API auf Port `:8081`
   - Blockchain-Daten anzeigen

## 🏗️ Architektur

```
┌─────────────────────────────────────────────────────────────┐
│                     KALON NETWORK                           │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │
│  │ Master Node  │  │  Node 2      │  │  Node 3      │    │
│  │              │  │              │  │              │    │
│  │ P2P :17335   │◄─┼─►P2P :17335 │◄─┼─►P2P :17335 │    │
│  │ RPC :16316   │  │ RPC :16316   │  │ RPC :16316   │    │
│  └──────┬───────┘  └──────────────┘  └──────────────┘    │
│         │                                                   │
│         ▼                                                   │
│  ┌───────────────────────────────────────────────────┐    │
│  │           LevelDB Persistence                     │    │
│  │  ┌─────────────┐  ┌──────────────┐               │    │
│  │  │  Blocks     │  │   UTXOs      │               │    │
│  │  └─────────────┘  └──────────────┘               │    │
│  └───────────────────────────────────────────────────┘    │
│                                                             │
│  ┌──────────────┐                                          │
│  │   Miner      │──► Mining (Block Creation)              │
│  └──────────────┘                                          │
│                                                             │
│  ┌──────────────┐                                          │
│  │   Explorer   │──► REST API (:8081)                     │
│  └──────────────┘                                          │
└─────────────────────────────────────────────────────────────┘
```

## 🌐 Master Node vs. Slave Nodes

### Master Node

**Aufgaben:**
- Erste Node im Netzwerk
- Mining von neuen Blöcken
- Blockchain-History verwalten
- P2P-Server für andere Nodes

**Start-Kommando:**
```bash
./build-v2/kalon-node-v2 \
  -datadir data-v2/testnet \
  -genesis genesis/testnet.json \
  -rpc :16316 \
  -p2p :17335
```

**Eigenschaften:**
- Läuft ohne Seed-Node-Konfiguration
- Andere Nodes verbinden sich zu dieser Node
- Has the longest chain (höchste Height)

### Slave Nodes (Worker Nodes)

**Aufgaben:**
- Synchronisieren mit Master Node
- Blockchain-Daten speichern
- Transaktionen weiterleiten
- P2P-Kommunikation

**Start-Kommando (mit Seed/Master):**
```bash
./build-v2/kalon-node-v2 \
  -datadir data-v2/testnet \
  -genesis genesis/testnet.json \
  -rpc :16316 \
  -p2p :17335 \
  -seednodes "master-ip:17335"
```

## 🔌 P2P-Verbindung

### Wie sich Nodes verbinden

1. **Master Node starten** (ohne Seed Nodes):
   ```bash
   # Master Node
   ./build-v2/kalon-node-v2 -datadir data-master -genesis genesis/testnet.json -rpc :16316 -p2p :17335
   ```

2. **Slave Node starten** (mit Master als Seed):
   ```bash
   # Slave Node
   ./build-v2/kalon-node-v2 -datadir data-slave -genesis genesis/testnet.json -rpc :16317 -p2p :17336 -seednodes "master-ip:17335"
   ```

### Kommunikation

- **Version Exchange**: Beim Verbinden tauschen Nodes ihre Versionen aus
- **Height Comparison**: Nodes vergleichen ihre Block-Höhe
- **Block Sync**: Node mit niedriger Höhe lädt fehlende Blöcke vom Master
- **Broadcasting**: Neue Blöcke werden an alle Peers weitergegeben

### Microbial Protocol

Die P2P-Kommunikation nutzt JSON-Format über TCP:

```json
{
  "type": "version",
  "data": {"version": "1.0"},
  "version": "1.0",
  "time": "2025-10-28T14:00:00Z"
}
```

**Message Types:**
- `version`: Version-Exchange
- `block`: Block-Broadcast
- `transaction`: Transaction-Broadcast
- `get_blocks`: Request fehlende Blöcke
- `blocks`: Response mit Blöcken
- `ping`: Health Check
- `pong`: Health Response

## 📊 Chain Synchronization

### Wie funktioniert die Synchronisation?

1. **Initial Connection**:
   - Slave Node verbindet sich mit Master
   - Tauscht Version und Height aus

2. **Height Comparison**:
   - Slave: Height = 0
   - Master: Height = 500
   - Slave erkennt niedrigere Höhe

3. **Block Request**:
   - Slave sendet `get_blocks` mit Start-Height
   - Master sendet `blocks` mit fehlenden Blöcken

4. **Block Processing**:
   - Slave verarbeitet erhaltene Blöcke
   - Validiert und fügt zur Chain hinzu
   - Aktualisiert LevelDB

5. **Synchronization Complete**:
   - Slave hat jetzt Height = 500
   - Bereit für neue Blöcke

### Wichtige P2P-Funktionen

```go
// Peer verbinden
func connectToPeer(address string)

// Block-Broadcast an alle Peers
func BroadcastBlock(block *Block)

// Block-Sync anfragen
func handleGetBlocksMessage(peer, message)

// Height vergleichen
func compareHeights(local, remote uint64) bool
```

## 🔧 Konfiguration

### P2P Config (network/p2p.go)

```go
type P2PConfig struct {
    ListenAddr    string        // ":17335"
    SeedNodes     []string      // ["master-ip:17335"]
    MaxPeers      int           // 10
    DialTimeout   time.Duration // 5s
    ReadTimeout   time.Duration // 30s
    WriteTimeout  time.Duration // 30s
    KeepAlive     time.Duration // 60s
}
```

### Beispiel-Konfiguration

**Master Node (ohne Seeds):**
```go
SeedNodes: []string{}  // Empty - wir sind der Master
```

**Slave Node (mit Master als Seed):**
```go
SeedNodes: []string{"192.168.1.100:17335"}  // Master IP
```

## 🚀 Praktisches Beispiel

### Master Node Setup

```bash
# 1. Cleanup
rm -rf data-master wallet-master.json

# 2. Wallet erstellen
./build-v2/kalon-wallet create --name master

# 3. Master Node starten
./build-v2/kalon-node-v2 \
  -datadir data-master \
  -genesis genesis/testnet.json \
  -rpc :16316 \
  -p2p :17335

# 4. Miner starten (optional)
./build-v2/kalon-miner-v2 \
  -wallet "$(cat wallet-master.json | jq -r .address)" \
  -rpc http://localhost:16316
```

### Slave Node Setup (auf anderem Server)

```bash
# 1. Cleanup
rm -rf data-slave wallet-slave.json

# 2. Wallet erstellen
./build-v2/kalon-wallet create --name slave

# 3. Slave Node starten (mit Master als Seed)
# Wichtig: -seednodes "master-ip:17335"
./build-v2/kalon-node-v2 \
  -datadir data-slave \
  -genesis genesis/testnet.json \
  -rpc :16317 \
  -p2p :17336 \
  -seednodes "192.168.1.100:17335"  # Master IP

# Die Node wird automatisch:
# - Mit Master verbinden
# - Height vergleichen
# - Fehlende Blöcke laden
# - Synchronisiert werden
```

## 📝 Wichtige Punkte

1. **Master Node**: Muss zuerst gestartet werden, keine Seed Nodes nötig
2. **Slave Nodes**: Verbinden sich mit Master über `-seednodes` Flag
3. **Height Sync**: Automatisch - Slave lädt fehlende Blöcke
4. **P2P Port**: Standard ist `:17335` (kann geändert werden)
5. **RPC Port**: Standard ist `:16316` (kann geändert werden)
6. **Firewall**: Port 17335 (P2P) muss für andere Nodes erreichbar sein

## 🔍 Debugging

### Peer-Status prüfen:
```bash
# Prüfe ob Node läuft
ps aux | grep kalon-node

# Prüfe RPC-Port
curl http://localhost:16316/rpc -d '{"jsonrpc":"2.0","method":"getHeight","id":1}'

# Prüfe P2P-Port
netstat -an | grep 17335

# Logs prüfen
tail -f /tmp/kalon-node.log
```

## 🎯 Zusammenfassung

- **Master Node**: Erste Node, minet Blöcke, keine Seeds nötig
- **Slave Nodes**: Verbinden über `-seednodes master-ip:17335`
- **Auto-Sync**: Automatische Synchronisation der Block-Height
- **P2P**: TCP-basiert, Port :17335
- **RPC**: JSON-RPC, Port :16316
- **Persistenz**: LevelDB speichert alles dauerhaft
