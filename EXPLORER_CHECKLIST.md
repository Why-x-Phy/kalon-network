=== EXPLORER OFFLINE - CHECKLIST ===

1. EXPLORER-DATEIEN AUF WEBSPACE?
────────────────────────────────────────────────
→ explorer/static/config.js muss existieren
→ Muss enthalten: window.RPC_URL = 'https://185.133.249.107:16317';
→ explorer/static/app.js muss existieren
→ Browser-Cache geleert? (Strg+Shift+R / Cmd+Shift+R)

2. BROWSER-WARNUNG AKZEPTIERT?
────────────────────────────────────────────────
→ Öffne: https://deine-website.de/explorer/
→ Browser zeigt Warnung: "Ihre Verbindung ist nicht privat"
→ Klicke: "Erweitert" → "Fortfahren zu ... (unsicher)"
→ OHNE DAS FUNKTIONIERT ES NICHT!

3. RPC-SERVER ERREICHBAR?
────────────────────────────────────────────────
→ Teste vom Browser aus:
  Developer Tools (F12) → Console
  → fetch('https://185.133.249.107:16317/rpc', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({jsonrpc:'2.0',method:'getHeight',id:1})
    }).then(r=>r.json()).then(console.log)

→ Wenn Fehler: Browser akzeptiert Zertifikat nicht
→ Lösung: Warnung akzeptieren!

