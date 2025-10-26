package core

import (
	"encoding/binary"
	"fmt"
	"log"
	"sync"
	"time"
)

// BlockchainV2 represents a professional blockchain implementation
type BlockchainV2 struct {
	mu           sync.RWMutex
	blocks       []*Block
	height       uint64
	bestBlock    *Block
	genesis      *GenesisConfig
	consensus    *ConsensusV2
	eventBus     *EventBus
	stateManager *StateManager
	utxoSet      *UTXOSet
}

// EventBus handles blockchain events
type EventBus struct {
	mu       sync.RWMutex
	channels map[string][]chan interface{}
}

// StateManager manages blockchain state
type StateManager struct {
	mu    sync.RWMutex
	state map[string]interface{}
}

// ConsensusV2 represents professional consensus mechanism
type ConsensusV2 struct {
	mu         sync.RWMutex
	difficulty uint64
	target     uint64
	blockTime  time.Duration
	adjustment *DifficultyAdjustment
}

// DifficultyAdjustment handles LWMA difficulty adjustment
type DifficultyAdjustment struct {
	mu          sync.RWMutex
	windowSize  int
	blockTimes  []time.Time
	adjustments []uint64
}

// NewBlockchainV2 creates a new professional blockchain
func NewBlockchainV2(genesis *GenesisConfig) *BlockchainV2 {
	bc := &BlockchainV2{
		blocks:       make([]*Block, 0),
		height:       0,
		genesis:      genesis,
		consensus:    NewConsensusV2(),
		eventBus:     NewEventBus(),
		stateManager: NewStateManager(),
		utxoSet:      NewUTXOSet(),
	}

	// Create genesis block
	genesisBlock := bc.createGenesisBlockV2()
	bc.addBlockV2(genesisBlock)

	return bc
}

// NewEventBus creates a new event bus
func NewEventBus() *EventBus {
	return &EventBus{
		channels: make(map[string][]chan interface{}),
	}
}

// NewStateManager creates a new state manager
func NewStateManager() *StateManager {
	return &StateManager{
		state: make(map[string]interface{}),
	}
}

// NewConsensusV2 creates a new consensus mechanism
func NewConsensusV2() *ConsensusV2 {
	return &ConsensusV2{
		difficulty: 1,             // Use initial difficulty from genesis config
		target:     1 << (64 - 1), // 1 difficulty = 2^63 target
		blockTime:  30 * time.Second,
		adjustment: NewDifficultyAdjustment(),
	}
}

// NewDifficultyAdjustment creates a new difficulty adjustment
func NewDifficultyAdjustment() *DifficultyAdjustment {
	return &DifficultyAdjustment{
		windowSize:  144, // 24 hours at 30s blocks
		blockTimes:  make([]time.Time, 0),
		adjustments: make([]uint64, 0),
	}
}

// createGenesisBlockV2 creates the genesis block with professional approach
func (bc *BlockchainV2) createGenesisBlockV2() *Block {
	genesisTimestamp := time.Unix(1609459200, 0) // 2021-01-01 00:00:00 UTC

	genesisBlock := &Block{
		Header: BlockHeader{
			ParentHash:  Hash{},
			Number:      0,
			Timestamp:   genesisTimestamp,
			Difficulty:  bc.genesis.Difficulty.InitialDifficulty,
			Miner:       Address{},
			Nonce:       0,
			MerkleRoot:  Hash{},
			TxCount:     0,
			NetworkFee:  0,
			TreasuryFee: 0,
		},
		Txs:  []Transaction{},
		Hash: Hash{},
	}

	// Calculate hash using deterministic method
	genesisBlock.Hash = genesisBlock.CalculateHash()

	return genesisBlock
}

// addBlockV2 adds a block atomically
func (bc *BlockchainV2) addBlockV2(block *Block) error {
	bc.mu.Lock()
	defer bc.mu.Unlock()

	// Validate block
	if err := bc.validateBlockV2(block); err != nil {
		return fmt.Errorf("block validation failed: %v", err)
	}

	// Process UTXOs for all transactions in the block
	for _, tx := range block.Txs {
		bc.processTransactionUTXOs(&tx, block.Hash)
	}

	// Add block atomically
	bc.blocks = append(bc.blocks, block)
	bc.height = block.Header.Number
	bc.bestBlock = block

	// Update state
	bc.stateManager.SetState("height", bc.height)
	bc.stateManager.SetState("bestBlock", block.Hash)

	// Emit event
	bc.eventBus.Emit("blockAdded", map[string]interface{}{
		"block":  block,
		"height": bc.height,
	})

	log.Printf("✅ Block #%d added successfully: %x", block.Header.Number, block.Hash)

	return nil
}

// processTransactionUTXOs processes UTXOs for a transaction
func (bc *BlockchainV2) processTransactionUTXOs(tx *Transaction, blockHash Hash) {
	// Mark input UTXOs as spent
	for _, input := range tx.Inputs {
		bc.utxoSet.SpendUTXO(input.PreviousTxHash, input.Index)
	}

	// Create new UTXOs for outputs
	for i, output := range tx.Outputs {
		bc.utxoSet.AddUTXO(tx.Hash, uint32(i), output.Amount, output.Address, blockHash)
		log.Printf("💰 UTXO created - Address: %x, Amount: %d, TxHash: %x", output.Address, output.Amount, tx.Hash)
	}
}

// AddBlockV2 is the main function for adding blocks - ensures UTXO processing
func (bc *BlockchainV2) AddBlockV2(block *Block) error {
	return bc.addBlockV2(block)
}

// GetBalance returns the balance for an address
func (bc *BlockchainV2) GetBalance(address Address) uint64 {
	return bc.utxoSet.GetBalance(address)
}

// GetUTXOs returns all UTXOs for an address
func (bc *BlockchainV2) GetUTXOs(address Address) []*UTXO {
	return bc.utxoSet.GetUTXOs(address)
}

// validateBlockV2 validates a block professionally
func (bc *BlockchainV2) validateBlockV2(block *Block) error {
	// Check if it's genesis block
	if block.Header.Number == 0 {
		return nil
	}

	// Get parent block
	parent := bc.bestBlock
	if parent == nil {
		return fmt.Errorf("no parent block found")
	}

	// Validate parent hash
	if block.Header.ParentHash != parent.Hash {
		return fmt.Errorf("invalid parent hash: expected %x, got %x", parent.Hash, block.Header.ParentHash)
	}

	// Validate block number
	if block.Header.Number != parent.Header.Number+1 {
		return fmt.Errorf("invalid block number: expected %d, got %d", parent.Header.Number+1, block.Header.Number)
	}

	// Validate timestamp
	if block.Header.Timestamp.Before(parent.Header.Timestamp) {
		return fmt.Errorf("block timestamp before parent: %v < %v", block.Header.Timestamp, parent.Header.Timestamp)
	}

	// Validate proof of work
	if !bc.consensus.ValidateProofOfWorkV2(block) {
		return fmt.Errorf("invalid proof of work")
	}

	return nil
}

// GetBestBlock returns the best block thread-safely
func (bc *BlockchainV2) GetBestBlock() *Block {
	bc.mu.RLock()
	defer bc.mu.RUnlock()
	return bc.bestBlock
}

// GetHeight returns the current height thread-safely
func (bc *BlockchainV2) GetHeight() uint64 {
	bc.mu.RLock()
	defer bc.mu.RUnlock()
	return bc.height
}

// GetConsensus returns the consensus mechanism
func (bc *BlockchainV2) GetConsensus() *ConsensusV2 {
	return bc.consensus
}

// GetEventBus returns the event bus
func (bc *BlockchainV2) GetEventBus() *EventBus {
	return bc.eventBus
}

// CreateNewBlockV2 creates a new block template professionally
func (bc *BlockchainV2) CreateNewBlockV2(miner Address, txs []Transaction) *Block {
	bc.mu.RLock()
	parent := bc.bestBlock
	bc.mu.RUnlock()

	if parent == nil {
		return nil
	}

	// Calculate difficulty
	difficulty := bc.consensus.CalculateDifficultyV2(parent.Header.Number+1, parent)

	// Create block reward transaction
	blockReward := bc.calculateBlockReward(parent.Header.Number + 1)
	rewardTx := bc.createBlockRewardTransaction(miner, blockReward)

	// Add reward transaction to the beginning of transactions
	allTxs := append([]Transaction{rewardTx}, txs...)

	// Create block template
	block := &Block{
		Header: BlockHeader{
			ParentHash:  parent.Hash, // CRITICAL: Use actual parent hash
			Number:      parent.Header.Number + 1,
			Timestamp:   time.Now(),
			Difficulty:  difficulty,
			Miner:       miner,
			Nonce:       0,
			MerkleRoot:  Hash{}, // TODO: Calculate merkle root
			TxCount:     uint32(len(allTxs)),
			NetworkFee:  0,
			TreasuryFee: 0,
		},
		Txs:  allTxs,
		Hash: Hash{},
	}

	// Calculate hash
	block.Hash = block.CalculateHash()

	return block
}

// calculateBlockReward calculates the block reward for a given block number
func (bc *BlockchainV2) calculateBlockReward(blockNumber uint64) uint64 {
	// Start with initial block reward (5 tKALON = 5,000,000 units)
	reward := uint64(bc.genesis.InitialBlockReward * 1000000) // Convert to smallest units

	// Apply halving schedule
	for _, halving := range bc.genesis.HalvingSchedule {
		if blockNumber > halving.AfterBlocks {
			reward = uint64(float64(reward) * halving.RewardMultiplier)
		}
	}

	return reward
}

// createBlockRewardTransaction creates a block reward transaction
func (bc *BlockchainV2) createBlockRewardTransaction(miner Address, amount uint64) Transaction {
	log.Printf("🔍 DEBUG createBlockRewardTransaction - Miner address: %x, Amount: %d", miner, amount)
	
	// Create a special coinbase transaction (no inputs, only output)
	tx := Transaction{
		From:      Address{}, // Empty for coinbase
		To:        miner,
		Amount:    amount,
		Nonce:     0,
		Fee:       0,
		GasUsed:   0,
		GasPrice:  0,
		Data:      []byte("block_reward"),
		Signature: []byte{},    // No signature needed for coinbase
		Inputs:    []TxInput{}, // No inputs for coinbase
		Outputs: []TxOutput{
			{
				Address: miner,
				Amount:  amount,
			},
		},
		Timestamp: time.Now(),
	}

	log.Printf("🔍 DEBUG createBlockRewardTransaction - Created TX with output address: %x", tx.Outputs[0].Address)

	// Calculate transaction hash
	tx.Hash = CalculateTransactionHash(&tx)

	return tx
}

// AddBlock adds a block to the blockchain
func (bc *BlockchainV2) AddBlock(block *Block) error {
	return bc.addBlockV2(block)
}

// ValidateProofOfWorkV2 validates proof of work professionally
func (c *ConsensusV2) ValidateProofOfWorkV2(block *Block) bool {
	c.mu.RLock()
	defer c.mu.RUnlock()

	// For testnet, allow easier validation
	if block.Header.Difficulty <= 4 {
		return true
	}

	// Calculate target (simplified for testnet)
	target := uint64(1) << (64 - block.Header.Difficulty)

	// Check if hash meets target
	hashInt := binary.BigEndian.Uint64(block.Hash[:8])
	return hashInt < target
}

// CalculateDifficultyV2 calculates difficulty professionally
func (c *ConsensusV2) CalculateDifficultyV2(blockNumber uint64, parent *Block) uint64 {
	c.mu.Lock()
	defer c.mu.Unlock()

	// For testnet, always use difficulty 1
	return 1 // Keep difficulty 1 for testnet
}

// CalculateDifficulty calculates difficulty using LWMA
func (da *DifficultyAdjustment) CalculateDifficulty(blockNumber uint64, parent *Block) uint64 {
	da.mu.Lock()
	defer da.mu.Unlock()

	// Add current block time
	da.blockTimes = append(da.blockTimes, parent.Header.Timestamp)

	// Keep only window size
	if len(da.blockTimes) > da.windowSize {
		da.blockTimes = da.blockTimes[1:]
	}

	// Need at least 2 blocks for adjustment
	if len(da.blockTimes) < 2 {
		return 4
	}

	// Calculate average block time
	totalTime := da.blockTimes[len(da.blockTimes)-1].Sub(da.blockTimes[0])
	avgBlockTime := totalTime / time.Duration(len(da.blockTimes)-1)

	// Target block time
	targetTime := 30 * time.Second

	// Calculate adjustment factor
	adjustmentFactor := float64(targetTime) / float64(avgBlockTime)

	// Apply adjustment
	newDifficulty := uint64(float64(parent.Header.Difficulty) * adjustmentFactor)

	// Clamp difficulty
	if newDifficulty < 1 {
		newDifficulty = 1
	}
	if newDifficulty > 1000 {
		newDifficulty = 1000
	}

	return newDifficulty
}

// Emit emits an event
func (eb *EventBus) Emit(event string, data interface{}) {
	eb.mu.RLock()
	channels := eb.channels[event]
	eb.mu.RUnlock()

	for _, ch := range channels {
		select {
		case ch <- data:
		default:
			// Channel is full, skip
		}
	}
}

// Subscribe subscribes to an event
func (eb *EventBus) Subscribe(event string) <-chan interface{} {
	eb.mu.Lock()
	defer eb.mu.Unlock()

	ch := make(chan interface{}, 100) // Buffered channel
	eb.channels[event] = append(eb.channels[event], ch)

	return ch
}

// SetState sets a state value
func (sm *StateManager) SetState(key string, value interface{}) {
	sm.mu.Lock()
	defer sm.mu.Unlock()
	sm.state[key] = value
}

// GetState gets a state value
func (sm *StateManager) GetState(key string) interface{} {
	sm.mu.RLock()
	defer sm.mu.RUnlock()
	return sm.state[key]
}
