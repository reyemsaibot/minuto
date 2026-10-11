# Minuto – Prüfbericht Tastaturkürzel

Datum: 11.10.2026  
Bundle: `build/Minuto.app`

## Änderung

- `⌘N` ersetzt den Standardbereich `newItem` vollständig und öffnet die manuelle Zeiterfassung, ohne gleichzeitig ein neues Fenster anzufordern.
- Der sichtbare Button **Timer starten** ist mit der Leertaste verknüpft.

## Prüfung

- `./test.sh`: **bestanden**.
- `./build.sh`: **bestanden**.
- `plutil -lint`: **bestanden**.
- `codesign --verify --deep --strict`: **bestanden**.
- Quellprüfung: `CommandGroup(replacing: .newItem)` und `keyboardShortcut(" ", modifiers: [])` vorhanden.

## Noch ungeprüft

- **NOT TESTED — ENVIRONMENT LIMITATION:** Echte Tastatureingaben im gestarteten Bundle. Die native Accessibility-Verbindung zum Bundlepfad ist in dieser Umgebung nicht verfügbar.
