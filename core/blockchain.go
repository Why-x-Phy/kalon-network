package core

import (
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

	// Debug: Log genesis block hash
	fmt.Printf("Genesis block hash: %x\n", genesisBlock.Hash)

	return bc
}

// createGenesisBlock creates the genesis block
func (bc *Blockchain) createGenesisBlock() *Block {
	genesisBlock := &Block{
		Header: BlockHeader{
			ParentHash:  Hash{},
			Number:      0,
			Timestamp:   time.Now(),
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
	if bc.bestBlock == nil || block.Header.Number >= bc.bestBlock.Header.Number {
		bc.bestBlock = block
	}

	// Persist to storage
	bc.persistBlock(block)
}

// AddBlock adds a new block to the blockchain
func (bc *Blockchain) AddBlock(block *Block) error {
	// Validate block
	if err := bc.consensus.ValidateBlock(block, bc.bestBlock); err != nil {
		return fmt.Errorf("invalid block: %v", err)
	}

	bc.addBlock(block)
	return nil
}

// GetBestBlock returns the best block
func (bc *Blockchain) GetBestBlock() *Block {
	bc.mu.RLock()
	defer bc.mu.RUnlock()
	return bc.bestBlock
}

// GetBlockByHash returns a block by hash
func (bc *Blockchain) GetBlockByHash(hash Hash) *Block {
	bc.mu.RLock()
	defer bc.mu.RUnlock()
	return bc.blockMap[hash]
}

// GetBlockByNumber returns a block by number
func (bc *Blockchain) GetBlockByNumber(number uint64) *Block {
	bc.mu.RLock()
	defer bc.mu.RUnlock()

	if number >= uint64(len(bc.blocks)) {
		return nil
	}
	return bc.blocks[number]
}

// GetHeight returns the current blockchain height
func (bc *Blockchain) GetHeight() uint64 {
	bc.mu.RLock()
	defer bc.mu.RUnlock()

	if bc.bestBlock == nil {
		return 0
	}
	return bc.bestBlock.Header.Number
}

// CreateNewBlock creates a new block
func (bc *Blockchain) CreateNewBlock(miner Address, txs []Transaction) *Block {
	bc.mu.RLock()
	defer bc.mu.RUnlock()

	parent := bc.bestBlock
	if parent == nil {
		// This shouldn't happen, but handle gracefully
		return nil
	}

	// Calculate difficulty
	difficulty := bc.consensus.CalculateDifficulty(parent.Header.Number+1, parent)

	// Create block header
	header := BlockHeader{
		ParentHash:  parent.Hash, // Use the actual parent hash
		Number:      parent.Header.Number + 1,
		Timestamp:   time.Now(),
		Difficulty:  difficulty,
		Miner:       miner,
		Nonce:       0,
		MerkleRoot:  bc.consensus.CalculateMerkleRoot(txs),
		TxCount:     uint32(len(txs)),
		NetworkFee:  0, // Will be calculated
		TreasuryFee: 0, // Will be calculated
	}

	// Create block
	block := &Block{
		Header: header,
		Txs:    txs,
		Hash:   Hash{}, // Will be calculated
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
	if err := bc.ValidateTransaction(tx); err != nil {
		return err
	}

	// In a real implementation, you would add to mempool
	// For now, just return success
	return nil
}

// GetBalance returns the balance of an address
func (bc *Blockchain) GetBalance(address Address) uint64 {
	// Simplified balance calculation
	// In a real implementation, you would track UTXOs or account balances
	return 1000000 // 1 KALON in micro-KALON
}

// GetMempoolSize returns the mempool size
func (bc *Blockchain) GetMempoolSize() int {
	// Simplified mempool size
	return 0
}

// GetTreasuryBalance returns treasury balance information
func (bc *Blockchain) GetTreasuryBalance() *TreasuryBalance {
	return &TreasuryBalance{
		Address:     bc.genesis.TreasuryAddress,
		Balance:     0, // Simplified
		BlockFees:   0,
		TxFees:      0,
		TotalIncome: 0,
	}
}

// GetConsensus returns the consensus manager
func (bc *Blockchain) GetConsensus() *ConsensusManager {
	return bc.consensus
}

// persistBlock persists a block to storage
func (bc *Blockchain) persistBlock(block *Block) {
	// Skip persistence for now to avoid nil pointer issues
	return
}
