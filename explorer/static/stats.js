// RPC Server URL (konfigurierbar)
const RPC_URL = window.RPC_URL || 'http://localhost:16316';
const RPC_ENDPOINT = `${RPC_URL}/rpc`;

// Online Status
let isOnline = false;
let statusCheckInterval = null;

// Load stats on page load
async function init() {
    // Start online status checking
    checkConnectionStatus();
    statusCheckInterval = setInterval(checkConnectionStatus, 5000); // Check every 5 seconds
    
    await loadStats();
    // Auto-refresh every 10 seconds
    setInterval(loadStats, 10000);
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
        throw error;
    }
}

// Load network stats
async function loadStats() {
    try {
        const height = await callRPC('getHeight');
        const miningInfo = await callRPC('getMiningInfo');
        const peerCount = await callRPC('getPeerCount').catch(() => 0);
        const totalTxs = await callRPC('getTotalTransactions').catch(() => 0);
        const pendingTxs = await callRPC('getPendingTransactions').catch(() => ({ count: 0 }));
        const addressCount = await callRPC('getAddressCount').catch(() => 0);
        const hashrate = await callRPC('getHashrate').catch(() => ({ hashrate: 0 }));
        const treasuryBalance = await callRPC('getTreasuryBalance').catch(() => 0);
        
        // Update all stat values
        document.getElementById('statHeight').textContent = height || 0;
        document.getElementById('statTotalBlocks').textContent = height || 0;
        document.getElementById('statDifficulty').textContent = formatNumber(miningInfo?.difficulty || 0);
        document.getElementById('statPeers').textContent = peerCount || 0;
        document.getElementById('statTotalTxs').textContent = formatNumber(totalTxs || 0);
        document.getElementById('statPendingTxs').textContent = formatNumber(pendingTxs?.count || 0);
        if (document.getElementById('statAddresses')) {
            document.getElementById('statAddresses').textContent = formatNumber(addressCount || 0);
        }
        const hashrateValue = hashrate?.hashrate || 0;
        document.getElementById('statHashrate').textContent = formatHashrate(hashrateValue);
        if (document.getElementById('treasuryBalance')) {
            document.getElementById('treasuryBalance').textContent = formatBalance(treasuryBalance || 0);
        }
        
    } catch (error) {
        console.error('Error loading stats:', error);
        updateOnlineStatus(false);
        // Show mock data on error
        showMockData();
    }
}

// Show mock data
function showMockData() {
    document.getElementById('statHeight').textContent = '0';
    document.getElementById('statHashrate').textContent = '0 H/s';
    document.getElementById('statTotalBlocks').textContent = '0';
    document.getElementById('statDifficulty').textContent = '0';
    document.getElementById('statPeers').textContent = '0';
    document.getElementById('statTotalTxs').textContent = '0';
    document.getElementById('statPendingTxs').textContent = '0';
    document.getElementById('statAddresses').textContent = '0';
    document.getElementById('treasuryBalance').textContent = '0 tKALON';
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

// Format balance
function formatBalance(balance) {
    if (!balance) return '0 tKALON';
    return `${(balance / 1000000).toFixed(2)} tKALON`;
}

// Initialize
init();
