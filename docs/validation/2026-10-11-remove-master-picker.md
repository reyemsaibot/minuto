# Validierung – Stammdatenauswahl entfernt

- **Datum:** 11.10.2026
- **Build:** 1.5.3 (9), lokaler Entwicklungsbuild
- **Bundle:** `build/Minuto.app`
- **Änderung:** Der aufklappbare Bereich „Stammdaten auswählen“ wurde aus Erfassung und Bearbeitungsdialog entfernt. Die vorhandenen Stammdatenvorschläge in der Erfassung bleiben erhalten.
- **Prüfungen:** Suche nach dem entfernten View-Namen und sichtbaren Text im Quellcode, `./build.sh`, `plutil -lint`, Prüfung auf ausführbare Datei und Icon-Ressource sowie `codesign --verify --deep --strict`.
- **Ergebnis:** Build erfolgreich. Die Datenhaltung und der Stammdaten-Reiter sind unverändert.
- **Offen:** Sicht- und Klickprüfung im laufenden nativen Fenster steht noch aus.
