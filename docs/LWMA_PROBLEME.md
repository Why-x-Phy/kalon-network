# LWMA Integration - Identifizierte Probleme

## Zusammenfassung
Die LWMA (Linearly Weighted Moving Average) Difficulty Adjustment Integration verursacht Performance-Probleme und Deadlocks, die dazu führen, dass der Miner keine Block-Templates mehr erstellen kann.

## Symptome
- **RPC-Timeout-Fehler**: `context deadline exceeded (Client.Timeout exceeded while awaiting headers)`
- **Miner hängt**: "Waiting for blocks to be mined..." - keine Blöcke werden mehr gefunden
- **createBlockTemplate blockiert**: RPC-Server antwortet nicht mehr auf `createBlockTemplate`-Anfragen

## Root Cause Analysis

### Problem 1: Lock Contention in `reorganizeChain`
**Lage**: `core/blockchain.go`, Funktion `reorganizeChain` (ursprünglich Zeile 636-777)

**Problem**:
- `reorganizeChain` hält den Write-Lock (`bc.mu.Lock()`) während der **gesamten** Reorganisation
- Dies blockiert alle `createBlockTemplate`-Aufrufe, die `GetBlockHistoryForDifficulty` benötigen (benötigt RLock)
- Während einer Reorganisation können keine neuen Block-Templates erstellt werden

**Betroffene Operationen**:
- `findCommonParent` - benötigt Zugriff auf `bc.blocks` und `bc.blockIndex`
- `blocksToRemove` und `blocksToAdd` Sammlung - benötigt Zugriff auf `bc.blocks`
- UTXO-Rollback - benötigt Zugriff auf `bc.utxoSet`
- Block-Array-Modifikation - benötigt Write-Lock für `bc.blocks`

### Problem 2: Lock Contention in `GetBlockHistoryForDifficulty`
**Lage**: `core/blockchain.go`, Funktion `GetBlockHistoryForDifficulty` (ursprünglich Zeile 1297-1344)

**Problem**:
- Iteriert durch `bc.blocks` während RLock gehalten wird
- Wenn `reorganizeChain` gleichzeitig `bc.blocks` modifiziert, kann es zu Race Conditions kommen
- Lock wird zu lange gehalten während der Iteration

**Betroffene Operationen**:
- Iteration durch `bc.blocks` Array (kann groß sein)
- Timestamp-Extraktion für alle Blöcke im Window

### Problem 3: Lock Contention in `addBlockV2`
**Lage**: `core/blockchain.go`, Funktion `addBlockV2` (ursprünglich Zeile 181-356)

**Problem**:
- `validateBlockV2WithParent` ruft `GetBlockHistoryForDifficulty` auf
- Wenn dies innerhalb des Write-Locks passiert, blockiert es alle Read-Operationen
- Validierung sollte außerhalb des Write-Locks erfolgen

## Versuchte Lösungen

### Lösung 1: Validierung außerhalb des Write-Locks verschieben
**Status**: ✅ Implementiert, aber Problem besteht weiterhin

**Änderungen**:
- `addBlockV2` holt RLock für Snapshot, gibt Lock frei, validiert außerhalb, holt dann Write-Lock nur für State-Änderungen
- `validateBlockV2WithParent` ruft `GetBlockHistoryForDifficulty` auf (außerhalb Write-Lock)

**Ergebnis**: Verbesserung, aber Problem besteht weiterhin wegen `reorganizeChain`

### Lösung 2: `reorganizeChain` Lock-Optimierung
**Status**: ✅ Implementiert, aber Problem besteht weiterhin

**Änderungen**:
- Lock nur für State-Änderungen, nicht für gesamte Reorganisation
- `findCommonParent` und Block-Listen-Sammlung außerhalb Write-Lock
- Write-Lock nur für kritische State-Änderungen (UTXO-Rollback, Block-Array-Modifikation)

**Ergebnis**: Verbesserung, aber Problem besteht weiterhin wegen `GetBlockHistoryForDifficulty`

### Lösung 3: `GetBlockHistoryForDifficulty` Snapshot-Optimierung
**Status**: ✅ Implementiert, aber Problem besteht weiterhin

**Änderungen**:
- Erstellt Snapshot-Kopie von Block-Pointern während RLock
- Gibt Lock schnell frei und iteriert über Snapshot außerhalb Lock
- Minimiert Lock-Contention

**Ergebnis**: Verbesserung, aber Problem besteht weiterhin

## Verbleibendes Problem

Trotz aller Optimierungen besteht das Problem weiterhin:
- **Miner erhält RPC-Timeout-Fehler**
- **createBlockTemplate hängt**

**Mögliche Ursachen**:
1. **Deadlock**: Möglicherweise gibt es einen Deadlock zwischen verschiedenen Lock-Operationen
2. **Zu viele gleichzeitige Requests**: Vielleicht gibt es zu viele gleichzeitige `createBlockTemplate`-Anfragen
3. **Storage-I/O**: Möglicherweise blockiert Storage-I/O in `addBlockV2` oder `reorganizeChain`
4. **Andere Blockierung**: Möglicherweise gibt es eine andere Blockierung, die wir noch nicht identifiziert haben

## Empfohlene nächste Schritte

1. **Deadlock-Analyse**: Prüfen, ob es einen Deadlock gibt (z.B. mit `go tool pprof` oder Race Detector)
2. **Lock-Tracing**: Lock-Operationen loggen, um zu sehen, welche Locks wann gehalten werden
3. **Timeout-Mechanismus**: Timeout für `createBlockTemplate` einführen, um hängende Requests zu vermeiden
4. **Alternative Architektur**: Eventuell LWMA-Berechnung asynchron durchführen oder in separatem Thread
5. **Lock-Free-Algorithmen**: Eventuell Lock-Free-Datenstrukturen für Block-Historie verwenden

## Baseline-Test (ohne LWMA)

**Datum**: 2025-11-12
**Ergebnis**: ✅ **ERFOLGREICH**
- 5 Blöcke gemined
- Best Block: #16
- Wallet-Balances korrekt
- Transaction erfolgreich
- Merkle Root und Difficulty vorhanden
- Keine kritischen Fehler
- Lock-Performance gut (7ms für 20 concurrent requests)

**Fazit**: Das System funktioniert **perfekt ohne LWMA**. Die Probleme entstehen erst durch die LWMA-Integration.

## Dateien mit LWMA-Änderungen

1. `core/blockchain.go`:
   - `GetBlockHistoryForDifficulty` Funktion hinzugefügt
   - `CreateNewBlockV2` ruft `GetBlockHistoryForDifficulty` auf
   - `validateBlockV2WithParent` ruft `GetBlockHistoryForDifficulty` auf

2. `core/consensus.go`:
   - `CalculateDifficulty` akzeptiert jetzt `blockHistory []time.Time` Parameter
   - LWMA-Algorithmus implementiert

3. `rpc/server_v2.go`:
   - `handleGetMiningInfo` ruft `GetBlockHistoryForDifficulty` auf

4. `core/difficulty_test.go`:
   - Tests angepasst für `blockHistory` Parameter

## Konfiguration

**Genesis-Konfiguration** (`genesis/testnet.json`):
```json
"Difficulty": {
  "Window": 120,
  "MaxAdjustPerBlockPct": 10
}
```

**Block-Time-Target**: 15 Sekunden (aus `genesis.BlockTimeTarget`)

