# LWMA Integration - Lösung

## Problem-Zusammenfassung
Die LWMA-Integration verursacht Lock-Contention, die dazu führt, dass `createBlockTemplate` blockiert und der Miner keine Block-Templates mehr erstellen kann.

## Lösung: Event-basierte Block-Historie mit separatem Lock

### Konzept
1. **Separate Block-History-Struktur**: Eine neue Struktur `BlockHistory` verwaltet die Block-Timestamps unabhängig vom Haupt-Lock
2. **Event-basierte Updates**: Die Historie wird nur bei Block-Hinzufügung aktualisiert (in `addBlockV2`), nicht bei jedem `createBlockTemplate`-Aufruf
3. **Lock-Free-Lesen**: Die Difficulty-Berechnung kann die Historie ohne Haupt-Lock lesen, da sie nur Timestamps enthält (immutable Daten)
4. **Minimale Lock-Zeit**: Nur für das Hinzufügen eines neuen Timestamps, nicht für die gesamte Berechnung

### Vorteile
- ✅ **Keine Blockierung**: `createBlockTemplate` blockiert nicht mehr, da es keinen Haupt-Lock benötigt
- ✅ **Thread-Safe**: Separate Lock-Struktur verhindert Deadlocks
- ✅ **Performance**: Historie wird nur bei Bedarf aktualisiert, nicht bei jedem Aufruf
- ✅ **Einfach**: Minimale Änderungen am bestehenden Code

## Implementierung

### 1. Neue BlockHistory-Struktur

```go
// BlockHistory manages block timestamps for LWMA difficulty adjustment
// Uses separate lock to avoid contention with main blockchain lock
type BlockHistory struct {
    mu          sync.RWMutex
    timestamps  []time.Time  // Oldest first (chronological order)
    windowSize  int
    maxSize     int  // windowSize + buffer for safety
}

// NewBlockHistory creates a new block history
func NewBlockHistory(windowSize int) *BlockHistory {
    maxSize := windowSize
    if maxSize < 120 {
        maxSize = 120  // Minimum buffer
    }
    return &BlockHistory{
        timestamps: make([]time.Time, 0, maxSize),
        windowSize: windowSize,
        maxSize:    maxSize,
    }
}

// AddBlock adds a new block timestamp (called from addBlockV2)
func (bh *BlockHistory) AddBlock(timestamp time.Time) {
    bh.mu.Lock()
    defer bh.mu.Unlock()
    
    // Add new timestamp
    bh.timestamps = append(bh.timestamps, timestamp)
    
    // Keep only last maxSize timestamps
    if len(bh.timestamps) > bh.maxSize {
        bh.timestamps = bh.timestamps[len(bh.timestamps)-bh.maxSize:]
    }
}

// GetHistory returns block history for LWMA calculation (lock-free read)
func (bh *BlockHistory) GetHistory() []time.Time {
    bh.mu.RLock()
    defer bh.mu.RUnlock()
    
    // Return copy to avoid race conditions
    result := make([]time.Time, len(bh.timestamps))
    copy(result, bh.timestamps)
    return result
}

// GetWindow returns last N timestamps (for LWMA window)
func (bh *BlockHistory) GetWindow(windowSize int) []time.Time {
    bh.mu.RLock()
    defer bh.mu.RUnlock()
    
    if windowSize > len(bh.timestamps) {
        windowSize = len(bh.timestamps)
    }
    
    if windowSize == 0 {
        return []time.Time{}
    }
    
    // Return last windowSize timestamps
    start := len(bh.timestamps) - windowSize
    if start < 0 {
        start = 0
    }
    
    result := make([]time.Time, windowSize)
    copy(result, bh.timestamps[start:])
    return result
}

// Clear clears the history (for reorganization)
func (bh *BlockHistory) Clear() {
    bh.mu.Lock()
    defer bh.mu.Unlock()
    bh.timestamps = make([]time.Time, 0, bh.maxSize)
}

// Rebuild rebuilds history from blocks (for reorganization)
func (bh *BlockHistory) Rebuild(blocks []*Block) {
    bh.mu.Lock()
    defer bh.mu.Unlock()
    
    bh.timestamps = make([]time.Time, 0, len(blocks))
    for _, block := range blocks {
        if block != nil {
            bh.timestamps = append(bh.timestamps, block.Header.Timestamp)
        }
    }
    
    // Keep only last maxSize
    if len(bh.timestamps) > bh.maxSize {
        bh.timestamps = bh.timestamps[len(bh.timestamps)-bh.maxSize:]
    }
}
```

### 2. BlockchainV2 erweitern

```go
type BlockchainV2 struct {
    mu              sync.RWMutex
    blocks          []*Block
    height          uint64
    bestBlock       *Block
    genesis         *GenesisConfig
    consensus       *ConsensusV2
    eventBus        *EventBus
    stateManager    *StateManager
    utxoSet         *UTXOSet
    mempool         *Mempool
    storage         BlockPersister
    SnapshotManager *SnapshotManager
    forkBlocks      map[string][]*Block
    blockIndex      map[string]*Block
    blockHistory    *BlockHistory  // NEW: Separate block history
}
```

### 3. Initialisierung

```go
func NewBlockchainV2(genesis *GenesisConfig, persister BlockPersister) *BlockchainV2 {
    windowSize := 120
    if genesis.Difficulty.Window > 0 {
        windowSize = int(genesis.Difficulty.Window)
    }
    
    bc := &BlockchainV2{
        // ... existing fields ...
        blockHistory: NewBlockHistory(windowSize),  // NEW
    }
    
    // ... rest of initialization ...
    
    // Initialize history from existing blocks
    if bc.height > 0 {
        bc.blockHistory.Rebuild(bc.blocks)
    }
    
    return bc
}
```

### 4. addBlockV2 erweitern

```go
func (bc *BlockchainV2) addBlockV2(block *Block) error {
    // ... existing validation and fork detection ...
    
    // Add block to chain
    bc.blocks = append(bc.blocks, block)
    bc.height = block.Header.Number
    bc.bestBlock = block
    
    // CRITICAL: Update block history OUTSIDE main lock (separate lock)
    // This prevents blocking createBlockTemplate
    bc.blockHistory.AddBlock(block.Header.Timestamp)
    
    // ... rest of block addition ...
}
```

### 5. CreateNewBlockV2 erweitern

```go
func (bc *BlockchainV2) CreateNewBlockV2(miner Address, txs []Transaction) *Block {
    bc.mu.RLock()
    parent := bc.bestBlock
    bc.mu.RUnlock()
    
    if parent == nil {
        return nil
    }
    
    // Get block history WITHOUT main lock (uses separate lock)
    blockHistory := bc.blockHistory.GetWindow(int(bc.genesis.Difficulty.Window))
    
    // Calculate difficulty using LWMA
    consensusManager := NewConsensusManager(bc.genesis)
    difficulty := consensusManager.CalculateDifficulty(
        parent.Header.Number+1, 
        parent, 
        blockHistory,  // Pass history
    )
    
    // ... rest of block creation ...
}
```

### 6. Reorganization erweitern

```go
func (bc *BlockchainV2) reorganizeChain(newBestBlock *Block) error {
    // ... existing reorganization logic ...
    
    // After reorganization, rebuild history
    bc.blockHistory.Rebuild(bc.blocks)
    
    // ... rest of reorganization ...
}
```

### 7. CalculateDifficulty erweitern

```go
func (cm *ConsensusManager) CalculateDifficulty(
    blockNumber uint64, 
    parent *Block, 
    blockHistory []time.Time,  // NEW parameter
) uint64 {
    // ... existing LWMA calculation using blockHistory ...
}
```

## Vorteile dieser Lösung

1. **Keine Lock-Contention**: `createBlockTemplate` benötigt keinen Haupt-Lock mehr
2. **Thread-Safe**: Separate Lock-Struktur verhindert Deadlocks
3. **Performance**: Historie wird nur bei Block-Hinzufügung aktualisiert
4. **Einfach**: Minimale Änderungen am bestehenden Code
5. **Robust**: Funktioniert auch bei Reorganisationen

## Test-Plan

1. **Unit-Tests**: Test `BlockHistory` isoliert
2. **Integration-Tests**: Test mit vollständiger Blockchain
3. **Performance-Tests**: Test mit vielen gleichzeitigen `createBlockTemplate`-Aufrufen
4. **Stress-Tests**: Test mit Reorganisationen und Forks

## Migration

1. Neue `BlockHistory` Struktur hinzufügen
2. `BlockchainV2` erweitern
3. `addBlockV2` erweitern (History-Update)
4. `CreateNewBlockV2` erweitern (History-Read)
5. `reorganizeChain` erweitern (History-Rebuild)
6. `CalculateDifficulty` erweitern (History-Parameter)
7. Tests durchführen

## Risiken und Mitigation

1. **Race Condition**: Verwendung von Kopien statt Referenzen
2. **Memory Leak**: Begrenzung der Historie-Größe
3. **Reorganization**: History-Rebuild bei Reorganisation

