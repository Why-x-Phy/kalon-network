=== FIXES FÜR LEVELDB & EXPLORER ===

LEVELDB PROBLEM:
────────────────────────────────────────────────
→ Implementiert: Automatische Reparatur
→ Wenn Datenbank korrupt: Reparatur versuchen
→ Wenn Reparatur fehlschlägt: Frische Datenbank erstellen
→ Keine manuelle Löschung mehr nötig

EXPLORER PROBLEM:
────────────────────────────────────────────────
→ Problem: Browser akzeptiert selbst-signiertes Zertifikat nicht
→ Lösung: User MUSS Browser-Warnung akzeptieren

WICHTIG FÜR USER:
────────────────────────────────────────────────
1. LevelDB: Automatisch behoben (Node startet mit frischer DB wenn korrupt)
2. Explorer: Browser-Warnung akzeptieren (siehe Anleitung)

