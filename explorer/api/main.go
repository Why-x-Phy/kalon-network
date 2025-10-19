package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os"
	"strconv"
	"time"

	"github.com/gorilla/mux"
)

// ExplorerAPI represents the explorer API server
type ExplorerAPI struct {
	rpcURL string
	port   string
}

// Block represents a blockchain block
type Block struct {
	Hash         string        `json:"hash"`
	Number       uint64        `json:"number"`
	ParentHash   string        `json:"parentHash"`
	Timestamp    time.Time     `json:"timestamp"`
	Difficulty   uint64        `json:"difficulty"`
	Miner        string        `json:"miner"`
	Nonce        uint64        `json:"nonce"`
	MerkleRoot   string        `json:"merkleRoot"`
	TxCount      uint32        `json:"txCount"`
	NetworkFee   uint64        `json:"networkFee"`
	TreasuryFee  uint64        `json:"treasuryFee"`
	Size         int           `json:"size"`
	GasUsed      uint64        `json:"gasUsed"`
	GasLimit     uint64        `json:"gasLimit"`
	Transactions []Transaction `json:"transactions"`
}

// Transaction represents a blockchain transaction
type Transaction struct {
	Hash        string    `json:"hash"`
	From        string    `json:"from"`
	To          string    `json:"to"`
	Amount      uint64    `json:"amount"`
	Nonce       uint64    `json:"nonce"`
	Fee         uint64    `json:"fee"`
	GasUsed     uint64    `json:"gasUsed"`
	GasPrice    uint64    `json:"gasPrice"`
	Data        string    `json:"data"`
	Timestamp   time.Time `json:"timestamp"`
	BlockHash   string    `json:"blockHash"`
	BlockNumber uint64    `json:"blockNumber"`
	Status      string    `json:"status"`
}

// Address represents an address with balance
type Address struct {
	Address    string    `json:"address"`
	Balance    uint64    `json:"balance"`
	TxCount    uint64    `json:"txCount"`
	FirstSeen  time.Time `json:"firstSeen"`
	LastSeen   time.Time `json:"lastSeen"`
	IsContract bool      `json:"isContract"`
}

// TreasuryInfo represents treasury information
type TreasuryInfo struct {
	Address     string    `json:"address"`
	Balance     uint64    `json:"balance"`
	BlockFees   uint64    `json:"blockFees"`
	TxFees      uint64    `json:"txFees"`
	TotalIncome uint64    `json:"totalIncome"`
	LastUpdate  time.Time `json:"lastUpdate"`
}

// NetworkStats represents network statistics
type NetworkStats struct {
	BlockHeight     uint64    `json:"blockHeight"`
	TotalBlocks     uint64    `json:"totalBlocks"`
	TotalTxs        uint64    `json:"totalTxs"`
	TotalAddresses  uint64    `json:"totalAddresses"`
	NetworkHashRate float64   `json:"networkHashRate"`
	Difficulty      uint64    `json:"difficulty"`
	BlockTime       float64   `json:"blockTime"`
	LastBlockTime   time.Time `json:"lastBlockTime"`
	Peers           int       `json:"peers"`
	MempoolSize     int       `json:"mempoolSize"`
}

// MempoolTx represents a mempool transaction
type MempoolTx struct {
	Hash      string    `json:"hash"`
	From      string    `json:"from"`
	To        string    `json:"to"`
	Amount    uint64    `json:"amount"`
	Fee       uint64    `json:"fee"`
	GasPrice  uint64    `json:"gasPrice"`
	Timestamp time.Time `json:"timestamp"`
	Priority  int       `json:"priority"`
}

// APIResponse represents a generic API response
type APIResponse struct {
	Success bool        `json:"success"`
	Data    interface{} `json:"data,omitempty"`
	Error   string      `json:"error,omitempty"`
	Meta    *Meta       `json:"meta,omitempty"`
}

// Meta represents pagination metadata
type Meta struct {
	Page       int   `json:"page"`
	Limit      int   `json:"limit"`
	Total      int64 `json:"total"`
	TotalPages int   `json:"totalPages"`
}

// NewExplorerAPI creates a new explorer API
func NewExplorerAPI(rpcURL, port string) *ExplorerAPI {
	return &ExplorerAPI{
		rpcURL: rpcURL,
		port:   port,
	}
}

// Start starts the explorer API server
func (api *ExplorerAPI) Start() error {
	router := mux.NewRouter()

	// CORS middleware
	router.Use(corsMiddleware)

	// API routes
	api.setupRoutes(router)

	log.Printf("Explorer API starting on port %s", api.port)
	return http.ListenAndServe(":"+api.port, router)
}

// setupRoutes sets up API routes
func (api *ExplorerAPI) setupRoutes(router *mux.Router) {
	// Health check
	router.HandleFunc("/health", api.handleHealth).Methods("GET")

	// Block routes
	router.HandleFunc("/blocks", api.handleGetBlocks).Methods("GET")
	router.HandleFunc("/blocks/latest", api.handleGetLatestBlock).Methods("GET")
	router.HandleFunc("/blocks/{hash}", api.handleGetBlockByHash).Methods("GET")
	router.HandleFunc("/blocks/height/{height}", api.handleGetBlockByHeight).Methods("GET")

	// Transaction routes
	router.HandleFunc("/transactions", api.handleGetTransactions).Methods("GET")
	router.HandleFunc("/transactions/{hash}", api.handleGetTransaction).Methods("GET")
	router.HandleFunc("/transactions/pending", api.handleGetPendingTransactions).Methods("GET")

	// Address routes
	router.HandleFunc("/addresses/{address}", api.handleGetAddress).Methods("GET")
	router.HandleFunc("/addresses/{address}/transactions", api.handleGetAddressTransactions).Methods("GET")
	router.HandleFunc("/addresses/{address}/balance", api.handleGetAddressBalance).Methods("GET")

	// Treasury routes
	router.HandleFunc("/treasury", api.handleGetTreasury).Methods("GET")

	// Network routes
	router.HandleFunc("/network/stats", api.handleGetNetworkStats).Methods("GET")
	router.HandleFunc("/network/peers", api.handleGetPeers).Methods("GET")

	// Search routes
	router.HandleFunc("/search", api.handleSearch).Methods("GET")

	// Stats routes
	router.HandleFunc("/stats", api.handleGetStats).Methods("GET")
}

// CORS middleware
func corsMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")

		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}

		next.ServeHTTP(w, r)
	})
}

// handleHealth handles health check requests
func (api *ExplorerAPI) handleHealth(w http.ResponseWriter, r *http.Request) {
	response := APIResponse{
		Success: true,
		Data: map[string]interface{}{
			"status":    "healthy",
			"timestamp": time.Now(),
			"version":   "1.0.0",
		},
	}
	api.writeJSON(w, http.StatusOK, response)
}

// handleGetBlocks handles get blocks requests
func (api *ExplorerAPI) handleGetBlocks(w http.ResponseWriter, r *http.Request) {
	// Parse query parameters
	page, _ := strconv.Atoi(r.URL.Query().Get("page"))
	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))

	if page <= 0 {
		page = 1
	}
	if limit <= 0 || limit > 100 {
		limit = 20
	}

	// Mock data for now
	blocks := []Block{
		{
			Hash:        "0x1234567890abcdef",
			Number:      1,
			ParentHash:  "0x0000000000000000",
			Timestamp:   time.Now().Add(-1 * time.Hour),
			Difficulty:  1000,
			Miner:       "kalon1miner123456789",
			Nonce:       12345,
			MerkleRoot:  "0xabcdef1234567890",
			TxCount:     5,
			NetworkFee:  250000,
			TreasuryFee: 250000,
			Size:        1024,
			GasUsed:     21000,
			GasLimit:    1000000,
		},
	}

	response := APIResponse{
		Success: true,
		Data:    blocks,
		Meta: &Meta{
			Page:       page,
			Limit:      limit,
			Total:      1,
			TotalPages: 1,
		},
	}
	api.writeJSON(w, http.StatusOK, response)
}

// handleGetLatestBlock handles get latest block requests
func (api *ExplorerAPI) handleGetLatestBlock(w http.ResponseWriter, r *http.Request) {
	// Mock data
	block := Block{
		Hash:        "0x1234567890abcdef",
		Number:      1,
		ParentHash:  "0x0000000000000000",
		Timestamp:   time.Now().Add(-1 * time.Hour),
		Difficulty:  1000,
		Miner:       "kalon1miner123456789",
		Nonce:       12345,
		MerkleRoot:  "0xabcdef1234567890",
		TxCount:     5,
		NetworkFee:  250000,
		TreasuryFee: 250000,
		Size:        1024,
		GasUsed:     21000,
		GasLimit:    1000000,
	}

	response := APIResponse{
		Success: true,
		Data:    block,
	}
	api.writeJSON(w, http.StatusOK, response)
}

// handleGetBlockByHash handles get block by hash requests
func (api *ExplorerAPI) handleGetBlockByHash(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	hash := vars["hash"]

	// Mock data
	block := Block{
		Hash:        hash,
		Number:      1,
		ParentHash:  "0x0000000000000000",
		Timestamp:   time.Now().Add(-1 * time.Hour),
		Difficulty:  1000,
		Miner:       "kalon1miner123456789",
		Nonce:       12345,
		MerkleRoot:  "0xabcdef1234567890",
		TxCount:     5,
		NetworkFee:  250000,
		TreasuryFee: 250000,
		Size:        1024,
		GasUsed:     21000,
		GasLimit:    1000000,
	}

	response := APIResponse{
		Success: true,
		Data:    block,
	}
	api.writeJSON(w, http.StatusOK, response)
}

// handleGetBlockByHeight handles get block by height requests
func (api *ExplorerAPI) handleGetBlockByHeight(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	height, err := strconv.ParseUint(vars["height"], 10, 64)
	if err != nil {
		api.writeError(w, http.StatusBadRequest, "Invalid height")
		return
	}

	// Mock data
	block := Block{
		Hash:        "0x1234567890abcdef",
		Number:      height,
		ParentHash:  "0x0000000000000000",
		Timestamp:   time.Now().Add(-1 * time.Hour),
		Difficulty:  1000,
		Miner:       "kalon1miner123456789",
		Nonce:       12345,
		MerkleRoot:  "0xabcdef1234567890",
		TxCount:     5,
		NetworkFee:  250000,
		TreasuryFee: 250000,
		Size:        1024,
		GasUsed:     21000,
		GasLimit:    1000000,
	}

	response := APIResponse{
		Success: true,
		Data:    block,
	}
	api.writeJSON(w, http.StatusOK, response)
}

// handleGetTransactions handles get transactions requests
func (api *ExplorerAPI) handleGetTransactions(w http.ResponseWriter, r *http.Request) {
	// Mock data
	transactions := []Transaction{
		{
			Hash:        "0xtx1234567890abcdef",
			From:        "kalon1sender123456789",
			To:          "kalon1receiver123456789",
			Amount:      1000000,
			Nonce:       1,
			Fee:         10000,
			GasUsed:     21000,
			GasPrice:    1000,
			Data:        "0x",
			Timestamp:   time.Now().Add(-30 * time.Minute),
			BlockHash:   "0x1234567890abcdef",
			BlockNumber: 1,
			Status:      "confirmed",
		},
	}

	response := APIResponse{
		Success: true,
		Data:    transactions,
	}
	api.writeJSON(w, http.StatusOK, response)
}

// handleGetTransaction handles get transaction requests
func (api *ExplorerAPI) handleGetTransaction(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	hash := vars["hash"]

	// Mock data
	transaction := Transaction{
		Hash:        hash,
		From:        "kalon1sender123456789",
		To:          "kalon1receiver123456789",
		Amount:      1000000,
		Nonce:       1,
		Fee:         10000,
		GasUsed:     21000,
		GasPrice:    1000,
		Data:        "0x",
		Timestamp:   time.Now().Add(-30 * time.Minute),
		BlockHash:   "0x1234567890abcdef",
		BlockNumber: 1,
		Status:      "confirmed",
	}

	response := APIResponse{
		Success: true,
		Data:    transaction,
	}
	api.writeJSON(w, http.StatusOK, response)
}

// handleGetPendingTransactions handles get pending transactions requests
func (api *ExplorerAPI) handleGetPendingTransactions(w http.ResponseWriter, r *http.Request) {
	// Mock data
	transactions := []MempoolTx{
		{
			Hash:      "0xtx1234567890abcdef",
			From:      "kalon1sender123456789",
			To:        "kalon1receiver123456789",
			Amount:    1000000,
			Fee:       10000,
			GasPrice:  1000,
			Timestamp: time.Now(),
			Priority:  1,
		},
	}

	response := APIResponse{
		Success: true,
		Data:    transactions,
	}
	api.writeJSON(w, http.StatusOK, response)
}

// handleGetAddress handles get address requests
func (api *ExplorerAPI) handleGetAddress(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	address := vars["address"]

	// Mock data
	addr := Address{
		Address:    address,
		Balance:    1000000000,
		TxCount:    25,
		FirstSeen:  time.Now().Add(-24 * time.Hour),
		LastSeen:   time.Now().Add(-1 * time.Hour),
		IsContract: false,
	}

	response := APIResponse{
		Success: true,
		Data:    addr,
	}
	api.writeJSON(w, http.StatusOK, response)
}

// handleGetAddressTransactions handles get address transactions requests
func (api *ExplorerAPI) handleGetAddressTransactions(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	address := vars["address"]

	// Mock data
	transactions := []Transaction{
		{
			Hash:        "0xtx1234567890abcdef",
			From:        address,
			To:          "kalon1receiver123456789",
			Amount:      1000000,
			Nonce:       1,
			Fee:         10000,
			GasUsed:     21000,
			GasPrice:    1000,
			Data:        "0x",
			Timestamp:   time.Now().Add(-30 * time.Minute),
			BlockHash:   "0x1234567890abcdef",
			BlockNumber: 1,
			Status:      "confirmed",
		},
	}

	response := APIResponse{
		Success: true,
		Data:    transactions,
	}
	api.writeJSON(w, http.StatusOK, response)
}

// handleGetAddressBalance handles get address balance requests
func (api *ExplorerAPI) handleGetAddressBalance(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	address := vars["address"]

	// Mock data
	balance := map[string]interface{}{
		"address": address,
		"balance": 1000000000,
		"unit":    "micro-KALON",
	}

	response := APIResponse{
		Success: true,
		Data:    balance,
	}
	api.writeJSON(w, http.StatusOK, response)
}

// handleGetTreasury handles get treasury requests
func (api *ExplorerAPI) handleGetTreasury(w http.ResponseWriter, r *http.Request) {
	// Mock data
	treasury := TreasuryInfo{
		Address:     "kalon1treasury00000000000000000000000",
		Balance:     5000000000,
		BlockFees:   2500000000,
		TxFees:      2500000000,
		TotalIncome: 5000000000,
		LastUpdate:  time.Now(),
	}

	response := APIResponse{
		Success: true,
		Data:    treasury,
	}
	api.writeJSON(w, http.StatusOK, response)
}

// handleGetNetworkStats handles get network stats requests
func (api *ExplorerAPI) handleGetNetworkStats(w http.ResponseWriter, r *http.Request) {
	// Mock data
	stats := NetworkStats{
		BlockHeight:     1,
		TotalBlocks:     1,
		TotalTxs:        5,
		TotalAddresses:  10,
		NetworkHashRate: 1000.0,
		Difficulty:      1000,
		BlockTime:       30.0,
		LastBlockTime:   time.Now().Add(-1 * time.Hour),
		Peers:           5,
		MempoolSize:     3,
	}

	response := APIResponse{
		Success: true,
		Data:    stats,
	}
	api.writeJSON(w, http.StatusOK, response)
}

// handleGetPeers handles get peers requests
func (api *ExplorerAPI) handleGetPeers(w http.ResponseWriter, r *http.Request) {
	// Mock data
	peers := []map[string]interface{}{
		{
			"id":      "peer1",
			"address": "192.168.1.100:17333",
			"version": "1.0.0",
			"height":  1,
			"latency": 50,
		},
		{
			"id":      "peer2",
			"address": "192.168.1.101:17333",
			"version": "1.0.0",
			"height":  1,
			"latency": 75,
		},
	}

	response := APIResponse{
		Success: true,
		Data:    peers,
	}
	api.writeJSON(w, http.StatusOK, response)
}

// handleSearch handles search requests
func (api *ExplorerAPI) handleSearch(w http.ResponseWriter, r *http.Request) {
	query := r.URL.Query().Get("q")
	if query == "" {
		api.writeError(w, http.StatusBadRequest, "Query parameter 'q' is required")
		return
	}

	// Mock search results
	results := map[string]interface{}{
		"query": query,
		"type":  "unknown",
		"data":  nil,
	}

	// Simple search logic
	if len(query) == 64 && query[:2] == "0x" {
		results["type"] = "block"
		results["data"] = map[string]string{"hash": query}
	} else if len(query) == 40 && query[:5] == "kalon" {
		results["type"] = "address"
		results["data"] = map[string]string{"address": query}
	} else if len(query) == 66 && query[:2] == "0x" {
		results["type"] = "transaction"
		results["data"] = map[string]string{"hash": query}
	}

	response := APIResponse{
		Success: true,
		Data:    results,
	}
	api.writeJSON(w, http.StatusOK, response)
}

// handleGetStats handles get stats requests
func (api *ExplorerAPI) handleGetStats(w http.ResponseWriter, r *http.Request) {
	// Mock data
	stats := map[string]interface{}{
		"blocks": map[string]interface{}{
			"total":   1,
			"latest":  1,
			"pending": 0,
		},
		"transactions": map[string]interface{}{
			"total":     5,
			"pending":   3,
			"confirmed": 2,
		},
		"addresses": map[string]interface{}{
			"total":  10,
			"active": 8,
		},
		"network": map[string]interface{}{
			"hashRate":   1000.0,
			"difficulty": 1000,
			"blockTime":  30.0,
			"peers":      5,
		},
		"treasury": map[string]interface{}{
			"balance":   5000000000,
			"blockFees": 2500000000,
			"txFees":    2500000000,
		},
	}

	response := APIResponse{
		Success: true,
		Data:    stats,
	}
	api.writeJSON(w, http.StatusOK, response)
}

// writeJSON writes JSON response
func (api *ExplorerAPI) writeJSON(w http.ResponseWriter, status int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(data)
}

// writeError writes error response
func (api *ExplorerAPI) writeError(w http.ResponseWriter, status int, message string) {
	response := APIResponse{
		Success: false,
		Error:   message,
	}
	api.writeJSON(w, status, response)
}

func main() {
	// Get configuration from environment
	rpcURL := os.Getenv("KALON_RPC_URL")
	if rpcURL == "" {
		rpcURL = "http://localhost:16314"
	}

	port := os.Getenv("KALON_API_ADDR")
	if port == "" {
		port = "8081"
	}

	// Create and start API server
	api := NewExplorerAPI(rpcURL, port)

	log.Printf("Starting Kalon Explorer API on port %s", port)
	log.Printf("RPC URL: %s", rpcURL)

	if err := api.Start(); err != nil {
		log.Fatalf("Failed to start API server: %v", err)
	}
}
