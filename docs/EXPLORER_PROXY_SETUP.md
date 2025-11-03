# Explorer Reverse Proxy Setup - Schritt-für-Schritt

## Übersicht

Diese Anleitung zeigt, wie man einen Reverse Proxy auf dem Webspace einrichtet, damit der Explorer über HTTPS ohne Browser-Warnung funktioniert.

## Konzept

```
Browser → https://deine-domain.de/api/rpc
    ↓
nginx auf Webspace (Let's Encrypt Zertifikat)
    ↓ (HTTP intern)
Node-Server http://185.133.249.107:16316/rpc
```

**Vorteile:**
- ✅ Keine Browser-Warnung
- ✅ Nutzt vorhandene Domain/Let's Encrypt
- ✅ Explorer bleibt auf Webspace
- ✅ Professionelle Lösung

## Schritt 1: nginx auf Webspace konfigurieren

Falls dein Webspace Apache verwendet, siehe Schritt 1B.

### Option A: nginx

Füge folgende Konfiguration zu deiner nginx-Konfiguration hinzu:

```nginx
location /api/rpc {
    proxy_pass http://185.133.249.107:16316/rpc;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    
    # Wichtig für POST-Requests:
    proxy_set_header Content-Type application/json;
    
    # Timeouts erhöhen für große Requests:
    proxy_connect_timeout 60s;
    proxy_send_timeout 60s;
    proxy_read_timeout 60s;
    
    # CORS Headers (falls nginx sie hinzufügen soll):
    add_header Access-Control-Allow-Origin * always;
    add_header Access-Control-Allow-Methods "POST, GET, OPTIONS" always;
    add_header Access-Control-Allow-Headers "Content-Type" always;
}
```

**Wichtig:** Stelle sicher, dass der Node-Server vom Webspace aus erreichbar ist (Port 16316).

### Option B: Apache (.htaccess)

Falls dein Webspace Apache verwendet:

```apache
RewriteEngine On
RewriteCond %{REQUEST_URI} ^/api/rpc
RewriteRule ^api/rpc(.*)$ http://185.133.249.107:16316/rpc$1 [P,L]

# Proxy-Module aktivieren (muss Server-Admin machen):
# LoadModule proxy_module modules/mod_proxy.so
# LoadModule proxy_http_module modules/mod_proxy_http.so
```

**Oder:** Verwende `ProxyPass` in der Apache-Konfiguration:

```apache
ProxyPass /api/rpc http://185.133.249.107:16316/rpc
ProxyPassReverse /api/rpc http://185.133.249.107:16316/rpc
```

## Schritt 2: Explorer config.js anpassen

Ändere `explorer/static/config.js`:

```javascript
// Explorer Configuration
if (typeof window.RPC_URL === 'undefined') {
    // Nutze Proxy über Webspace-Domain
    window.RPC_URL = 'https://deine-domain.de/api/rpc';
}
```

**Wichtig:** Ersetze `deine-domain.de` mit deiner tatsächlichen Domain!

## Schritt 3: Firewall auf Node-Server prüfen

Stelle sicher, dass der Node-Server vom Webspace aus erreichbar ist:

```bash
# Auf Webspace testen:
curl http://185.133.249.107:16316/rpc \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"getHeight","id":1}'
```

Falls nicht erreichbar:
- Firewall auf Node-Server: `sudo ufw allow 16316/tcp`
- IP-Whitelist prüfen (falls aktiviert)

## Schritt 4: Testen

1. **Proxy testen:**
   ```bash
   curl https://deine-domain.de/api/rpc \
     -H "Content-Type: application/json" \
     -d '{"jsonrpc":"2.0","method":"getHeight","id":1}'
   ```

2. **Explorer testen:**
   - Öffne: `https://deine-domain.de/explorer/`
   - Browser-Console öffnen (F12)
   - Prüfe ob RPC-Aufrufe funktionieren
   - Explorer sollte "ONLINE" zeigen

## Schritt 5: Fehlerbehebung

### Problem: "502 Bad Gateway"
- **Ursache:** Node-Server nicht erreichbar vom Webspace
- **Lösung:** Firewall prüfen, IP-Whitelist prüfen

### Problem: "Connection refused"
- **Ursache:** Node läuft nicht oder falscher Port
- **Lösung:** Node starten, Port prüfen

### Problem: CORS-Fehler
- **Ursache:** CORS-Header fehlen
- **Lösung:** CORS-Header in nginx hinzufügen (siehe Schritt 1)

### Problem: Proxy funktioniert nicht
- **Ursache:** nginx/Apache-Konfiguration falsch
- **Lösung:** Logs prüfen: `tail -f /var/log/nginx/error.log`

## Zusammenfassung

✅ **Reverse Proxy auf Webspace** ist die beste Lösung für:
- Keine Browser-Warnung
- Nutzung vorhandener Infrastruktur
- Professionelle, benutzerfreundliche Lösung

## Alternative: Direkte Domain auf Node

Falls Reverse Proxy nicht möglich ist, siehe `NODE_HTTPS_SETUP.md` für:
- Domain für Node-Server konfigurieren
- Let's Encrypt direkt auf Node-Server

