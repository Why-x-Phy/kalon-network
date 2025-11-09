// RPC Server URL (konfigurierbar)
const RPC_URL = window.RPC_URL || 'http://localhost:16316';
const RPC_ENDPOINT = `${RPC_URL}/rpc`;

// Online Status
let isOnline = false;
let statusCheckInterval = null;

// Load initial data
async function init() {
    // Start online status checking
    checkConnectionStatus();
    statusCheckInterval = setInterval(checkConnectionStatus, 5000); // Check every 5 seconds
    
    await loadNetworkStats();
    await loadBlocks();
    // Auto-refresh every 10 seconds
    setInterval(() => {
        loadNetworkStats();
        loadBlocks();
    }, 10000);
}

// Check connection status (for green/red indicator)
async function checkConnectionStatus() {
    try {
        const response = await fetch(RPC_ENDPOINT, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                jsonrpc: '2.0',
                method: 'getHeight',
                id: 1
            })
        });
        
        const data = await response.json();
        if (data.result !== undefined) {
            updateOnlineStatus(true);
        } else {
            updateOnlineStatus(false);
        }
    } catch (error) {
        console.error('Connection check failed:', error);
        
        // Note: HTTP fallback will be blocked by browser if page is HTTPS (Mixed Content)
        // User must accept HTTPS certificate warning instead
        console.error('HTTPS connection failed. Possible causes:');
        console.error('1. Browser blocked self-signed certificate');
        console.error('   → Solution: Click "Advanced" → "Proceed" in browser');
        console.error('2. Mixed Content (if page is HTTPS)');
        console.error('   → HTTP fallback will be blocked by browser security');
        
        updateOnlineStatus(false);
    }
}

// Update online status indicator
function updateOnlineStatus(online) {
    isOnline = online;
    const statusIndicator = document.getElementById('onlineStatus');
    if (statusIndicator) {
        statusIndicator.className = online ? 'status-online' : 'status-offline';
        statusIndicator.textContent = online ? '● ONLINE' : '● OFFLINE';
    }
}

// Call RPC method
async function callRPC(method, params = {}) {
    try {
        const response = await fetch(RPC_ENDPOINT, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                jsonrpc: '2.0',
                method: method,
                params: params,
                id: 1
            })
        });
        
        const data = await response.json();
        if (data.error) {
            throw new Error(data.error.message || 'RPC Error');
        }
        return data.result;
    } catch (error) {
        console.error(`RPC call failed (${method}):`, error);
        
        // Note: HTTP fallback blocked by browser if page is HTTPS (Mixed Content)
        // User must accept HTTPS certificate warning
        
        throw error;
    }
}

// Load network stats
async function loadNetworkStats() {
    try {
        const height = await callRPC('getHeight');
        const miningInfo = await callRPC('getMiningInfo');
        const peerCount = await callRPC('getPeerCount').catch(() => 0);
        const totalTxs = await callRPC('getTotalTransactions').catch(() => 0);
        const pendingTxs = await callRPC('getPendingTransactions').catch(() => ({ count: 0 }));
        const hashrate = await callRPC('getHashrate').catch(() => ({ hashrate: 0 }));
        
        // Update stats
        document.getElementById('statHeight').textContent = height || 0;
        document.getElementById('statTotalBlocks').textContent = height || 0;
        document.getElementById('statDifficulty').textContent = formatNumber(miningInfo?.difficulty || 0);
        document.getElementById('statPeers').textContent = peerCount || 0;
        document.getElementById('statTotalTxs').textContent = formatNumber(totalTxs || 0);
        document.getElementById('statPendingTxs').textContent = formatNumber(pendingTxs?.count || 0);
        const hashrateValue = hashrate?.hashrate || 0;
        document.getElementById('statHashrate').textContent = formatHashrate(hashrateValue);
        
    } catch (error) {
        console.error('Error loading network stats:', error);
        updateOnlineStatus(false);
    }
}

// Load recent blocks
async function loadBlocks() {
    try {
        const height = await callRPC('getHeight');
        const bestBlock = await callRPC('getBestBlock');
        
        if (!bestBlock || height === 0) {
            renderBlocks([]);
            return;
        }
        
        // For now, show only the best block
        // TODO: Load more blocks via RPC when available
        const blocks = [{
            number: bestBlock.number || height,
            hash: bestBlock.hash || '',
            txCount: bestBlock.txCount || 0,
            timestamp: bestBlock.timestamp ? new Date(bestBlock.timestamp * 1000) : new Date()
        }];
        
        renderBlocks(blocks);
    } catch (error) {
        console.error('Error loading blocks:', error);
        updateOnlineStatus(false);
        renderBlocks([]);
    }
}

// Render blocks table
function renderBlocks(blocks) {
    const tbody = document.getElementById('blocksTable');
    
    if (blocks.length === 0) {
        tbody.innerHTML = `
            <tr>
                <td colspan="4" style="text-align: center; padding: 40px; color: #666;">
                    No blocks found
                </td>
            </tr>
        `;
        return;
    }
    
    tbody.innerHTML = blocks.map(block => `
        <tr>
            <td>#${block.number}</td>
            <td>
                <a href="block.html?h=${formatHash(block.hash)}" class="hash-link">
                    ${formatHash(block.hash)}
                </a>
            </td>
            <td>${block.txCount || 0}</td>
            <td>${formatAge(block.timestamp)}</td>
        </tr>
    `).join('');
}

// Format hash for display
function formatHash(hash) {
    if (!hash) return 'N/A';
    if (typeof hash === 'string' && hash.length > 20) {
        return hash.substring(0, 10) + '...' + hash.substring(hash.length - 10);
    }
    return hash.startsWith('0x') ? hash : `0x${hash}`;
}

// Format age
function formatAge(timestamp) {
    if (!timestamp) return 'N/A';
    
    const date = timestamp instanceof Date ? timestamp : new Date(timestamp);
    const now = new Date();
    const diff = Math.floor((now - date) / 1000);
    
    if (diff < 60) return `${diff}s ago`;
    if (diff < 3600) return `${Math.floor(diff / 60)}m ${diff % 60}s ago`;
    return `${Math.floor(diff / 3600)}h ${Math.floor((diff % 3600) / 60)}m ago`;
}

// Format hashrate
function formatHashrate(hashRate) {
    if (!hashRate) return '0 H/s';
    if (hashRate < 1000) return `${hashRate} H/s`;
    if (hashRate < 1000000) return `${(hashRate / 1000).toFixed(2)} KH/s`;
    return `${(hashRate / 1000000).toFixed(2)} MH/s`;
}

// Format number
function formatNumber(num) {
    if (!num) return '0';
    return num.toLocaleString();
}

// Setup search functionality
function setupSearch() {
    const searchInput = document.querySelector('.search input');
    if (!searchInput) return;
    
    searchInput.addEventListener('keypress', (e) => {
        if (e.key === 'Enter') {
            const query = searchInput.value.trim();
            if (query) {
                handleSearch(query);
            }
        }
    });
    
    // Also handle search icon click
    const searchIcon = document.querySelector('.search-icon');
    if (searchIcon) {
        searchIcon.parentElement.addEventListener('click', () => {
            const query = searchInput.value.trim();
            if (query) {
                handleSearch(query);
            }
        });
    }
}

// Handle search query
async function handleSearch(query) {
    // Check if it's a wallet address (starts with kalon1 or tkalon1 or is hex)
    if (query.startsWith('kalon1') || query.startsWith('tkalon1') || /^[0-9a-fA-F]{40,}$/.test(query)) {
        // Redirect to wallet page
        window.location.href = `wallet.html?address=${encodeURIComponent(query)}`;
    } else if (/^[0-9a-fA-F]{64}$/i.test(query) || query.startsWith('0x')) {
        // Block or transaction hash
        window.location.href = `block.html?h=${encodeURIComponent(query)}`;
    } else if (/^\d+$/.test(query)) {
        // Block number
        window.location.href = `block.html?n=${query}`;
    } else {
        alert('Ungültige Suche. Bitte geben Sie eine Wallet-Adresse, Block-Hash oder Block-Nummer ein.');
    }
}

// Initialize on page load
init();
setupSearch();
