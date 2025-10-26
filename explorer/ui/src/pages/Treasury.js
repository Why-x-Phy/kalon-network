import React from 'react';
import { useQuery } from 'react-query';
import styled from 'styled-components';
import { 
  Wallet, 
  TrendingUp, 
  DollarSign, 
  Activity,
  Clock,
  BarChart3
} from 'lucide-react';
import { formatDistanceToNow } from 'date-fns';
import { api } from '../services/api';

const TreasuryContainer = styled.div`
  max-width: 1200px;
  margin: 0 auto;
`;

const Header = styled.div`
  margin-bottom: 32px;
`;

const Title = styled.h1`
  font-size: 2rem;
  font-weight: 700;
  color: #ffffff;
  display: flex;
  align-items: center;
  gap: 12px;
  margin: 0 0 16px 0;
`;

const Subtitle = styled.p`
  font-size: 1.1rem;
  color: #cccccc;
  margin: 0;
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

const StatSubtext = styled.div`
  font-size: 12px;
  color: #666666;
  margin-top: 4px;
`;

const ContentGrid = styled.div`
  display: grid;
  grid-template-columns: 2fr 1fr;
  gap: 32px;
  margin-bottom: 32px;
  
  @media (max-width: 768px) {
    grid-template-columns: 1fr;
  }
`;

const Card = styled.div`
  background: #1a1a1a;
  border: 1px solid #333333;
  border-radius: 12px;
  padding: 24px;
`;

const CardTitle = styled.h3`
  font-size: 1.25rem;
  font-weight: 600;
  color: #ffffff;
  margin: 0 0 16px 0;
  display: flex;
  align-items: center;
  gap: 8px;
`;

const CardContent = styled.div`
  color: #cccccc;
`;

const TreasuryInfo = styled.div`
  margin-bottom: 24px;
`;

const InfoRow = styled.div`
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 12px 0;
  border-bottom: 1px solid #333333;
  
  &:last-child {
    border-bottom: none;
  }
`;

const InfoLabel = styled.span`
  color: #cccccc;
  font-weight: 500;
`;

const InfoValue = styled.span`
  color: #ffffff;
  font-family: monospace;
  font-weight: 600;
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

const ChartContainer = styled.div`
  height: 200px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: #2a2a2a;
  border-radius: 8px;
  color: #666666;
  font-size: 14px;
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

const formatKALON = (amount) => {
  return (amount / 1000000).toFixed(6);
};

const formatMicroKALON = (amount) => {
  return amount.toLocaleString();
};

function Treasury() {
  const { data: treasury, isLoading, error } = useQuery(
    'treasury',
    () => api.getTreasury(),
    { refetchInterval: 30000 }
  );

  const { data: networkStats } = useQuery(
    'networkStats',
    () => api.getNetworkStats(),
    { refetchInterval: 30000 }
  );

  if (isLoading) {
    return (
      <TreasuryContainer>
        <LoadingSpinner>
          <div className="spinner"></div>
          <span style={{ marginLeft: '12px' }}>Loading treasury data...</span>
        </LoadingSpinner>
      </TreasuryContainer>
    );
  }

  if (error) {
    return (
      <TreasuryContainer>
        <ErrorMessage>
          Failed to load treasury data. Please try again later.
        </ErrorMessage>
      </TreasuryContainer>
    );
  }

  return (
    <TreasuryContainer>
      <Header>
        <Title>
          <Wallet />
          Treasury
        </Title>
        <Subtitle>
          Kalon Network Treasury Management and Statistics
        </Subtitle>
      </Header>

      <StatsGrid>
        <StatCard>
          <StatIcon>
            <DollarSign />
          </StatIcon>
          <StatValue>{formatKALON(treasury?.balance || 0)}</StatValue>
          <StatLabel>Total Balance</StatLabel>
          <StatSubtext>KALON</StatSubtext>
        </StatCard>

        <StatCard>
          <StatIcon>
            <TrendingUp />
          </StatIcon>
          <StatValue>{formatKALON(treasury?.totalIncome || 0)}</StatValue>
          <StatLabel>Total Income</StatLabel>
          <StatSubtext>KALON</StatSubtext>
        </StatCard>

        <StatCard>
          <StatIcon>
            <Activity />
          </StatIcon>
          <StatValue>{formatKALON(treasury?.blockFees || 0)}</StatValue>
          <StatLabel>Block Fees</StatLabel>
          <StatSubtext>KALON</StatSubtext>
        </StatCard>

        <StatCard>
          <StatIcon>
            <BarChart3 />
          </StatIcon>
          <StatValue>{formatKALON(treasury?.txFees || 0)}</StatValue>
          <StatLabel>Transaction Fees</StatLabel>
          <StatSubtext>KALON</StatSubtext>
        </StatCard>
      </StatsGrid>

      <ContentGrid>
        <Card>
          <CardTitle>
            <Wallet />
            Treasury Information
          </CardTitle>
          <CardContent>
            <TreasuryInfo>
              <InfoRow>
                <InfoLabel>Treasury Address</InfoLabel>
                <InfoValue>
                  <AddressLink href={`/addresses/${treasury?.address}`}>
                    {treasury?.address}
                  </AddressLink>
                </InfoValue>
              </InfoRow>
              <InfoRow>
                <InfoLabel>Total Balance</InfoLabel>
                <InfoValue>
                  {formatMicroKALON(treasury?.balance || 0)} micro-KALON
                </InfoValue>
              </InfoRow>
              <InfoRow>
                <InfoLabel>Block Fees Collected</InfoLabel>
                <InfoValue>
                  {formatMicroKALON(treasury?.blockFees || 0)} micro-KALON
                </InfoValue>
              </InfoRow>
              <InfoRow>
                <InfoLabel>Transaction Fees Collected</InfoLabel>
                <InfoValue>
                  {formatMicroKALON(treasury?.txFees || 0)} micro-KALON
                </InfoValue>
              </InfoRow>
              <InfoRow>
                <InfoLabel>Total Income</InfoLabel>
                <InfoValue>
                  {formatMicroKALON(treasury?.totalIncome || 0)} micro-KALON
                </InfoValue>
              </InfoRow>
              <InfoRow>
                <InfoLabel>Last Updated</InfoLabel>
                <InfoValue>
                  {treasury?.lastUpdate ? 
                    formatDistanceToNow(new Date(treasury.lastUpdate), { addSuffix: true }) : 
                    'Unknown'
                  }
                </InfoValue>
              </InfoRow>
            </TreasuryInfo>
          </CardContent>
        </Card>

        <Card>
          <CardTitle>
            <TrendingUp />
            Income Breakdown
          </CardTitle>
          <CardContent>
            <div style={{ marginBottom: '16px' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '8px' }}>
                <span style={{ color: '#cccccc' }}>Block Fees</span>
                <span style={{ color: '#00d4ff' }}>
                  {((treasury?.blockFees || 0) / (treasury?.totalIncome || 1) * 100).toFixed(1)}%
                </span>
              </div>
              <div style={{ 
                width: '100%', 
                height: '8px', 
                background: '#333333', 
                borderRadius: '4px',
                overflow: 'hidden'
              }}>
                <div style={{
                  width: `${(treasury?.blockFees || 0) / (treasury?.totalIncome || 1) * 100}%`,
                  height: '100%',
                  background: 'linear-gradient(90deg, #00d4ff, #0099cc)',
                  borderRadius: '4px'
                }} />
              </div>
            </div>

            <div>
              <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '8px' }}>
                <span style={{ color: '#cccccc' }}>Transaction Fees</span>
                <span style={{ color: '#10b981' }}>
                  {((treasury?.txFees || 0) / (treasury?.totalIncome || 1) * 100).toFixed(1)}%
                </span>
              </div>
              <div style={{ 
                width: '100%', 
                height: '8px', 
                background: '#333333', 
                borderRadius: '4px',
                overflow: 'hidden'
              }}>
                <div style={{
                  width: `${(treasury?.txFees || 0) / (treasury?.totalIncome || 1) * 100}%`,
                  height: '100%',
                  background: 'linear-gradient(90deg, #10b981, #059669)',
                  borderRadius: '4px'
                }} />
              </div>
            </div>
          </CardContent>
        </Card>
      </ContentGrid>

      <Card>
        <CardTitle>
          <BarChart3 />
          Treasury Growth Chart
        </CardTitle>
        <CardContent>
          <ChartContainer>
            <div style={{ textAlign: 'center' }}>
              <BarChart3 size={48} style={{ marginBottom: '16px', opacity: 0.5 }} />
              <div>Chart visualization coming soon</div>
              <div style={{ fontSize: '12px', marginTop: '8px' }}>
                Historical treasury balance and income data
              </div>
            </div>
          </ChartContainer>
        </CardContent>
      </Card>
    </TreasuryContainer>
  );
}

export default Treasury;
