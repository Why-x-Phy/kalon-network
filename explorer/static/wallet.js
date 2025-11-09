// RPC Server URL (konfigurierbar)
const RPC_URL = window.RPC_URL || 'http://localhost:16316';
const RPC_ENDPOINT = `${RPC_URL}/rpc`;

// Get address from URL
function getAddressFromURL() {
    const params = new URLSearchParams(window.location.search);
    return params.get('address') || '';
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

// Load wallet information
async function loadWalletInfo() {
    const address = getAddressFromURL();
    
    if (!address) {
        document.getElementById('walletAddress').textContent = 'No address provided';
        return;
    }
    
    try {
        // Get wallet info
        const walletInfo = await callRPC('getAddressInfo', { address: address });
        const transactions = await callRPC('getAddressTransactions', { address: address });
        
        // Update wallet info
        document.getElementById('walletAddress').textContent = address;
        document.getElementById('walletBalance').textContent = formatBalance(walletInfo.balance || 0);
        document.getElementById('walletTxCount').textContent = formatNumber(walletInfo.transactionCount || 0);
        document.getElementById('walletSentCount').textContent = formatNumber(walletInfo.sentCount || 0);
        document.getElementById('walletReceivedCount').textContent = formatNumber(walletInfo.receivedCount || 0);
        document.getElementById('walletTotalSent').textContent = formatBalance(walletInfo.totalSent || 0);
        document.getElementById('walletTotalReceived').textContent = formatBalance(walletInfo.totalReceived || 0);
        
        // Render transactions
        renderTransactions(transactions.transactions || []);
        
    } catch (error) {
        console.error('Error loading wallet info:', error);
        document.getElementById('walletAddress').textContent = `Error: ${error.message}`;
        document.getElementById('transactionsTable').innerHTML = `
            <tr>
                <td colspan="6" style="text-align: center; padding: 40px; color: #f44336;">
                    Error loading wallet information: ${error.message}
                </td>
            </tr>
        `;
    }
}

// Render transactions table
function renderTransactions(transactions) {
    const tbody = document.getElementById('transactionsTable');
    
    if (transactions.length === 0) {
        tbody.innerHTML = `
            <tr>
                <td colspan="6" style="text-align: center; padding: 40px; color: #666;">
                    No transactions found
                </td>
            </tr>
        `;
        return;
    }
    
    tbody.innerHTML = transactions.map(tx => `
        <tr>
            <td>
                <a href="block.html?h=${tx.hash}" class="hash-link">
                    ${formatHash(tx.hash)}
                </a>
            </td>
            <td>${formatHash(tx.from)}</td>
            <td>${formatHash(tx.to)}</td>
            <td>${formatBalance(tx.amount)}</td>
            <td>${formatBalance(tx.fee)}</td>
            <td>${formatTimestamp(tx.timestamp)}</td>
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

// Format balance
function formatBalance(balance) {
    if (!balance) return '0 tKALON';
    return `${(balance / 1000000).toFixed(6)} tKALON`;
}

// Format number
function formatNumber(num) {
    if (!num) return '0';
    return num.toLocaleString();
}

// Format timestamp
function formatTimestamp(timestamp) {
    if (!timestamp) return 'N/A';
    const date = new Date(timestamp * 1000);
    return date.toLocaleString('de-DE');
}

// Setup search functionality
function setupSearch() {
    const searchInput = document.getElementById('searchInput');
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
loadWalletInfo();
setupSearch();

