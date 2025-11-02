// Explorer Configuration
// Set RPC_URL before loading other scripts if you need a different server
// Example: window.RPC_URL = 'http://your-node-server:16316';

// Default RPC URL (configured for test server - HTTP for reliability)
// Note: HTTPS requires browser to accept self-signed certificate warning
// HTTP works without browser warnings
if (typeof window.RPC_URL === 'undefined') {
    // Use HTTP by default (works without browser warnings)
    window.RPC_URL = 'http://185.133.249.107:16316';
    window.RPC_URL_HTTPS = 'https://185.133.249.107:16317'; // Optional HTTPS fallback
}

