package rpc

import (
	"encoding/hex"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"time"

	"github.com/kalon-network/kalon/core"
)

// Server represents the JSON-RPC server
type Server struct {
	addr       string
	blockchain Blockchain
	p2p        P2P
	miner      Miner
	handler    *RPCHandler
}

// Blockchain interface for RPC
type Blockchain interface {
	GetBestBlock() *core.Block
	GetBlockByHash(hash core.Hash) *core.Block
	GetBlockByNumber(number uint64) *core.Block
	GetHeight() uint64
	GetBalance(address core.Address) uint64
	GetTreasuryBalance() *core.TreasuryBalance
	ValidateTransaction(tx *core.Transaction) error
	AddTransaction(tx *core.Transaction) error
}

// P2P interface for RPC
type P2P interface {
	GetPeerCount() int
	GetPeers() []*Peer
	BroadcastBlock(block *core.Block) error
	BroadcastTransaction(tx *core.Transaction) error
}

// Miner interface for RPC
type Miner interface {
	IsRunning() bool
	GetStats() *MinerStats
	Start() error
	Stop()
	GetHashRate() float64
	GetBlocksFound() uint64
}

// Use core types directly

// Peer represents a P2P peer
type Peer struct {
	ID        string    `json:"id"`
	Address   string    `json:"address"`
	Connected bool      `json:"connected"`
	Version   string    `json:"version"`
	Height    uint64    `json:"height"`
	LastSeen  time.Time `json:"lastSeen"`
}

// Use core.TreasuryBalance directly

// MinerStats represents miner statistics
type MinerStats struct {
	StartTime       time.Time `json:"startTime"`
	TotalHashes     uint64    `json:"totalHashes"`
	BlocksFound     uint64    `json:"blocksFound"`
	CurrentHashRate float64   `json:"currentHashRate"`
	LastBlockTime   time.Time `json:"lastBlockTime"`
	Difficulty      uint64    `json:"difficulty"`
}

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

// RPCError represents a JSON-RPC error
type RPCError struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
	Data    string `json:"data,omitempty"`
}

// RPCHandler handles RPC requests
type RPCHandler struct {
	blockchain Blockchain
	p2p        P2P
	miner      Miner
}

// NewServer creates a new RPC server
func NewServer(addr string, blockchain Blockchain, p2p P2P, miner Miner) *Server {
	handler := &RPCHandler{
		blockchain: blockchain,
		p2p:        p2p,
		miner:      miner,
	}

	return &Server{
		addr:       addr,
		blockchain: blockchain,
		p2p:        p2p,
		miner:      miner,
		handler:    handler,
	}
}

// Start starts the RPC server
func (s *Server) Start() error {
	mux := http.NewServeMux()
	mux.HandleFunc("/", s.handleRequest)
	mux.HandleFunc("/health", s.handleHealth)
	mux.HandleFunc("/rpc", s.handleRequest)

	log.Printf("RPC server starting on %s", s.addr)
	return http.ListenAndServe(s.addr, mux)
}

// handleRequest handles RPC requests
func (s *Server) handleRequest(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Parse request
	var req RPCRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		s.writeError(w, nil, -32700, "Parse error", err.Error())
		return
	}

	// Handle request
	response := s.handler.HandleRequest(&req)

	// Write response
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// handleHealth handles health check requests
func (s *Server) handleHealth(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"status":    "ok",
		"timestamp": time.Now(),
		"version":   "1.0",
	})
}

// writeError writes an error response
func (s *Server) writeError(w http.ResponseWriter, id interface{}, code int, message, data string) {
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

// HandleRequest handles an RPC request
func (h *RPCHandler) HandleRequest(req *RPCRequest) *RPCResponse {
	switch req.Method {
	case "getBestBlock":
		return h.handleGetBestBlock(req)
	case "getBlockByHash":
		return h.handleGetBlockByHash(req)
	case "getBlockByNumber":
		return h.handleGetBlockByNumber(req)
	case "getHeight":
		return h.handleGetHeight(req)
	case "getBalance":
		return h.handleGetBalance(req)
	case "getTreasuryBalance":
		return h.handleGetTreasuryBalance(req)
	case "sendTransaction":
		return h.handleSendTransaction(req)
	case "getPeerCount":
		return h.handleGetPeerCount(req)
	case "getPeers":
		return h.handleGetPeers(req)
	case "getMiningInfo":
		return h.handleGetMiningInfo(req)
	case "startMining":
		return h.handleStartMining(req)
	case "stopMining":
		return h.handleStopMining(req)
	case "getNetworkInfo":
		return h.handleGetNetworkInfo(req)
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

// handleGetBestBlock handles getBestBlock requests
func (h *RPCHandler) handleGetBestBlock(req *RPCRequest) *RPCResponse {
	block := h.blockchain.GetBestBlock()
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
		Result:  block,
		ID:      req.ID,
	}
}

// handleGetBlockByHash handles getBlockByHash requests
func (h *RPCHandler) handleGetBlockByHash(req *RPCRequest) *RPCResponse {
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

	hashStr, ok := params["hash"].(string)
	if !ok {
		return &RPCResponse{
			JSONRPC: "2.0",
			Error: &RPCError{
				Code:    -32602,
				Message: "Invalid params",
				Data:    "hash parameter required",
			},
			ID: req.ID,
		}
	}

	// Parse hash
	hashBytes, err := hex.DecodeString(hashStr)
	if err != nil || len(hashBytes) != 32 {
		return &RPCResponse{
			JSONRPC: "2.0",
			Error: &RPCError{
				Code:    -32602,
				Message: "Invalid params",
				Data:    "Invalid hash format",
			},
			ID: req.ID,
		}
	}

	var hash core.Hash
	copy(hash[:], hashBytes)

	block := h.blockchain.GetBlockByHash(hash)
	if block == nil {
		return &RPCResponse{
			JSONRPC: "2.0",
			Error: &RPCError{
				Code:    -32603,
				Message: "Internal error",
				Data:    "Block not found",
			},
			ID: req.ID,
		}
	}

	return &RPCResponse{
		JSONRPC: "2.0",
		Result:  block,
		ID:      req.ID,
	}
}

// handleGetBlockByNumber handles getBlockByNumber requests
func (h *RPCHandler) handleGetBlockByNumber(req *RPCRequest) *RPCResponse {
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

	number, ok := params["number"].(float64)
	if !ok {
		return &RPCResponse{
			JSONRPC: "2.0",
			Error: &RPCError{
				Code:    -32602,
				Message: "Invalid params",
				Data:    "number parameter required",
			},
			ID: req.ID,
		}
	}

	block := h.blockchain.GetBlockByNumber(uint64(number))
	if block == nil {
		return &RPCResponse{
			JSONRPC: "2.0",
			Error: &RPCError{
				Code:    -32603,
				Message: "Internal error",
				Data:    "Block not found",
			},
			ID: req.ID,
		}
	}

	return &RPCResponse{
		JSONRPC: "2.0",
		Result:  block,
		ID:      req.ID,
	}
}

// handleGetHeight handles getHeight requests
func (h *RPCHandler) handleGetHeight(req *RPCRequest) *RPCResponse {
	height := h.blockchain.GetHeight()
	return &RPCResponse{
		JSONRPC: "2.0",
		Result:  height,
		ID:      req.ID,
	}
}

// handleGetBalance handles getBalance requests
func (h *RPCHandler) handleGetBalance(req *RPCRequest) *RPCResponse {
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

	addressStr, ok := params["address"].(string)
	if !ok {
		return &RPCResponse{
			JSONRPC: "2.0",
			Error: &RPCError{
				Code:    -32602,
				Message: "Invalid params",
				Data:    "address parameter required",
			},
			ID: req.ID,
		}
	}

	// Parse address
	addressBytes, err := hex.DecodeString(addressStr)
	if err != nil || len(addressBytes) != 20 {
		return &RPCResponse{
			JSONRPC: "2.0",
			Error: &RPCError{
				Code:    -32602,
				Message: "Invalid params",
				Data:    "Invalid address format",
			},
			ID: req.ID,
		}
	}

	var address core.Address
	copy(address[:], addressBytes)

	balance := h.blockchain.GetBalance(address)
	return &RPCResponse{
		JSONRPC: "2.0",
		Result:  balance,
		ID:      req.ID,
	}
}

// handleGetTreasuryBalance handles getTreasuryBalance requests
func (h *RPCHandler) handleGetTreasuryBalance(req *RPCRequest) *RPCResponse {
	balance := h.blockchain.GetTreasuryBalance()
	return &RPCResponse{
		JSONRPC: "2.0",
		Result:  balance,
		ID:      req.ID,
	}
}

// handleSendTransaction handles sendTransaction requests
func (h *RPCHandler) handleSendTransaction(req *RPCRequest) *RPCResponse {
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

	// Parse transaction
	txData, err := json.Marshal(params)
	if err != nil {
		return &RPCResponse{
			JSONRPC: "2.0",
			Error: &RPCError{
				Code:    -32602,
				Message: "Invalid params",
				Data:    err.Error(),
			},
			ID: req.ID,
		}
	}

	var tx core.Transaction
	if err := json.Unmarshal(txData, &tx); err != nil {
		return &RPCResponse{
			JSONRPC: "2.0",
			Error: &RPCError{
				Code:    -32602,
				Message: "Invalid params",
				Data:    err.Error(),
			},
			ID: req.ID,
		}
	}

	// Validate transaction
	if err := h.blockchain.ValidateTransaction(&tx); err != nil {
		return &RPCResponse{
			JSONRPC: "2.0",
			Error: &RPCError{
				Code:    -32603,
				Message: "Internal error",
				Data:    err.Error(),
			},
			ID: req.ID,
		}
	}

	// Add transaction
	if err := h.blockchain.AddTransaction(&tx); err != nil {
		return &RPCResponse{
			JSONRPC: "2.0",
			Error: &RPCError{
				Code:    -32603,
				Message: "Internal error",
				Data:    err.Error(),
			},
			ID: req.ID,
		}
	}

	// Broadcast transaction
	if err := h.p2p.BroadcastTransaction(&tx); err != nil {
		log.Printf("Failed to broadcast transaction: %v", err)
	}

	return &RPCResponse{
		JSONRPC: "2.0",
		Result:  map[string]string{"txHash": fmt.Sprintf("%x", tx.Hash)},
		ID:      req.ID,
	}
}

// handleGetPeerCount handles getPeerCount requests
func (h *RPCHandler) handleGetPeerCount(req *RPCRequest) *RPCResponse {
	count := h.p2p.GetPeerCount()
	return &RPCResponse{
		JSONRPC: "2.0",
		Result:  count,
		ID:      req.ID,
	}
}

// handleGetPeers handles getPeers requests
func (h *RPCHandler) handleGetPeers(req *RPCRequest) *RPCResponse {
	peers := h.p2p.GetPeers()
	return &RPCResponse{
		JSONRPC: "2.0",
		Result:  peers,
		ID:      req.ID,
	}
}

// handleGetMiningInfo handles getMiningInfo requests
func (h *RPCHandler) handleGetMiningInfo(req *RPCRequest) *RPCResponse {
	if h.miner == nil {
		return &RPCResponse{
			JSONRPC: "2.0",
			Error: &RPCError{
				Code:    -32603,
				Message: "Internal error",
				Data:    "Miner not available",
			},
			ID: req.ID,
		}
	}

	stats := h.miner.GetStats()
	return &RPCResponse{
		JSONRPC: "2.0",
		Result:  stats,
		ID:      req.ID,
	}
}

// handleStartMining handles startMining requests
func (h *RPCHandler) handleStartMining(req *RPCRequest) *RPCResponse {
	if h.miner == nil {
		return &RPCResponse{
			JSONRPC: "2.0",
			Error: &RPCError{
				Code:    -32603,
				Message: "Internal error",
				Data:    "Miner not available",
			},
			ID: req.ID,
		}
	}

	if err := h.miner.Start(); err != nil {
		return &RPCResponse{
			JSONRPC: "2.0",
			Error: &RPCError{
				Code:    -32603,
				Message: "Internal error",
				Data:    err.Error(),
			},
			ID: req.ID,
		}
	}

	return &RPCResponse{
		JSONRPC: "2.0",
		Result:  "Mining started",
		ID:      req.ID,
	}
}

// handleStopMining handles stopMining requests
func (h *RPCHandler) handleStopMining(req *RPCRequest) *RPCResponse {
	if h.miner == nil {
		return &RPCResponse{
			JSONRPC: "2.0",
			Error: &RPCError{
				Code:    -32603,
				Message: "Internal error",
				Data:    "Miner not available",
			},
			ID: req.ID,
		}
	}

	h.miner.Stop()
	return &RPCResponse{
		JSONRPC: "2.0",
		Result:  "Mining stopped",
		ID:      req.ID,
	}
}

// handleGetNetworkInfo handles getNetworkInfo requests
func (h *RPCHandler) handleGetNetworkInfo(req *RPCRequest) *RPCResponse {
	info := map[string]interface{}{
		"blockchain": map[string]interface{}{
			"height": h.blockchain.GetHeight(),
		},
		"p2p": map[string]interface{}{
			"peerCount": h.p2p.GetPeerCount(),
		},
	}

	if h.miner != nil {
		info["miner"] = map[string]interface{}{
			"running":     h.miner.IsRunning(),
			"hashRate":    h.miner.GetHashRate(),
			"blocksFound": h.miner.GetBlocksFound(),
		}
	}

	return &RPCResponse{
		JSONRPC: "2.0",
		Result:  info,
		ID:      req.ID,
	}
}
