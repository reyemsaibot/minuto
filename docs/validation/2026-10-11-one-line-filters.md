# Validierung – einzeilige Filterleiste

- **Datum:** 11.10.2026
- **Build:** 1.5.1 (7), lokaler Entwicklungsbuild
- **Bundle:** `build/Minuto.app`
- **Änderung:** Zeitraum und Status liegen auf einer gemeinsamen Leiste, getrennt durch einen vertikalen Abstand. Die Mindestfensterbreite beträgt 1120 pt.
- **Prüfungen:** `./build.sh`, `plutil -lint`, Prüfung auf ausführbare Datei und Icon-Ressource sowie `codesign --verify --deep --strict`.
- **Ergebnis:** Build erfolgreich erstellt; UI-Sichtprüfung bleibt separat offen.
