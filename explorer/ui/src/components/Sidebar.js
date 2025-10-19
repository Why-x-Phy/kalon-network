import React from 'react';
import { NavLink } from 'react-router-dom';
import styled from 'styled-components';
import { 
  Home, 
  Blocks, 
  CreditCard, 
  Users, 
  Wallet, 
  Network, 
  Search,
  TrendingUp
} from 'lucide-react';

const SidebarContainer = styled.aside`
  width: 250px;
  background: #1a1a1a;
  border-right: 1px solid #333333;
  position: fixed;
  top: 0;
  left: 0;
  height: 100vh;
  overflow-y: auto;
  z-index: 200;
  
  @media (max-width: 768px) {
    transform: translateX(-100%);
    transition: transform 0.3s ease;
    
    &.open {
      transform: translateX(0);
    }
  }
`;

const SidebarHeader = styled.div`
  padding: 24px;
  border-bottom: 1px solid #333333;
`;

const SidebarTitle = styled.h2`
  font-size: 18px;
  font-weight: 600;
  color: #00d4ff;
  margin: 0;
`;

const SidebarSubtitle = styled.p`
  font-size: 14px;
  color: #666666;
  margin: 4px 0 0 0;
`;

const Nav = styled.nav`
  padding: 16px 0;
`;

const NavItem = styled(NavLink)`
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px 24px;
  color: #cccccc;
  text-decoration: none;
  transition: all 0.2s ease;
  border-left: 3px solid transparent;
  
  &:hover {
    background: #2a2a2a;
    color: #ffffff;
  }
  
  &.active {
    background: #2a2a2a;
    color: #00d4ff;
    border-left-color: #00d4ff;
  }
  
  svg {
    width: 20px;
    height: 20px;
  }
`;

const NavLabel = styled.span`
  font-size: 14px;
  font-weight: 500;
`;

const NavSection = styled.div`
  margin-bottom: 24px;
`;

const SectionTitle = styled.h3`
  font-size: 12px;
  font-weight: 600;
  color: #666666;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  margin: 0 0 8px 0;
  padding: 0 24px;
`;

const Footer = styled.div`
  position: absolute;
  bottom: 0;
  left: 0;
  right: 0;
  padding: 24px;
  border-top: 1px solid #333333;
  background: #1a1a1a;
`;

const FooterText = styled.p`
  font-size: 12px;
  color: #666666;
  margin: 0;
  text-align: center;
`;

function Sidebar() {
  return (
    <SidebarContainer>
      <SidebarHeader>
        <SidebarTitle>Kalon Explorer</SidebarTitle>
        <SidebarSubtitle>Blockchain Explorer</SidebarSubtitle>
      </SidebarHeader>
      
      <Nav>
        <NavSection>
          <SectionTitle>Overview</SectionTitle>
          <NavItem to="/" end>
            <Home />
            <NavLabel>Dashboard</NavLabel>
          </NavItem>
          <NavItem to="/network">
            <Network />
            <NavLabel>Network</NavLabel>
          </NavItem>
        </NavSection>
        
        <NavSection>
          <SectionTitle>Blockchain</SectionTitle>
          <NavItem to="/blocks">
            <Blocks />
            <NavLabel>Blocks</NavLabel>
          </NavItem>
          <NavItem to="/transactions">
            <CreditCard />
            <NavLabel>Transactions</NavLabel>
          </NavItem>
          <NavItem to="/addresses">
            <Users />
            <NavLabel>Addresses</NavLabel>
          </NavItem>
        </NavSection>
        
        <NavSection>
          <SectionTitle>Tools</SectionTitle>
          <NavItem to="/treasury">
            <Wallet />
            <NavLabel>Treasury</NavLabel>
          </NavItem>
          <NavItem to="/search">
            <Search />
            <NavLabel>Search</NavLabel>
          </NavItem>
        </NavSection>
      </Nav>
      
      <Footer>
        <FooterText>
          Kalon Network v1.0.0
        </FooterText>
      </Footer>
    </SidebarContainer>
  );
}

export default Sidebar;
