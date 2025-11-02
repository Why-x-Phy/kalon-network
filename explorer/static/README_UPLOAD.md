# Kalon Explorer - Upload-Anleitung

## Dateien zum Hochladen

Laden Sie ALLE folgenden Dateien in das Root-Verzeichnis Ihres Webspaces hoch:

### Erforderliche Dateien:
1. **index.html** - Hauptseite (Explorer)
2. **stats.html** - Statistik-Seite
3. **block.html** - Block-Detail-Seite
4. **app.js** - JavaScript für Explorer
5. **stats.js** - JavaScript für Stats
6. **style.css** - Stylesheet
7. **config.js** - Konfiguration (RPC URL ist bereits auf 185.133.249.107:16316 gesetzt)

### Verzeichnisstruktur auf Webspace:
```
/www/ (oder /public_html/)
├── index.html
├── stats.html
├── block.html
├── app.js
├── stats.js
├── style.css
└── config.js
```

## Konfiguration

Die `config.js` ist bereits konfiguriert mit:
```javascript
window.RPC_URL = 'http://185.133.249.107:16316';
```

Falls Sie die IP ändern müssen, editieren Sie `config.js` nach dem Upload.

## Nach dem Upload

1. Öffnen Sie Ihre Domain im Browser
2. Prüfen Sie ob "● ONLINE" grün ist
3. Prüfen Sie ob Block-Height angezeigt wird

## Troubleshooting

**Explorer zeigt "OFFLINE":**
- Prüfen Sie ob Node läuft: `ps aux | grep kalon-node-v2`
- Prüfen Sie ob RPC erreichbar ist: `curl http://185.133.249.107:16316/rpc -d '{"jsonrpc":"2.0","method":"getHeight","id":1}'`
- Prüfen Sie Browser-Konsole (F12) auf Fehler
- Prüfen Sie ob Firewall Port 16316 erlaubt

**CORS-Fehler im Browser:**
- Node RPC-Server hat bereits CORS aktiviert
- Falls trotzdem Fehler: Prüfen Sie Node-Log auf CORS-Header

**Daten werden nicht angezeigt:**
- Prüfen Sie Browser-Konsole (F12) auf JavaScript-Fehler
- Prüfen Sie ob RPC URL in `config.js` korrekt ist

