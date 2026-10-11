# Minuto – App-Steckbrief

Stand: 11.10.2026

| Feld | Entscheidung |
| --- | --- |
| Produkt | **Minuto** ist eine persönliche, lokale Zeiterfassung für macOS. Sie ordnet Zeiten Kunden, Projekten und Jira-Tickets zu. |
| Hauptablauf | App öffnen → Timer starten oder Zeit manuell erfassen → Einträge kontrollieren, abschließen oder als CSV exportieren. |
| Umfang | Timer, manuelle Erfassung, eindeutige Stammdaten, Filter, CSV, vollständige Sicherung/Wiederherstellung, Kalender, Kennzahlen und persistenter Wochenabschluss. |
| Spätere Etappen | Importvorschau, Stammdaten-Bearbeitung, Entscheidung über Timer an Mitternacht, Release-Signierung und Notarisierung. |
| Technik | SwiftUI und AppKit, macOS 13+, Apple-Silicon-Build, keine Laufzeitabhängigkeiten. Datenmodell, Fachregeln, Persistenz, Store-Bereiche und Ansichten sind getrennt. |
| Identität | Bundle-ID `local.tobiasmeyer.minuto`, ausführbare Datei `Minuto`, Build unter `build/Minuto.app`. |
| Daten | `~/Library/Application Support/Minuto/minuto.json`, Schema 1; vollständiger Export/Import als JSON; automatische Sicherungen unter `Sicherungen/`; Migration aus `Kundenzeit` und früheren Einzeldateien. |
| Bedienung | Deutsche Oberfläche; Startansicht **Zeiten**; Bereiche Zeiten, Übersicht und Stammdaten über Kopfzeile oder `⌘1–3`; manuelle Erfassung mit `⌘N`; Timerstart mit Leertaste. |
| Gestaltung | Ruhige native macOS-Oberfläche. Kopfzeile: Icon und App-Name links, Bereichsnavigation mittig, seltene Datenaktionen rechts. |
| Timerregel | Timer verwendet den gespeicherten Startzeitpunkt; ein Timer über Mitternacht bleibt beim Startdatum, bis eine andere Regel beschlossen wird. |
| Abnahme | Tests für Persistenz, Migration und Datumsfilter; Bundle bauen, Plist und Signatur prüfen; anschließend Navigation, Timer, manuelle Erfassung, Filter, Kalender, Datenmenü und Dock im fertigen Bundle prüfen. |
