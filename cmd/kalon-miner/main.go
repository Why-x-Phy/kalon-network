package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/kalon-network/kalon/crypto"
	"github.com/kalon-network/kalon/mining"
)

// MinerConfig represents the miner configuration
type MinerConfig struct {
	Wallet        string
	Threads       int
	RPCURL        string
	LogLevel      string
	Stats         bool
	StatsInterval time.Duration
}

// MinerCLI represents the miner CLI
type MinerCLI struct {
	config  *MinerConfig
	miner   *mining.Miner
	wallet  *crypto.Wallet
	running bool
}

func main() {
	// Parse command line flags
	var (
		wallet        = flag.String("wallet", "", "Wallet address to receive rewards")
		threads       = flag.Int("threads", 0, "Number of CPU threads (0 = auto)")
		rpcURL        = flag.String("rpc", "http://localhost:16314", "RPC server URL")
		logLevel      = flag.String("loglevel", "info", "Log level (debug, info, warn, error)")
		stats         = flag.Bool("stats", false, "Show mining statistics")
		statsInterval = flag.Duration("stats-interval", 10*time.Second, "Statistics update interval")
		version       = flag.Bool("version", false, "Show version information")
	)
	flag.Parse()

	// Show version
	if *version {
		fmt.Println("Kalon Miner v1.0.0")
		os.Exit(0)
	}

	// Validate required parameters
	if *wallet == "" {
		log.Fatal("Wallet address is required. Use -wallet flag.")
	}

	// Create configuration
	config := &MinerConfig{
		Wallet:        *wallet,
		Threads:       *threads,
		RPCURL:        *rpcURL,
		LogLevel:      *logLevel,
		Stats:         *stats,
		StatsInterval: *statsInterval,
	}

	// Create miner CLI
	minerCLI, err := NewMinerCLI(config)
	if err != nil {
		log.Fatalf("Failed to create miner: %v", err)
	}

	// Start miner
	if err := minerCLI.Start(); err != nil {
		log.Fatalf("Failed to start miner: %v", err)
	}

	// Wait for shutdown signal
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
	<-sigChan

	// Stop miner
	log.Println("Shutting down miner...")
	minerCLI.Stop()
}

// NewMinerCLI creates a new miner CLI
func NewMinerCLI(config *MinerConfig) (*MinerCLI, error) {
	// Create wallet from address
	wallet, err := createWalletFromAddress(config.Wallet)
	if err != nil {
		return nil, fmt.Errorf("failed to create wallet: %v", err)
	}

	// Create mock blockchain for mining
	blockchain := &MockBlockchain{}

	// Create miner
	threads := config.Threads
	if threads <= 0 {
		threads = 2 // Default to 2 threads
	}

	miner := mining.NewMiner(blockchain, wallet, threads)

	return &MinerCLI{
		config: config,
		miner:  miner,
		wallet: wallet,
	}, nil
}

// Start starts the miner
func (mc *MinerCLI) Start() error {
	if mc.running {
		return fmt.Errorf("miner is already running")
	}

	log.Printf("Starting Kalon Miner")
	log.Printf("Wallet: %s", mc.config.Wallet)
	log.Printf("Threads: %d", mc.miner.GetStats().Threads)
	log.Printf("RPC URL: %s", mc.config.RPCURL)

	// Start miner
	if err := mc.miner.Start(); err != nil {
		return fmt.Errorf("failed to start miner: %v", err)
	}

	mc.running = true

	// Start statistics display if enabled
	if mc.config.Stats {
		go mc.displayStats()
	}

	log.Println("Miner started successfully")
	return nil
}

// Stop stops the miner
func (mc *MinerCLI) Stop() {
	if !mc.running {
		return
	}

	mc.miner.Stop()
	mc.running = false
	log.Println("Miner stopped")
}

// displayStats displays mining statistics
func (mc *MinerCLI) displayStats() {
	ticker := time.NewTicker(mc.config.StatsInterval)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			if !mc.running {
				return
			}

			stats := mc.miner.GetStats()
			info := mc.miner.GetMiningInfo()

			// Clear screen and display stats
			fmt.Print("\033[2J\033[H")
			fmt.Println("=== Kalon Miner Statistics ===")
			fmt.Printf("Wallet: %s\n", mc.config.Wallet)
			fmt.Printf("Running: %v\n", mc.miner.IsRunning())
			fmt.Printf("Start Time: %s\n", stats.StartTime.Format("2006-01-02 15:04:05"))
			fmt.Printf("Total Hashes: %d\n", stats.TotalHashes)
			fmt.Printf("Blocks Found: %d\n", stats.BlocksFound)
			fmt.Printf("Current Hash Rate: %.2f H/s\n", stats.CurrentHashRate)
			fmt.Printf("Difficulty: %d\n", stats.Difficulty)
			fmt.Printf("Last Block Time: %s\n", stats.LastBlockTime.Format("2006-01-02 15:04:05"))
			fmt.Println("================================")
		}
	}
}

// createWalletFromAddress creates a wallet from an address string
func createWalletFromAddress(address string) (*crypto.Wallet, error) {
	// This is a simplified implementation
	// In a real implementation, you would need to store the private key
	// For now, create a new wallet and use its address

	wallet, err := crypto.NewWallet("")
	if err != nil {
		return nil, err
	}

	// Verify the address matches
	walletAddress, err := wallet.GetAddressString()
	if err != nil {
		return nil, err
	}

	if walletAddress != address {
		return nil, fmt.Errorf("address mismatch: expected %s, got %s", address, walletAddress)
	}

	return wallet, nil
}

// MockBlockchain is a mock blockchain for testing
type MockBlockchain struct{}

// GetBestBlock returns a mock best block
func (mb *MockBlockchain) GetBestBlock() *mining.Block {
	return &mining.Block{
		Header: mining.BlockHeader{
			Number:     1,
			Timestamp:  time.Now(),
			Difficulty: 1000,
		},
		Hash: [32]byte{},
	}
}

// CreateBlock creates a mock block
func (mb *MockBlockchain) CreateBlock(miner [20]byte, txs []mining.Transaction) *mining.Block {
	return &mining.Block{
		Header: mining.BlockHeader{
			ParentHash: [32]byte{},
			Number:     2,
			Timestamp:  time.Now(),
			Difficulty: 1000,
			Miner:      miner,
			Nonce:      0,
		},
		Txs:  txs,
		Hash: [32]byte{},
	}
}

// AddBlock adds a mock block
func (mb *MockBlockchain) AddBlock(block *mining.Block) error {
	log.Printf("Mock: Added block %d", block.Header.Number)
	return nil
}

// GetConsensus returns a mock consensus
func (mb *MockBlockchain) GetConsensus() mining.Consensus {
	return &MockConsensus{}
}

// MockConsensus is a mock consensus for testing
type MockConsensus struct{}

// CalculateDifficulty calculates mock difficulty
func (mc *MockConsensus) CalculateDifficulty(height uint64, parent *mining.Block) uint64 {
	return 1000
}

// CalculateTarget calculates mock target
func (mc *MockConsensus) CalculateTarget(difficulty uint64) []byte {
	target := make([]byte, 32)
	target[31] = byte(difficulty % 256)
	return target
}

// ValidateBlock validates a mock block
func (mc *MockConsensus) ValidateBlock(block *mining.Block, parent *mining.Block) error {
	return nil
}

// GetMiningStats returns current mining statistics
func (mc *MinerCLI) GetMiningStats() map[string]interface{} {
	return mc.miner.GetMiningInfo()
}

// GetWalletInfo returns wallet information
func (mc *MinerCLI) GetWalletInfo() map[string]interface{} {
	address, _ := mc.wallet.GetAddressString()
	return map[string]interface{}{
		"address":   address,
		"publicKey": mc.wallet.Keypair.GetPublicHex(),
	}
}

// GetConfig returns miner configuration
func (mc *MinerCLI) GetConfig() *MinerConfig {
	return mc.config
}

// IsRunning returns true if the miner is running
func (mc *MinerCLI) IsRunning() bool {
	return mc.running
}

// SetThreads sets the number of mining threads
func (mc *MinerCLI) SetThreads(threads int) {
	mc.miner.SetThreads(threads)
}

// GetThreads returns the number of mining threads
func (mc *MinerCLI) GetThreads() int {
	return mc.config.Threads
}

// GetHashRate returns the current hash rate
func (mc *MinerCLI) GetHashRate() float64 {
	return mc.miner.GetHashRate()
}

// GetBlocksFound returns the number of blocks found
func (mc *MinerCLI) GetBlocksFound() uint64 {
	return mc.miner.GetBlocksFound()
}

// GetTotalHashes returns the total number of hashes computed
func (mc *MinerCLI) GetTotalHashes() uint64 {
	return mc.miner.GetTotalHashes()
}

// GetDifficulty returns the current mining difficulty
func (mc *MinerCLI) GetDifficulty() uint64 {
	stats := mc.miner.GetStats()
	return stats.Difficulty
}

// GetTarget returns the current mining target
func (mc *MinerCLI) GetTarget() []byte {
	stats := mc.miner.GetStats()
	return stats.Target
}

// GetMiningStatsJSON returns mining stats as JSON
func (mc *MinerCLI) GetMiningStatsJSON() ([]byte, error) {
	info := mc.GetMiningStats()
	return json.MarshalIndent(info, "", "  ")
}

// GetWalletInfoJSON returns wallet info as JSON
func (mc *MinerCLI) GetWalletInfoJSON() ([]byte, error) {
	info := mc.GetWalletInfo()
	return json.MarshalIndent(info, "", "  ")
}

// GetConfigJSON returns config as JSON
func (mc *MinerCLI) GetConfigJSON() ([]byte, error) {
	return json.MarshalIndent(mc.config, "", "  ")
}

// GetFullInfo returns complete miner information
func (mc *MinerCLI) GetFullInfo() map[string]interface{} {
	return map[string]interface{}{
		"config":  mc.GetConfig(),
		"wallet":  mc.GetWalletInfo(),
		"mining":  mc.GetMiningStats(),
		"running": mc.IsRunning(),
	}
}

// GetFullInfoJSON returns complete miner information as JSON
func (mc *MinerCLI) GetFullInfoJSON() ([]byte, error) {
	info := mc.GetFullInfo()
	return json.MarshalIndent(info, "", "  ")
}
