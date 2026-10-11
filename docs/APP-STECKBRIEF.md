# Minuto – App-Steckbrief

Stand: 11.10.2026

| Feld | Entscheidung |
| --- | --- |
| Produkt | **Minuto** ist eine persönliche, lokale Zeiterfassung für macOS. Sie richtet Zeiten Kunden, Projekten und Jira-Tickets zu. |
| Hauptablauf | App öffnen → Timer starten oder Zeit manuell erfassen → Einträge kontrollieren, abschließen oder als CSV exportieren. |
| Umfang | Timer, manuelle Erfassung, Stammdaten, Filter, CSV, Sicherung, Import, Kalender und Übersicht. |
| Später | Automatisierte Tests, schema-versionierte Sicherungen, Release-Signierung und Notarisierung. |
| Technik | SwiftUI und AppKit, macOS 13+, Apple Silicon Build, keine Laufzeitabhängigkeiten. |
| Identität | Bundle-ID `local.tobiasmeyer.minuto`, ausführbare Datei `Minuto`, Build unter `build/Minuto.app`. |
| Daten | `~/Library/Application Support/Minuto/`; JSON für Einträge und Stammdaten. Bestehende Daten aus `Kundenzeit` werden einmalig übernommen. |
| Bedienung | Deutsche Oberfläche; Startansicht **Zeiten**; Stammdaten, Übersicht und Datenaktionen sind getrennt. |
| Gestaltung | Ruhige native macOS-Oberfläche. Kopfzeile: Icon und App-Name links, Bereichsnavigation mittig, seltene Datenaktionen rechts. |
| Abnahme | Bundle bauen, Plist und Signatur prüfen; Navigation und Timer, manuelle Erfassung, Filter, Kalender sowie Datenmenü im gebauten Bundle testen. |

## Offene Annahmen

- Die App wird derzeit direkt aus dem lokalen Build gestartet, nicht aus einer installierten Kopie in `/Applications`.
- Der aktuelle Build richtet sich an Apple-Silicon-Macs; ein Universal- oder Intel-Build ist noch nicht vorgesehen.
