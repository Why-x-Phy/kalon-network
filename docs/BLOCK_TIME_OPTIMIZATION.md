# Block-Zeit Optimierung: 15 Sekunden mit 1 Thread

## Ziel

- **Block-Zeit:** 15 Sekunden (aktuell: 30 Sekunden)
- **Ressourcen:** Wenig (1 Thread)
- **Fairness:** Gleiche Chance für alle
- **Limit:** Maximal 1 Block alle 15 Sekunden

## Aktuelle Konfiguration

**genesis/testnet.json:**
```json
{
  "blockTimeTargetSeconds": 30,  // ← Sollte auf 15 geändert werden
  "difficulty": {
    "initialDifficulty": 15,     // ← Zu niedrig für 15 Sekunden
    ...
  }
}
```

## Problem-Analyse

### 1. Aktuelle Difficulty (15)

**Berechnung:**
- Target = `1 << (64 - 15)` = `1 << 49` = 562 Billionen
- Bei Difficulty 15 wird der Block **sofort** gefunden (< 1 Sekunde)
- **ValidateProofOfWork** akzeptiert alles bei Difficulty <= 50000 (Testnet)

### 2. Block-Zeit-Limit

**Aktuell:** Keine Begrenzung der Mindest-Zeit zwischen Blöcken
- Miner kann mehrere Blöcke hintereinander finden
- Keine Zeit-Verzögerung nach Block-Fund

## Lösung (Nur Anpassungen)

### 1. Block-Zeit-Target anpassen

**genesis/testnet.json:**
```json
{
  "blockTimeTargetSeconds": 15,  // Von 30 auf 15 geändert
  ...
}
```

### 2. Initial Difficulty erhöhen

**Für ~15 Sekunden Block-Zeit mit 1 Thread:**

**Rough Calculation:**
- Bei Difficulty 15: Target = `1 << 49` → **sofort** (< 1 Sekunde)
- Bei Difficulty 20: Target = `1 << 44` → **~1-2 Sekunden**
- Bei Difficulty 22: Target = `1 << 42` → **~4-8 Sekunden**
- Bei Difficulty 23: Target = `1 << 41` → **~8-15 Sekunden** ✅
- Bei Difficulty 24: Target = `1 << 40` → **~15-30 Sekunden**
- Bei Difficulty 25: Target = `1 << 39` → **~30-60 Sekunden**

**Empfehlung:** `initialDifficulty: 23` für ~15 Sekunden mit 1 Thread

**genesis/testnet.json:**
```json
{
  "difficulty": {
    "initialDifficulty": 23,  // Von 15 auf 23 erhöht
    ...
  }
}
```

### 3. ValidateProofOfWork Toleranz anpassen

**Aktuell:** `core/consensus.go` akzeptiert alles bei Difficulty <= 50000

**Für 15 Sekunden Block-Zeit:**
- Difficulty 23-25 sollte valide PoW erfordern
- Toleranz bleibt bei Difficulty <= 50000 (OK für Testnet)

### 4. DifficultyAdjustment Target anpassen

**core/blockchain.go Zeile 659:**
```go
targetTime := 30 * time.Second  // ← Sollte auf 15 geändert werden
```

**Änderung:**
```go
targetTime := 15 * time.Second
```

## Empfohlene Anpassungen

### 1. genesis/testnet.json

```json
{
  "blockTimeTargetSeconds": 15,  // Von 30 auf 15
  "difficulty": {
    "initialDifficulty": 23,     // Von 15 auf 23
    ...
  }
}
```

### 2. core/blockchain.go Zeile 659

```go
targetTime := 15 * time.Second  // Von 30 auf 15
```

### 3. core/blockchain.go Zeile 119 (falls vorhanden)

```go
blockTime:  15 * time.Second,  // Von 30 auf 15
```

## Erwartetes Verhalten nach Anpassung

1. **Mining-Zeit:** ~15 Sekunden pro Block (statt sofort)
2. **Difficulty:** 23 (statt 15)
3. **Block-Zeit:** Durchschnittlich 15 Sekunden
4. **1 Thread:** Ausreichend für 15 Sekunden Block-Zeit
5. **Fairness:** Alle Miner haben gleiche Chance

## Testing

**Nach Anpassung:**
```bash
# Test mit 1 Thread
./build-v2/kalon-miner-v2 -threads 1 -wallet YOUR_WALLET

# Prüfe Block-Zeit:
tail -f node.log | grep "Block.*added"

# Block-Zeit sollte ~15 Sekunden sein
```

## Anpassungen ohne Code-Änderungen

**Nur Konfigurationswerte ändern:**
1. ✅ `genesis/testnet.json`: `blockTimeTargetSeconds: 15`
2. ✅ `genesis/testnet.json`: `initialDifficulty: 23`
3. ⚠️ `core/blockchain.go`: `targetTime := 15 * time.Second` (kleine Code-Anpassung)

**Optional (für strikte 15 Sekunden Begrenzung):**
- Miner könnte nach Block-Fund 15 Sekunden warten (aber Benutzer sagt "nichts ändern")

