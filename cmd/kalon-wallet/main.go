package main

import (
	"bufio"
	"encoding/hex"
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"os"
	"strings"

	"github.com/kalon-network/kalon/crypto"
)

var version = "1.0.2"

// WalletManager handles wallet operations
type WalletManager struct {
	wallet *crypto.Wallet
}

// TransactionRequest represents a transaction request
type TransactionRequest struct {
	From   string `json:"from"`
	To     string `json:"to"`
	Amount uint64 `json:"amount"`
	Fee    uint64 `json:"fee"`
	Data   string `json:"data,omitempty"`
}

// BalanceResponse represents a balance response
type BalanceResponse struct {
	Address string `json:"address"`
	Balance uint64 `json:"balance"`
}

// TransactionResponse represents a transaction response
type TransactionResponse struct {
	Hash    string `json:"hash"`
	From    string `json:"from"`
	To      string `json:"to"`
	Amount  uint64 `json:"amount"`
	Fee     uint64 `json:"fee"`
	Nonce   uint64 `json:"nonce"`
	Success bool   `json:"success"`
}

// WalletInfo represents wallet information
type WalletInfo struct {
	Address    string `json:"address"`
	PublicKey  string `json:"publicKey"`
	PrivateKey string `json:"privateKey,omitempty"`
	Mnemonic   string `json:"mnemonic,omitempty"`
}

func main() {
	if len(os.Args) < 2 {
		usage()
		os.Exit(1)
	}

	command := os.Args[1]
	args := os.Args[2:]

	walletManager := &WalletManager{}

	switch command {
	case "create":
		handleCreate(walletManager, args)
	case "import":
		handleImport(walletManager, args)
	case "export":
		handleExport(walletManager, args)
	case "balance":
		handleBalance(walletManager, args)
	case "send":
		handleSend(walletManager, args)
	case "info":
		handleInfo(walletManager, args)
	case "help":
		usage()
	default:
		fmt.Printf("Unknown command: %s\n", command)
		usage()
		os.Exit(1)
	}
}

// handleCreate handles wallet creation
func handleCreate(wm *WalletManager, args []string) {
	fs := flag.NewFlagSet("create", flag.ExitOnError)
	passphrase := fs.String("passphrase", "", "Passphrase for wallet encryption")
	output := fs.String("output", "wallet.json", "Output file for wallet")
	fs.Parse(args)

	// Get passphrase if not provided
	if *passphrase == "" {
		fmt.Print("Enter passphrase (optional): ")
		reader := bufio.NewReader(os.Stdin)
		pass, err := reader.ReadString('\n')
		if err != nil {
			log.Fatalf("Failed to read passphrase: %v", err)
		}
		*passphrase = strings.TrimSpace(pass)
	}

	// Create wallet
	wallet, err := crypto.NewWallet(*passphrase)
	if err != nil {
		log.Fatalf("Failed to create wallet: %v", err)
	}

	wm.wallet = wallet

	// Get address
	address, err := wallet.GetAddressString()
	if err != nil {
		log.Fatalf("Failed to get address: %v", err)
	}

	// Create wallet info
	walletInfo := &WalletInfo{
		Address:   address,
		PublicKey: wallet.Keypair.GetPublicHex(),
		Mnemonic:  wallet.Mnemonic,
	}

	// Save wallet
	if err := saveWallet(walletInfo, *output); err != nil {
		log.Fatalf("Failed to save wallet: %v", err)
	}

	fmt.Printf("Wallet created successfully!\n")
	fmt.Printf("Address: %s\n", address)
	fmt.Printf("Public Key: %s\n", wallet.Keypair.GetPublicHex())
	fmt.Printf("Mnemonic: %s\n", wallet.Mnemonic)
	fmt.Printf("Wallet saved to: %s\n", *output)
	fmt.Println("\n⚠️  IMPORTANT: Save your mnemonic phrase in a safe place!")
	fmt.Println("   You will need it to recover your wallet if you lose access.")
}

// handleImport handles wallet import
func handleImport(wm *WalletManager, args []string) {
	fs := flag.NewFlagSet("import", flag.ExitOnError)
	mnemonic := fs.String("mnemonic", "", "Mnemonic phrase to import")
	passphrase := fs.String("passphrase", "", "Passphrase for wallet encryption")
	output := fs.String("output", "wallet.json", "Output file for wallet")
	fs.Parse(args)

	// Get mnemonic if not provided
	if *mnemonic == "" {
		fmt.Print("Enter mnemonic phrase: ")
		reader := bufio.NewReader(os.Stdin)
		mnemonicInput, err := reader.ReadString('\n')
		if err != nil {
			log.Fatalf("Failed to read mnemonic: %v", err)
		}
		*mnemonic = strings.TrimSpace(mnemonicInput)
	}

	// Get passphrase if not provided
	if *passphrase == "" {
		fmt.Print("Enter passphrase (optional): ")
		reader := bufio.NewReader(os.Stdin)
		pass, err := reader.ReadString('\n')
		if err != nil {
			log.Fatalf("Failed to read passphrase: %v", err)
		}
		*passphrase = strings.TrimSpace(pass)
	}

	// Create BIP39 manager
	bm := crypto.NewBIP39Manager()

	// Import wallet from mnemonic
	wallet, err := bm.CreateWalletFromMnemonic(*mnemonic, *passphrase)
	if err != nil {
		log.Fatalf("Failed to import wallet: %v", err)
	}

	wm.wallet = wallet

	// Get address
	address, err := wallet.GetAddressString()
	if err != nil {
		log.Fatalf("Failed to get address: %v", err)
	}

	// Create wallet info
	walletInfo := &WalletInfo{
		Address:   address,
		PublicKey: wallet.Keypair.GetPublicHex(),
		Mnemonic:  wallet.Mnemonic,
	}

	// Save wallet
	if err := saveWallet(walletInfo, *output); err != nil {
		log.Fatalf("Failed to save wallet: %v", err)
	}

	fmt.Printf("Wallet imported successfully!\n")
	fmt.Printf("Address: %s\n", address)
	fmt.Printf("Public Key: %s\n", wallet.Keypair.GetPublicHex())
	fmt.Printf("Wallet saved to: %s\n", *output)
}

// handleExport handles wallet export
func handleExport(wm *WalletManager, args []string) {
	fs := flag.NewFlagSet("export", flag.ExitOnError)
	input := fs.String("input", "wallet.json", "Input wallet file")
	showPrivate := fs.Bool("private", false, "Show private key")
	fs.Parse(args)

	// Load wallet
	walletInfo, err := loadWallet(*input)
	if err != nil {
		log.Fatalf("Failed to load wallet: %v", err)
	}

	// Create export data
	exportData := map[string]interface{}{
		"address":   walletInfo.Address,
		"publicKey": walletInfo.PublicKey,
		"mnemonic":  walletInfo.Mnemonic,
	}

	if *showPrivate {
		exportData["privateKey"] = walletInfo.PrivateKey
	}

	// Export as JSON
	jsonData, err := json.MarshalIndent(exportData, "", "  ")
	if err != nil {
		log.Fatalf("Failed to marshal wallet data: %v", err)
	}

	fmt.Println(string(jsonData))
}

// handleBalance handles balance queries
func handleBalance(wm *WalletManager, args []string) {
	fs := flag.NewFlagSet("balance", flag.ExitOnError)
	address := fs.String("address", "", "Address to check balance")
	rpcURL := fs.String("rpc", "http://localhost:16314", "RPC server URL")
	fs.Parse(args)

	// Get address
	var targetAddress string
	if *address != "" {
		targetAddress = *address
	} else if wm.wallet != nil {
		addr, err := wm.wallet.GetAddressString()
		if err != nil {
			log.Fatalf("Failed to get wallet address: %v", err)
		}
		targetAddress = addr
	} else {
		log.Fatal("No address provided and no wallet loaded")
	}

	// Query balance via RPC
	balance, err := queryBalance(*rpcURL, targetAddress)
	if err != nil {
		log.Fatalf("Failed to query balance: %v", err)
	}

	// Create response
	response := &BalanceResponse{
		Address: targetAddress,
		Balance: balance,
	}

	// Output result
	jsonData, err := json.MarshalIndent(response, "", "  ")
	if err != nil {
		log.Fatalf("Failed to marshal balance: %v", err)
	}

	fmt.Println(string(jsonData))
}

// handleSend handles transaction sending
func handleSend(wm *WalletManager, args []string) {
	fs := flag.NewFlagSet("send", flag.ExitOnError)
	to := fs.String("to", "", "Recipient address")
	amount := fs.Uint64("amount", 0, "Amount to send")
	fee := fs.Uint64("fee", 1000000, "Transaction fee (micro-KALON)")
	rpcURL := fs.String("rpc", "http://localhost:16314", "RPC server URL")
	fs.Parse(args)

	if *to == "" || *amount == 0 {
		log.Fatal("Recipient address and amount are required")
	}

	if wm.wallet == nil {
		log.Fatal("No wallet loaded. Use 'create' or 'import' first.")
	}

	// Get wallet address
	fromAddress, err := wm.wallet.GetAddressString()
	if err != nil {
		log.Fatalf("Failed to get wallet address: %v", err)
	}

	// Create transaction request
	txReq := &TransactionRequest{
		From:   fromAddress,
		To:     *to,
		Amount: *amount,
		Fee:    *fee,
	}

	// Send transaction
	txResp, err := sendTransaction(*rpcURL, txReq)
	if err != nil {
		log.Fatalf("Failed to send transaction: %v", err)
	}

	// Output result
	jsonData, err := json.MarshalIndent(txResp, "", "  ")
	if err != nil {
		log.Fatalf("Failed to marshal transaction: %v", err)
	}

	fmt.Println(string(jsonData))
}

// handleInfo handles wallet info display
func handleInfo(wm *WalletManager, args []string) {
	fs := flag.NewFlagSet("info", flag.ExitOnError)
	input := fs.String("input", "wallet.json", "Input wallet file")
	fs.Parse(args)

	// Load wallet
	walletInfo, err := loadWallet(*input)
	if err != nil {
		log.Fatalf("Failed to load wallet: %v", err)
	}

	// Output wallet info
	jsonData, err := json.MarshalIndent(walletInfo, "", "  ")
	if err != nil {
		log.Fatalf("Failed to marshal wallet info: %v", err)
	}

	fmt.Println(string(jsonData))
}

// saveWallet saves wallet to file
func saveWallet(walletInfo *WalletInfo, filename string) error {
	data, err := json.MarshalIndent(walletInfo, "", "  ")
	if err != nil {
		return err
	}

	return os.WriteFile(filename, data, 0600)
}

// loadWallet loads wallet from file
func loadWallet(filename string) (*WalletInfo, error) {
	data, err := os.ReadFile(filename)
	if err != nil {
		return nil, err
	}

	var walletInfo WalletInfo
	if err := json.Unmarshal(data, &walletInfo); err != nil {
		return nil, err
	}

	return &walletInfo, nil
}

// queryBalance queries balance via RPC
func queryBalance(rpcURL, address string) (uint64, error) {
	// This is a simplified implementation
	// In a real implementation, you would make an HTTP request to the RPC server

	// For now, return a mock balance
	return 1000000, nil // 1 KALON in micro-KALON
}

// sendTransaction sends a transaction via RPC
func sendTransaction(rpcURL string, txReq *TransactionRequest) (*TransactionResponse, error) {
	// This is a simplified implementation
	// In a real implementation, you would make an HTTP request to the RPC server

	// For now, return a mock response
	return &TransactionResponse{
		Hash:    "0x" + hex.EncodeToString([]byte("mock_tx_hash")),
		From:    txReq.From,
		To:      txReq.To,
		Amount:  txReq.Amount,
		Fee:     txReq.Fee,
		Nonce:   1,
		Success: true,
	}, nil
}

// usage displays usage information
func usage() {
	fmt.Printf("Kalon Wallet CLI v%s\n", version)
	fmt.Println()
	fmt.Println("Usage:")
	fmt.Println("  kalon-wallet <command> [flags]")
	fmt.Println()
	fmt.Println("Commands:")
	fmt.Println("  create     Create a new wallet")
	fmt.Println("  import     Import wallet from mnemonic")
	fmt.Println("  export     Export wallet information")
	fmt.Println("  balance    Check wallet balance")
	fmt.Println("  send       Send transaction")
	fmt.Println("  info       Show wallet information")
	fmt.Println("  help       Show this help message")
	fmt.Println()
	fmt.Println("Examples:")
	fmt.Println("  kalon-wallet create")
	fmt.Println("  kalon-wallet import --mnemonic 'word1 word2 ...'")
	fmt.Println("  kalon-wallet balance --address kalon1abc...")
	fmt.Println("  kalon-wallet send --to kalon1def... --amount 1000000")
	fmt.Println("  kalon-wallet info --input wallet.json")
}
