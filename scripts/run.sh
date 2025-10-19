#!/usr/bin/env bash
set -euo pipefail

# Kalon Network Run Script
# Starts the Kalon node with default configuration

# Default configuration
RPC_ADDR=":16314"
P2P_ADDR=":17333"
DATA_DIR="./data"
GENESIS_FILE="genesis/genesis.json"
SEED_NODES="seed1.kalon.network:17333,seed2.kalon.network:17333,seed3.kalon.network:17333"
MINING="false"
THREADS="2"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Show usage
usage() {
    echo "Kalon Network Run Script"
    echo
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -r, --rpc ADDR        RPC listen address (default: $RPC_ADDR)"
    echo "  -p, --p2p ADDR        P2P listen address (default: $P2P_ADDR)"
    echo "  -d, --datadir DIR     Data directory (default: $DATA_DIR)"
    echo "  -g, --genesis FILE    Genesis file (default: $GENESIS_FILE)"
    echo "  -s, --seednodes NODES Comma-separated seed nodes (default: $SEED_NODES)"
    echo "  -m, --mining          Enable mining"
    echo "  -t, --threads NUM     Number of mining threads (default: $THREADS)"
    echo "  -h, --help            Show this help message"
    echo
    echo "Examples:"
    echo "  $0                                    # Run with defaults"
    echo "  $0 --mining --threads 4              # Run with mining enabled"
    echo "  $0 --rpc :8080 --p2p :8081           # Custom ports"
    echo "  $0 --datadir /custom/data             # Custom data directory"
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -r|--rpc)
                RPC_ADDR="$2"
                shift 2
                ;;
            -p|--p2p)
                P2P_ADDR="$2"
                shift 2
                ;;
            -d|--datadir)
                DATA_DIR="$2"
                shift 2
                ;;
            -g|--genesis)
                GENESIS_FILE="$2"
                shift 2
                ;;
            -s|--seednodes)
                SEED_NODES="$2"
                shift 2
                ;;
            -m|--mining)
                MINING="true"
                shift
                ;;
            -t|--threads)
                THREADS="$2"
                shift 2
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if kalon-node exists
    if [[ ! -f "./build/kalon-node" ]]; then
        log_error "kalon-node binary not found. Run 'make build' first."
        exit 1
    fi
    
    # Check if genesis file exists
    if [[ ! -f "$GENESIS_FILE" ]]; then
        log_error "Genesis file not found: $GENESIS_FILE"
        exit 1
    fi
    
    # Create data directory if it doesn't exist
    if [[ ! -d "$DATA_DIR" ]]; then
        log_info "Creating data directory: $DATA_DIR"
        mkdir -p "$DATA_DIR"
    fi
    
    log_success "Prerequisites check passed"
}

# Initialize node if needed
init_node() {
    log_info "Initializing node..."
    
    # Check if node is already initialized
    if [[ -f "$DATA_DIR/blockchain" ]]; then
        log_info "Node already initialized"
        return
    fi
    
    # Initialize node (just create data directory)
    log_info "Creating data directory and initializing..."
    mkdir -p "$DATA_DIR"
    
    log_success "Node initialized"
}

# Start the node
start_node() {
    log_info "Starting Kalon Node..."
    echo
    echo "Configuration:"
    echo "  RPC Address:    $RPC_ADDR"
    echo "  P2P Address:    $P2P_ADDR"
    echo "  Data Directory: $DATA_DIR"
    echo "  Genesis File:   $GENESIS_FILE"
    echo "  Seed Nodes:     $SEED_NODES"
    echo "  Mining:         $MINING"
    if [[ "$MINING" == "true" ]]; then
        echo "  Threads:        $THREADS"
    fi
    echo
    
    # Build command
    local cmd="./build/kalon-node"
    cmd="$cmd --rpc $RPC_ADDR"
    cmd="$cmd --p2p $P2P_ADDR"
    cmd="$cmd --datadir $DATA_DIR"
    cmd="$cmd --genesis $GENESIS_FILE"
    cmd="$cmd --seednodes $SEED_NODES"
    
    if [[ "$MINING" == "true" ]]; then
        cmd="$cmd --mining --threads $THREADS"
    fi
    
    log_info "Executing: $cmd"
    echo
    
    # Start the node
    exec $cmd
}

# Handle signals
handle_signals() {
    trap 'log_info "Received interrupt signal. Shutting down..."; exit 0' INT TERM
}

# Main function
main() {
    echo "Kalon Network Run Script"
    echo "========================"
    echo
    
    parse_args "$@"
    check_prerequisites
    init_node
    handle_signals
    start_node
}

# Run main function
main "$@"
