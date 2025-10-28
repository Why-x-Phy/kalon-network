# Release Notes

## Version 1.3.0 - "Persistence & Security Update" (2025-10-28)

### 🎉 Hauptfeatures

#### Persistente Datenbank (LevelDB)
- **Neue Funktion**: Blockchain-Daten werden jetzt dauerhaft gespeichert
- **Vorteil**: Node behält alle Blöcke und Transaktionen nach Neustart
- **Technik**: LevelDB-Integration mit automatischer UTXO-Reconstruction

#### Sicherheits-Verbesserungen
- **Rate Limiting**: Maximal 60 Anfragen pro Minute pro IP
- **IP Whitelist**: Konfigurierbare Zugriffskontrolle
- **Connection Tracking**: Überwachung aktiver Verbindungen

#### P2P-Netzwerk
- **Peer-to-Peer**: Nodes können sich untereinander verbinden
- **Port**: :17335 für P2P-Kommunikation
- **Graceful Shutdown**: Sauberes Beenden aller Services

### 🔧 Technische Verbesserungen

- **Persistenz-Fix**: Chain lädt korrekt aus LevelDB (Height wird beibehalten)
- **Hex-Konvertierung**: Korrekte Behandlung von Block-Hashes
- **Debug-Logs**: Umfassende Protokollierung für Troubleshooting
- **Error Handling**: Verbesserte Fehlerbehandlung für LevelDB-Operationen

### 🧪 Testing

- **Vollständiger Test**: End-to-End-Test mit 30+ Blöcken erfolgreich
- **Persistenz-Test**: Chain wird nach Neustart korrekt geladen
- **Mining-Test**: Blöcke werden erfolgreich gemined und gespeichert

### 📋 Kompatibilität

- **Backward Compatible**: Alle bestehenden Features funktionieren weiterhin
- **API**: RPC-API bleibt unverändert
- **Wallet**: Bestehende Wallets funktionieren ohne Änderungen

### 🚀 Installation

```bash
# Neueste Version herunterladen
git clone https://github.com/Why-x-Phy/kalon-network.git
cd kalon-network

# Kompilieren
go build -o build-v2/kalon-node-v2 cmd/kalon-node-v2/main.go
go build -o build-v2/kalon-miner-v2 cmd/kalon-miner-v2/main.go
go build -o build-v2/kalon-wallet cmd/kalon-wallet/main.go

# Node starten
./build-v2/kalon-node-v2 -datadir data-v2/testnet -genesis genesis/testnet.json -rpc :16316
```

### 🔗 Links

- **Repository**: https://github.com/Why-x-Phy/kalon-network
- **Documentation**: Siehe `docs/` Verzeichnis
- **Issues**: https://github.com/Why-x-Phy/kalon-network/issues

---

## Version 1.0.0 - "Initial Release" (2025-10-27)

### 🎉 Erste Version

- Grundlegende Blockchain-Funktionalität
- UTXO-System
- Mining-Algorithmus
- RPC-Server
- Wallet-System
- Block Explorer
- Testnet-Support

### Technische Details

- Go-basierte Implementierung
- SHA-256 Hash-Funktionen
- Bech32-Adressen
- JSON-RPC API
- Modularer Aufbau
