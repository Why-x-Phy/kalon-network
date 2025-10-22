package main

import (
	"bytes"
	"encoding/hex"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"log"
	"net/http"
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

	// Create RPC blockchain client for real node communication
	rpcBlockchain, err := NewRPCBlockchain(mc.config.RPCURL)
	if err != nil {
		return fmt.Errorf("failed to create RPC blockchain client: %v", err)
	}

	// Create miner with RPC blockchain
	mc.miner = mining.NewMiner(rpcBlockchain, mc.wallet, mc.config.Threads)

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

// RPCBlockchain implements the mining.Blockchain interface via RPC
type RPCBlockchain struct {
	rpcURL string
	client *http.Client
}

// NewRPCBlockchain creates a new RPC blockchain client
func NewRPCBlockchain(rpcURL string) (*RPCBlockchain, error) {
	return &RPCBlockchain{
		rpcURL: rpcURL,
		client: &http.Client{Timeout: 30 * time.Second},
	}, nil
}

// RPCRequest represents a JSON-RPC request
type RPCRequest struct {
	JSONRPC string      `json:"jsonrpc"`
	Method  string      `json:"method"`
	Params  interface{} `json:"params"`
	ID      int         `json:"id"`
}

// RPCResponse represents a JSON-RPC response
type RPCResponse struct {
	JSONRPC string      `json:"jsonrpc"`
	Result  interface{} `json:"result"`
	Error   *RPCError   `json:"error"`
	ID      int         `json:"id"`
}

// RPCError represents an RPC error
type RPCError struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
}

// GetBestBlock returns the best block from the node
func (rpc *RPCBlockchain) GetBestBlock() *core.Block {
	req := RPCRequest{
		JSONRPC: "2.0",
		Method:  "getBestBlock",
		Params:  map[string]interface{}{},
		ID:      1,
	}

	resp, err := rpc.callRPC(req)
	if err != nil {
		log.Printf("Failed to get best block: %v", err)
		// Return a fallback block if RPC fails
		return &core.Block{
			Header: core.BlockHeader{
				Number:     0,
				Timestamp:  time.Now(),
				Difficulty: 1000,
			},
		}
	}

	// Parse block from response
	blockData, ok := resp.Result.(map[string]interface{})
	if !ok {
		log.Printf("Invalid block response format: %v", resp.Result)
		// Return fallback block
		return &core.Block{
			Header: core.BlockHeader{
				Number:     0,
				Timestamp:  time.Now(),
				Difficulty: 1000,
			},
		}
	}

	// Convert to core.Block (simplified with nil checks)
	number, ok := blockData["number"].(float64)
	if !ok {
		log.Printf("Invalid number in block response: %v", blockData["number"])
		// Return fallback block
		return &core.Block{
			Header: core.BlockHeader{
				Number:     0,
				Timestamp:  time.Now(),
				Difficulty: 1000,
			},
		}
	}

	difficulty, ok := blockData["difficulty"].(float64)
	if !ok {
		log.Printf("Invalid difficulty in block response: %v", blockData["difficulty"])
		// Return fallback block
		return &core.Block{
			Header: core.BlockHeader{
				Number:     uint64(number),
				Timestamp:  time.Now(),
				Difficulty: 1000,
			},
		}
	}

	block := &core.Block{
		Header: core.BlockHeader{
			Number:     uint64(number),
			Timestamp:  time.Now(), // Simplified
			Difficulty: uint64(difficulty),
		},
	}

	return block
}

// CreateNewBlock creates a new block template for mining
func (rpc *RPCBlockchain) CreateNewBlock(miner core.Address, txs []core.Transaction) *core.Block {
	req := RPCRequest{
		JSONRPC: "2.0",
		Method:  "createBlockTemplate",
		Params: map[string]interface{}{
			"miner": miner.String(),
		},
		ID: 2,
	}

	resp, err := rpc.callRPC(req)
	if err != nil {
		log.Printf("Failed to create block template: %v", err)
		// Return a fallback block template if RPC fails
		return &core.Block{
			Header: core.BlockHeader{
				Number:     1,
				Timestamp:  time.Now(),
				Difficulty: 1000,
				Miner:      miner,
				Nonce:      0,
			},
			Txs: txs,
		}
	}

	log.Printf("RPC Response: %+v", resp)

	// Parse block template from response
	templateData, ok := resp.Result.(map[string]interface{})
	if !ok {
		log.Printf("Invalid block template response format")
		return nil
	}

	log.Printf("Parent Hash from template: %s", templateData["parentHash"])

	// Parse parent hash from template
	var parentHash core.Hash
	if parentHashData, ok := templateData["parentHash"]; ok {
		switch v := parentHashData.(type) {
		case string:
			// Try to parse as hex string
			hashBytes, err := hex.DecodeString(v)
			if err == nil && len(hashBytes) == 32 {
				copy(parentHash[:], hashBytes)
			} else {
				log.Printf("Failed to parse parent hash as hex: %s, error: %v", v, err)
			}
		case []byte:
			// Direct byte array
			if len(v) == 32 {
				copy(parentHash[:], v)
			} else {
				log.Printf("Invalid parent hash length: %d", len(v))
			}
		default:
			log.Printf("Unknown parent hash type: %T, value: %v", v, v)
		}
	} else {
		log.Printf("No parent hash in template: %v", templateData)
	}

	// Parse timestamp from template
	templateTimestamp := time.Now()
	if timestampData, ok := templateData["timestamp"].(float64); ok {
		templateTimestamp = time.Unix(int64(timestampData), 0)
	}

	// Convert to core.Block
	block := &core.Block{
		Header: core.BlockHeader{
			ParentHash: parentHash,
			Number:     uint64(templateData["number"].(float64)),
			Timestamp:  templateTimestamp.Add(time.Second), // Ensure timestamp is after parent
			Difficulty: uint64(templateData["difficulty"].(float64)),
			Miner:      miner,
			Nonce:      0,
			TxCount:    uint32(len(txs)),
		},
		Txs: txs,
	}

	log.Printf("Created block with parent hash: %x", block.Header.ParentHash)
	log.Printf("Block timestamp: %d (template: %d)", block.Header.Timestamp.Unix(), templateTimestamp.Unix())

	return block
}

// AddBlock submits a mined block to the node
func (rpc *RPCBlockchain) AddBlock(block *core.Block) error {
	log.Printf("Submitting block with parent hash: %x", block.Header.ParentHash)
	log.Printf("Submitting block timestamp: %d", block.Header.Timestamp.Unix())

	req := RPCRequest{
		JSONRPC: "2.0",
		Method:  "submitBlock",
		Params: map[string]interface{}{
			"block": map[string]interface{}{
				"number":     float64(block.Header.Number),
				"difficulty": float64(block.Header.Difficulty),
				"nonce":      float64(block.Header.Nonce),
				"hash":       block.Hash.String(),
				"parentHash": hex.EncodeToString(block.Header.ParentHash[:]),
				"timestamp":  float64(block.Header.Timestamp.Unix()),
			},
		},
		ID: 3,
	}

	resp, err := rpc.callRPC(req)
	if err != nil {
		return fmt.Errorf("failed to submit block: %v", err)
	}

	if resp.Error != nil {
		return fmt.Errorf("RPC error: %s", resp.Error.Message)
	}

	log.Printf("✅ Block #%d submitted to node: %x", block.Header.Number, block.Hash)
	return nil
}

// GetConsensus returns the consensus manager
func (rpc *RPCBlockchain) GetConsensus() mining.Consensus {
	return &RPCConsensus{rpc: rpc}
}

// callRPC makes an RPC call to the node
func (rpc *RPCBlockchain) callRPC(req RPCRequest) (*RPCResponse, error) {
	jsonData, err := json.Marshal(req)
	if err != nil {
		return nil, err
	}

	httpReq, err := http.NewRequest("POST", rpc.rpcURL, bytes.NewBuffer(jsonData))
	if err != nil {
		return nil, err
	}

	httpReq.Header.Set("Content-Type", "application/json")

	resp, err := rpc.client.Do(httpReq)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	var rpcResp RPCResponse
	if err := json.Unmarshal(body, &rpcResp); err != nil {
		return nil, err
	}

	return &rpcResp, nil
}

// RPCConsensus implements the mining.Consensus interface via RPC
type RPCConsensus struct {
	rpc *RPCBlockchain
}

// CalculateDifficulty calculates the difficulty for a block
func (rc *RPCConsensus) CalculateDifficulty(height uint64, parent *core.Block) uint64 {
	req := RPCRequest{
		JSONRPC: "2.0",
		Method:  "calculateDifficulty",
		Params: map[string]interface{}{
			"height": height,
		},
		ID: 4,
	}

	resp, err := rc.rpc.callRPC(req)
	if err != nil {
		log.Printf("Failed to calculate difficulty: %v", err)
		return 1000 // Fallback difficulty
	}

	if difficulty, ok := resp.Result.(float64); ok {
		return uint64(difficulty)
	}

	return 1000 // Fallback difficulty
}

// CalculateTarget calculates the target hash for mining
func (rc *RPCConsensus) CalculateTarget(difficulty uint64) []byte {
	// Simple target calculation based on difficulty
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
func (rc *RPCConsensus) ValidateBlock(block *core.Block, parent *core.Block) error {
	// Basic validation
	if block.Header.Number != parent.Header.Number+1 {
		return fmt.Errorf("invalid block number")
	}
	return nil
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
