// Explorer Configuration
// Set RPC_URL before loading other scripts if you need a different server
// Example: window.RPC_URL = 'https://explorer.kalon-network.com/rpc';

// Default RPC URL (configured for Explorer on same server as Node)
// Explorer runs on same server as Node, nginx makes proxy to Node RPC
// RPC calls go through same domain (no cross-origin issues)
if (typeof window.RPC_URL === 'undefined') {
    // Use same domain as Explorer (nginx makes proxy to Node)
    // This works when Explorer and Node are on the same server
    const protocol = window.location.protocol === 'https:' ? 'https:' : 'http:';
    const host = window.location.host;
    window.RPC_URL = `${protocol}//${host}`;
}

