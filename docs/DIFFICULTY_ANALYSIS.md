# Difficulty Analysis

## Wie wird Difficulty aktuell definiert?

### 1. Genesis-Konfiguration (`genesis/testnet.json`)

```json
{
  "difficulty": {
    "algo": "LWMA",
    "window": 120,
    "initialDifficulty": 15,
    "maxAdjustPerBlockPct": 25,
    "launchGuard": {
      "enabled": false,
      "durationHours": 24,
      "difficultyFloorMultiplier": 1.0,
      "initialReward": 2.0
    }
  }
}
```

**Aktuelle Werte:**
- **Initial Difficulty:** 15
- **Launch Guard:** DEAKTIVIERT (enabled: false)
- **Window:** 120 Blöcke
- **Max Adjustment:** 25% pro Block

### 2. Difficulty-Berechnung (`core/consensus.go`)

Die Difficulty wird in `ConsensusManager.CalculateDifficulty()` berechnet:

**Aktueller Zustand:**
1. **Height 0:** `InitialDifficulty` (15)
2. **Launch Guard:** Aktuell deaktiviert, würde sonst `InitialDifficulty * DifficultyFloorMultiplier` verwenden
3. **Height < Window (120):** Parent Difficulty (keine Anpassung)
4. **Height >= Window:** **PROBLEM: `adjustmentFactor = 1.0` (keine echte Anpassung!)**

**WICHTIG:** Die LWMA-Implementierung ist aktuell **NICHT VOLLSTÄNDIG**:
- `adjustmentFactor` ist fest auf 1.0 gesetzt
- Es gibt **KEINE echte Block-Zeit-basierte Anpassung**
- Difficulty bleibt stabil (Parent Difficulty)

### 3. Proof of Work Validierung

**Testnet-Tolerance:**
- Difficulty <= 50000: **Akzeptiert alles** (keine echte PoW-Validierung)
- Difficulty > 50000: Echte PoW-Validierung aktiv

### 4. Wo wird Difficulty verwendet?

1. **Block-Erstellung:** `CreateNewBlockV2()` → `ConsensusManager.CalculateDifficulty()`
2. **Block-Validierung:** `ValidateBlock()` → `ConsensusManager.CalculateDifficulty()` (Prüft ob Difficulty korrekt)
3. **RPC:** `getMiningInfo` → `ConsensusManager.CalculateDifficulty()`

### 5. Aktuelles Problem

**Difficulty bleibt STABIL:**
- Nach Height 120 wird `adjustmentFactor = 1.0` verwendet
- Das bedeutet: **Difficulty ändert sich NIE**, bleibt bei Parent Difficulty
- **Keine echte LWMA-Implementierung**

## Mögliche Probleme auf Contabo VPS / Raspberry Pi

1. **CPU-Performance:** Langsamere CPU → Mining zu langsam → Timeouts
2. **I/O-Performance:** Langsamer Storage (HDD vs SSD) → LevelDB-Operationen zu langsam
3. **Speicher-Limits:** Nicht genug RAM → Prozess wird gekillt
4. **Go-Version:** Unterschiedliche Go-Version → Verhalten könnte anders sein
5. **Firewall:** Ports nicht freigegeben → RPC nicht erreichbar
6. **Prozess-Limits:** ulimit zu niedrig → Zu viele Datei-Deskriptoren

