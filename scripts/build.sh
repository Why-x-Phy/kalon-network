#!/usr/bin/env bash
set -euo pipefail

# Kalon Network Build Script
# Builds all Kalon binaries for different platforms

VERSION="1.0.0"
BUILD_DIR="build"
DIST_DIR="dist"

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
    echo "Kalon Network Build Script"
    echo
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -v, --version VERSION  Set version (default: $VERSION)"
    echo "  -o, --output DIR       Output directory (default: $BUILD_DIR)"
    echo "  -d, --dist DIR         Distribution directory (default: $DIST_DIR)"
    echo "  -p, --platform PLAT   Build for specific platform (linux/amd64, linux/arm64, etc.)"
    echo "  -a, --all              Build for all platforms"
    echo "  -c, --clean            Clean build directories"
    echo "  -h, --help             Show this help message"
    echo
    echo "Examples:"
    echo "  $0                     # Build for current platform"
    echo "  $0 --all               # Build for all platforms"
    echo "  $0 --platform linux/amd64  # Build for Linux AMD64"
    echo "  $0 --clean             # Clean build directories"
}

# Parse command line arguments
parse_args() {
    local build_all=false
    local clean=false
    local platform=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -v|--version)
                VERSION="$2"
                shift 2
                ;;
            -o|--output)
                BUILD_DIR="$2"
                shift 2
                ;;
            -d|--dist)
                DIST_DIR="$2"
                shift 2
                ;;
            -p|--platform)
                platform="$2"
                shift 2
                ;;
            -a|--all)
                build_all=true
                shift
                ;;
            -c|--clean)
                clean=true
                shift
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
    
    # Handle clean
    if [[ "$clean" == true ]]; then
        clean_build
        exit 0
    fi
    
    # Handle build all
    if [[ "$build_all" == true ]]; then
        build_all_platforms
        exit 0
    fi
    
    # Handle specific platform
    if [[ -n "$platform" ]]; then
        build_platform "$platform"
        exit 0
    fi
}

# Clean build directories
clean_build() {
    log_info "Cleaning build directories..."
    
    if [[ -d "$BUILD_DIR" ]]; then
        rm -rf "$BUILD_DIR"
        log_success "Cleaned $BUILD_DIR"
    fi
    
    if [[ -d "$DIST_DIR" ]]; then
        rm -rf "$DIST_DIR"
        log_success "Cleaned $DIST_DIR"
    fi
    
    # Clean Go build cache
    go clean -cache
    log_success "Cleaned Go build cache"
}

# Build for specific platform
build_platform() {
    local platform="$1"
    local os=$(echo "$platform" | cut -d'/' -f1)
    local arch=$(echo "$platform" | cut -d'/' -f2)
    
    log_info "Building for $os/$arch..."
    
    # Set environment variables
    export GOOS="$os"
    export GOARCH="$arch"
    export CGO_ENABLED=0
    
    # Create build directory
    local build_path="$BUILD_DIR/$os-$arch"
    mkdir -p "$build_path"
    
    # Build binaries
    local binaries=("kalon-node" "kalon-wallet" "kalon-miner")
    
    for binary in "${binaries[@]}"; do
        log_info "Building $binary..."
        
        local output_path="$build_path/$binary"
        if [[ "$os" == "windows" ]]; then
            output_path="$build_path/${binary}.exe"
        fi
        
        go build \
            -ldflags="-s -w -X main.version=$VERSION" \
            -o "$output_path" \
            "./cmd/$binary"
        
        log_success "Built $binary"
    done
    
    # Copy additional files
    cp -r genesis "$build_path/"
    cp README.md "$build_path/"
    cp LICENSE "$build_path/"
    
    # Create archive
    local archive_name="kalon-$VERSION-$os-$arch"
    local archive_path="$DIST_DIR/$archive_name"
    
    mkdir -p "$DIST_DIR"
    
    if [[ "$os" == "windows" ]]; then
        zip -r "$archive_path.zip" -C "$build_path" .
    else
        tar -czf "$archive_path.tar.gz" -C "$build_path" .
    fi
    
    log_success "Created archive: $archive_path"
}

# Build for all platforms
build_all_platforms() {
    log_info "Building for all platforms..."
    
    local platforms=(
        "linux/amd64"
        "linux/arm64"
        "linux/arm"
        "darwin/amd64"
        "darwin/arm64"
        "windows/amd64"
    )
    
    for platform in "${platforms[@]}"; do
        build_platform "$platform"
    done
    
    log_success "Built for all platforms"
}

# Build for current platform
build_current() {
    log_info "Building for current platform..."
    
    local os=$(go env GOOS)
    local arch=$(go env GOARCH)
    local platform="$os/$arch"
    
    build_platform "$platform"
}

# Create checksums
create_checksums() {
    log_info "Creating checksums..."
    
    if [[ -d "$DIST_DIR" ]]; then
        cd "$DIST_DIR"
        find . -name "*.tar.gz" -o -name "*.zip" | while read -r file; do
            if command -v sha256sum &> /dev/null; then
                sha256sum "$file" > "${file}.sha256"
            elif command -v shasum &> /dev/null; then
                shasum -a 256 "$file" > "${file}.sha256"
            fi
        done
        cd - > /dev/null
        log_success "Created checksums"
    fi
}

# Show build info
show_build_info() {
    log_info "Build Information:"
    echo "  Version: $VERSION"
    echo "  Go Version: $(go version)"
    echo "  Build Directory: $BUILD_DIR"
    echo "  Distribution Directory: $DIST_DIR"
    echo
    
    if [[ -d "$DIST_DIR" ]]; then
        echo "Built Archives:"
        ls -la "$DIST_DIR"/*.tar.gz "$DIST_DIR"/*.zip 2>/dev/null || true
        echo
    fi
}

# Main function
main() {
    echo "Kalon Network Build Script v$VERSION"
    echo "===================================="
    echo
    
    parse_args "$@"
    build_current
    create_checksums
    show_build_info
    
    log_success "Build completed successfully!"
}

# Run main function
main "$@"
