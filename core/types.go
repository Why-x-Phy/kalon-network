package core

import (
	"crypto/sha256"
	"encoding/binary"
	"encoding/json"
	"time"
)

// Hash represents a 32-byte hash
type Hash [32]byte

// Address represents a 20-byte address
type Address [20]byte

// BlockHeader represents the header of a block
type BlockHeader struct {
	ParentHash  Hash      `json:"parentHash"`
	Number      uint64    `json:"number"`
	Timestamp   time.Time `json:"timestamp"`
	Difficulty  uint64    `json:"difficulty"`
	Miner       Address   `json:"miner"`
	Nonce       uint64    `json:"nonce"`
	MerkleRoot  Hash      `json:"merkleRoot"`
	TxCount     uint32    `json:"txCount"`
	NetworkFee  uint64    `json:"networkFee"`
	TreasuryFee uint64    `json:"treasuryFee"`
}

// Block represents a complete block
type Block struct {
	Header BlockHeader   `json:"header"`
	Txs    []Transaction `json:"transactions"`
	Hash   Hash          `json:"hash"`
}

// Transaction represents a transaction
type Transaction struct {
	From      Address `json:"from"`
	To        Address `json:"to"`
	Amount    uint64  `json:"amount"`
	Nonce     uint64  `json:"nonce"`
	Fee       uint64  `json:"fee"`
	GasUsed   uint64  `json:"gasUsed"`
	GasPrice  uint64  `json:"gasPrice"`
	Data      []byte  `json:"data"`
	Signature []byte  `json:"signature"`
	Hash      Hash    `json:"hash"`
}

// GenesisConfig represents the genesis configuration
type GenesisConfig struct {
	ChainID            uint64           `json:"chainId"`
	Name               string           `json:"name"`
	Symbol             string           `json:"symbol"`
	BlockTimeTarget    uint64           `json:"blockTimeTargetSeconds"`
	MaxSupply          uint64           `json:"maxSupply"`
	InitialBlockReward float64          `json:"initialBlockReward"`
	HalvingSchedule    []HalvingEvent   `json:"halvingSchedule"`
	Difficulty         DifficultyConfig `json:"difficulty"`
	AddressFormat      AddressFormat    `json:"addressFormat"`
	Premine            PremineConfig    `json:"premine"`
	TreasuryAddress    string           `json:"treasuryAddress"`
	NetworkFee         NetworkFeeConfig `json:"networkFee"`
	Governance         GovernanceConfig `json:"governance"`
}

// HalvingEvent represents a halving event
type HalvingEvent struct {
	AfterBlocks      uint64  `json:"afterBlocks"`
	RewardMultiplier float64 `json:"rewardMultiplier"`
}

// DifficultyConfig represents difficulty adjustment configuration
type DifficultyConfig struct {
	Algo                 string      `json:"algo"`
	Window               uint64      `json:"window"`
	MaxAdjustPerBlockPct uint64      `json:"maxAdjustPerBlockPct"`
	LaunchGuard          LaunchGuard `json:"launchGuard"`
}

// LaunchGuard represents fair launch protection
type LaunchGuard struct {
	Enabled                   bool    `json:"enabled"`
	DurationHours             uint64  `json:"durationHours"`
	DifficultyFloorMultiplier float64 `json:"difficultyFloorMultiplier"`
	InitialReward             float64 `json:"initialReward"`
}

// AddressFormat represents address format configuration
type AddressFormat struct {
	Type string `json:"type"`
	HRP  string `json:"hrp"`
}

// PremineConfig represents premine configuration
type PremineConfig struct {
	Enabled bool `json:"enabled"`
}

// NetworkFeeConfig represents network fee configuration
type NetworkFeeConfig struct {
	BlockFeeRate       float64 `json:"blockFeeRate"`
	TxFeeShareTreasury float64 `json:"txFeeShareTreasury"`
	BaseTxFee          float64 `json:"baseTxFee"`
	GasPrice           uint64  `json:"gasPrice"`
}

// GovernanceConfig represents governance configuration
type GovernanceConfig struct {
	Parameters GovernanceParameters `json:"parameters"`
}

// GovernanceParameters represents governance parameters
type GovernanceParameters struct {
	NetworkFeeRate     float64 `json:"networkFeeRate"`
	TxFeeShareTreasury float64 `json:"txFeeShareTreasury"`
	TreasuryCapPercent uint64  `json:"treasuryCapPercent"`
}

// BlockReward represents block reward distribution
type BlockReward struct {
	MinerReward    uint64 `json:"minerReward"`
	TreasuryReward uint64 `json:"treasuryReward"`
	TotalReward    uint64 `json:"totalReward"`
}

// TreasuryBalance represents treasury balance information
type TreasuryBalance struct {
	Address     string `json:"address"`
	Balance     uint64 `json:"balance"`
	BlockFees   uint64 `json:"blockFees"`
	TxFees      uint64 `json:"txFees"`
	TotalIncome uint64 `json:"totalIncome"`
}

// Helper functions
func (h Hash) String() string {
	return string(h[:])
}

func (h Hash) Bytes() []byte {
	return h[:]
}

func (a Address) String() string {
	return string(a[:])
}

func (a Address) Bytes() []byte {
	return a[:]
}

// CalculateHash calculates the hash of a block
func (b *Block) CalculateHash() Hash {
	data, _ := json.Marshal(b.Header)
	hash := sha256.Sum256(data)
	return Hash(hash)
}

// CalculateTxHash calculates the hash of a transaction
func (tx *Transaction) CalculateHash() Hash {
	data := make([]byte, 0, 200)
	data = append(data, tx.From.Bytes()...)
	data = append(data, tx.To.Bytes()...)
	
	// Use compatible binary encoding for older Go versions
	amountBytes := make([]byte, 8)
	binary.BigEndian.PutUint64(amountBytes, tx.Amount)
	data = append(data, amountBytes...)
	
	nonceBytes := make([]byte, 8)
	binary.BigEndian.PutUint64(nonceBytes, tx.Nonce)
	data = append(data, nonceBytes...)
	
	feeBytes := make([]byte, 8)
	binary.BigEndian.PutUint64(feeBytes, tx.Fee)
	data = append(data, feeBytes...)
	
	gasUsedBytes := make([]byte, 8)
	binary.BigEndian.PutUint64(gasUsedBytes, tx.GasUsed)
	data = append(data, gasUsedBytes...)
	
	gasPriceBytes := make([]byte, 8)
	binary.BigEndian.PutUint64(gasPriceBytes, tx.GasPrice)
	data = append(data, gasPriceBytes...)
	
	data = append(data, tx.Data...)

	hash := sha256.Sum256(data)
	return Hash(hash)
}

// IsValid checks if a transaction is valid
func (tx *Transaction) IsValid() bool {
	return tx.Amount > 0 && tx.Fee > 0 && len(tx.Signature) > 0
}

// GetCurrentReward calculates the current block reward based on height and halving schedule
func (g *GenesisConfig) GetCurrentReward(height uint64) float64 {
	baseReward := g.InitialBlockReward

	// Check if we're in launch guard period
	if g.Difficulty.LaunchGuard.Enabled {
		launchGuardBlocks := g.Difficulty.LaunchGuard.DurationHours * 3600 / g.BlockTimeTarget
		if height < launchGuardBlocks {
			return g.Difficulty.LaunchGuard.InitialReward
		}
	}

	// Apply halving schedule
	for _, halving := range g.HalvingSchedule {
		if height >= halving.AfterBlocks {
			baseReward *= halving.RewardMultiplier
		}
	}

	return baseReward
}

// CalculateNetworkFees calculates network fees for a block
func (g *GenesisConfig) CalculateNetworkFees(blockReward float64, txFees uint64) BlockReward {
	totalReward := uint64(blockReward * 1000000) // Convert to micro-KALON

	// Block fee (percentage of block reward)
	blockFeeRate := g.NetworkFee.BlockFeeRate
	treasuryFromBlock := uint64(float64(totalReward) * blockFeeRate)
	minerFromBlock := totalReward - treasuryFromBlock

	// Transaction fees
	txFeeShareTreasury := g.NetworkFee.TxFeeShareTreasury
	treasuryFromTx := uint64(float64(txFees) * txFeeShareTreasury)
	minerFromTx := txFees - treasuryFromTx

	return BlockReward{
		MinerReward:    minerFromBlock + minerFromTx,
		TreasuryReward: treasuryFromBlock + treasuryFromTx,
		TotalReward:    totalReward + txFees,
	}
}
