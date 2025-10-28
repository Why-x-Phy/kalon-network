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

	"github.com/kalon-network/kalon/core"
	"github.com/kalon-network/kalon/network"
	"github.com/kalon-network/kalon/rpc"
	"github.com/kalon-network/kalon/storage"
)

// NodeV2 represents a professional node
type NodeV2 struct {
	config     *NodeConfig
	blockchain *core.BlockchainV2
	rpcServer  *rpc.ServerV2
	p2p        *network.P2P
	running    bool
}

// NodeConfig represents node configuration
type NodeConfig struct {
	DataDir string
	Genesis string
	RPCAddr string
	P2PAddr string
}

func main() {
	var (
		dataDir = flag.String("datadir", "data/testnet", "Data directory")
		genesis = flag.String("genesis", "genesis/testnet.json", "Genesis file")
		rpcAddr = flag.String("rpc", ":16316", "RPC server address")
		p2pAddr = flag.String("p2p", ":17335", "P2P server address")
	)
	flag.Parse()

	config := &NodeConfig{
		DataDir: *dataDir,
		Genesis: *genesis,
		RPCAddr: *rpcAddr,
		P2PAddr: *p2pAddr,
	}

	node := NewNodeV2(config)

	// Start node
	if err := node.Start(); err != nil {
		log.Fatalf("ÔØî Failed to start node: %v", err)
	}

	// Wait for shutdown signal
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

	<-sigChan
	log.Printf("­ƒøæ Shutdown signal received")

	// Stop node
	if err := node.Stop(); err != nil {
		log.Printf("ÔØî Error stopping node: %v", err)
	}
}

// NewNodeV2 creates a new professional node
func NewNodeV2(config *NodeConfig) *NodeV2 {
	return &NodeV2{
		config: config,
	}
}

// Start starts the node professionally
func (n *NodeV2) Start() error {
	log.Printf("­ƒÜÇ Starting Professional Kalon Node v2.0")
	log.Printf("   Data Dir: %s", n.config.DataDir)
	log.Printf("   Genesis: %s", n.config.Genesis)
	log.Printf("   RPC: %s", n.config.RPCAddr)
	log.Printf("   P2P: %s", n.config.P2PAddr)

	// Load genesis configuration
	genesis, err := n.loadGenesis()
	if err != nil {
		return err
	}

	// Initialize persistent storage
	dbPath := n.config.DataDir + "/chaindb"
	log.Printf("🔧 Initializing persistent storage at %s", dbPath)
	levelDBStorage, err := storage.NewLevelDBStorage(dbPath)
	if err != nil {
		log.Printf("⚠️ Failed to initialize LevelDB: %v. Continuing in-memory mode.", err)
		// Create blockchain without persistence
		n.blockchain = core.NewBlockchainV2(genesis, nil)
	} else {
		// Create storage persister
		persister := storage.NewBlockStorage(levelDBStorage)
		n.blockchain = core.NewBlockchainV2(genesis, persister)
	}
	log.Printf("✅ Blockchain initialized with height: %d", n.blockchain.GetHeight())

	// Create RPC server
	n.rpcServer = rpc.NewServerV2(n.config.RPCAddr, n.blockchain)

	// Start RPC server
	go func() {
		if err := n.rpcServer.Start(); err != nil {
			log.Printf("ÔØî RPC Server error: %v", err)
		}
	}()

	// Initialize P2P network
	p2pConfig := &network.P2PConfig{
		ListenAddr:   n.config.P2PAddr,
		SeedNodes:    []string{}, // TODO: Add seed nodes
		MaxPeers:     50,
		DialTimeout:  10 * time.Second,
		ReadTimeout:  30 * time.Second,
		WriteTimeout: 30 * time.Second,
		KeepAlive:    60 * time.Second,
	}
	n.p2p = network.NewP2P(p2pConfig)

	// Start P2P server
	if err := n.p2p.Start(); err != nil {
		log.Printf("⚠️ Failed to start P2P: %v", err)
	} else {
		log.Printf("✅ P2P network started on %s", n.config.P2PAddr)
	}

	// Wait a moment for server to start
	time.Sleep(1 * time.Second)

	log.Printf("✅ Node started successfully")
	n.running = true

	return nil
}

// Stop stops the node gracefully
func (n *NodeV2) Stop() error {
	if !n.running {
		return nil
	}

	log.Printf("­ƒøæ Stopping node...")

	// Stop RPC server
	if n.rpcServer != nil {
		n.rpcServer.Stop()
	}

	// Stop P2P network
	if n.p2p != nil {
		n.p2p.Stop()
	}

	// Close blockchain storage
	if n.blockchain != nil {
		if err := n.blockchain.Close(); err != nil {
			log.Printf("⚠️ Error closing blockchain: %v", err)
		}
	}

	log.Printf("✅ Node stopped successfully")
	n.running = false

	return nil
}

// loadGenesis loads the genesis configuration
func (n *NodeV2) loadGenesis() (*core.GenesisConfig, error) {
	// Load genesis from file
	data, err := os.ReadFile(n.config.Genesis)
	if err != nil {
		log.Printf("⚠️ Failed to read genesis file %s: %v. Using defaults.", n.config.Genesis, err)
		// Return default genesis with proper difficulty
		return &core.GenesisConfig{
			ChainID:            7718,
			Name:               "Kalon Testnet",
			Symbol:             "tKALON",
			BlockTimeTarget:    30,
			MaxSupply:          1000000000,
			InitialBlockReward: 5.0,
			HalvingSchedule:    []core.HalvingEvent{},
			Difficulty: core.DifficultyConfig{
				Algo:              "LWMA",
				Window:            120,
				InitialDifficulty: 5000,
				MaxAdjustPerBlockPct: 25,
				LaunchGuard: core.LaunchGuard{
					Enabled:                   true,
					DurationHours:             24,
					DifficultyFloorMultiplier: 4.0,
					InitialReward:             2.0,
				},
			},
			AddressFormat: core.AddressFormat{
				Type: "bech32",
				HRP:  "tkalon",
			},
			Premine: core.PremineConfig{
				Enabled: false,
			},
			TreasuryAddress: "tkalon1treasury0000000000000000000000000000000000000000000000000000000000",
			NetworkFee: core.NetworkFeeConfig{
				BlockFeeRate:       0.05,
				TxFeeShareTreasury: 0.20,
				BaseTxFee:          0.01,
				GasPrice:           1000,
			},
			Governance: core.GovernanceConfig{
				Parameters: core.GovernanceParameters{
					NetworkFeeRate:      0.05,
					TxFeeShareTreasury:  0.20,
					TreasuryCapPercent:  10,
				},
			},
		}, nil
	}

	// Parse JSON
	var genesis core.GenesisConfig
	if err := json.Unmarshal(data, &genesis); err != nil {
		return nil, fmt.Errorf("failed to parse genesis JSON: %w", err)
	}

	log.Printf("✅ Loaded genesis from %s", n.config.Genesis)
	return &genesis, nil
}
