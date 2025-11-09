=== BROWSER-TEST FÜR EXPLORER ===

SCHRITT 1: BROWSER-CONSOLE ÖFFNEN
────────────────────────────────────────────────
1. Öffne: https://deine-website.de/explorer/
2. Drücke: F12 (Developer Tools)
3. Gehe zu: "Console" Tab

SCHRITT 2: FEHLER PRÜFEN
────────────────────────────────────────────────
→ Siehst du rote Fehler?
→ Typischer Fehler: "net::ERR_CERT_AUTHORITY_INVALID"
→ Das bedeutet: Browser akzeptiert Zertifikat nicht!

SCHRITT 3: MANUELLER RPC-TEST IN CONSOLE
────────────────────────────────────────────────
Kopiere und führe aus in Console:

fetch('https://185.133.249.107:16317/rpc', {
  method: 'POST',
  headers: {'Content-Type': 'application/json'},
  body: JSON.stringify({jsonrpc:'2.0',method:'getHeight',id:1})
})
.then(r => r.json())
.then(data => console.log('SUCCESS:', data))
.catch(err => console.error('ERROR:', err))

WENN FEHLER:
────────────────────────────────────────────────
→ Browser zeigt Zertifikat-Warnung
→ Klicke auf URL (oben links)
→ Klicke "Erweitert"
→ Klicke "Fortfahren zu 185.133.249.107 (unsicher)"
→ Dann nochmal Console-Test

WENN SUCCESS:
────────────────────────────────────────────────
→ RPC funktioniert!
→ Problem ist dann im Explorer-JavaScript
→ Prüfe config.js auf Webspace

