import React from 'react';
import { Routes, Route } from 'react-router-dom';
import styled from 'styled-components';
import Header from './components/Header';
import Sidebar from './components/Sidebar';
import Home from './pages/Home';
import Blocks from './pages/Blocks';
import BlockDetail from './pages/BlockDetail';
import Transactions from './pages/Transactions';
import TransactionDetail from './pages/TransactionDetail';
import Addresses from './pages/Addresses';
import AddressDetail from './pages/AddressDetail';
import Treasury from './pages/Treasury';
import Network from './pages/Network';
import Search from './pages/Search';

const AppContainer = styled.div`
  display: flex;
  min-height: 100vh;
  background-color: #0a0a0a;
  color: #ffffff;
`;

const MainContent = styled.main`
  flex: 1;
  display: flex;
  flex-direction: column;
  margin-left: 250px;
  
  @media (max-width: 768px) {
    margin-left: 0;
  }
`;

const Content = styled.div`
  flex: 1;
  padding: 24px;
  
  @media (max-width: 768px) {
    padding: 16px;
  }
`;

function App() {
  return (
    <AppContainer>
      <Sidebar />
      <MainContent>
        <Header />
        <Content>
          <Routes>
            <Route path="/" element={<Home />} />
            <Route path="/blocks" element={<Blocks />} />
            <Route path="/blocks/:hash" element={<BlockDetail />} />
            <Route path="/transactions" element={<Transactions />} />
            <Route path="/transactions/:hash" element={<TransactionDetail />} />
            <Route path="/addresses" element={<Addresses />} />
            <Route path="/addresses/:address" element={<AddressDetail />} />
            <Route path="/treasury" element={<Treasury />} />
            <Route path="/network" element={<Network />} />
            <Route path="/search" element={<Search />} />
          </Routes>
        </Content>
      </MainContent>
    </AppContainer>
  );
}

export default App;
