# Validierung – Filterlayout und Quellcode-Aufteilung

- **Datum:** 11.10.2026
- **Build:** 1.5 (6), lokaler Entwicklungsbuild
- **Bundle:** `build/Minuto.app`
- **Änderung:** Die Filter für Zeitraum und Status sind über eine gemeinsame Labelspalte ausgerichtet. Die App ist in Modell, Store, Support und Ansichten aufgeteilt.
- **Prüfungen:** `./build.sh`, `plutil -lint`, Prüfung auf ausführbare Datei und Icon-Ressource sowie `codesign --verify --deep --strict`.
- **Ergebnis:** Der Build wurde erfolgreich erstellt und signiert. Die Umstellung verändert keine Datenpfade, Datenmodelle oder Migrationslogik.
- **Offen:** Sicht- und Klickprüfung im nativen Fenster steht aus; für diesen Build war keine funktionierende UI-Automation verfügbar.
