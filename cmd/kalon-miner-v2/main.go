package main

import (
	"bytes"
	"crypto/sha256"
	"encoding/binary"
	"encoding/hex"
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/kalon-network/kalon/core"
	"github.com/kalon-network/kalon/crypto"
)

// MinerV2 represents a professional miner
type MinerV2 struct {
	config     *MinerConfig
	blockchain *RPCBlockchainV2
	running    bool
	mu         sync.RWMutex
	stats      *MiningStats
	eventBus   chan MiningEvent
	stopChan   chan struct{}
	wg         sync.WaitGroup
}

// MinerConfig represents miner configuration
type MinerConfig struct {
	Wallet        string
	Threads       int
	RPCURL        string
	StatsInterval time.Duration
}

// MiningStats represents mining statistics
type MiningStats struct {
	mu            sync.RWMutex
	StartTime     time.Time
	TotalHashes   uint64
	BlocksFound   uint64
	CurrentRate   float64
	LastBlockTime time.Time
}

// MiningEvent represents a mining event
type MiningEvent struct {
	Type      string
	Data      interface{}
	Timestamp time.Time
}

// RPCBlockchainV2 represents professional RPC blockchain client
type RPCBlockchainV2 struct {
	rpcURL    string
	client    *http.Client
	mu        sync.RWMutex
	lastBlock *core.Block
}

// NewMinerV2 creates a new professional miner
func NewMinerV2(config *MinerConfig) *MinerV2 {
	blockchain, err := NewRPCBlockchainV2(config.RPCURL)
	if err != nil {
		log.Fatalf("Failed to create RPC blockchain: %v", err)
	}

	return &MinerV2{
		config:     config,
		blockchain: blockchain,
		running:    false,
		stats:      &MiningStats{StartTime: time.Now()},
		eventBus:   make(chan MiningEvent, 100),
		stopChan:   make(chan struct{}),
	}
}

// NewRPCBlockchainV2 creates a new professional RPC blockchain client
func NewRPCBlockchainV2(rpcURL string) (*RPCBlockchainV2, error) {
	return &RPCBlockchainV2{
		rpcURL: rpcURL,
		client: &http.Client{Timeout: 30 * time.Second},
	}, nil
}

// Start starts the miner professionally
func (m *MinerV2) Start() error {
	m.mu.Lock()
	if m.running {
		m.mu.Unlock()
		return fmt.Errorf("miner is already running")
	}
	m.running = true
	m.mu.Unlock()

	log.Printf("­ƒÜÇ Starting Professional Kalon Miner v2.0")
	log.Printf("   Wallet: %s", m.config.Wallet)
	log.Printf("   Threads: %d", m.config.Threads)
	log.Printf("   RPC URL: %s", m.config.RPCURL)

	// Start mining threads
	for i := 0; i < m.config.Threads; i++ {
		m.wg.Add(1)
		go m.miningWorker(i)
	}

	// Start stats reporter
	m.wg.Add(1)
	go m.statsReporter()

	// Start event processor
	m.wg.Add(1)
	go m.eventProcessor()

	return nil
}

// Stop stops the miner gracefully
func (m *MinerV2) Stop() error {
	m.mu.Lock()
	if !m.running {
		m.mu.Unlock()
		return fmt.Errorf("miner is not running")
	}
	m.running = false
	m.mu.Unlock()

	log.Printf("­ƒøæ Stopping miner...")

	// Signal all workers to stop
	close(m.stopChan)

	// Wait for all workers to finish
	m.wg.Wait()

	log.Printf("Ô£à Miner stopped successfully")
	return nil
}

// miningWorker performs mining work
func (m *MinerV2) miningWorker(workerID int) {
	defer m.wg.Done()

	log.Printf("­ƒöº Mining worker %d started", workerID)

	for {
		select {
		case <-m.stopChan:
			log.Printf("­ƒöº Mining worker %d stopped", workerID)
			return
		default:
			m.mineBlock(workerID)
		}
	}
}

// mineBlock mines a single block
func (m *MinerV2) mineBlock(workerID int) {
	// Get miner address
	miner, err := m.parseAddress(m.config.Wallet)
	if err != nil {
		log.Printf("ÔØî Failed to parse wallet address: %v", err)
		time.Sleep(1 * time.Second)
		return
	}

	// Create new block template with transactions from RPC server
	block := m.blockchain.CreateNewBlock(miner, []core.Transaction{}, m.config.Wallet)
	if block == nil {
		log.Printf("ÔØî Failed to create block template")
		time.Sleep(1 * time.Second)
		return
	}

	// Mine the block
	startTime := time.Now()
	nonce := uint64(0)
	target := uint64(1) << (64 - block.Header.Difficulty) // Use 64-bit target, not 256-bit

	for {
		select {
		case <-m.stopChan:
			return
		default:
			// Update nonce
			block.Header.Nonce = nonce
			block.Hash = block.CalculateHash()

			// Check if hash meets target
			hashInt := binary.BigEndian.Uint64(block.Hash[:8])
			if hashInt < target {
				// Block found!
				m.handleBlockFound(block, workerID, time.Since(startTime))
				return
			}

			nonce++
			if nonce%1000000 == 0 {
				// Update stats every million hashes
				m.updateStats(1000000, time.Since(startTime))
			}
		}
	}
}

// handleBlockFound handles a found block
func (m *MinerV2) handleBlockFound(block *core.Block, workerID int, duration time.Duration) {
	log.Printf("­ƒÄë Block found by worker %d! Hash: %x, Nonce: %d, Time: %v",
		workerID, block.Hash, block.Header.Nonce, duration)

	// Update stats
	m.stats.mu.Lock()
	m.stats.BlocksFound++
	m.stats.LastBlockTime = time.Now()
	m.stats.mu.Unlock()

	// Emit event
	m.eventBus <- MiningEvent{
		Type: "blockFound",
		Data: map[string]interface{}{
			"block":    block,
			"workerID": workerID,
			"duration": duration,
		},
		Timestamp: time.Now(),
	}

	// Submit block
	if err := m.blockchain.AddBlock(block); err != nil {
		log.Printf("ÔØî Failed to submit block: %v", err)
	} else {
		log.Printf("Ô£à Block #%d submitted successfully: %x", block.Header.Number, block.Hash)
	}
}

// updateStats updates mining statistics
func (m *MinerV2) updateStats(hashes uint64, duration time.Duration) {
	m.stats.mu.Lock()
	m.stats.TotalHashes += hashes
	m.stats.CurrentRate = float64(hashes) / duration.Seconds()
	m.stats.mu.Unlock()
}

// statsReporter reports mining statistics
func (m *MinerV2) statsReporter() {
	defer m.wg.Done()

	ticker := time.NewTicker(m.config.StatsInterval)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			m.printStats()
		case <-m.stopChan:
			return
		}
	}
}

// printStats prints current statistics
func (m *MinerV2) printStats() {
	m.stats.mu.RLock()
	startTime := m.stats.StartTime
	totalHashes := m.stats.TotalHashes
	blocksFound := m.stats.BlocksFound
	currentRate := m.stats.CurrentRate
	m.stats.mu.RUnlock()

	uptime := time.Since(startTime)
	avgRate := float64(totalHashes) / uptime.Seconds()

	log.Printf("­ƒôè Mining Stats - Uptime: %v, Total Hashes: %d, Blocks Found: %d, Avg Rate: %.2f H/s, Current Rate: %.2f H/s",
		uptime.Truncate(time.Second), totalHashes, blocksFound, avgRate, currentRate)
}

// eventProcessor processes mining events
func (m *MinerV2) eventProcessor() {
	defer m.wg.Done()

	for {
		select {
		case event := <-m.eventBus:
			m.processEvent(event)
		case <-m.stopChan:
			return
		}
	}
}

// processEvent processes a mining event
func (m *MinerV2) processEvent(event MiningEvent) {
	switch event.Type {
	case "blockFound":
		// Handle block found event
		log.Printf("­ƒôó Event: Block found at %v", event.Timestamp)
	default:
		log.Printf("­ƒôó Event: %s at %v", event.Type, event.Timestamp)
	}
}

// CreateNewBlock creates a new block template
func (rpc *RPCBlockchainV2) CreateNewBlock(miner core.Address, txs []core.Transaction, walletAddress string) *core.Block {
	req := RPCRequest{
		JSONRPC: "2.0",
		Method:  "createBlockTemplate",
		Params: map[string]interface{}{
			"miner": walletAddress, // Send original Bech32 address
		},
		ID: 2,
	}

	resp, err := rpc.callRPC(req)
	if err != nil {
		log.Printf("ÔØî Failed to create block template: %v", err)
		return nil
	}

	if resp.Error != nil {
		log.Printf("ÔØî RPC error: %s", resp.Error.Message)
		return nil
	}

	// Parse response
	result, ok := resp.Result.(map[string]interface{})
	if !ok {
		log.Printf("ÔØî Invalid response format")
		return nil
	}

	// Extract values
	number, _ := result["number"].(float64)
	difficulty, _ := result["difficulty"].(float64)
	parentHashStr, _ := result["parentHash"].(string)
	timestamp, _ := result["timestamp"].(float64)

	// Parse parent hash
	parentHashBytes, err := hex.DecodeString(parentHashStr)
	if err != nil {
		log.Printf("ÔØî Failed to parse parent hash: %v", err)
		return nil
	}

	var parentHash core.Hash
	copy(parentHash[:], parentHashBytes)

	// CRITICAL: Extract transactions from RPC response
	var blockTxs []core.Transaction
	if txsData, ok := result["transactions"].([]interface{}); ok {
		for _, txData := range txsData {
			if txMap, ok := txData.(map[string]interface{}); ok {
				// Parse transaction from map
				tx := core.Transaction{}

				// Parse From address
				if fromStr, ok := txMap["from"].(string); ok {
					tx.From = core.AddressFromString(fromStr)
				}

				// Parse To address
				if toStr, ok := txMap["to"].(string); ok {
					tx.To = core.AddressFromString(toStr)
				}

				// Parse Amount
				if amount, ok := txMap["amount"].(float64); ok {
					tx.Amount = uint64(amount)
				}

				// Parse other fields
				if nonce, ok := txMap["nonce"].(float64); ok {
					tx.Nonce = uint64(nonce)
				}
				if fee, ok := txMap["fee"].(float64); ok {
					tx.Fee = uint64(fee)
				}
				if gasUsed, ok := txMap["gasUsed"].(float64); ok {
					tx.GasUsed = uint64(gasUsed)
				}
				if gasPrice, ok := txMap["gasPrice"].(float64); ok {
					tx.GasPrice = uint64(gasPrice)
				}
				if data, ok := txMap["data"].([]byte); ok {
					tx.Data = data
				}
				if signature, ok := txMap["signature"].([]byte); ok {
					tx.Signature = signature
				}
				if hashStr, ok := txMap["hash"].(string); ok {
					if hashBytes, err := hex.DecodeString(hashStr); err == nil {
						copy(tx.Hash[:], hashBytes)
					}
				}

				// Parse UTXO fields
				if inputs, ok := txMap["inputs"].([]interface{}); ok {
					for _, inputData := range inputs {
						if inputMap, ok := inputData.(map[string]interface{}); ok {
							input := core.TxInput{}
							if prevTxHashStr, ok := inputMap["previousTxHash"].(string); ok {
								if prevTxHashBytes, err := hex.DecodeString(prevTxHashStr); err == nil {
									copy(input.PreviousTxHash[:], prevTxHashBytes)
								}
							}
							if index, ok := inputMap["index"].(float64); ok {
								input.Index = uint32(index)
							}
							if signature, ok := inputMap["signature"].([]byte); ok {
								input.Signature = signature
							}
							tx.Inputs = append(tx.Inputs, input)
						}
					}
				}

				if outputs, ok := txMap["outputs"].([]interface{}); ok {
					for _, outputData := range outputs {
						if outputMap, ok := outputData.(map[string]interface{}); ok {
							output := core.TxOutput{}
							if addressStr, ok := outputMap["address"].(string); ok {
								// CRITICAL: Decode hex directly, don't use AddressFromString!
								if addressBytes, err := hex.DecodeString(addressStr); err == nil && len(addressBytes) == 20 {
									copy(output.Address[:], addressBytes)
									log.Printf("🔍 Miner: Parsed output address: %s -> %x", addressStr, output.Address)
								}
							}
							if amount, ok := outputMap["amount"].(float64); ok {
								output.Amount = uint64(amount)
							}
							tx.Outputs = append(tx.Outputs, output)
						}
					}
				}

				// Parse timestamp
				if timestamp, ok := txMap["timestamp"].(string); ok {
					if t, err := time.Parse(time.RFC3339, timestamp); err == nil {
						tx.Timestamp = t
					}
				}

				blockTxs = append(blockTxs, tx)
				log.Printf("­ƒÆ░ Loaded transaction with %d outputs, total amount: %d", len(tx.Outputs), tx.Amount)
			}
		}
	}

	// Create block with transactions from RPC server
	block := &core.Block{
		Header: core.BlockHeader{
			ParentHash:  parentHash, // CRITICAL: Use actual parent hash
			Number:      uint64(number),
			Timestamp:   time.Unix(int64(timestamp), 0),
			Difficulty:  uint64(difficulty),
			Miner:       miner,
			Nonce:       0,
			MerkleRoot:  core.Hash{},
			TxCount:     uint32(len(blockTxs)),
			NetworkFee:  0,
			TreasuryFee: 0,
		},
		Txs:  blockTxs, // Use transactions from RPC server
		Hash: core.Hash{},
	}

	// Calculate hash
	block.Hash = block.CalculateHash()

	log.Printf("­ƒöº Created block template #%d with %d transactions and parent hash: %x", block.Header.Number, len(blockTxs), block.Header.ParentHash)

	return block
}

// AddBlock submits a mined block
func (rpc *RPCBlockchainV2) AddBlock(block *core.Block) error {
	// Convert transactions to JSON format
	var transactions []map[string]interface{}
	for _, tx := range block.Txs {
		// Convert outputs to JSON format with explicit address strings
		var outputs []map[string]interface{}
		for _, output := range tx.Outputs {
			// Address ist bereits bytes - DON'T re-encode!
			outputs = append(outputs, map[string]interface{}{
				"address": hex.EncodeToString(output.Address[:]),
				"amount":  float64(output.Amount),
			})
		}

		txMap := map[string]interface{}{
			"from":      tx.From.String(),
			"to":        tx.To.String(),
			"amount":    float64(tx.Amount),
			"nonce":     float64(tx.Nonce),
			"fee":       float64(tx.Fee),
			"gasUsed":   float64(tx.GasUsed),
			"gasPrice":  float64(tx.GasPrice),
			"data":      tx.Data,
			"signature": tx.Signature,
			"hash":      hex.EncodeToString(tx.Hash[:]),
			"inputs":    tx.Inputs,
			"outputs":   outputs, // CRITICAL: Use manually constructed outputs
			"timestamp": tx.Timestamp.Format(time.RFC3339),
		}
		transactions = append(transactions, txMap)
	}

	req := RPCRequest{
		JSONRPC: "2.0",
		Method:  "submitBlock",
		Params: map[string]interface{}{
			"block": map[string]interface{}{
				"number":       float64(block.Header.Number),
				"difficulty":   float64(block.Header.Difficulty),
				"nonce":        float64(block.Header.Nonce),
				"hash":         hex.EncodeToString(block.Hash[:]),
				"parentHash":   hex.EncodeToString(block.Header.ParentHash[:]),
				"timestamp":    float64(block.Header.Timestamp.Unix()),
				"transactions": transactions, // CRITICAL: Include transactions!
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

	log.Printf("Ô£à Block #%d submitted successfully", block.Header.Number)
	return nil
}

// callRPC makes an RPC call
func (rpc *RPCBlockchainV2) callRPC(req RPCRequest) (*RPCResponse, error) {
	jsonData, err := json.Marshal(req)
	if err != nil {
		return nil, err
	}

	resp, err := rpc.client.Post(rpc.rpcURL, "application/json", bytes.NewBuffer(jsonData))
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var rpcResp RPCResponse
	if err := json.NewDecoder(resp.Body).Decode(&rpcResp); err != nil {
		return nil, err
	}

	return &rpcResp, nil
}

// parseAddress parses a wallet address
func (m *MinerV2) parseAddress(address string) (core.Address, error) {
	// If it's a Bech32 address (starts with kalon1), decode it
	if strings.HasPrefix(address, "kalon1") {
		decodedBytes, err := crypto.DecodeBech32(address)
		if err == nil && len(decodedBytes) == 20 {
			var addr core.Address
			copy(addr[:], decodedBytes)
			log.Printf("✅ Parsed Bech32 address: %s -> %x", address, addr)
			return addr, nil
		}
	}

	// Try to decode as hex first
	if len(address) == 40 {
		bytes, err := hex.DecodeString(address)
		if err == nil && len(bytes) == 20 {
			var addr core.Address
			copy(addr[:], bytes)
			return addr, nil
		}
	}

	// Fallback: create hash from string
	hash := sha256.Sum256([]byte(address))
	var addr core.Address
	// Use first 20 bytes of hash
	copy(addr[:], hash[:20])
	return addr, nil
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
	Result  interface{} `json:"result,omitempty"`
	Error   *RPCError   `json:"error,omitempty"`
	ID      int         `json:"id"`
}

// RPCError represents a JSON-RPC error
type RPCError struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
	Data    string `json:"data,omitempty"`
}

func main() {
	var (
		wallet        = flag.String("wallet", "", "Wallet address")
		threads       = flag.Int("threads", 2, "Number of mining threads")
		rpcURL        = flag.String("rpc", "http://localhost:16316", "RPC server URL")
		statsInterval = flag.Duration("stats", 30*time.Second, "Statistics reporting interval")
	)
	flag.Parse()

	if *wallet == "" {
		log.Fatal("ÔØî Wallet address is required")
	}

	config := &MinerConfig{
		Wallet:        *wallet,
		Threads:       *threads,
		RPCURL:        *rpcURL,
		StatsInterval: *statsInterval,
	}

	miner := NewMinerV2(config)

	// Start miner
	if err := miner.Start(); err != nil {
		log.Fatalf("ÔØî Failed to start miner: %v", err)
	}

	// Wait for shutdown signal
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

	<-sigChan
	log.Printf("­ƒøæ Shutdown signal received")

	// Stop miner
	if err := miner.Stop(); err != nil {
		log.Printf("ÔØî Error stopping miner: %v", err)
	}
}
