// Explorer Configuration
// Set RPC_URL before loading other scripts if you need a different server
// Example: window.RPC_URL = 'https://your-node-server:16317';

// Default RPC URL (configured for test server - HTTPS)
if (typeof window.RPC_URL === 'undefined') {
    // Try HTTPS first, fallback to HTTP
    window.RPC_URL = 'https://185.133.249.107:16317';
    window.RPC_URL_HTTP = 'http://185.133.249.107:16316'; // Fallback
}

