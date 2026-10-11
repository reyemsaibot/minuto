# Minuto – Prüfbericht Erfassungsfelder

Datum: 11.10.2026  
Bundle: `build/Minuto.app`

## Änderung

- Kunde, Projekt und Jira-Ticket haben in der Erfassung dauerhaft sichtbare Beschriftungen.
- Das manuelle Datum ist ein linksbündiger Eingabeblock mit eigener Beschriftung.

## Prüfung

- `./test.sh`: **bestanden**.
- `./build.sh`: **bestanden**.
- `plutil -lint`: **bestanden**.
- `codesign --verify --deep --strict`: **bestanden**.
- `git diff --check`: **bestanden**.

## Noch ungeprüft

- **NOT TESTED — ENVIRONMENT LIMITATION:** Sichtprüfung im nativen App-Fenster; die native Accessibility-Verbindung zum Bundlepfad ist nicht verfügbar.
