# Domain für Node-Server + Let's Encrypt Setup

## Übersicht

Da du auf dem Webspace nichts installieren kannst, aber DNS anpassen kannst, ist dies die beste Lösung:
- Subdomain für Node-Server erstellen
- Let's Encrypt Zertifikat direkt auf Node-Server
- Explorer ruft direkt die Domain auf

## Aktuelle Domain-Struktur

- **Explorer:** `explorer.kalon-network.com` → Webspace
- **Node:** `185.133.249.107` → Testserver (wird zu `node.kalon-network.com`)

## Schritt 1: DNS A-Record erstellen

In deinem DNS-Provider (z.B. 1und1, Cloudflare, etc.):

**Subdomain für Node-Server erstellen:**
```
Type: A
Name: node
Value: 185.133.249.107
TTL: 3600 (oder Auto)
```

**Ergebnis:**
- `node.kalon-network.com` → `185.133.249.107`
- `explorer.kalon-network.com` → Webspace (bleibt wie es ist)

**Wichtig:** Warte 5-15 Minuten bis DNS propagiert ist. Prüfe mit:
```bash
dig node.kalon-network.com
# Oder:
nslookup node.kalon-network.com
```

## Schritt 2: Certbot auf Node-Server installieren

```bash
# Auf Node-Server (185.133.249.107):
sudo apt update
sudo apt install certbot

# Zertifikat erstellen (für Domain):
sudo certbot certonly --standalone -d node.kalon-network.com

# Zertifikate finden:
# → /etc/letsencrypt/live/node.kalon-network.com/fullchain.pem
# → /etc/letsencrypt/live/node.kalon-network.com/privkey.pem
```

**Wichtig:** 
- Port 80 muss frei sein (für Certbot)
- Falls nginx/Apache läuft: temporär stoppen
- Node sollte nicht auf Port 80 laufen

## Schritt 3: Node mit Let's Encrypt Zertifikat starten

```bash
./build-v2/kalon-node-v2 \
  -datadir data-testnet \
  -genesis genesis/testnet.json \
  -rpc 0.0.0.0:16316 \
  -https 0.0.0.0:16317 \
  -certfile /etc/letsencrypt/live/node.kalon-network.com/fullchain.pem \
  -keyfile /etc/letsencrypt/live/node.kalon-network.com/privkey.pem \
  -p2p 0.0.0.0:17335 \
  > node.log 2>&1 &
```

## Schritt 4: Firewall Port 16317 öffnen

```bash
sudo ufw allow 16317/tcp
```

## Schritt 5: Explorer config.js anpassen

Ändere `explorer/static/config.js`:

```javascript
if (typeof window.RPC_URL === 'undefined') {
    window.RPC_URL = 'https://node.kalon-network.com:16317';
}
```

**Wichtig:** Der Explorer bleibt auf `explorer.kalon-network.com` (Webspace) und ruft nur die Node-Domain auf.

## Schritt 6: Testen

```bash
# HTTPS testen (sollte funktionieren ohne -k):
curl https://node.kalon-network.com:16317/rpc \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"getHeight","id":1}'
```

**Explorer testen:**
- Öffne: `https://deine-website.de/explorer/`
- Explorer sollte "ONLINE" zeigen
- Keine Browser-Warnung!

## Schritt 7: Zertifikat erneuern (automatisch)

Let's Encrypt Zertifikate sind 90 Tage gültig. Automatische Erneuerung:

```bash
# Certbot automatische Erneuerung testen:
sudo certbot renew --dry-run

# Cronjob für automatische Erneuerung:
sudo crontab -e
# Füge hinzu:
0 0 * * * certbot renew --quiet --deploy-hook "pkill -HUP kalon-node-v2 || killall kalon-node-v2; cd ~/kalon-network && ./build-v2/kalon-node-v2 [deine-parameter] > node.log 2>&1 &"
```

**Wichtig:** Node muss nach Zertifikats-Erneuerung neu gestartet werden!

## Zusammenfassung

✅ **DNS A-Record:** `node.kalon-network.com` → `185.133.249.107`
✅ **Certbot:** Let's Encrypt Zertifikat auf Node-Server
✅ **Node:** Start mit Let's Encrypt Zertifikat
✅ **Explorer:** Ruft `https://node.kalon-network.com:16317` auf
✅ **Explorer selbst:** Bleibt auf `explorer.kalon-network.com` (Webspace)
✅ **Keine Browser-Warnung!**

## Vorteile

- ✅ Keine Webspace-Konfiguration nötig
- ✅ Keine Browser-Warnung
- ✅ Professionelle Lösung
- ✅ Direkter HTTPS-Zugriff

## Nachteile

- ❌ Benötigt Subdomain (aber du hast Domain)
- ❌ Certbot auf Node-Server installieren
- ❌ Zertifikat-Erneuerung muss gehandhabt werden

