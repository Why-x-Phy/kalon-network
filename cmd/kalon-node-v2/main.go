package main

import (
	"flag"
	"log"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/kalon-network/kalon/core"
	"github.com/kalon-network/kalon/rpc"
)

// NodeV2 represents a professional node
type NodeV2 struct {
	config     *NodeConfig
	blockchain *core.BlockchainV2
	rpcServer  *rpc.ServerV2
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

	// Create blockchain
	n.blockchain = core.NewBlockchainV2(genesis)
	log.Printf("Ô£à Blockchain initialized with height: %d", n.blockchain.GetHeight())

	// Create RPC server
	n.rpcServer = rpc.NewServerV2(n.config.RPCAddr, n.blockchain)

	// Start RPC server
	go func() {
		if err := n.rpcServer.Start(); err != nil {
			log.Printf("ÔØî RPC Server error: %v", err)
		}
	}()

	// Wait a moment for server to start
	time.Sleep(1 * time.Second)

	log.Printf("Ô£à Node started successfully")
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

	log.Printf("Ô£à Node stopped successfully")
	n.running = false

	return nil
}

// loadGenesis loads the genesis configuration
func (n *NodeV2) loadGenesis() (*core.GenesisConfig, error) {
	// For now, create a default genesis
	// In a real implementation, this would load from file
	return &core.GenesisConfig{
		InitialBlockReward: 5.0, // 5 tKALON block reward
		Difficulty: core.DifficultyConfig{
			InitialDifficulty: 4,
		},
	}, nil
}
