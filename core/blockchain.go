package core

import (
	"encoding/json"
	"fmt"
	"sync"
	"time"
)

// Blockchain represents the blockchain state
type Blockchain struct {
	genesis   *GenesisConfig
	consensus *ConsensusManager
	blocks    []*Block
	blockMap  map[Hash]*Block
	bestBlock *Block
	mu        sync.RWMutex
	storage   Storage
}

// Storage interface for blockchain data persistence
type Storage interface {
	Put(key []byte, value []byte) error
	Get(key []byte) ([]byte, error)
	Delete(key []byte) error
	Close() error
}

// NewBlockchain creates a new blockchain
func NewBlockchain(genesis *GenesisConfig, storage Storage) *Blockchain {
	consensus := NewConsensusManager(genesis)

	bc := &Blockchain{
		genesis:   genesis,
		consensus: consensus,
		blocks:    make([]*Block, 0),
		blockMap:  make(map[Hash]*Block),
		storage:   storage,
	}

	// Create genesis block
	genesisBlock := bc.createGenesisBlock()
	bc.addBlock(genesisBlock)

	return bc
}

// createGenesisBlock creates the genesis block
func (bc *Blockchain) createGenesisBlock() *Block {
	genesisBlock := &Block{
		Header: BlockHeader{
			ParentHash:  Hash{},
			Number:      0,
			Timestamp:   time.Now(),
			Difficulty:  bc.genesis.Difficulty.Window,
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

	// Calculate hash
	genesisBlock.Hash = genesisBlock.CalculateHash()

	return genesisBlock
}

// addBlock adds a block to the blockchain
func (bc *Blockchain) addBlock(block *Block) {
	bc.mu.Lock()
	defer bc.mu.Unlock()

	bc.blocks = append(bc.blocks, block)
	bc.blockMap[block.Hash] = block

	// Update best block if this is the longest chain
	if block.Header.Number >= bc.bestBlock.Header.Number {
		bc.bestBlock = block
	}

	// Persist to storage
	bc.persistBlock(block)
}

// AddBlock adds a new block to the blockchain
func (bc *Blockchain) AddBlock(block *Block) error {
	bc.mu.Lock()
	defer bc.mu.Unlock()

	// Validate block
	var parent *Block
	if block.Header.Number > 0 {
		parent = bc.getBlockByHash(block.Header.ParentHash)
		if parent == nil {
			return fmt.Errorf("parent block not found")
		}
	}

	if err := bc.consensus.ValidateBlock(block, parent); err != nil {
		return fmt.Errorf("block validation failed: %v", err)
	}

	// Add block
	bc.blocks = append(bc.blocks, block)
	bc.blockMap[block.Hash] = block

	// Update best block if this is the longest chain
	if block.Header.Number >= bc.bestBlock.Header.Number {
		bc.bestBlock = block
	}

	// Persist to storage
	bc.persistBlock(block)

	return nil
}

// GetBlockByHash returns a block by its hash
func (bc *Blockchain) GetBlockByHash(hash Hash) *Block {
	bc.mu.RLock()
	defer bc.mu.RUnlock()

	return bc.getBlockByHash(hash)
}

// getBlockByHash internal method without locking
func (bc *Blockchain) getBlockByHash(hash Hash) *Block {
	return bc.blockMap[hash]
}

// GetBlockByNumber returns a block by its number
func (bc *Blockchain) GetBlockByNumber(number uint64) *Block {
	bc.mu.RLock()
	defer bc.mu.RUnlock()

	if number >= uint64(len(bc.blocks)) {
		return nil
	}

	return bc.blocks[number]
}

// GetBestBlock returns the best (highest) block
func (bc *Blockchain) GetBestBlock() *Block {
	bc.mu.RLock()
	defer bc.mu.RUnlock()

	return bc.bestBlock
}

// GetHeight returns the current blockchain height
func (bc *Blockchain) GetHeight() uint64 {
	bc.mu.RLock()
	defer bc.mu.RUnlock()

	return bc.bestBlock.Header.Number
}

// GetGenesis returns the genesis configuration
func (bc *Blockchain) GetGenesis() *GenesisConfig {
	return bc.genesis
}

// GetConsensus returns the consensus manager
func (bc *Blockchain) GetConsensus() *ConsensusManager {
	return bc.consensus
}

// CreateBlock creates a new block for mining
func (bc *Blockchain) CreateBlock(miner Address, txs []Transaction) *Block {
	bc.mu.RLock()
	defer bc.mu.RUnlock()

	parent := bc.bestBlock
	height := parent.Header.Number + 1

	// Calculate difficulty
	difficulty := bc.consensus.CalculateDifficulty(height, parent)

	// Calculate total transaction fees
	var totalTxFees uint64
	for _, tx := range txs {
		totalTxFees += tx.Fee
	}

	// Calculate block reward
	blockReward := bc.consensus.CalculateBlockReward(height, totalTxFees)

	// Create block header
	header := BlockHeader{
		ParentHash:  parent.Hash,
		Number:      height,
		Timestamp:   time.Now(),
		Difficulty:  difficulty,
		Miner:       miner,
		Nonce:       0,
		MerkleRoot:  Hash{}, // Will be calculated
		TxCount:     uint32(len(txs)),
		NetworkFee:  blockReward.TreasuryReward,
		TreasuryFee: blockReward.TreasuryReward,
	}

	// Calculate merkle root
	header.MerkleRoot = bc.consensus.CalculateMerkleRoot(txs)

	// Create block
	block := &Block{
		Header: header,
		Txs:    txs,
		Hash:   Hash{}, // Will be calculated during mining
	}

	// Calculate hash
	block.Hash = block.CalculateHash()

	return block
}

// ValidateTransaction validates a transaction
func (bc *Blockchain) ValidateTransaction(tx *Transaction) error {
	return bc.consensus.ValidateTransaction(tx)
}

// AddTransaction adds a transaction to the mempool
func (bc *Blockchain) AddTransaction(tx *Transaction) error {
	// Validate transaction
	if err := bc.consensus.ValidateTransaction(tx); err != nil {
		return fmt.Errorf("invalid transaction: %v", err)
	}

	// Add to mempool (simplified - in real implementation would use proper mempool)
	// For now, just return success
	return nil
}

// GetBalance returns the balance of an address
func (bc *Blockchain) GetBalance(address Address) uint64 {
	bc.mu.RLock()
	defer bc.mu.RUnlock()

	// This is a simplified implementation
	// In a real blockchain, you would track UTXOs or account balances
	balance := uint64(0)

	// Scan through all blocks to calculate balance
	for _, block := range bc.blocks {
		for _, tx := range block.Txs {
			if tx.To == address {
				balance += tx.Amount
			}
			if tx.From == address {
				if balance >= tx.Amount {
					balance -= tx.Amount
				}
			}
		}
	}

	return balance
}

// GetTreasuryBalance returns the treasury balance
func (bc *Blockchain) GetTreasuryBalance() *TreasuryBalance {
	bc.mu.RLock()
	defer bc.mu.RUnlock()

	treasuryAddr := bc.genesis.TreasuryAddress
	balance := uint64(0)
	blockFees := uint64(0)
	txFees := uint64(0)

	// Calculate treasury balance from all blocks
	for _, block := range bc.blocks {
		blockFees += block.Header.TreasuryFee

		// Add transaction fees (20% goes to treasury)
		for _, tx := range block.Txs {
			treasuryShare := uint64(float64(tx.Fee) * bc.consensus.GetTxFeeShareTreasury())
			txFees += treasuryShare
		}
	}

	balance = blockFees + txFees

	return &TreasuryBalance{
		Address:     treasuryAddr,
		Balance:     balance,
		BlockFees:   blockFees,
		TxFees:      txFees,
		TotalIncome: balance,
	}
}

// persistBlock persists a block to storage
func (bc *Blockchain) persistBlock(block *Block) error {
	if bc.storage == nil {
		return nil
	}

	// Serialize block
	data, err := json.Marshal(block)
	if err != nil {
		return fmt.Errorf("failed to marshal block: %v", err)
	}

	// Store block
	key := []byte(fmt.Sprintf("block_%d_%x", block.Header.Number, block.Hash))
	err = bc.storage.Put(key, data)
	if err != nil {
		return fmt.Errorf("failed to store block: %v", err)
	}

	// Store best block reference
	bestBlockKey := []byte("best_block")
	bestBlockData := []byte(fmt.Sprintf("%x", block.Hash))
	err = bc.storage.Put(bestBlockKey, bestBlockData)
	if err != nil {
		return fmt.Errorf("failed to store best block: %v", err)
	}

	return nil
}

// LoadFromStorage loads blockchain from storage
func (bc *Blockchain) LoadFromStorage() error {
	bc.mu.Lock()
	defer bc.mu.Unlock()

	if bc.storage == nil {
		return nil
	}

	// Load best block
	bestBlockKey := []byte("best_block")
	bestBlockData, err := bc.storage.Get(bestBlockKey)
	if err != nil {
		return fmt.Errorf("failed to load best block: %v", err)
	}

	if len(bestBlockData) == 0 {
		// No stored data, start with genesis
		return nil
	}

	// Parse best block hash
	var bestBlockHash Hash
	copy(bestBlockHash[:], bestBlockData)

	// Load all blocks (simplified - would need proper indexing)
	// For now, just return the genesis block
	return nil
}

// Close closes the blockchain
func (bc *Blockchain) Close() error {
	if bc.storage != nil {
		return bc.storage.Close()
	}
	return nil
}
