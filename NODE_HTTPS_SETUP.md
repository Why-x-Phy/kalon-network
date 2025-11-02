# Node HTTPS Setup - Schritt-für-Schritt Anleitung

## Übersicht

Der Node RPC Server soll sowohl HTTP (Port 16316) als auch HTTPS (Port 16317) unterstützen, damit der Explorer sowohl über HTTP als auch HTTPS funktionieren kann.

## Schritt 1: SSL-Zertifikat besorgen

### Option A: Let's Encrypt (Empfohlen für Production)

```bash
# Certbot installieren
sudo apt update
sudo apt install certbot

# Zertifikat erstellen (für Domain)
sudo certbot certonly --standalone -d your-node-domain.com

# Zertifikate finden:
# → /etc/letsencrypt/live/your-node-domain.com/fullchain.pem
# → /etc/letsencrypt/live/your-node-domain.com/privkey.pem
```

### Option B: Selbst-signiertes Zertifikat (für Test)

```bash
# Zertifikat generieren
openssl req -x509 -newkey rsa:4096 -keyout node-key.pem -out node-cert.pem -days 365 -nodes

# Achtung: Browser zeigt Warnung bei selbst-signiertem Zertifikat!
# Für Test OK, für Production Let's Encrypt verwenden
```

## Schritt 2: Node Code ändern

### Änderungen in `rpc/server_v2.go`:

1. **Neue Felder hinzufügen:**
   - `httpsAddr string` (HTTPS Port, z.B. ":16317")
   - `certFile string` (Pfad zu cert.pem)
   - `keyFile string` (Pfad zu key.pem)

2. **Start() Funktion erweitern:**
   - HTTP Server startet weiterhin auf Port 16316
   - Zusätzlich HTTPS Server auf Port 16317 starten
   - `ListenAndServeTLS(certFile, keyFile)` verwenden

3. **Beide Server in Goroutines starten:**
   - HTTP Server in Goroutine (bestehend)
   - HTTPS Server in Goroutine (neu)

## Schritt 3: Node-Konfiguration

### Flags hinzufügen in `cmd/kalon-node-v2/main.go`:

```go
-https       string  "HTTPS server address (e.g. :16317)"
-certfile   string  "SSL certificate file path"
-keyfile    string  "SSL private key file path"
```

### Start-Befehl:

```bash
./build-v2/kalon-node-v2 \
  -datadir data-testnet \
  -genesis genesis/testnet.json \
  -rpc 0.0.0.0:16316 \
  -https 0.0.0.0:16317 \
  -certfile /path/to/cert.pem \
  -keyfile /path/to/key.pem
```

## Schritt 4: Firewall

```bash
# HTTP Port (bestehend)
sudo ufw allow 16316/tcp

# HTTPS Port (neu)
sudo ufw allow 16317/tcp

# Prüfen
sudo ufw status | grep 1631
```

## Schritt 5: Explorer config.js anpassen

### `explorer/static/config.js`:

```javascript
// HTTPS bevorzugen, HTTP als Fallback
if (typeof window.RPC_URL === 'undefined') {
    window.RPC_URL = 'https://185.133.249.107:16317';
}

// Optional: HTTP Fallback
// window.RPC_URL_HTTP = 'http://185.133.249.107:16316';
```

## Schritt 6: Website HTTP/HTTPS (Webspace)

### Normalerweise automatisch:

Die meisten Webserver (Apache/Nginx) unterstützen automatisch beide:
- HTTP: `http://ihre-domain.de`
- HTTPS: `https://ihre-domain.de`

### Falls manuell nötig:

#### Apache (.htaccess):
```apache
RewriteEngine On
RewriteCond %{HTTPS} off
RewriteRule ^(.*)$ https://%{HTTP_HOST}%{REQUEST_URI} [L,R=301]
```

#### Nginx:
```nginx
server {
    listen 80;
    server_name ihre-domain.de;
    return 301 https://$server_name$request_uri;
}
```

## Schritt 7: Testen

### HTTP testen:
```bash
curl http://185.133.249.107:16316/rpc \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"getHeight","id":1}'
```

### HTTPS testen:
```bash
curl https://185.133.249.107:16317/rpc \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"getHeight","id":1}' \
  -k  # -k für selbst-signiertes Zertifikat
```

## Zusammenfassung

1. ✅ SSL-Zertifikat besorgen (Let's Encrypt oder selbst-signiert)
2. ✅ Node Code ändern (HTTPS Support hinzufügen)
3. ✅ Node Flags hinzufügen (-https, -certfile, -keyfile)
4. ✅ Firewall Port 16317 öffnen
5. ✅ Explorer config.js auf HTTPS ändern
6. ✅ Website HTTP/HTTPS konfigurieren (meist automatisch)
7. ✅ Beide Protokolle testen

## Vorteile

- ✅ Explorer funktioniert über HTTPS
- ✅ HTTP bleibt verfügbar (Kompatibilität)
- ✅ Sichere Verbindung für RPC
- ✅ Keine Mixed Content Probleme

