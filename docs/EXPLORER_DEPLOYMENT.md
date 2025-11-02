# Explorer Deployment auf Webspace

## Übersicht

Der Kalon Explorer kann auf jedem normalen Webspace (z.B. 1und1) hochgeladen werden, **ohne** einen Go-Server oder Node.js.

## Was wird benötigt?

### Auf dem Webspace:
- **Nur statische Dateien** aus `explorer/static/` hochladen
- Kein Go, kein Node.js, kein PHP nötig
- Einfacher HTTP-Server (wie Apache/Nginx)

### Auf dem Server:
- **Master Node läuft** mit RPC Server (Port 16316)
- RPC Server ist **öffentlich erreichbar** (oder über Reverse Proxy)

## Dateien zum Hochladen

### Alle Dateien aus `explorer/static/`:

```
explorer/static/
├── index.html      ✅ Hauptseite (Explorer)
├── stats.html      ✅ Statistiken-Seite
├── block.html      ✅ Block-Details-Seite
├── app.js          ✅ Explorer-Logik
├── stats.js        ✅ Stats-Logik
├── style.css       ✅ Styling
└── config.js       ✅ Konfiguration (optional)
```

**Alle diese Dateien** einfach auf den Webspace hochladen.

## RPC URL konfigurieren

### Option 1: Standard (localhost)
Wenn der Explorer und Node auf demselben Server laufen:
- Keine Änderung nötig
- `config.js` verwendet `http://localhost:16316`

### Option 2: Externe Node
Wenn der Node auf einem anderen Server läuft:

**In `config.js` ändern:**
```javascript
window.RPC_URL = 'http://ihr-node-server:16316';
```

**ODER direkt in HTML einbinden (vor den anderen Scripts):**
```html
<script>
    window.RPC_URL = 'http://ihr-node-server:16316';
</script>
<script src="app.js"></script>
```

## Schritt-für-Schritt Anleitung

### 1. Dateien vorbereiten
```bash
cd explorer/static/
# Alle Dateien sind bereit zum Hochladen
ls -la
```

### 2. Auf Webspace hochladen
- Via FTP/SFTP: Alle Dateien aus `explorer/static/` hochladen
- Via File Manager: Alle Dateien hochladen
- Struktur beibehalten (alle Dateien im gleichen Verzeichnis)

### 3. RPC URL anpassen (falls nötig)
- Falls Node auf anderem Server: `config.js` anpassen
- Oder direkt in `index.html` einbinden

### 4. Domain verknüpfen
- Webspace mit Domain verknüpfen (normaler Prozess)
- Explorer ist unter `http://ihre-domain.de/` erreichbar

### 5. Node RPC erreichbar machen
- **Wichtig**: RPC Server muss vom Browser aus erreichbar sein
- Option A: Node läuft auf öffentlichem Server (Port 16316 offen)
- Option B: Reverse Proxy (z.B. Nginx) macht RPC öffentlich verfügbar

## Online-Status

Der Explorer zeigt automatisch:
- **Grün (● ONLINE)**: Verbindung zum RPC Server erfolgreich
- **Rot (● OFFLINE)**: Keine Verbindung zum RPC Server

Die Prüfung erfolgt automatisch alle 5 Sekunden.

## Beispiele

### Beispiel 1: Node auf eigenem Server
```
Node Server: node.kalon.network (Port 16316)
Webspace: www.kalon.network

config.js:
  window.RPC_URL = 'http://node.kalon.network:16316';
```

### Beispiel 2: Node und Explorer auf gleichem Server
```
Beide auf: www.kalon.network

config.js:
  window.RPC_URL = 'http://localhost:16316';
```

### Beispiel 3: Reverse Proxy (empfohlen für Production)
```
Node: 127.0.0.1:16316 (nur lokal)
Nginx: rpc.kalon.network → 127.0.0.1:16316

config.js:
  window.RPC_URL = 'https://rpc.kalon.network';
```

## Sicherheit

⚠️ **Wichtig für Production:**
- CORS ist aktuell auf `*` (alle Domains erlaubt)
- Für Production: CORS sollte auf spezifische Domains beschränkt werden
- RPC Server sollte Rate Limiting aktiviert haben (ist bereits implementiert)

## Troubleshooting

### Explorer zeigt "OFFLINE" (rot)
- Prüfe: Läuft der Node mit RPC?
- Prüfe: Ist RPC_URL korrekt konfiguriert?
- Prüfe: Ist RPC Server öffentlich erreichbar?
- Prüfe: CORS ist aktiviert im RPC Server?

### Browser Console zeigt CORS-Fehler
- Prüfe: RPC Server sendet CORS Headers
- Prüfe: `Access-Control-Allow-Origin: *` in Response

### Explorer zeigt keine Daten
- Prüfe: Node läuft und hat Blocks?
- Prüfe: RPC Server antwortet korrekt?
- Prüfe: Browser Console für Fehler

## Zusammenfassung

✅ **Nur Dateien aus `explorer/static/` hochladen**
✅ **RPC_URL konfigurieren (falls nötig)**
✅ **Node RPC Server muss erreichbar sein**
✅ **Fertig!**

Der Explorer funktioniert dann vollständig als statische Website ohne Server-Side-Code.

