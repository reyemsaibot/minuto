# Validierung – Hinweis für Pflichtfelder

- **Datum:** 11.10.2026
- **Build:** 1.5.2 (8), lokaler Entwicklungsbuild
- **Bundle:** `build/Minuto.app`
- **Änderung:** Beim Starten des Timers oder Speichern einer manuellen Zeit benennt eine Inline-Meldung fehlende Pflichtfelder; der Fokus geht zum ersten fehlenden Textfeld.
- **Prüfungen:** Swift-Kompilation, `plutil -lint`, Prüfung auf ausführbare Datei und Icon-Ressource sowie `codesign --verify --deep --strict`.
- **Ergebnis:** Build erfolgreich. Die Validierung verwendet die bestehenden Eingabefelder und verändert weder Datenmodell noch Speicherung.
- **Offen:** Sicht- und Klickprüfung im laufenden nativen Fenster steht noch aus.
