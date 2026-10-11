# Minuto – Prüfbericht Datenintegrität und Review-Maßnahmen

Datum: 11.10.2026  
Build: 1.6.0 (10)  
Bundle: `build/Minuto.app`  
Architektur: Apple Silicon Build auf dem lokalen Entwicklungs-Mac

## Automatisierte Prüfungen

- `./test.sh`: **bestanden**. Prüft Migration aus einem teilweise vorhandenen Datenordner, vollständige automatische Sicherungen, Ablehnung doppelter Stammdaten und inklusive lokale Datumsgrenzen.
- `./build.sh`: **bestanden**.
- `plutil -lint build/Minuto.app/Contents/Info.plist`: **bestanden**.
- `codesign --verify --deep --strict build/Minuto.app`: **bestanden**.

## Prüfumfang

- Vollständige Sicherung enthält Zeiteinträge, Stammdaten, Sollzeit und Wochenabschlüsse.
- Vor jeder gespeicherten Änderung wird der vorherige Gesamtbestand gesichert; maximal 30 Sicherungen bleiben erhalten.
- Neue doppelte Kunde/Projekt-Kombinationen werden abgewiesen.
- Wochenabschlüsse werden im Gesamtbestand persistiert.
- Dateifunktionen laufen im Repository-Actor außerhalb des MainActor.

## Noch ungeprüft

- **NOT TESTED — ENVIRONMENT LIMITATION:** Der exakte Bundlepfad wurde gestartet, aber die native Accessibility-Verbindung schloss beim Auslesen der Oberfläche. Navigation, Tastaturkürzel, Einträge, Dialoge und Fenstergrößen konnten deshalb nicht automatisiert bedient werden.
- **NOT TESTED — ENVIRONMENT LIMITATION:** Finder-, Dock- und `⌘Tab`-Icon am tatsächlich gestarteten Bundle.
- GitHub Actions nach dem Push.
- Notarisierung und zweiter Mac.
