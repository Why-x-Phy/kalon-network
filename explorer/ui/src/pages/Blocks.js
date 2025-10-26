import React, { useState } from 'react';
import { useQuery } from 'react-query';
import { Link } from 'react-router-dom';
import styled from 'styled-components';
import { 
  Blocks, 
  Clock, 
  Hash, 
  User, 
  CreditCard,
  ChevronLeft,
  ChevronRight,
  Search
} from 'lucide-react';
import { formatDistanceToNow } from 'date-fns';
import { api } from '../services/api';

const BlocksContainer = styled.div`
  max-width: 1200px;
  margin: 0 auto;
`;

const Header = styled.div`
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 32px;
  
  @media (max-width: 768px) {
    flex-direction: column;
    gap: 16px;
    align-items: stretch;
  }
`;

const Title = styled.h1`
  font-size: 2rem;
  font-weight: 700;
  color: #ffffff;
  display: flex;
  align-items: center;
  gap: 12px;
  margin: 0;
`;

const SearchContainer = styled.div`
  display: flex;
  gap: 12px;
  align-items: center;
  
  @media (max-width: 768px) {
    flex-direction: column;
  }
`;

const SearchInput = styled.input`
  padding: 12px 16px;
  background: #2a2a2a;
  border: 1px solid #333333;
  border-radius: 8px;
  color: #ffffff;
  font-size: 16px;
  min-width: 300px;
  
  &:focus {
    outline: none;
    border-color: #00d4ff;
  }
  
  &::placeholder {
    color: #666666;
  }
  
  @media (max-width: 768px) {
    min-width: auto;
    width: 100%;
  }
`;

const SearchButton = styled.button`
  padding: 12px 24px;
  background: linear-gradient(135deg, #00d4ff, #0099cc);
  color: white;
  border: none;
  border-radius: 8px;
  font-size: 16px;
  font-weight: 500;
  cursor: pointer;
  display: flex;
  align-items: center;
  gap: 8px;
  transition: all 0.2s ease;
  
  &:hover {
    background: linear-gradient(135deg, #00b8e6, #0088bb);
    transform: translateY(-2px);
  }
`;

const StatsGrid = styled.div`
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
  gap: 24px;
  margin-bottom: 32px;
`;

const StatCard = styled.div`
  background: #1a1a1a;
  border: 1px solid #333333;
  border-radius: 12px;
  padding: 24px;
  text-align: center;
`;

const StatValue = styled.div`
  font-size: 2rem;
  font-weight: 700;
  color: #00d4ff;
  margin-bottom: 8px;
`;

const StatLabel = styled.div`
  font-size: 14px;
  color: #cccccc;
  text-transform: uppercase;
  letter-spacing: 0.5px;
`;

const TableContainer = styled.div`
  background: #1a1a1a;
  border: 1px solid #333333;
  border-radius: 12px;
  overflow: hidden;
`;

const Table = styled.table`
  width: 100%;
  border-collapse: collapse;
`;

const TableHeader = styled.thead`
  background: #2a2a2a;
`;

const TableHeaderCell = styled.th`
  padding: 16px;
  text-align: left;
  font-weight: 600;
  color: #ffffff;
  font-size: 14px;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  border-bottom: 1px solid #333333;
`;

const TableBody = styled.tbody``;

const TableRow = styled.tr`
  border-bottom: 1px solid #333333;
  transition: background-color 0.2s ease;
  
  &:hover {
    background: #2a2a2a;
  }
  
  &:last-child {
    border-bottom: none;
  }
`;

const TableCell = styled.td`
  padding: 16px;
  color: #cccccc;
  font-size: 14px;
`;

const HashLink = styled(Link)`
  color: #00d4ff;
  text-decoration: none;
  font-family: monospace;
  font-size: 14px;
  
  &:hover {
    text-decoration: underline;
  }
`;

const AddressLink = styled(Link)`
  color: #00d4ff;
  text-decoration: none;
  font-family: monospace;
  font-size: 14px;
  
  &:hover {
    text-decoration: underline;
  }
`;

const StatusBadge = styled.span`
  display: inline-block;
  padding: 4px 12px;
  border-radius: 20px;
  font-size: 12px;
  font-weight: 500;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  background: #10b981;
  color: white;
`;

const Pagination = styled.div`
  display: flex;
  justify-content: center;
  align-items: center;
  gap: 12px;
  margin-top: 32px;
`;

const PaginationButton = styled.button`
  padding: 8px 16px;
  background: ${props => props.disabled ? '#333333' : '#2a2a2a'};
  color: ${props => props.disabled ? '#666666' : '#ffffff'};
  border: 1px solid #333333;
  border-radius: 8px;
  cursor: ${props => props.disabled ? 'not-allowed' : 'pointer'};
  display: flex;
  align-items: center;
  gap: 8px;
  transition: all 0.2s ease;
  
  &:hover:not(:disabled) {
    background: #00d4ff;
    color: white;
    border-color: #00d4ff;
  }
`;

const LoadingSpinner = styled.div`
  display: flex;
  justify-content: center;
  align-items: center;
  height: 200px;
  font-size: 18px;
  color: #666666;
`;

const ErrorMessage = styled.div`
  background: #2a1a1a;
  border: 1px solid #ff4444;
  border-radius: 8px;
  padding: 16px;
  color: #ff4444;
  text-align: center;
`;

function Blocks() {
  const [page, setPage] = useState(1);
  const [searchQuery, setSearchQuery] = useState('');
  const limit = 20;

  const { data: blocksData, isLoading, error } = useQuery(
    ['blocks', page, searchQuery],
    () => api.getBlocks({ 
      page, 
      limit,
      ...(searchQuery && { search: searchQuery })
    }),
    { 
      refetchInterval: 10000,
      keepPreviousData: true 
    }
  );

  const { data: networkStats } = useQuery(
    'networkStats',
    () => api.getNetworkStats(),
    { refetchInterval: 30000 }
  );

  const handleSearch = (e) => {
    e.preventDefault();
    setPage(1);
  };

  const handlePageChange = (newPage) => {
    setPage(newPage);
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  if (isLoading) {
    return (
      <BlocksContainer>
        <LoadingSpinner>
          <div className="spinner"></div>
          <span style={{ marginLeft: '12px' }}>Loading blocks...</span>
        </LoadingSpinner>
      </BlocksContainer>
    );
  }

  if (error) {
    return (
      <BlocksContainer>
        <ErrorMessage>
          Failed to load blocks. Please try again later.
        </ErrorMessage>
      </BlocksContainer>
    );
  }

  const blocks = blocksData?.data || [];
  const totalPages = Math.ceil((blocksData?.meta?.total || 0) / limit);

  return (
    <BlocksContainer>
      <Header>
        <Title>
          <Blocks />
          Blocks
        </Title>
        
        <SearchContainer>
          <form onSubmit={handleSearch}>
            <SearchInput
              type="text"
              placeholder="Search by block hash or height..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
            />
          </form>
          <SearchButton onClick={handleSearch}>
            <Search />
            Search
          </SearchButton>
        </SearchContainer>
      </Header>

      <StatsGrid>
        <StatCard>
          <StatValue>{networkStats?.blockHeight || 0}</StatValue>
          <StatLabel>Current Height</StatLabel>
        </StatCard>
        <StatCard>
          <StatValue>{networkStats?.totalBlocks || 0}</StatValue>
          <StatLabel>Total Blocks</StatLabel>
        </StatCard>
        <StatCard>
          <StatValue>{networkStats?.blockTime || 0}s</StatValue>
          <StatLabel>Avg Block Time</StatLabel>
        </StatCard>
        <StatCard>
          <StatValue>{networkStats?.networkHashRate || 0}</StatValue>
          <StatLabel>Network Hash Rate</StatLabel>
        </StatCard>
      </StatsGrid>

      <TableContainer>
        <Table>
          <TableHeader>
            <tr>
              <TableHeaderCell>Height</TableHeaderCell>
              <TableHeaderCell>Hash</TableHeaderCell>
              <TableHeaderCell>Timestamp</TableHeaderCell>
              <TableHeaderCell>Miner</TableHeaderCell>
              <TableHeaderCell>Transactions</TableHeaderCell>
              <TableHeaderCell>Size</TableHeaderCell>
              <TableHeaderCell>Difficulty</TableHeaderCell>
            </tr>
          </TableHeader>
          <TableBody>
            {blocks.map((block) => (
              <TableRow key={block.hash}>
                <TableCell>
                  <HashLink to={`/blocks/${block.hash}`}>
                    #{block.number}
                  </HashLink>
                </TableCell>
                <TableCell>
                  <HashLink to={`/blocks/${block.hash}`}>
                    {block.hash.slice(0, 16)}...
                  </HashLink>
                </TableCell>
                <TableCell>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                    <Clock size={16} />
                    {formatDistanceToNow(new Date(block.timestamp), { addSuffix: true })}
                  </div>
                </TableCell>
                <TableCell>
                  <AddressLink to={`/addresses/${block.miner}`}>
                    {block.miner.slice(0, 16)}...
                  </AddressLink>
                </TableCell>
                <TableCell>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                    <CreditCard size={16} />
                    {block.txCount}
                  </div>
                </TableCell>
                <TableCell>
                  {(block.size / 1024).toFixed(2)} KB
                </TableCell>
                <TableCell>
                  {block.difficulty.toLocaleString()}
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </TableContainer>

      <Pagination>
        <PaginationButton
          disabled={page <= 1}
          onClick={() => handlePageChange(page - 1)}
        >
          <ChevronLeft size={16} />
          Previous
        </PaginationButton>
        
        <span style={{ color: '#cccccc' }}>
          Page {page} of {totalPages}
        </span>
        
        <PaginationButton
          disabled={page >= totalPages}
          onClick={() => handlePageChange(page + 1)}
        >
          Next
          <ChevronRight size={16} />
        </PaginationButton>
      </Pagination>
    </BlocksContainer>
  );
}

export default Blocks;
