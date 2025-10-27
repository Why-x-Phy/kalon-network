// API Base URL
const API_BASE = 'http://localhost:8081';

// Load stats on page load
async function init() {
    await loadStats();
    // Auto-refresh every 10 seconds
    setInterval(loadStats, 10000);
}

// Load network stats
async function loadStats() {
    try {
        const response = await fetch(`${API_BASE}/network/stats`);
        const data = await response.json();
        
        if (data.success) {
            const stats = data.data;
            
            // Update all stat values (using correct API structure)
            document.getElementById('statHeight').textContent = stats.blockHeight || 0;
            document.getElementById('statHashrate').textContent = formatHashrate(stats.networkHashRate);
            document.getElementById('statTotalBlocks').textContent = stats.totalBlocks || 0;
            document.getElementById('statDifficulty').textContent = formatNumber(stats.difficulty);
            document.getElementById('statPeers').textContent = stats.peers || 0;
            document.getElementById('statTotalTxs').textContent = stats.totalTxs || 0;
            document.getElementById('statPendingTxs').textContent = stats.mempoolSize || 0;
            document.getElementById('statAddresses').textContent = stats.totalAddresses || 0;
            document.getElementById('treasuryBalance').textContent = formatBalance(stats.totalTxs);
        }
    } catch (error) {
        console.error('Error loading stats:', error);
        // Show mock data
        showMockData();
    }
}

// Show mock data
function showMockData() {
    document.getElementById('statHeight').textContent = '0';
    document.getElementById('statHashrate').textContent = '0 MH/s';
    document.getElementById('statTotalBlocks').textContent = '1';
    document.getElementById('statDifficulty').textContent = '1000';
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
