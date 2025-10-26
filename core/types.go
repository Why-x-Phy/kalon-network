package core

import (
	"crypto/sha256"
	"encoding/binary"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"strings"
	"time"
)

// Hash represents a 32-byte hash
type Hash [32]byte

// Address represents a 20-byte address
type Address [20]byte

// AddressFromString converts a hex address string to Address (NO FALLBACK)
func AddressFromString(addrStr string) Address {
	// Remove "kalon1" prefix if present
	if strings.HasPrefix(addrStr, "kalon1") {
		addrStr = addrStr[6:] // Remove "kalon1" prefix
	}

	// Try to decode as hex - MUST be exactly 40 hex chars for 20 bytes
	if len(addrStr) == 40 {
		bytes, err := hex.DecodeString(addrStr)
		if err == nil && len(bytes) == 20 {
			var addr Address
			copy(addr[:], bytes)
			fmt.Printf("✅ AddressFromString: Successfully decoded %s -> %x\n", addrStr[:20]+"...", addr[:])
			return addr
		}
		fmt.Printf("⚠️ AddressFromString: Failed to decode hex %s: %v\n", addrStr[:20]+"...", err)
	}

	// NO FALLBACK! Return zero address if decoding fails
	fmt.Printf("❌ AddressFromString: Invalid address format %s (len=%d)\n", addrStr, len(addrStr))
	return Address{}
}

// String returns the string representation of an address
func (a Address) String() string {
	return hex.EncodeToString(a[:])
}

// ParseAddress parses an address from various formats
func ParseAddress(addrStr string) (Address, error) {
	// Remove any prefix if present
	if strings.HasPrefix(addrStr, "kalon1") {
		addrStr = addrStr[6:] // Remove "kalon1" prefix
	}

	// Try to decode as hex
	if len(addrStr) == 40 { // 20 bytes = 40 hex chars
		bytes, err := hex.DecodeString(addrStr)
		if err == nil && len(bytes) == 20 {
			var addr Address
			copy(addr[:], bytes)
			return addr, nil
		}
	}

	// Fallback to hash-based conversion
	return AddressFromString(addrStr), nil
}

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
	// UTXO-based fields
	Inputs    []TxInput  `json:"inputs"`
	Outputs   []TxOutput `json:"outputs"`
	Timestamp time.Time  `json:"timestamp"`
}

// TxInput represents a transaction input (UTXO reference)
type TxInput struct {
	PreviousTxHash Hash   `json:"previousTxHash"`
	Index          uint32 `json:"index"`
	Signature      []byte `json:"signature"`
}

// TxOutput represents a transaction output (UTXO creation)
type TxOutput struct {
	Address Address `json:"address"`
	Amount  uint64  `json:"amount"`
}

// MarshalJSON customizes JSON encoding for TxOutput
func (o TxOutput) MarshalJSON() ([]byte, error) {
	type Alias TxOutput
	return json.Marshal(struct {
		Address string `json:"address"`
		Amount  uint64 `json:"amount"`
	}{
		Address: hex.EncodeToString(o.Address[:]), // Direct hex, not String() to avoid double encoding
		Amount:  o.Amount,
	})
}

// UnmarshalJSON customizes JSON decoding for TxOutput
func (o *TxOutput) UnmarshalJSON(data []byte) error {
	type Alias TxOutput
	aux := &struct {
		Address string `json:"address"`
		Amount  uint64 `json:"amount"`
	}{}
	if err := json.Unmarshal(data, &aux); err != nil {
		return err
	}

	// Parse address string - if it's 40 hex chars, decode directly
	if len(aux.Address) == 40 {
		if decoded, err := hex.DecodeString(aux.Address); err == nil && len(decoded) == 20 {
			copy(o.Address[:], decoded)
		} else {
			o.Address = AddressFromString(aux.Address)
		}
	} else {
		o.Address = AddressFromString(aux.Address)
	}
	o.Amount = aux.Amount
	return nil
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
	InitialDifficulty    uint64      `json:"initialDifficulty"`
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

func (a Address) Bytes() []byte {
	return a[:]
}

// CalculateHash calculates the hash of a block
func (b *Block) CalculateHash() Hash {
	// Create deterministic hash without JSON marshalling
	data := make([]byte, 0, 200)

	// Add parent hash
	data = append(data, b.Header.ParentHash[:]...)

	// Add number (8 bytes)
	numberBytes := make([]byte, 8)
	binary.BigEndian.PutUint64(numberBytes, b.Header.Number)
	data = append(data, numberBytes...)

	// Add timestamp (8 bytes - Unix timestamp)
	timestampBytes := make([]byte, 8)
	binary.BigEndian.PutUint64(timestampBytes, uint64(b.Header.Timestamp.Unix()))
	data = append(data, timestampBytes...)

	// Add difficulty (8 bytes)
	difficultyBytes := make([]byte, 8)
	binary.BigEndian.PutUint64(difficultyBytes, b.Header.Difficulty)
	data = append(data, difficultyBytes...)

	// Add miner address
	data = append(data, b.Header.Miner[:]...)

	// Add nonce (8 bytes)
	nonceBytes := make([]byte, 8)
	binary.BigEndian.PutUint64(nonceBytes, b.Header.Nonce)
	data = append(data, nonceBytes...)

	// Add merkle root
	data = append(data, b.Header.MerkleRoot[:]...)

	// Add tx count (4 bytes)
	txCountBytes := make([]byte, 4)
	binary.BigEndian.PutUint32(txCountBytes, b.Header.TxCount)
	data = append(data, txCountBytes...)

	// Add network fee (8 bytes)
	networkFeeBytes := make([]byte, 8)
	binary.BigEndian.PutUint64(networkFeeBytes, b.Header.NetworkFee)
	data = append(data, networkFeeBytes...)

	// Add treasury fee (8 bytes)
	treasuryFeeBytes := make([]byte, 8)
	binary.BigEndian.PutUint64(treasuryFeeBytes, b.Header.TreasuryFee)
	data = append(data, treasuryFeeBytes...)

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
