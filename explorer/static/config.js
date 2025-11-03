// Explorer Configuration
// Set RPC_URL before loading other scripts if you need a different server
// Example: window.RPC_URL = 'http://your-node-server:16316';

// Default RPC URL (configured for test server - HTTP for reliability)
// Note: HTTP works without browser warnings and certificate issues
// If your website runs on HTTPS and browser blocks HTTP, use HTTPS with certificate warning acceptance
if (typeof window.RPC_URL === 'undefined') {
    // Use HTTP by default (works without browser warnings)
    window.RPC_URL = 'http://185.133.249.107:16316';
    window.RPC_URL_HTTPS = 'https://185.133.249.107:16317'; // Optional HTTPS fallback
}

