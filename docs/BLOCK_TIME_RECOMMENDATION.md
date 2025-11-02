# Block-Zeit Empfehlung und Strategie

## Ziele

1. **Stabilität**: Eine der stabilsten Blockchains
2. **Fairness**: Gleiche Chance für alle (Contabo VPS, Raspberry Pi)
3. **Geschwindigkeit**: Transaktionen in wenigen Sekunden
4. **Einfachheit**: Nur 1-2 zentrale Werte zum Anpassen
5. **Effizienz**: Mit wenig Ressourcen (1 Thread)

## Aktuelle Situation

### Probleme:
1. **ValidateProofOfWork** akzeptiert alles bei Difficulty <= 50000
   - Difficulty 15 → Blöcke werden **SOFORT** gefunden
   - Keine echte Mining-Zeit → Keine Fairness

2. **Block-Zeit** ist nicht kontrolliert
   - `blockTimeTargetSeconds: 30` wird ignoriert
   - Tatsächliche Block-Zeit: SOFORT (weil PoW deaktiviert)

3. **Difficulty** ist zu niedrig
   - `initialDifficulty: 15` → Zu leicht für echte Mining-Zeit

4. **LWMA Difficulty Adjustment** ist nicht vollständig implementiert
   - `adjustmentFactor = 1.0` (keine echte Anpassung)

## Empfehlung

### 1. Block-Zeit: **15 Sekunden**

**Warum 15 Sekunden?**
- ✅ Gut für schnelle Transaktionen (wenige Sekunden)
- ✅ Stabil genug für Raspberry Pi / Contabo VPS
- ✅ Fair: Alle haben gleiche Chance (1 Thread)
- ✅ Ausreichend Zeit für Block-Propagation
- ✅ Nicht zu schnell → Weniger Konflikte

**Alternative:** 30 Sekunden wäre auch OK, aber langsamer für Transaktionen.

### 2. Zentrale Konfigurationswerte (nur 2 Werte!)

**Empfehlung:** Nur 2 Werte in `genesis/testnet.json` anpassen:

#### Wert 1: `blockTimeTargetSeconds`
- **Zweck:** Block-Zeit-Ziel (z.B. 15 Sekunden)
- **Verwendung:** 
  - Difficulty Adjustment (LWMA)
  - Block-Validierung (Min/Max Time-Between-Blocks)
  - Network-Synchronisation

#### Wert 2: `initialDifficulty`
- **Zweck:** Start-Schwierigkeit
- **Berechnung für 15 Sekunden Block-Zeit:**
  - Mit 1 Thread: Difficulty ~23-25
  - Mit Raspberry Pi: Difficulty ~20-23
  - Mit Contabo VPS: Difficulty ~23-25

**Aktueller Vorschlag:**
```json
{
  "blockTimeTargetSeconds": 15,
  "difficulty": {
    "initialDifficulty": 23,  // Für ~15 Sekunden mit 1 Thread
    ...
  }
}
```

### 3. Proof of Work Aktivierung

**Problem:** Aktuell akzeptiert `ValidateProofOfWork` alles bei Difficulty <= 50000

**Empfehlung:**
- **Option A:** Toleranz reduzieren (z.B. Difficulty <= 100)
  - Difficulty 23 würde dann echte PoW erfordern
  - **Pro:** Echte Mining-Zeit, Fairness
  - **Con:** Raspberry Pi könnte zu langsam sein

- **Option B:** "Smart Difficulty" - Adaptive Toleranz
  - Difficulty 1-20: PoW deaktiviert (für Testnet)
  - Difficulty 21-50: Leichte PoW-Validierung
  - Difficulty >50: Volle PoW-Validierung
  - **Pro:** Balance zwischen Testnet und Fairness
  - **Con:** Komplexer

- **Option C (Empfohlen):** Difficulty-basierte Toleranz
  - Difficulty 1-20: PoW deaktiviert (Testnet)
  - Difficulty 21-30: Leichte PoW-Validierung (10% Toleranz)
  - Difficulty >30: Volle PoW-Validierung
  - **Pro:** Einfach, Fair, Funktioniert mit Raspberry Pi
  - **Con:** Benötigt Code-Anpassung

**Aktueller Code (core/consensus.go:131):**
```go
if block.Header.Difficulty <= 50000 {
    return true  // Akzeptiert alles → SOFORT
}
```

**Empfohlene Änderung:**
```go
if block.Header.Difficulty <= 20 {
    return true  // Nur für sehr niedrige Difficulty (Testnet)
}
// Sonst: Echte PoW-Validierung
```

### 4. LWMA Difficulty Adjustment

**Problem:** Aktuell ist `adjustmentFactor = 1.0` (keine Anpassung)

**Empfehlung:**
- **Vollständige LWMA-Implementierung** aktivieren
- Basierend auf `blockTimeTargetSeconds` (15 Sekunden)
- Automatische Anpassung wenn Blöcke zu schnell/langsam

**Funktionsweise:**
1. Sammle Block-Zeiten der letzten 120 Blöcke
2. Berechne Durchschnitts-Block-Zeit
3. Vergleiche mit `blockTimeTargetSeconds` (15 Sekunden)
4. Passe Difficulty an:
   - Zu schnell → Difficulty erhöhen
   - Zu langsam → Difficulty senken
5. Max 25% Änderung pro Block (bereits konfiguriert)

### 5. Block-Zeit-Validierung

**Empfehlung:** Min/Max Time-Between-Blocks

**Implementierung:**
- Min: 5 Sekunden (zu schnell = Reject)
- Max: 60 Sekunden (zu langsam = Warning)
- Target: 15 Sekunden (von `blockTimeTargetSeconds`)

**Code-Beispiel:**
```go
// In validateBlockV2()
minBlockTime := 5 * time.Second
maxBlockTime := 60 * time.Second
targetBlockTime := time.Duration(genesis.BlockTimeTarget) * time.Second

if parent != nil {
    timeSinceParent := block.Header.Timestamp.Sub(parent.Header.Timestamp)
    if timeSinceParent < minBlockTime {
        return fmt.Errorf("block too fast: %v < %v", timeSinceParent, minBlockTime)
    }
    if timeSinceParent > maxBlockTime {
        log.Printf("WARNING: Block too slow: %v > %v", timeSinceParent, maxBlockTime)
    }
}
```

## Zusammenfassung der Empfehlung

### Zentrale Werte (nur 2 Werte!):

1. **`blockTimeTargetSeconds: 15`**
   - Ziel-Block-Zeit
   - Wird für Difficulty Adjustment verwendet
   - Wird für Block-Validierung verwendet

2. **`initialDifficulty: 23`**
   - Start-Schwierigkeit
   - Für ~15 Sekunden Block-Zeit mit 1 Thread
   - LWMA passt automatisch an

### Code-Anpassungen (minimal):

1. **ValidateProofOfWork Toleranz reduzieren:**
   - Von Difficulty <= 50000 → Difficulty <= 20
   - Difficulty 23 würde dann echte PoW erfordern

2. **LWMA vollständig implementieren:**
   - `adjustmentFactor` basierend auf Block-Zeit berechnen
   - Nicht fest auf 1.0 setzen

3. **Block-Zeit-Validierung:**
   - Min/Max Time-Between-Blocks prüfen
   - Basierend auf `blockTimeTargetSeconds`

### Erwartetes Verhalten:

- ✅ **Block-Zeit:** ~15 Sekunden (durch Difficulty 23)
- ✅ **Transaktionen:** In wenigen Sekunden bestätigt
- ✅ **Fairness:** Alle haben gleiche Chance (1 Thread)
- ✅ **Stabilität:** Funktioniert auf Raspberry Pi
- ✅ **Einfachheit:** Nur 2 Werte anpassen

### Vorteile:

1. **Zentral:** Nur 2 Werte (`blockTimeTargetSeconds`, `initialDifficulty`)
2. **Fair:** Echte Mining-Zeit (kein "Sofort-Finden")
3. **Schnell:** Transaktionen in wenigen Sekunden
4. **Stabil:** Funktioniert mit wenig Ressourcen
5. **Anpassbar:** Difficulty passt automatisch an (LWMA)

## Alternative Strategien

### Strategie A: Konservativ (30 Sekunden)
- `blockTimeTargetSeconds: 30`
- `initialDifficulty: 25`
- **Pro:** Sehr stabil
- **Con:** Langsamere Transaktionen

### Strategie B: Aggressiv (10 Sekunden)
- `blockTimeTargetSeconds: 10`
- `initialDifficulty: 20`
- **Pro:** Sehr schnelle Transaktionen
- **Con:** Mehr Konflikte, weniger stabil

### Strategie C: Empfohlen (15 Sekunden) ✅
- `blockTimeTargetSeconds: 15`
- `initialDifficulty: 23`
- **Pro:** Balance zwischen Geschwindigkeit und Stabilität

## Empfehlung: **Strategie C (15 Sekunden)**

Begründung:
- Gut für Transaktionen (wenige Sekunden)
- Stabil genug für Raspberry Pi
- Fair (gleiche Chance für alle)
- Einfach (nur 2 Werte anpassen)

