// Explorer Configuration
// Set RPC_URL before loading other scripts if you need a different server
// Example: window.RPC_URL = 'https://your-node-server:16317';

// Default RPC URL (configured for test server - HTTPS for Mixed Content compliance)
// IMPORTANT: If your website runs on HTTPS, you MUST use HTTPS for RPC too!
// Browser will show a warning for self-signed certificates - user must click "Advanced" → "Proceed"
if (typeof window.RPC_URL === 'undefined') {
    // Use HTTPS to avoid Mixed Content blocking (when website is HTTPS)
    window.RPC_URL = 'https://185.133.249.107:16317';
    window.RPC_URL_HTTP = 'http://185.133.249.107:16316'; // HTTP fallback (will be blocked on HTTPS pages)
}

