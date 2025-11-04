# Schnell-Setup für Testserver

## Server-Zugang
- IP: 185.133.249.107
- User: root
- Passwort: Admin1102

## Schnell-Setup (Ein Befehl)

```bash
# Auf Testserver einloggen
ssh root@185.133.249.107

# Dann ausführen:
cd ~ && git clone https://github.com/Why-x-Phy/kalon-network.git && cd kalon-network && chmod +x complete-server-setup.sh && sudo ./complete-server-setup.sh
```

## Oder Schritt für Schritt

### 1. Einloggen
```bash
ssh root@185.133.249.107
```

### 2. System aktualisieren
```bash
sudo apt update && sudo apt upgrade -y
```

### 3. Go installieren
```bash
wget https://go.dev/dl/go1.21.5.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.21.5.linux-amd64.tar.gz
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
export PATH=$PATH:/usr/local/go/bin
```

### 4. Repository klonen
```bash
cd ~
git clone https://github.com/Why-x-Phy/kalon-network.git
cd kalon-network
```

### 5. Setup ausführen
```bash
chmod +x complete-server-setup.sh
sudo ./complete-server-setup.sh
```

## Wichtig

- DNS A-Record muss gesetzt sein: `explorer.kalon-network.com` → `185.133.249.107`
- Script fragt nach DNS-Bestätigung

## Nach dem Setup

```bash
# Teste Node
curl http://localhost:16316/rpc -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"getHeight","id":1}'

# Teste HTTPS
curl https://explorer.kalon-network.com
```

## Im Browser testen

- Öffne: `https://explorer.kalon-network.com`
- Explorer sollte "ONLINE" zeigen

