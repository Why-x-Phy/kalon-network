package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"os"
	"os/signal"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/kalon-network/kalon/core"
	"github.com/kalon-network/kalon/rpc"
	"github.com/kalon-network/kalon/storage"
)

// Config represents the node configuration
type Config struct {
	DataDir     string
	GenesisFile string
	RPCAddr     string
	P2PAddr     string
	SeedNodes   []string
	Mining      bool
	Threads     int
	LogLevel    string
}

// Node represents the Kalon node
type Node struct {
	config     *Config
	genesis    *core.GenesisConfig
	blockchain *core.Blockchain
	storage    *storage.LevelDBStorage
	rpcServer  *rpc.Server
	running    bool
	mu         sync.RWMutex
}

var (
	version = "1.0.1"
)

func main() {
	// Parse command line flags
	config := parseFlags()

	// Create node
	node, err := NewNode(config)
	if err != nil {
		log.Fatalf("Failed to create node: %v", err)
	}

	// Initialize node
	if err := node.Initialize(); err != nil {
		log.Fatalf("Failed to initialize node: %v", err)
	}

	// Start node
	if err := node.Start(); err != nil {
		log.Fatalf("Failed to start node: %v", err)
	}

	// Wait for shutdown signal
	waitForShutdown(node)
}

// parseFlags parses command line flags
func parseFlags() *Config {
	config := &Config{}

	flag.StringVar(&config.DataDir, "datadir", "./data", "Data directory")
	flag.StringVar(&config.GenesisFile, "genesis", "./genesis/genesis.json", "Genesis file path")
	flag.StringVar(&config.RPCAddr, "rpc", "localhost:16314", "RPC server address")
	flag.StringVar(&config.P2PAddr, "p2p", "localhost:17333", "P2P server address")
	flag.StringVar(&config.LogLevel, "log", "info", "Log level")
	flag.BoolVar(&config.Mining, "mining", false, "Enable mining")
	flag.IntVar(&config.Threads, "threads", 1, "Number of mining threads")

	flag.Parse()

	// Parse seed nodes from environment or use defaults
	seedNodes := os.Getenv("KALON_SEED_NODES")
	if seedNodes != "" {
		config.SeedNodes = strings.Split(seedNodes, ",")
	} else {
		config.SeedNodes = []string{
			"localhost:17333",
		}
	}

	return config
}

// NewNode creates a new node
func NewNode(config *Config) (*Node, error) {
	return &Node{
		config: config,
	}, nil
}

// Initialize initializes the node
func (n *Node) Initialize() error {
	log.Printf("Initializing Kalon Node v%s", version)

	// Load genesis configuration
	if err := n.loadGenesis(); err != nil {
		return fmt.Errorf("failed to load genesis: %v", err)
	}

	// Setup data directory
	if err := n.setupDataDir(); err != nil {
		return fmt.Errorf("failed to setup data directory: %v", err)
	}

	// Initialize storage
	storage, err := storage.NewLevelDBStorage(n.config.DataDir)
	if err != nil {
		return fmt.Errorf("failed to initialize storage: %v", err)
	}
	n.storage = storage

	// Initialize blockchain
	blockchain := core.NewBlockchain(n.genesis, n.storage)
	n.blockchain = blockchain

	// Initialize RPC server
	n.rpcServer = rpc.NewServer(n.config.RPCAddr, n.blockchain, nil, nil)

	log.Printf("Node initialized successfully")
	return nil
}

// Start starts the node
func (n *Node) Start() error {
	n.mu.Lock()
	defer n.mu.Unlock()

	if n.running {
		return fmt.Errorf("node is already running")
	}

	log.Printf("Starting Kalon Node...")
	log.Printf("Data directory: %s", n.config.DataDir)
	log.Printf("RPC address: %s", n.config.RPCAddr)
	log.Printf("P2P address: %s", n.config.P2PAddr)

	n.running = true

	// Start RPC server
	go func() {
		if err := n.rpcServer.Start(); err != nil {
			log.Printf("RPC server error: %v", err)
		}
	}()

	// Start background processes
	go n.processBlocks()
	go n.processTransactions()

	log.Printf("Kalon Node started successfully")
	return nil
}

// Stop stops the node
func (n *Node) Stop() error {
	n.mu.Lock()
	defer n.mu.Unlock()

	if !n.running {
		return fmt.Errorf("node is not running")
	}

	log.Printf("Stopping Kalon Node...")

	n.running = false

	// Close storage
	if n.storage != nil {
		if err := n.storage.Close(); err != nil {
			log.Printf("Error closing storage: %v", err)
		}
	}

	log.Printf("Kalon Node stopped")
	return nil
}

// processBlocks processes incoming blocks
func (n *Node) processBlocks() {
	for n.running {
		// Simplified block processing
		time.Sleep(30 * time.Second)

		// Get current height
		height := n.blockchain.GetHeight()

		log.Printf("Current block height: %d", height)
	}
}

// processTransactions processes incoming transactions
func (n *Node) processTransactions() {
	for n.running {
		// Simplified transaction processing
		time.Sleep(10 * time.Second)

		// Get mempool size (simplified)
		mempoolSize := 0
		if mempoolSize > 0 {
			log.Printf("Mempool size: %d", mempoolSize)
		}
	}
}

// loadGenesis loads the genesis configuration
func (n *Node) loadGenesis() error {
	data, err := os.ReadFile(n.config.GenesisFile)
	if err != nil {
		return fmt.Errorf("failed to read genesis file: %v", err)
	}

	var genesis core.GenesisConfig
	if err := json.Unmarshal(data, &genesis); err != nil {
		return fmt.Errorf("failed to parse genesis file: %v", err)
	}

	n.genesis = &genesis
	return nil
}

// setupDataDir creates the data directory if it doesn't exist
func (n *Node) setupDataDir() error {
	return os.MkdirAll(n.config.DataDir, 0755)
}

// waitForShutdown waits for shutdown signals
func waitForShutdown(node *Node) {
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

	<-sigChan
	log.Printf("Shutdown signal received")

	if err := node.Stop(); err != nil {
		log.Printf("Error stopping node: %v", err)
	}

	os.Exit(0)
}
