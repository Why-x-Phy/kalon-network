# Explorer auf Node-Server Setup - Schritt-für-Schritt

## Übersicht

Diese Anleitung zeigt, wie man den Explorer auf dem gleichen Server wie den Node laufen lässt. Dies ist die **einfachste und beste Lösung** für HTTPS ohne Browser-Warnung.

## Vorteile

- ✅ Alles zentral auf einem Server
- ✅ Keine Cross-Origin Probleme
- ✅ Nutzt vorhandene Domain (`explorer.kalon-network.com`)
- ✅ Keine zusätzliche Subdomain nötig
- ✅ Einfacher zu verwalten
- ✅ Professioneller Setup (nginx + Node)

## Schritt 1: DNS A-Record ändern

**Aktuell:**
- `explorer.kalon-network.com` → Webspace

**Ändern zu:**
- `explorer.kalon-network.com` → `185.133.249.107` (Testserver)

**In deinem DNS-Provider:**
```
Type: A
Name: explorer
Value: 185.133.249.107
TTL: 3600 (oder Auto)
```

**Wichtig:** Warte 5-15 Minuten bis DNS propagiert ist. Prüfe mit:
```bash
dig explorer.kalon-network.com
# Oder:
nslookup explorer.kalon-network.com
```

## Schritt 2: nginx auf Testserver installieren

```bash
# Auf Testserver (185.133.249.107):
sudo apt update
sudo apt install nginx

# nginx starten:
sudo systemctl start nginx
sudo systemctl enable nginx
```

## Schritt 3: Explorer-Dateien auf Testserver kopieren

```bash
# Auf Testserver:
cd ~/kalon-network

# Verzeichnis erstellen:
sudo mkdir -p /var/www/explorer

# Explorer-Dateien kopieren:
sudo cp -r explorer/static/* /var/www/explorer/

# Berechtigungen setzen:
sudo chown -R www-data:www-data /var/www/explorer
sudo chmod -R 755 /var/www/explorer
```

## Schritt 4: nginx konfigurieren

Erstelle `/etc/nginx/sites-available/explorer`:

```nginx
server {
    listen 80;
    server_name explorer.kalon-network.com;

    # Explorer-Dateien
    root /var/www/explorer;
    index index.html;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Explorer-Dateien
    location / {
        try_files $uri $uri/ /index.html;
    }

    # RPC Proxy zu Node (localhost)
    location /rpc {
        proxy_pass http://localhost:16316/rpc;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Wichtig für POST-Requests:
        proxy_set_header Content-Type application/json;
        
        # CORS Headers
        add_header Access-Control-Allow-Origin * always;
        add_header Access-Control-Allow-Methods "POST, GET, OPTIONS" always;
        add_header Access-Control-Allow-Headers "Content-Type" always;
    }

    # Health check
    location /health {
        proxy_pass http://localhost:16316/health;
    }
}
```

**nginx aktivieren:**
```bash
sudo ln -s /etc/nginx/sites-available/explorer /etc/nginx/sites-enabled/
sudo nginx -t  # Konfiguration testen
sudo systemctl reload nginx
```

## Schritt 5: Setup-Script ausführen (oder manuell)

**Option A: Automatisches Setup-Script:**
```bash
cd ~/kalon-network
./setup-explorer-nginx.sh
```

**Option B: Manuell (siehe ursprüngliche Anleitung weiter unten)**

## Schritt 6: Certbot auf Testserver installieren

```bash
# Certbot installieren:
sudo apt install certbot python3-certbot-nginx

# Zertifikat erstellen (für Domain):
sudo certbot --nginx -d explorer.kalon-network.com

# Automatische Erneuerung testen:
sudo certbot renew --dry-run
```

**Wichtig:** 
- Port 80 muss frei sein (für Certbot)
- nginx muss laufen
- Certbot konfiguriert nginx automatisch für HTTPS

## Schritt 6: Explorer config.js (bereits angepasst)

Die `config.js` wurde bereits angepasst und verwendet automatisch die gleiche Domain wie der Explorer. Keine weitere Änderung nötig!

Die config.js verwendet jetzt:
```javascript
const protocol = window.location.protocol === 'https:' ? 'https:' : 'http:';
const host = window.location.host;
window.RPC_URL = `${protocol}//${host}`;
```

Das bedeutet: Explorer ruft automatisch `/rpc` auf der gleichen Domain auf, nginx macht Proxy zu Node.

## Schritt 7: Node starten (nur HTTP auf localhost, da nginx macht Proxy)

```bash
# Node starten (nur HTTP, nginx macht HTTPS):
./build-v2/kalon-node-v2 \
  -datadir data-testnet \
  -genesis genesis/testnet.json \
  -rpc 127.0.0.1:16316 \
  -p2p 0.0.0.0:17335 \
  > node.log 2>&1 &

# WICHTIG: RPC nur auf localhost (127.0.0.1), da nginx macht Proxy!
```

**Oder:** Node mit HTTPS starten und nginx macht Proxy zu HTTPS (komplexer, nicht nötig).

## Schritt 8: Firewall Ports öffnen

```bash
# HTTP/HTTPS (nginx):
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# P2P (Node):
sudo ufw allow 17335/tcp

# RPC (nur localhost, nicht nötig):
# sudo ufw allow 16316/tcp  # NICHT nötig, da nur localhost!
```

## Schritt 9: Testen

```bash
# HTTP testen (sollte zu HTTPS weiterleiten):
curl http://explorer.kalon-network.com/rpc \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"getHeight","id":1}'

# HTTPS testen:
curl https://explorer.kalon-network.com/rpc \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"getHeight","id":1}'
```

**Explorer testen:**
- Öffne: `https://explorer.kalon-network.com`
- Explorer sollte "ONLINE" zeigen
- Keine Browser-Warnung!

## Schritt 10: Automatische Zertifikats-Erneuerung

Certbot erneuert automatisch (Cronjob wird automatisch erstellt). Falls Node nach Erneuerung neu gestartet werden muss:

```bash
# Cronjob für Node-Neustart nach Zertifikats-Erneuerung (falls nötig):
sudo crontab -e
# Füge hinzu (falls Node nach Erneuerung neu gestartet werden muss):
0 0 * * * certbot renew --quiet --deploy-hook "systemctl reload nginx"
```

## Zusammenfassung

✅ **DNS:** `explorer.kalon-network.com` → `185.133.249.107`
✅ **nginx:** Läuft auf Testserver, macht Proxy zu Node
✅ **Explorer:** Läuft auf Testserver (`/var/www/explorer`)
✅ **Node:** Läuft auf Testserver (localhost:16316)
✅ **HTTPS:** Let's Encrypt für `explorer.kalon-network.com`
✅ **Keine Browser-Warnung!**

## Vorteile dieser Lösung

- ✅ Alles zentral auf einem Server
- ✅ Keine Cross-Origin Probleme
- ✅ Nutzt vorhandene Domain
- ✅ Einfacher zu verwalten
- ✅ Professioneller Setup

## Nachteile

- ❌ Alles auf einem Server (Last)
- ❌ nginx auf Testserver nötig
- ❌ Webspace wird nicht genutzt

