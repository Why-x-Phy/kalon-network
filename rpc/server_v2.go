package rpc

import (
	"context"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/kalon-network/kalon/core"
)

// RPCRequest represents a JSON-RPC request
type RPCRequest struct {
	JSONRPC string      `json:"jsonrpc"`
	Method  string      `json:"method"`
	Params  interface{} `json:"params"`
	ID      interface{} `json:"id"`
}

// RPCResponse represents a JSON-RPC response
type RPCResponse struct {
	JSONRPC string      `json:"jsonrpc"`
	Result  interface{} `json:"result,omitempty"`
	Error   *RPCError   `json:"error,omitempty"`
	ID      interface{} `json:"id"`
}

// RPCError represents an RPC error
type RPCError struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
	Data    string `json:"data,omitempty"`
}

// ServerV2 represents a professional RPC server
type ServerV2 struct {
	addr        string
	blockchain  *core.BlockchainV2
	mu          sync.RWMutex
	connections map[string]*Connection
	eventBus    *core.EventBus
	ctx         context.Context
	cancel      context.CancelFunc
	allowedIPs  map[string]bool       // Whitelist of allowed IPs
	rateLimits  map[string]*RateLimit // Rate limiting per IP
	requireAuth bool                  // Whether auth is required
	authTokens  map[string]bool       // Valid auth tokens
}

// Connection represents a client connection
type Connection struct {
	ID        string
	CreatedAt time.Time
	LastSeen  time.Time
	Requests  int64
}

// RateLimit tracks rate limiting for an IP
type RateLimit struct {
	mu             sync.RWMutex
	Count          int
	LastReset      time.Time
	RequestsPerMin int
}

// NewServerV2 creates a new professional RPC server
func NewServerV2(addr string, blockchain *core.BlockchainV2) *ServerV2 {
	ctx, cancel := context.WithCancel(context.Background())

	server := &ServerV2{
		addr:        addr,
		blockchain:  blockchain,
		connections: make(map[string]*Connection),
		eventBus:    blockchain.GetEventBus(),
		ctx:         ctx,
		cancel:      cancel,
		allowedIPs:  make(map[string]bool),
		rateLimits:  make(map[string]*RateLimit),
		requireAuth: false, // For testnet: auth disabled by default
		authTokens:  make(map[string]bool),
	}

	// Start connection cleanup routine
	go server.cleanupConnections()

	return server
}

// Start starts the RPC server professionally
func (s *ServerV2) Start() error {
	mux := http.NewServeMux()
	mux.HandleFunc("/", s.handleRequest)
	mux.HandleFunc("/health", s.handleHealth)
	mux.HandleFunc("/rpc", s.handleRequest)

	// Create server with professional settings
	server := &http.Server{
		Addr:           s.addr,
		Handler:        s.limitConnections(mux),
		ReadTimeout:    30 * time.Second,
		WriteTimeout:   30 * time.Second,
		IdleTimeout:    60 * time.Second,
		MaxHeaderBytes: 1 << 20, // 1MB
	}

	log.Printf("🚀 Professional RPC Server starting on %s", s.addr)

	// Start server in goroutine
	go func() {
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Printf("RPC Server error: %v", err)
		}
	}()

	// Wait for context cancellation
	<-s.ctx.Done()

	// Graceful shutdown
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	return server.Shutdown(ctx)
}

// Stop stops the RPC server
func (s *ServerV2) Stop() {
	s.cancel()
}

// handleRequest handles RPC requests professionally
func (s *ServerV2) handleRequest(w http.ResponseWriter, r *http.Request) {
	// Extract IP
	ip := s.extractIP(r)

	// Check IP whitelist if enabled
	if len(s.allowedIPs) > 0 && !s.allowedIPs[ip] {
		http.Error(w, "Forbidden", http.StatusForbidden)
		return
	}

	// Check rate limit
	if !s.checkRateLimit(ip) {
		http.Error(w, "Too many requests", http.StatusTooManyRequests)
		return
	}

	// Track connection
	s.trackConnection(ip)

	// Parse request
	var req RPCRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		s.writeError(w, nil, -32700, "Parse error", err.Error())
		return
	}

	// Handle request
	response := s.handleRPCMethod(&req)

	// Write response
	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(response); err != nil {
		log.Printf("❌ Failed to encode RPC response: %v", err)
		http.Error(w, "Internal server error", http.StatusInternalServerError)
	}
}

// handleRPCMethod handles RPC methods professionally
func (s *ServerV2) handleRPCMethod(req *RPCRequest) *RPCResponse {
	switch req.Method {
	case "getHeight":
		return s.handleGetHeight(req)
	case "getBestBlock":
		return s.handleGetBestBlock(req)
	case "getRecentBlocks":
		return s.handleGetRecentBlocks(req)
	case "createBlockTemplate":
		return s.handleCreateBlockTemplateV2(req)
	case "submitBlock":
		return s.handleSubmitBlockV2(req)
	case "getMiningInfo":
		return s.handleGetMiningInfo(req)
	case "getBalance":
		return s.handleGetBalance(req)
	case "sendTransaction":
		return s.handleSendTransaction(req)
	default:
		return &RPCResponse{
			JSONRPC: "2.0",
			Error: &RPCError{
				Code:    -32601,
				Message: "Method not found",
			},
			ID: req.ID,
		}
	}
}

// handleGetHeight handles getHeight requests
func (s *ServerV2) handleGetHeight(req *RPCRequest) *RPCResponse {
	height := s.blockchain.GetHeight()
	return &RPCResponse{
		JSONRPC: "2.0",
		Result:  height,
		ID:      req.ID,
	}
}

// handleGetBestBlock handles getBestBlock requests
func (s *ServerV2) handleGetBestBlock(req *RPCRequest) *RPCResponse {
	block := s.blockchain.GetBestBlock()
	if block == nil {
		return &RPCResponse{
			JSONRPC: "2.0",
			Error: &RPCError{
				Code:    -32603,
				Message: "Internal error",
				Data:    "No blocks found",
			},
			ID: req.ID,
		}
	}

	return &RPCResponse{
		JSONRPC: "2.0",
		Result: map[string]interface{}{
			"hash":   hex.EncodeToString(block.Hash[:]),
			"number": block.Header.Number,
		},
		ID: req.ID,
	}
}

// handleGetRecentBlocks handles getRecentBlocks requests
func (s *ServerV2) handleGetRecentBlocks(req *RPCRequest) *RPCResponse {
	// Parse parameters
	params, ok := req.Params.(map[string]interface{})
	limit := 20 // Default limit

	if ok {
		if limitVal, ok := params["limit"].(float64); ok {
			limit = int(limitVal)
			if limit > 100 {
				limit = 100
			}
			if limit < 1 {
				limit = 1
			}
		}
	}

	// Get recent blocks
	blocks := s.blockchain.GetRecentBlocks(limit)
	if blocks == nil || len(blocks) == 0 {
		return &RPCResponse{
			JSONRPC: "2.0",
			Result:  []interface{}{},
			ID:      req.ID,
		}
	}

	// Convert blocks to JSON-compatible format
	result := make([]map[string]interface{}, 0, len(blocks))
	for _, block := range blocks {
		txCount := uint32(len(block.Txs))
		blockMap := map[string]interface{}{
			"hash":        hex.EncodeToString(block.Hash[:]),
			"number":      block.Header.Number,
			"parentHash":  hex.EncodeToString(block.Header.ParentHash[:]),
			"timestamp":   float64(block.Header.Timestamp.Unix()),
			"difficulty":  block.Header.Difficulty,
			"nonce":       block.Header.Nonce,
			"merkleRoot":  hex.EncodeToString(block.Header.MerkleRoot[:]),
			"txCount":     txCount,
			"networkFee":  block.Header.NetworkFee,
			"treasuryFee": block.Header.TreasuryFee,
			"gasUsed":     uint64(0), // Not used in Kalon
			"gasLimit":    uint64(0), // Not used in Kalon
		}

		// Add miner if available
		if block.Header.Miner != (core.Address{}) {
			blockMap["miner"] = block.Header.Miner.String()
		}

		result = append(result, blockMap)
	}

	return &RPCResponse{
		JSONRPC: "2.0",
		Result:  result,
		ID:      req.ID,
	}
}

// handleCreateBlockTemplateV2 handles createBlockTemplate requests professionally
func (s *ServerV2) handleCreateBlockTemplateV2(req *RPCRequest) *RPCResponse {
	params, ok := req.Params.(map[string]interface{})
	if !ok {
		return &RPCResponse{
			JSONRPC: "2.0",
			Error: &RPCError{
				Code:    -32602,
				Message: "Invalid params",
			},
			ID: req.ID,
		}
	}

	minerStr, ok := params["miner"].(string)
	if !ok {
		return &RPCResponse{
			JSONRPC: "2.0",
			Error: &RPCError{
				Code:    -32602,
				Message: "Invalid params",
				Data:    "miner parameter required",
			},
			ID: req.ID,
		}
	}

	// Parse miner address - handle kalon1 + hex format
	var miner core.Address

	if strings.HasPrefix(minerStr, "kalon1") {
		// Remove "kalon1" prefix and decode hex
		hexStr := strings.TrimPrefix(minerStr, "kalon1")
		if len(hexStr) == 40 {
			// Decode 40-char hex to 20 bytes
			decodedBytes, err := hex.DecodeString(hexStr)
			if err == nil && len(decodedBytes) == 20 {
				copy(miner[:], decodedBytes)
				log.Printf("✅ Parsed kalon1+hex address successfully")
			} else {
				log.Printf("❌ Failed to decode kalon1+hex: %v", err)
				return &RPCResponse{
					JSONRPC: "2.0",
					Error:   &RPCError{Code: -32602, Message: "Invalid miner address"},
					ID:      req.ID,
				}
			}
		} else {
			// Not a valid hex after kalon1
			log.Printf("❌ Invalid: kalon1 address has wrong length: %d", len(hexStr))
			return &RPCResponse{
				JSONRPC: "2.0",
				Error:   &RPCError{Code: -32602, Message: "Invalid miner address format"},
				ID:      req.ID,
			}
		}
	} else {
		// Try to parse as plain 40-char hex
		if len(minerStr) == 40 {
			decodedBytes, err := hex.DecodeString(minerStr)
			if err == nil && len(decodedBytes) == 20 {
				copy(miner[:], decodedBytes)
				log.Printf("✅ Parsed plain 40-char hex address")
			} else {
				log.Printf("❌ Invalid address format: %s", minerStr)
				return &RPCResponse{
					JSONRPC: "2.0",
					Error:   &RPCError{Code: -32602, Message: "Invalid miner address format"},
					ID:      req.ID,
				}
			}
		} else {
			log.Printf("❌ Invalid address format: %s (len=%d)", minerStr, len(minerStr))
			return &RPCResponse{
				JSONRPC: "2.0",
				Error:   &RPCError{Code: -32602, Message: "Invalid miner address format"},
				ID:      req.ID,
			}
		}
	}
	log.Printf("🔍 Miner address bytes: %x", miner)

	// Get current blockchain state
	bestBlock := s.blockchain.GetBestBlock()
	if bestBlock == nil {
		return &RPCResponse{
			JSONRPC: "2.0",
			Error: &RPCError{
				Code:    -32603,
				Message: "Internal error",
				Data:    "No blocks found",
			},
			ID: req.ID,
		}
	}

	// Create new block with rewards using CreateNewBlockV2
	block := s.blockchain.CreateNewBlockV2(miner, []core.Transaction{})
	log.Printf("🔍 Block created with %d transactions", len(block.Txs))
	log.Printf("🔍 Miner address in block: %x", block.Header.Miner)
	if len(block.Txs) > 0 && len(block.Txs[0].Outputs) > 0 {
		log.Printf("🔍 Reward TX Output - Address: %x (40 chars: %t)", block.Txs[0].Outputs[0].Address, len(hex.EncodeToString(block.Txs[0].Outputs[0].Address[:])) == 40)
		log.Printf("🔍 Reward TX Output - Amount: %d", block.Txs[0].Outputs[0].Amount)
	}
	if block == nil {
		return &RPCResponse{
			JSONRPC: "2.0",
			Error: &RPCError{
				Code:    -32603,
				Message: "Internal error",
				Data:    "Failed to create block template",
			},
			ID: req.ID,
		}
	}

	log.Printf("🔧 Creating template for block #%d with parent hash: %x", block.Header.Number, block.Header.ParentHash)

	// Serialize transactions properly for JSON response
	txList := make([]interface{}, 0, len(block.Txs))
	for _, tx := range block.Txs {
		txMap := map[string]interface{}{
			"hash":      hex.EncodeToString(tx.Hash[:]),
			"from":      tx.From.String(),
			"to":        tx.To.String(),
			"amount":    tx.Amount,
			"fee":       tx.Fee,
			"nonce":     tx.Nonce,
			"timestamp": tx.Timestamp.Unix(),
		}

		// Serialize outputs
		outputs := make([]interface{}, 0, len(tx.Outputs))
		for _, output := range tx.Outputs {
			outputs = append(outputs, map[string]interface{}{
				"address": hex.EncodeToString(output.Address[:]),
				"amount":  output.Amount,
			})
		}
		txMap["outputs"] = outputs

		txList = append(txList, txMap)
	}

	return &RPCResponse{
		JSONRPC: "2.0",
		Result: map[string]interface{}{
			"number":       block.Header.Number,
			"difficulty":   block.Header.Difficulty,
			"parentHash":   hex.EncodeToString(block.Header.ParentHash[:]),
			"timestamp":    block.Header.Timestamp.Unix(),
			"miner":        hex.EncodeToString(block.Header.Miner[:]),
			"transactions": txList,
		},
		ID: req.ID,
	}
}

// handleSubmitBlockV2 handles submitBlock requests professionally
func (s *ServerV2) handleSubmitBlockV2(req *RPCRequest) (response *RPCResponse) {
	defer func() {
		if r := recover(); r != nil {
			log.Printf("❌ PANIC in handleSubmitBlockV2: %v", r)
			response = &RPCResponse{
				JSONRPC: "2.0",
				Error: &RPCError{
					Code:    -32603,
					Message: "Internal error",
					Data:    fmt.Sprintf("Panic: %v", r),
				},
				ID: req.ID,
			}
		}
	}()

	params, ok := req.Params.(map[string]interface{})
	if !ok {
		return &RPCResponse{
			JSONRPC: "2.0",
			Error: &RPCError{
				Code:    -32602,
				Message: "Invalid params",
			},
			ID: req.ID,
		}
	}

	blockData, ok := params["block"].(map[string]interface{})
	if !ok {
		return &RPCResponse{
			JSONRPC: "2.0",
			Error: &RPCError{
				Code:    -32602,
				Message: "Invalid params",
				Data:    "block parameter required",
			},
			ID: req.ID,
		}
	}

	// Parse block data
	block, err := s.parseBlockData(blockData)
	if err != nil {
		log.Printf("❌ Failed to parse block data: %v", err)
		return &RPCResponse{
			JSONRPC: "2.0",
			Error: &RPCError{
				Code:    -32602,
				Message: "Invalid block data",
				Data:    err.Error(),
			},
			ID: req.ID,
		}
	}

	// Submit block to blockchain using V2 function
	if err := s.blockchain.AddBlockV2(block); err != nil {
		log.Printf("❌ Failed to add block: %v", err)
		return &RPCResponse{
			JSONRPC: "2.0",
			Error: &RPCError{
				Code:    -32603,
				Message: "Block submission failed",
				Data:    err.Error(),
			},
			ID: req.ID,
		}
	}

	log.Printf("✅ Block #%d submitted successfully: %x", block.Header.Number, block.Hash)

	return &RPCResponse{
		JSONRPC: "2.0",
		Result: map[string]interface{}{
			"success": true,
			"hash":    hex.EncodeToString(block.Hash[:]),
			"number":  block.Header.Number,
		},
		ID: req.ID,
	}
}

// parseBlockData parses block data from RPC request
func (s *ServerV2) parseBlockData(data map[string]interface{}) (*core.Block, error) {
	// Parse number
	number, ok := data["number"].(float64)
	if !ok {
		return nil, fmt.Errorf("invalid number")
	}

	// Parse difficulty
	difficulty, ok := data["difficulty"].(float64)
	if !ok {
		return nil, fmt.Errorf("invalid difficulty")
	}

	// Parse nonce
	nonce, ok := data["nonce"].(float64)
	if !ok {
		return nil, fmt.Errorf("invalid nonce")
	}

	// Parse hash
	hashStr, ok := data["hash"].(string)
	if !ok {
		return nil, fmt.Errorf("invalid hash")
	}

	hashBytes, err := hex.DecodeString(hashStr)
	if err != nil || len(hashBytes) != 32 {
		return nil, fmt.Errorf("invalid hash format")
	}

	// Parse parent hash
	parentHashStr, ok := data["parentHash"].(string)
	if !ok {
		return nil, fmt.Errorf("invalid parentHash")
	}

	parentHashBytes, err := hex.DecodeString(parentHashStr)
	if err != nil || len(parentHashBytes) != 32 {
		return nil, fmt.Errorf("invalid parentHash format")
	}

	// Parse timestamp
	timestamp, ok := data["timestamp"].(float64)
	if !ok {
		return nil, fmt.Errorf("invalid timestamp")
	}

	// Parse transactions from block data
	var transactions []core.Transaction
	log.Printf("🔍 DEBUG: Parsing block data, checking for transactions...")
	if txsData, ok := data["transactions"].([]interface{}); ok {
		log.Printf("🔍 DEBUG: Found %d transactions in block data", len(txsData))
		for _, txData := range txsData {
			if txMap, ok := txData.(map[string]interface{}); ok {
				// Parse transaction from map
				tx := core.Transaction{}

				// IMPORTANT: Parse transaction hash FIRST so it's available
				if hashStr, ok := txMap["hash"].(string); ok {
					if hashBytes, err := hex.DecodeString(hashStr); err == nil {
						copy(tx.Hash[:], hashBytes)
					}
				}

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
							if addressValue, ok := outputMap["address"]; ok {
								// Parse address from various formats
								var address core.Address
								addressSet := false

								// Try to parse as string (40-char hex or kalon1... format)
								if addressStr, ok := addressValue.(string); ok {
									// If it's a hex-encoded address (like from Miner)
									if len(addressStr) == 40 && isHexString(addressStr) {
										if decoded, err := hex.DecodeString(addressStr); err == nil && len(decoded) == 20 {
											copy(address[:], decoded)
											addressSet = true
										}
									} else {
										// Use AddressFromString for other formats
										address = core.AddressFromString(addressStr)
										addressSet = true
									}
								}

								// Try to parse as array of numbers
								if !addressSet {
									if addressBytes, ok := addressValue.([]interface{}); ok && len(addressBytes) == 20 {
										var addrBytes []byte
										for _, b := range addressBytes {
											if byteVal, ok := b.(float64); ok {
												addrBytes = append(addrBytes, byte(byteVal))
											}
										}
										if len(addrBytes) == 20 {
											copy(address[:], addrBytes)
											addressSet = true
										}
									}
								}

								if addressSet {
									output.Address = address
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

				// Calculate transaction hash if not set
				if tx.Hash == (core.Hash{}) {
					tx.Hash = core.CalculateTransactionHash(&tx)
				}

				transactions = append(transactions, tx)
				log.Printf("💰 Parsed transaction with %d outputs, total amount: %d, hash: %x", len(tx.Outputs), tx.Amount, tx.Hash)
			}
		}
	} else {
		log.Printf("⚠️ DEBUG: No transactions found in block data!")
	}

	log.Printf("🔍 DEBUG: Total transactions parsed: %d", len(transactions))

	// Create block with transactions
	block := &core.Block{
		Header: core.BlockHeader{
			Number:     uint64(number),
			Difficulty: uint64(difficulty),
			Nonce:      uint64(nonce),
			Timestamp:  time.Unix(int64(timestamp), 0),
		},
		Txs: transactions, // Use parsed transactions
	}

	// Copy hashes
	copy(block.Hash[:], hashBytes)
	copy(block.Header.ParentHash[:], parentHashBytes)

	return block, nil
}

// handleGetMiningInfo handles getMiningInfo requests
func (s *ServerV2) handleGetMiningInfo(req *RPCRequest) *RPCResponse {
	bestBlock := s.blockchain.GetBestBlock()
	if bestBlock == nil {
		return &RPCResponse{
			JSONRPC: "2.0",
			Error: &RPCError{
				Code:    -32603,
				Message: "Internal error",
				Data:    "No blocks found",
			},
			ID: req.ID,
		}
	}

	consensus := s.blockchain.GetConsensus()
	difficulty := consensus.CalculateDifficultyV2(bestBlock.Header.Number+1, bestBlock)

	return &RPCResponse{
		JSONRPC: "2.0",
		Result: map[string]interface{}{
			"height":     s.blockchain.GetHeight(),
			"difficulty": difficulty,
			"bestBlock":  hex.EncodeToString(bestBlock.Hash[:]),
		},
		ID: req.ID,
	}
}

// handleGetBalance handles getBalance requests
func (s *ServerV2) handleGetBalance(req *RPCRequest) *RPCResponse {
	// Parse parameters
	params, ok := req.Params.(map[string]interface{})
	if !ok {
		return &RPCResponse{
			JSONRPC: "2.0",
			Error: &RPCError{
				Code:    -32602,
				Message: "Invalid params",
				Data:    "Expected object with 'address' field",
			},
			ID: req.ID,
		}
	}

	addressStr, ok := params["address"].(string)
	if !ok {
		return &RPCResponse{
			JSONRPC: "2.0",
			Error: &RPCError{
				Code:    -32602,
				Message: "Invalid params",
				Data:    "Missing or invalid 'address' field",
			},
			ID: req.ID,
		}
	}

	// Convert string address to Address type
	address := core.AddressFromString(addressStr)

	// Get balance from blockchain
	balance := s.blockchain.GetBalance(address)

	// Debug logging
	log.Printf("🔍 Balance query - Address: %s, Parsed: %s, Balance: %d", addressStr, hex.EncodeToString(address[:]), balance)

	return &RPCResponse{
		JSONRPC: "2.0",
		Result:  balance,
		ID:      req.ID,
	}
}

// handleSendTransaction handles sendTransaction requests
func (s *ServerV2) handleSendTransaction(req *RPCRequest) *RPCResponse {
	params, ok := req.Params.(map[string]interface{})
	if !ok {
		return &RPCResponse{
			JSONRPC: "2.0",
			Error: &RPCError{
				Code:    -32602,
				Message: "Invalid params",
			},
			ID: req.ID,
		}
	}

	// Parse transaction fields
	fromStr, _ := params["from"].(string)
	toStr, _ := params["to"].(string)
	amount, _ := params["amount"].(float64)
	fee, _ := params["fee"].(float64)

	if fromStr == "" || toStr == "" || amount == 0 {
		return &RPCResponse{
			JSONRPC: "2.0",
			Error: &RPCError{
				Code:    -32602,
				Message: "Invalid params",
				Data:    "from, to and amount are required",
			},
			ID: req.ID,
		}
	}

	// Get addresses
	fromAddr := core.AddressFromString(fromStr)
	toAddr := core.AddressFromString(toStr)

	// Create transaction from UTXOs
	tx, err := s.blockchain.CreateTransaction(fromAddr, toAddr, uint64(amount), uint64(fee))
	if err != nil {
		return &RPCResponse{
			JSONRPC: "2.0",
			Error: &RPCError{
				Code:    -32603,
				Message: "Transaction creation failed",
				Data:    err.Error(),
			},
			ID: req.ID,
		}
	}

	log.Printf("📤 Transaction created - From: %s, To: %s, Amount: %d, Hash: %x", fromStr, toStr, tx.Amount, tx.Hash)

	// Add to mempool
	s.blockchain.GetMempool().AddTransaction(tx)

	// Return transaction hash
	return &RPCResponse{
		JSONRPC: "2.0",
		Result: map[string]interface{}{
			"txHash": hex.EncodeToString(tx.Hash[:]),
			"status": "pending",
		},
		ID: req.ID,
	}
}

// handleHealth handles health check requests
func (s *ServerV2) handleHealth(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"status":    "ok",
		"timestamp": time.Now(),
		"version":   "2.0",
		"height":    s.blockchain.GetHeight(),
	})
}

// writeError writes an error response
func (s *ServerV2) writeError(w http.ResponseWriter, id interface{}, code int, message, data string) {
	response := RPCResponse{
		JSONRPC: "2.0",
		Error: &RPCError{
			Code:    code,
			Message: message,
			Data:    data,
		},
		ID: id,
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// limitConnections limits concurrent connections professionally
func (s *ServerV2) limitConnections(h http.Handler) http.Handler {
	semaphore := make(chan struct{}, 50) // Max 50 concurrent connections

	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		select {
		case semaphore <- struct{}{}:
			defer func() { <-semaphore }()
			h.ServeHTTP(w, r)
		default:
			http.Error(w, "Too many connections", http.StatusServiceUnavailable)
		}
	})
}

// trackConnection tracks a client connection
func (s *ServerV2) trackConnection(connID string) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if conn, exists := s.connections[connID]; exists {
		conn.LastSeen = time.Now()
		conn.Requests++
	} else {
		s.connections[connID] = &Connection{
			ID:        connID,
			CreatedAt: time.Now(),
			LastSeen:  time.Now(),
			Requests:  1,
		}
	}
}

// cleanupConnections cleans up old connections
func (s *ServerV2) cleanupConnections() {
	ticker := time.NewTicker(5 * time.Minute)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			s.mu.Lock()
			now := time.Now()
			for id, conn := range s.connections {
				if now.Sub(conn.LastSeen) > 10*time.Minute {
					delete(s.connections, id)
				}
			}
			s.mu.Unlock()
		case <-s.ctx.Done():
			return
		}
	}
}

// Helper function to check if string is hex
func isHexString(s string) bool {
	for _, c := range s {
		if !((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')) {
			return false
		}
	}
	return true
}

// extractIP extracts the client IP from the request
func (s *ServerV2) extractIP(r *http.Request) string {
	ip := r.Header.Get("X-Forwarded-For")
	if ip == "" {
		ip = r.Header.Get("X-Real-Ip")
	}
	if ip == "" {
		ip = strings.Split(r.RemoteAddr, ":")[0]
	}
	return ip
}

// checkRateLimit checks if the request rate is within limits
func (s *ServerV2) checkRateLimit(ip string) bool {
	s.mu.Lock()
	defer s.mu.Unlock()

	// Get or create rate limit for this IP
	limit, exists := s.rateLimits[ip]
	if !exists {
		limit = &RateLimit{
			Count:          0,
			LastReset:      time.Now(),
			RequestsPerMin: 60, // Default: 60 requests per minute
		}
		s.rateLimits[ip] = limit
	}

	// Reset counter if more than a minute has passed
	if time.Since(limit.LastReset) > time.Minute {
		limit.Count = 0
		limit.LastReset = time.Now()
	}

	// Check if limit exceeded
	if limit.Count >= limit.RequestsPerMin {
		return false
	}

	// Increment counter
	limit.Count++
	return true
}
