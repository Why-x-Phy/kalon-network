package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/kalon-network/kalon/core"
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
	wallet  *crypto.Wallet
	miner   *mining.Miner
	running bool
}

var (
	version = "1.0.1"
)

func main() {
	// Parse command line flags
	config := parseFlags()

	// Create miner CLI
	minerCLI, err := NewMinerCLI(config)
	if err != nil {
		log.Fatalf("Failed to create miner: %v", err)
	}

	// Initialize miner
	if err := minerCLI.Initialize(); err != nil {
		log.Fatalf("Failed to initialize miner: %v", err)
	}

	// Start mining
	if err := minerCLI.Start(); err != nil {
		log.Fatalf("Failed to start miner: %v", err)
	}

	// Wait for shutdown signal
	waitForShutdown(minerCLI)
}

// parseFlags parses command line flags
func parseFlags() *MinerConfig {
	config := &MinerConfig{}

	flag.StringVar(&config.Wallet, "wallet", "", "Wallet address for mining rewards")
	flag.IntVar(&config.Threads, "threads", 1, "Number of mining threads")
	flag.StringVar(&config.RPCURL, "rpc", "http://localhost:16314", "RPC server URL")
	flag.StringVar(&config.LogLevel, "log", "info", "Log level")
	flag.BoolVar(&config.Stats, "stats", true, "Enable mining statistics")
	flag.DurationVar(&config.StatsInterval, "stats-interval", 30*time.Second, "Statistics update interval")

	// Version flag
	showVersion := flag.Bool("version", false, "Show version information")

	flag.Parse()

	// Check for version flag
	if *showVersion {
		fmt.Printf("Kalon Miner v%s\n", version)
		os.Exit(0)
	}

	return config
}

// NewMinerCLI creates a new miner CLI
func NewMinerCLI(config *MinerConfig) (*MinerCLI, error) {
	return &MinerCLI{
		config: config,
	}, nil
}

// Initialize initializes the miner
func (mc *MinerCLI) Initialize() error {
	log.Printf("Initializing Kalon Miner v%s", version)

	// Create wallet if not provided
	if mc.config.Wallet == "" {
		wallet, err := crypto.NewWallet("")
		if err != nil {
			return fmt.Errorf("failed to create wallet: %v", err)
		}
		mc.wallet = wallet

		// Get wallet address
		address, err := wallet.GetAddressString()
		if err != nil {
			return fmt.Errorf("failed to get wallet address: %v", err)
		}
		mc.config.Wallet = address

		log.Printf("Created new wallet: %s", address)
	} else {
		// Create a wallet for the provided address
		// In a real implementation, you would load the wallet from storage
		wallet, err := crypto.NewWallet("")
		if err != nil {
			return fmt.Errorf("failed to create wallet for address: %v", err)
		}
		mc.wallet = wallet
		log.Printf("Using provided wallet: %s", mc.config.Wallet)
	}

	// Create mock blockchain for mining
	mockBlockchain := &MockBlockchain{}

	// Create miner with mock blockchain
	mc.miner = mining.NewMiner(mockBlockchain, mc.wallet, mc.config.Threads)

	log.Printf("Miner initialized successfully")
	return nil
}

// Start starts the miner
func (mc *MinerCLI) Start() error {
	if mc.running {
		return fmt.Errorf("miner is already running")
	}

	log.Printf("Starting Kalon Miner...")
	log.Printf("Wallet: %s", mc.config.Wallet)
	log.Printf("Threads: %d", mc.config.Threads)
	log.Printf("RPC URL: %s", mc.config.RPCURL)

	mc.running = true

	// Start mining loop
	go mc.miningLoop()

	// Start statistics loop
	if mc.config.Stats {
		go mc.statsLoop()
	}

	log.Printf("Kalon Miner started successfully")
	return nil
}

// Stop stops the miner
func (mc *MinerCLI) Stop() error {
	if !mc.running {
		return fmt.Errorf("miner is not running")
	}

	log.Printf("Stopping Kalon Miner...")
	mc.running = false
	log.Printf("Kalon Miner stopped")
	return nil
}

// miningLoop is the main mining loop
func (mc *MinerCLI) miningLoop() {
	// Start real mining
	if err := mc.miner.Start(); err != nil {
		log.Printf("Failed to start miner: %v", err)
		return
	}

	// Keep mining running
	for mc.running {
		time.Sleep(30 * time.Second)

		if !mc.miner.IsRunning() {
			break
		}

		stats := mc.miner.GetStats()
		log.Printf("Mining Stats - Threads: %d, Hash Rate: %.2f H/s, Blocks Found: %d",
			mc.config.Threads, stats.CurrentHashRate, stats.BlocksFound)
	}
}

// statsLoop prints mining statistics
func (mc *MinerCLI) statsLoop() {
	for mc.running {
		time.Sleep(mc.config.StatsInterval)

		if mc.running {
			log.Printf("Mining Stats - Threads: %d, Wallet: %s",
				mc.config.Threads, mc.config.Wallet)
		}
	}
}

// waitForShutdown waits for shutdown signals
func waitForShutdown(minerCLI *MinerCLI) {
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

	<-sigChan
	log.Printf("Shutdown signal received")

	if err := minerCLI.Stop(); err != nil {
		log.Printf("Error stopping miner: %v", err)
	}

	os.Exit(0)
}

// MockBlockchain implements the mining.Blockchain interface for testing
type MockBlockchain struct {
	bestBlock *core.Block
	height    uint64
}

// GetBestBlock returns the best block
func (mb *MockBlockchain) GetBestBlock() *core.Block {
	if mb.bestBlock == nil {
		// Create genesis block
		mb.bestBlock = &core.Block{
			Header: core.BlockHeader{
				Number:     0,
				Timestamp:  time.Now(),
				Difficulty: 1000,
				Miner:      core.Address{},
				Nonce:      0,
			},
		}
		mb.height = 0
	}
	return mb.bestBlock
}

// CreateNewBlock creates a new block to mine
func (mb *MockBlockchain) CreateNewBlock(miner core.Address, txs []core.Transaction) *core.Block {
	bestBlock := mb.GetBestBlock()

	return &core.Block{
		Header: core.BlockHeader{
			ParentHash: bestBlock.Hash,
			Number:     bestBlock.Header.Number + 1,
			Timestamp:  time.Now(),
			Difficulty: mb.GetConsensus().CalculateDifficulty(bestBlock.Header.Number+1, bestBlock),
			Miner:      miner,
			Nonce:      0,
			TxCount:    uint32(len(txs)),
		},
		Txs: txs,
	}
}

// AddBlock adds a block to the blockchain
func (mb *MockBlockchain) AddBlock(block *core.Block) error {
	mb.bestBlock = block
	mb.height = block.Header.Number
	log.Printf("✅ Block #%d added to blockchain: %x", block.Header.Number, block.Hash)
	return nil
}

// GetConsensus returns the consensus manager
func (mb *MockBlockchain) GetConsensus() mining.Consensus {
	return &MockConsensus{}
}

// MockConsensus implements the mining.Consensus interface
type MockConsensus struct{}

// CalculateDifficulty calculates the difficulty for a block
func (mc *MockConsensus) CalculateDifficulty(height uint64, parent *core.Block) uint64 {
	// Simple difficulty calculation for testing
	baseDifficulty := uint64(1000)
	if height > 100 {
		return baseDifficulty * 2
	}
	return baseDifficulty
}

// CalculateTarget calculates the target hash for mining
func (mc *MockConsensus) CalculateTarget(difficulty uint64) []byte {
	// Simple target calculation
	target := make([]byte, 32)
	for i := 0; i < 32; i++ {
		if difficulty > uint64(i*8) {
			target[i] = 0xFF
		} else {
			target[i] = 0x00
		}
	}
	return target
}

// ValidateBlock validates a block
func (mc *MockConsensus) ValidateBlock(block *core.Block, parent *core.Block) error {
	// Simple validation for testing
	if block.Header.Number != parent.Header.Number+1 {
		return fmt.Errorf("invalid block number")
	}
	return nil
}
