import axios from 'axios';

const API_BASE_URL = process.env.REACT_APP_API_URL || 'http://localhost:8081';

const api = axios.create({
  baseURL: API_BASE_URL,
  timeout: 10000,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Request interceptor
api.interceptors.request.use(
  (config) => {
    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

// Response interceptor
api.interceptors.response.use(
  (response) => {
    return response.data;
  },
  (error) => {
    console.error('API Error:', error);
    return Promise.reject(error);
  }
);

// API methods
export const apiService = {
  // Health check
  health: () => api.get('/health'),

  // Blocks
  getBlocks: (params = {}) => api.get('/blocks', { params }),
  getBlockByHash: (hash) => api.get(`/blocks/${hash}`),
  getBlockByHeight: (height) => api.get(`/blocks/height/${height}`),
  getLatestBlock: () => api.get('/blocks/latest'),

  // Transactions
  getTransactions: (params = {}) => api.get('/transactions', { params }),
  getTransaction: (hash) => api.get(`/transactions/${hash}`),
  getPendingTransactions: () => api.get('/transactions/pending'),

  // Addresses
  getAddress: (address) => api.get(`/addresses/${address}`),
  getAddressTransactions: (address, params = {}) => 
    api.get(`/addresses/${address}/transactions`, { params }),
  getAddressBalance: (address) => api.get(`/addresses/${address}/balance`),

  // Treasury
  getTreasury: () => api.get('/treasury'),

  // Network
  getNetworkStats: () => api.get('/network/stats'),
  getPeers: () => api.get('/network/peers'),

  // Search
  search: (query) => api.get('/search', { params: { q: query } }),

  // Stats
  getStats: () => api.get('/stats'),
};

// Convenience methods
export const api = {
  // Health check
  health: apiService.health,

  // Blocks
  getBlocks: apiService.getBlocks,
  getBlockByHash: apiService.getBlockByHash,
  getBlockByHeight: apiService.getBlockByHeight,
  getLatestBlock: apiService.getLatestBlock,

  // Transactions
  getTransactions: apiService.getTransactions,
  getTransaction: apiService.getTransaction,
  getPendingTransactions: apiService.getPendingTransactions,

  // Addresses
  getAddress: apiService.getAddress,
  getAddressTransactions: apiService.getAddressTransactions,
  getAddressBalance: apiService.getAddressBalance,

  // Treasury
  getTreasury: apiService.getTreasury,

  // Network
  getNetworkStats: apiService.getNetworkStats,
  getPeers: apiService.getPeers,

  // Search
  search: apiService.search,

  // Stats
  getStats: apiService.getStats,
};

export default api;
