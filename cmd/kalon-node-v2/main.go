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
	DataDir   string
	Genesis   string
	RPCAddr   string
	HTTPSAddr string
	CertFile  string
	KeyFile   string
	P2PAddr   string
}

func main() {
	var (
		dataDir   = flag.String("datadir", "data/testnet", "Data directory")
		genesis   = flag.String("genesis", "genesis/testnet.json", "Genesis file")
		rpcAddr   = flag.String("rpc", ":16316", "RPC server address")
		httpsAddr = flag.String("https", "", "HTTPS server address (e.g. :16317)")
		certFile  = flag.String("certfile", "", "SSL certificate file path")
		keyFile   = flag.String("keyfile", "", "SSL private key file path")
		p2pAddr   = flag.String("p2p", ":17335", "P2P server address")
	)
	flag.Parse()

	config := &NodeConfig{
		DataDir:   *dataDir,
		Genesis:   *genesis,
		RPCAddr:   *rpcAddr,
		HTTPSAddr: *httpsAddr,
		CertFile:  *certFile,
		KeyFile:   *keyFile,
		P2PAddr:   *p2pAddr,
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

	// Initialize P2P network first (before RPC server)
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

	// Create RPC server
	n.rpcServer = rpc.NewServerV2(n.config.RPCAddr, n.blockchain)

	// Set P2P network in RPC server for peer count queries
	if n.p2p != nil {
		n.rpcServer.SetP2PNetwork(n.p2p)
	}

	// Configure HTTPS if provided
	if n.config.HTTPSAddr != "" && n.config.CertFile != "" && n.config.KeyFile != "" {
		n.rpcServer.SetHTTPS(n.config.HTTPSAddr, n.config.CertFile, n.config.KeyFile)
		log.Printf("🔒 HTTPS RPC configured: %s (cert: %s, key: %s)", n.config.HTTPSAddr, n.config.CertFile, n.config.KeyFile)
	}

	// Start RPC server
	go func() {
		if err := n.rpcServer.Start(); err != nil {
			log.Printf("⚠️ RPC Server error: %v", err)
		}
	}()

	// Start P2P server
	if err := n.p2p.Start(); err != nil {
		log.Printf("⚠️ Failed to start P2P: %v", err)
	} else {
		log.Printf("✅ P2P network started on %s", n.config.P2PAddr)
	}

	// Setup P2P integration with blockchain
	n.setupP2PIntegration()

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
				Algo:                 "LWMA",
				Window:               120,
				InitialDifficulty:    5000,
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
					NetworkFeeRate:     0.05,
					TxFeeShareTreasury: 0.20,
					TreasuryCapPercent: 10,
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

// setupP2PIntegration sets up the integration between P2P network and blockchain
func (n *NodeV2) setupP2PIntegration() {
	// Subscribe to blockAdded events and broadcast to peers
	blockAddedChan := n.blockchain.GetEventBus().Subscribe("blockAdded")
	go func() {
		for event := range blockAddedChan {
			if eventData, ok := event.(map[string]interface{}); ok {
				if block, ok := eventData["block"].(*core.Block); ok {
					// Convert core.Block to network.Block
					networkBlock := network.ConvertCoreBlockToNetworkBlock(block)
					if networkBlock != nil {
						// Broadcast to all peers
						if err := n.p2p.BroadcastBlock(networkBlock); err != nil {
							log.Printf("⚠️ Failed to broadcast block: %v", err)
						} else {
							log.Printf("📡 Broadcasted block #%d to peers", block.Header.Number)
						}
					}
				}
			}
		}
	}()

	// Set handler for received blocks from peers
	n.p2p.SetBlockHandler(func(networkBlock *network.Block) error {
		// Convert network.Block to core.Block
		coreBlock, err := network.ConvertNetworkBlockToCoreBlock(networkBlock)
		if err != nil {
			return fmt.Errorf("failed to convert network block: %w", err)
		}

		// Add block to blockchain
		if err := n.blockchain.AddBlockV2(coreBlock); err != nil {
			// Don't log error if block already exists (common case)
			if err.Error() != "block already exists" {
				log.Printf("⚠️ Failed to add block from peer: %v", err)
			}
			return err
		}

		log.Printf("📥 Received and added block #%d from peer", coreBlock.Header.Number)
		return nil
	})

	// Set handler for received transactions from peers
	n.p2p.SetTransactionHandler(func(networkTx *network.Transaction) error {
		// Convert network.Transaction to core.Transaction
		coreTx := network.ConvertNetworkTransactionToCoreTransaction(networkTx)
		if coreTx == nil {
			return fmt.Errorf("failed to convert network transaction")
		}

		// Add transaction to mempool
		// Note: We need to validate the transaction first
		// For now, we'll just add it to the mempool
		// TODO: Add proper transaction validation
		n.blockchain.GetMempool().AddTransaction(coreTx)
		log.Printf("📥 Received transaction from peer: %x", coreTx.Hash)
		return nil
	})

	// Set handler for get_blocks requests
	n.p2p.SetGetBlocksHandler(func(startHeight uint64, endHeight uint64) ([]*network.Block, error) {
		// Get blocks from blockchain
		currentHeight := n.blockchain.GetHeight()

		// Limit end height to current height
		if endHeight > currentHeight {
			endHeight = currentHeight
		}

		// Limit range to 100 blocks max
		if endHeight-startHeight > 100 {
			endHeight = startHeight + 100
		}

		blocks := make([]*network.Block, 0)
		for i := startHeight; i <= endHeight; i++ {
			// Get block by number
			block, err := n.blockchain.GetBlockByNumber(i)
			if err != nil || block == nil {
				continue
			}

			// Convert to network block
			networkBlock := network.ConvertCoreBlockToNetworkBlock(block)
			if networkBlock != nil {
				blocks = append(blocks, networkBlock)
			}
		}

		return blocks, nil
	})

	log.Printf("✅ P2P integration with blockchain setup completed")
}
