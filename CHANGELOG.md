# Changelog

Alle wichtigen Änderungen an diesem Projekt werden in dieser Datei dokumentiert.

Das Format basiert auf [Keep a Changelog](https://keepachangelog.com/de/1.0.0/),
und dieses Projekt folgt [Semantic Versioning](https://semver.org/lang/de/).

## [1.3.0] - 2025-10-28

### Hinzugefügt
- LevelDB-Persistenz für Blockchain-Daten
- Rate Limiting für RPC-Server (60 req/min)
- IP Whitelist-Support für RPC-Server
- P2P-Netzwerk-Integration (Port :17335)
- Connection-Tracking für Sicherheit
- Graceful Shutdown für alle Services
- UTXO-Reconstruction beim Laden der Chain
- Umfassende Debug-Logs für Persistenz

### Geändert
- Blockchain lädt jetzt korrekt aus LevelDB beim Neustart
- Verbesserte Fehlerbehandlung für LevelDB-Operationen
- Optimierte Block-Speicherung mit Hex-String-Konvertierung

### Behoben
- LevelDB-Persistenz-Problem: Best Block wird jetzt korrekt geladen
- Hex-String zu Bytes Konvertierung in GetBestBlock
- Chain-Reset auf Height 0 beim Neustart behoben

### Technische Details
- LevelDB-Integration vollständig implementiert
- Sicherheits-Features aktiviert
- P2P-Netzwerk funktionsfähig
- Vollständiger End-to-End-Test erfolgreich

## [1.0.0] - 2025-10-27

### Hinzugefügt
- Grundlegende Blockchain-Funktionalität
- UTXO-System
- Mining-Algorithmus
- RPC-Server
- Wallet-System
- Block Explorer (statisch)
- Genesis-Konfiguration
- Testnet-Support

### Technische Details
- Go-basierte Implementierung
- SHA-256 Hash-Funktionen
- Bech32-Adressen
- JSON-RPC API
- Modularer Aufbau
