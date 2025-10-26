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

// ServerV2 represents a professional RPC server
type ServerV2 struct {
	addr        string
	blockchain  *core.BlockchainV2
	mu          sync.RWMutex
	connections map[string]*Connection
	eventBus    *core.EventBus
	ctx         context.Context
	cancel      context.CancelFunc
}

// Connection represents a client connection
type Connection struct {
	ID        string
	CreatedAt time.Time
	LastSeen  time.Time
	Requests  int64
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
	// Track connection
	connID := r.RemoteAddr
	s.trackConnection(connID)

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
	json.NewEncoder(w).Encode(response)
}

// handleRPCMethod handles RPC methods professionally
func (s *ServerV2) handleRPCMethod(req *RPCRequest) *RPCResponse {
	switch req.Method {
	case "getHeight":
		return s.handleGetHeight(req)
	case "getBestBlock":
		return s.handleGetBestBlock(req)
	case "createBlockTemplate":
		return s.handleCreateBlockTemplateV2(req)
	case "submitBlock":
		return s.handleSubmitBlockV2(req)
	case "getMiningInfo":
		return s.handleGetMiningInfo(req)
	case "getBalance":
		return s.handleGetBalance(req)
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
					Error: &RPCError{Code: -32602, Message: "Invalid miner address"},
					ID: req.ID,
				}
			}
		} else {
			// Not a valid hex after kalon1
			log.Printf("❌ Invalid: kalon1 address has wrong length: %d", len(hexStr))
			return &RPCResponse{
				JSONRPC: "2.0",
				Error: &RPCError{Code: -32602, Message: "Invalid miner address format"},
				ID: req.ID,
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
					Error: &RPCError{Code: -32602, Message: "Invalid miner address format"},
					ID: req.ID,
				}
			}
		} else {
			log.Printf("❌ Invalid address format: %s (len=%d)", minerStr, len(minerStr))
			return &RPCResponse{
				JSONRPC: "2.0",
				Error: &RPCError{Code: -32602, Message: "Invalid miner address format"},
				ID: req.ID,
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

	return &RPCResponse{
		JSONRPC: "2.0",
		Result: map[string]interface{}{
			"number":       block.Header.Number,
			"difficulty":   block.Header.Difficulty,
			"parentHash":   hex.EncodeToString(block.Header.ParentHash[:]),
			"timestamp":    block.Header.Timestamp.Unix(),
			"miner":        hex.EncodeToString(block.Header.Miner[:]),
			"transactions": block.Txs, // Include transactions with block rewards
		},
		ID: req.ID,
	}
}

// handleSubmitBlockV2 handles submitBlock requests professionally
func (s *ServerV2) handleSubmitBlockV2(req *RPCRequest) *RPCResponse {
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
							if addressValue, ok := outputMap["address"]; ok {
								// Parse address from various formats
								if addressStr, ok := addressValue.(string); ok {
									// First check if it's 20 bytes directly
									if len(addressStr) == 20 {
										copy(output.Address[:], []byte(addressStr))
										log.Printf("✅ Parsed 20-byte address: %x", output.Address)
									} else if len(addressStr) == 40 {
										// If it's 40 hex chars, decode directly
										if decoded, err := hex.DecodeString(addressStr); err == nil && len(decoded) == 20 {
											copy(output.Address[:], decoded)
											log.Printf("✅ Parsed hex address: %s -> %x", addressStr[:20]+"...", output.Address)
										} else {
											log.Printf("⚠️ Failed to decode hex: %s", addressStr)
											// Fallback to AddressFromString
											output.Address = core.AddressFromString(addressStr)
										}
									} else {
										// Use AddressFromString for other formats (including Bech32)
										output.Address = core.AddressFromString(addressStr)
										log.Printf("✅ Used AddressFromString: %s -> %x", addressStr, output.Address)
									}
								} else if addressBytes, ok := addressValue.([]byte); ok && len(addressBytes) == 20 {
									copy(output.Address[:], addressBytes)
									log.Printf("✅ Parsed bytes address: %x", output.Address)
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

				transactions = append(transactions, tx)
				log.Printf("💰 Parsed transaction with %d outputs, total amount: %d", len(tx.Outputs), tx.Amount)
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
