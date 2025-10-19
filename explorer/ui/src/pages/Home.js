import React from 'react';
import { useQuery } from 'react-query';
import styled from 'styled-components';
import { 
  TrendingUp, 
  Blocks, 
  CreditCard, 
  Users, 
  Clock,
  Hash,
  Activity
} from 'lucide-react';
import { formatDistanceToNow } from 'date-fns';
import { api } from '../services/api';

const HomeContainer = styled.div`
  max-width: 1200px;
  margin: 0 auto;
`;

const WelcomeSection = styled.div`
  background: linear-gradient(135deg, #00d4ff, #0099cc);
  border-radius: 12px;
  padding: 32px;
  margin-bottom: 32px;
  color: white;
  text-align: center;
`;

const WelcomeTitle = styled.h1`
  font-size: 2.5rem;
  margin-bottom: 16px;
  font-weight: 700;
`;

const WelcomeSubtitle = styled.p`
  font-size: 1.2rem;
  opacity: 0.9;
  margin-bottom: 24px;
`;

const StatsGrid = styled.div`
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
  gap: 24px;
  margin-bottom: 32px;
`;

const StatCard = styled.div`
  background: #1a1a1a;
  border: 1px solid #333333;
  border-radius: 12px;
  padding: 24px;
  text-align: center;
  transition: all 0.2s ease;
  
  &:hover {
    border-color: #00d4ff;
    transform: translateY(-2px);
  }
`;

const StatIcon = styled.div`
  width: 48px;
  height: 48px;
  background: linear-gradient(135deg, #00d4ff, #0099cc);
  border-radius: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
  margin: 0 auto 16px;
  color: white;
`;

const StatValue = styled.div`
  font-size: 2rem;
  font-weight: 700;
  color: #ffffff;
  margin-bottom: 8px;
`;

const StatLabel = styled.div`
  font-size: 14px;
  color: #cccccc;
  text-transform: uppercase;
  letter-spacing: 0.5px;
`;

const RecentSection = styled.div`
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 32px;
  margin-bottom: 32px;
  
  @media (max-width: 768px) {
    grid-template-columns: 1fr;
  }
`;

const SectionCard = styled.div`
  background: #1a1a1a;
  border: 1px solid #333333;
  border-radius: 12px;
  padding: 24px;
`;

const SectionTitle = styled.h3`
  font-size: 1.25rem;
  font-weight: 600;
  color: #ffffff;
  margin-bottom: 16px;
  display: flex;
  align-items: center;
  gap: 8px;
`;

const List = styled.div`
  space-y: 12px;
`;

const ListItem = styled.div`
  padding: 12px 0;
  border-bottom: 1px solid #333333;
  display: flex;
  justify-content: space-between;
  align-items: center;
  
  &:last-child {
    border-bottom: none;
  }
`;

const ListItemLeft = styled.div`
  flex: 1;
`;

const ListItemRight = styled.div`
  text-align: right;
  color: #666666;
  font-size: 14px;
`;

const HashLink = styled.a`
  color: #00d4ff;
  text-decoration: none;
  font-family: monospace;
  font-size: 14px;
  
  &:hover {
    text-decoration: underline;
  }
`;

const AddressLink = styled.a`
  color: #00d4ff;
  text-decoration: none;
  font-family: monospace;
  font-size: 14px;
  
  &:hover {
    text-decoration: underline;
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

function Home() {
  const { data: networkStats, isLoading: statsLoading, error: statsError } = useQuery(
    'networkStats',
    () => api.getNetworkStats(),
    { refetchInterval: 30000 }
  );

  const { data: latestBlocks, isLoading: blocksLoading, error: blocksError } = useQuery(
    'latestBlocks',
    () => api.getBlocks({ limit: 5 }),
    { refetchInterval: 10000 }
  );

  const { data: latestTxs, isLoading: txsLoading, error: txsError } = useQuery(
    'latestTransactions',
    () => api.getTransactions({ limit: 5 }),
    { refetchInterval: 10000 }
  );

  if (statsLoading || blocksLoading || txsLoading) {
    return (
      <HomeContainer>
        <LoadingSpinner>
          <div className="spinner"></div>
          <span style={{ marginLeft: '12px' }}>Loading...</span>
        </LoadingSpinner>
      </HomeContainer>
    );
  }

  if (statsError || blocksError || txsError) {
    return (
      <HomeContainer>
        <ErrorMessage>
          Failed to load data. Please try again later.
        </ErrorMessage>
      </HomeContainer>
    );
  }

  return (
    <HomeContainer>
      <WelcomeSection>
        <WelcomeTitle>Welcome to Kalon Explorer</WelcomeTitle>
        <WelcomeSubtitle>
          Explore the Kalon Network blockchain, view blocks, transactions, and addresses
        </WelcomeSubtitle>
      </WelcomeSection>

      <StatsGrid>
        <StatCard>
          <StatIcon>
            <Blocks />
          </StatIcon>
          <StatValue>{networkStats?.blockHeight || 0}</StatValue>
          <StatLabel>Block Height</StatLabel>
        </StatCard>

        <StatCard>
          <StatIcon>
            <CreditCard />
          </StatIcon>
          <StatValue>{networkStats?.totalTxs || 0}</StatValue>
          <StatLabel>Total Transactions</StatLabel>
        </StatCard>

        <StatCard>
          <StatIcon>
            <Users />
          </StatIcon>
          <StatValue>{networkStats?.totalAddresses || 0}</StatValue>
          <StatLabel>Addresses</StatLabel>
        </StatCard>

        <StatCard>
          <StatIcon>
            <Activity />
          </StatIcon>
          <StatValue>{networkStats?.peers || 0}</StatValue>
          <StatLabel>Network Peers</StatLabel>
        </StatCard>
      </StatsGrid>

      <RecentSection>
        <SectionCard>
          <SectionTitle>
            <Blocks />
            Recent Blocks
          </SectionTitle>
          <List>
            {latestBlocks?.map((block, index) => (
              <ListItem key={block.hash}>
                <ListItemLeft>
                  <div>
                    <HashLink href={`/blocks/${block.hash}`}>
                      #{block.number}
                    </HashLink>
                  </div>
                  <div style={{ fontSize: '12px', color: '#666666' }}>
                    {formatDistanceToNow(new Date(block.timestamp), { addSuffix: true })}
                  </div>
                </ListItemLeft>
                <ListItemRight>
                  {block.txCount} txs
                </ListItemRight>
              </ListItem>
            ))}
          </List>
        </SectionCard>

        <SectionCard>
          <SectionTitle>
            <CreditCard />
            Recent Transactions
          </SectionTitle>
          <List>
            {latestTxs?.map((tx, index) => (
              <ListItem key={tx.hash}>
                <ListItemLeft>
                  <div>
                    <HashLink href={`/transactions/${tx.hash}`}>
                      {tx.hash.slice(0, 16)}...
                    </HashLink>
                  </div>
                  <div style={{ fontSize: '12px', color: '#666666' }}>
                    {formatDistanceToNow(new Date(tx.timestamp), { addSuffix: true })}
                  </div>
                </ListItemLeft>
                <ListItemRight>
                  {tx.amount} KALON
                </ListItemRight>
              </ListItem>
            ))}
          </List>
        </SectionCard>
      </RecentSection>
    </HomeContainer>
  );
}

export default Home;
