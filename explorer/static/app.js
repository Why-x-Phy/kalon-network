// API Base URL
const API_BASE = 'http://localhost:8081';

// Load initial data
async function init() {
    await loadStats();
    await loadBlocks();
    // Auto-refresh every 10 seconds
    setInterval(loadBlocks, 10000);
}

// Load network stats
async function loadStats() {
    try {
        const response = await fetch(`${API_BASE}/stats`);
        const data = await response.json();
        
        if (data.success) {
            const stats = data.data;
            
            // Update stat cards
            document.getElementById('blockHeight').textContent = stats.blocks.latest || 0;
            document.getElementById('hashrate').textContent = formatHashrate(stats.network.hashRate);
            document.getElementById('reward').textContent = '5.00 tKALON';
        }
    } catch (error) {
        console.error('Error loading stats:', error);
    }
}

// Load recent blocks
async function loadBlocks() {
    try {
        const response = await fetch(`${API_BASE}/blocks?limit=20`);
        const data = await response.json();
        
        if (data.success && data.data) {
            renderBlocks(data.data);
        }
    } catch (error) {
        console.error('Error loading blocks:', error);
        // Fallback to mock data
        renderMockBlocks();
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
                <a href="#" class="hash-link" data-hash="${block.hash}">
                    ${formatHash(block.hash)}
                </a>
            </td>
            <td>${block.txCount || 0}</td>
            <td>${formatAge(block.timestamp)}</td>
        </tr>
    `).join('');
    
    // Add click handlers
    document.querySelectorAll('.hash-link').forEach(link => {
        link.addEventListener('click', (e) => {
            e.preventDefault();
            const hash = e.target.dataset.hash;
            viewBlock(hash);
        });
    });
}

// Render mock blocks (fallback)
function renderMockBlocks() {
    const mockBlocks = [
        { number: 1, hash: '0x1234567890abcdef1234567890abcdef12345678', txCount: 1, timestamp: new Date() },
        { number: 2, hash: '0xabcdef1234567890abcdef1234567890abcdef12', txCount: 0, timestamp: new Date(Date.now() - 12000) },
        { number: 3, hash: '0x9876543210fedcba9876543210fedcba98765432', txCount: 2, timestamp: new Date(Date.now() - 24000) },
    ];
    
    renderBlocks(mockBlocks);
}

// Format hash for display
function formatHash(hash) {
    if (!hash) return 'N/A';
    return hash.startsWith('0x') ? hash : `0x${hash}`;
}

// Format age
function formatAge(timestamp) {
    if (!timestamp) return 'N/A';
    
    const date = new Date(timestamp);
    const now = new Date();
    const diff = Math.floor((now - date) / 1000);
    
    if (diff < 60) return `${diff}s`;
    if (diff < 3600) return `${Math.floor(diff / 60)}m ${diff % 60}s`;
    return `${Math.floor(diff / 3600)}h ${Math.floor((diff % 3600) / 60)}m`;
}

// Format hashrate
function formatHashrate(hashRate) {
    if (hashRate < 1000) return `${hashRate} H/s`;
    if (hashRate < 1000000) return `${(hashRate / 1000).toFixed(2)} KH/s`;
    return `${(hashRate / 1000000).toFixed(2)} MH/s`;
}

// View block details
function viewBlock(hash) {
    alert(`Block details for: ${hash}\n\n(Block detail view would be implemented here)`);
}

// Initialize on page load
init();
