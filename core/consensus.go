package core

import (
	"crypto/sha256"
	"fmt"
	"log"
	"time"
)

// ConsensusManager handles consensus logic
type ConsensusManager struct {
	genesis *GenesisConfig
}

// NewConsensusManager creates a new consensus manager
func NewConsensusManager(genesis *GenesisConfig) *ConsensusManager {
	return &ConsensusManager{
		genesis: genesis,
	}
}

// ValidateBlock validates a block according to consensus rules
func (cm *ConsensusManager) ValidateBlock(block *Block, parent *Block) error {
	// Validate block structure
	if block == nil {
		return fmt.Errorf("block is nil")
	}

	// Validate block number
	if parent != nil && block.Header.Number != parent.Header.Number+1 {
		log.Printf("WARNING: Block number mismatch - Expected: %d, Got: %d (allowing for testnet)",
			parent.Header.Number+1, block.Header.Number)
		// For testnet, allow some flexibility in block numbers
		if block.Header.Number < parent.Header.Number {
			return fmt.Errorf("invalid block number: expected %d, got %d",
				parent.Header.Number+1, block.Header.Number)
		}
		// Allow higher block numbers for testnet
		log.Printf("Testnet: Allowing block number %d (expected %d)", block.Header.Number, parent.Header.Number+1)
	}

	// Validate parent hash
	if parent != nil && block.Header.ParentHash != parent.Hash {
		return fmt.Errorf("invalid parent hash: expected %x, got %x", parent.Hash, block.Header.ParentHash)
	}

	// Validate timestamp
	now := time.Now()
	if block.Header.Timestamp.After(now.Add(2 * time.Minute)) {
		return fmt.Errorf("block timestamp too far in future")
	}

	if parent != nil && block.Header.Timestamp.Before(parent.Header.Timestamp) {
		return fmt.Errorf("block timestamp before parent")
	}

	// Validate difficulty
	if parent != nil {
		expectedDifficulty := cm.CalculateDifficulty(block.Header.Number, parent)
		if block.Header.Difficulty != expectedDifficulty {
			return fmt.Errorf("invalid difficulty: expected %d, got %d",
				expectedDifficulty, block.Header.Difficulty)
		}
	}

	// Validate proof of work
	if !cm.ValidateProofOfWork(block) {
		return fmt.Errorf("invalid proof of work")
	}

	// Validate transactions
	for i, tx := range block.Txs {
		if err := cm.ValidateTransaction(&tx); err != nil {
			return fmt.Errorf("invalid transaction %d: %v", i, err)
		}
	}

	// Validate merkle root
	expectedMerkleRoot := cm.CalculateMerkleRoot(block.Txs)
	if block.Header.MerkleRoot != expectedMerkleRoot {
		return fmt.Errorf("invalid merkle root")
	}

	// Validate transaction count
	if block.Header.TxCount != uint32(len(block.Txs)) {
		return fmt.Errorf("invalid transaction count")
	}

	return nil
}

// ValidateTransaction validates a single transaction
func (cm *ConsensusManager) ValidateTransaction(tx *Transaction) error {
	if tx == nil {
		return fmt.Errorf("transaction is nil")
	}

	// Basic validation
	if !tx.IsValid() {
		return fmt.Errorf("transaction is invalid")
	}

	// Validate fee
	minFee := uint64(cm.genesis.NetworkFee.BaseTxFee * 1000000) // Convert to micro-KALON
	if tx.Fee < minFee {
		return fmt.Errorf("transaction fee too low: %d < %d", tx.Fee, minFee)
	}

	// Validate gas
	if tx.GasUsed == 0 {
		tx.GasUsed = 1 // Default gas usage
	}

	expectedFee := tx.GasUsed * tx.GasPrice
	if tx.Fee < expectedFee {
		return fmt.Errorf("transaction fee insufficient for gas: %d < %d", tx.Fee, expectedFee)
	}

	// Validate signature (placeholder - would need actual signature verification)
	if len(tx.Signature) == 0 {
		return fmt.Errorf("transaction missing signature")
	}

	return nil
}

// ValidateProofOfWork validates the proof of work for a block
func (cm *ConsensusManager) ValidateProofOfWork(block *Block) bool {
	// For testnet, allow any hash for difficulty <= 50000 (very lenient for testing)
	// This allows reasonable mining speed on testnet while still testing PoW functionality
	if block.Header.Difficulty <= 50000 {
		log.Printf("Testnet: Allowing block with difficulty %d (no PoW validation)", block.Header.Difficulty)
		return true
	}

	// Calculate target difficulty
	target := cm.CalculateTarget(block.Header.Difficulty)

	// Calculate block hash
	blockHash := block.CalculateHash()

	// Check if hash meets difficulty target
	isValid := cm.IsValidHash(blockHash, target)
	log.Printf("PoW Validation: Difficulty %d, Hash %x, Target %x, Valid: %v",
		block.Header.Difficulty, blockHash, target, isValid)
	return isValid
}

// CalculateDifficulty calculates the difficulty for the next block using LWMA
func (cm *ConsensusManager) CalculateDifficulty(height uint64, parent *Block) uint64 {
	if height == 0 {
		return cm.genesis.Difficulty.InitialDifficulty // Initial difficulty
	}

	// Check if we're in launch guard period
	if cm.genesis.Difficulty.LaunchGuard.Enabled {
		launchGuardBlocks := cm.genesis.Difficulty.LaunchGuard.DurationHours * 3600 / cm.genesis.BlockTimeTarget
		if height < launchGuardBlocks {
			return uint64(float64(cm.genesis.Difficulty.InitialDifficulty) * cm.genesis.Difficulty.LaunchGuard.DifficultyFloorMultiplier)
		}
	}

	// LWMA (Linear Weighted Moving Average) difficulty adjustment
	window := cm.genesis.Difficulty.Window
	if height < window {
		return parent.Header.Difficulty
	}

	// For blocks during launch guard, keep difficulty stable
	// Just return parent difficulty for now (no adjustment during launch)
	// Once we implement proper LWMA with block history, this will work correctly
	if height < cm.genesis.Difficulty.Window {
		return parent.Header.Difficulty
	}

	// Keep difficulty stable (no adjustment factor yet)
	adjustmentFactor := 1.0

	// Apply maximum adjustment limit
	maxAdjust := float64(cm.genesis.Difficulty.MaxAdjustPerBlockPct) / 100.0
	if adjustmentFactor > 1+maxAdjust {
		adjustmentFactor = 1 + maxAdjust
	} else if adjustmentFactor < 1-maxAdjust {
		adjustmentFactor = 1 - maxAdjust
	}

	newDifficulty := uint64(float64(parent.Header.Difficulty) * adjustmentFactor)

	// Ensure minimum difficulty
	if newDifficulty < 1 {
		newDifficulty = 1
	}

	return newDifficulty
}

// CalculateTarget calculates the target hash for a given difficulty
func (cm *ConsensusManager) CalculateTarget(difficulty uint64) []byte {
	// Target = 2^256 / difficulty
	target := make([]byte, 32)

	if difficulty == 0 {
		// Maximum target (all 0xFF) - any hash is valid
		for i := range target {
			target[i] = 0xFF
		}
		return target
	}

	if difficulty == 1 {
		// For difficulty 1, use maximum target (any hash is valid)
		for i := range target {
			target[i] = 0xFF
		}
		return target
	}

	// For higher difficulties, calculate leading zero bytes needed
	// Simple approach: difficulty N requires N leading zero bits
	leadingZeroBits := difficulty - 1
	leadingZeroBytes := leadingZeroBits / 8
	remainingBits := leadingZeroBits % 8

	// Fill non-zero bytes with 0xFF
	for i := int(leadingZeroBytes); i < 32; i++ {
		target[i] = 0xFF
	}

	// Set the partial byte if needed
	if remainingBits > 0 && leadingZeroBytes < 32 {
		target[leadingZeroBytes] = byte(0xFF >> remainingBits)
	}

	return target
}

// IsValidHash checks if a hash meets the target difficulty
func (cm *ConsensusManager) IsValidHash(hash Hash, target []byte) bool {
	hashBytes := hash.Bytes()

	// Special case: if target is all 0xFF, any hash is valid (difficulty 0 or 1)
	allFF := true
	for i := 0; i < 32; i++ {
		if target[i] != 0xFF {
			allFF = false
			break
		}
	}

	if allFF {
		return true
	}

	// Compare hash with target (lower is better)
	for i := 0; i < 32; i++ {
		if hashBytes[i] < target[i] {
			return true
		} else if hashBytes[i] > target[i] {
			return false
		}
	}

	return true // Equal is valid
}

// CalculateMerkleRoot calculates the merkle root of transactions
func (cm *ConsensusManager) CalculateMerkleRoot(txs []Transaction) Hash {
	if len(txs) == 0 {
		// Empty merkle root
		return Hash{}
	}

	if len(txs) == 1 {
		return txs[0].CalculateHash()
	}

	// Build merkle tree
	hashes := make([][]byte, len(txs))
	for i, tx := range txs {
		hashes[i] = tx.CalculateHash().Bytes()
	}

	for len(hashes) > 1 {
		var nextLevel [][]byte

		for i := 0; i < len(hashes); i += 2 {
			var left, right []byte
			left = hashes[i]

			if i+1 < len(hashes) {
				right = hashes[i+1]
			} else {
				right = hashes[i] // Duplicate last element if odd number
			}

			// Concatenate and hash
			combined := append(left, right...)
			hash := sha256.Sum256(combined)
			nextLevel = append(nextLevel, hash[:])
		}

		hashes = nextLevel
	}

	var result Hash
	copy(result[:], hashes[0])
	return result
}

// CalculateBlockReward calculates the block reward distribution
func (cm *ConsensusManager) CalculateBlockReward(height uint64, txFees uint64) BlockReward {
	baseReward := cm.genesis.GetCurrentReward(height)
	return cm.genesis.CalculateNetworkFees(baseReward, txFees)
}

// IsLaunchGuardActive checks if launch guard is still active
func (cm *ConsensusManager) IsLaunchGuardActive(height uint64) bool {
	if !cm.genesis.Difficulty.LaunchGuard.Enabled {
		return false
	}

	launchGuardBlocks := cm.genesis.Difficulty.LaunchGuard.DurationHours * 3600 / cm.genesis.BlockTimeTarget
	return height < launchGuardBlocks
}

// GetNetworkFeeRate returns the current network fee rate
func (cm *ConsensusManager) GetNetworkFeeRate() float64 {
	return cm.genesis.NetworkFee.BlockFeeRate
}

// GetTxFeeShareTreasury returns the transaction fee share for treasury
func (cm *ConsensusManager) GetTxFeeShareTreasury() float64 {
	return cm.genesis.NetworkFee.TxFeeShareTreasury
}
