# Minuto

Minuto ist eine lokale, native Zeiterfassung für macOS. Sie ordnet Zeiten Kunden, Projekten und Jira-Tickets zu; Abrechnungstickets werden über Stammdaten beim Abschließen ergänzt. Die App benötigt weder Anmeldung noch Internetverbindung.

## Funktionen

- Timer und manuelle Erfassung mit Datum, Dauer und optionaler Notiz
- Manuelle Buchungen auch bei laufendem Timer
- Kunde → Projekt → Abrechnungsticket als eindeutige Stammdatenzuordnung
- Favoriten, archivierte Projekte und Vorschläge aus Stammdaten
- Einträge bearbeiten, duplizieren, abschließen, wieder öffnen und löschen
- Filter für Kunde, Jira-Ticket, Notiz, Status und lokalen Datumsbereich
- CSV-Export der aktuell gefilterten Einträge
- Versionierte JSON-Sicherungen, Import und Wiederherstellung
- Automatische Sicherung vor jeder gespeicherten Änderung, Aufbewahrung der letzten 30 Sicherungen
- Tages- und Wochenübersicht, Sollzeit, Kalender, Kennzahlen und persistenter Wochenabschluss
- Native SwiftUI-Oberfläche ohne Web- oder JavaScript-Runtime

## Installation

Die gebaute App liegt unter `build/Minuto.app`.

1. `Minuto.app` in den Ordner **Programme** kopieren.
2. Per Doppelklick starten.
3. Falls macOS den ersten Start blockiert: Im Finder bei gedrückter `ctrl`-Taste auf die App klicken und **Öffnen** wählen.

Minuto ist lokal signiert, wird aber nicht über den Mac App Store verteilt.

## Zeiten erfassen

### Timer

1. Kunde, Projekt und Jira-Ticket eingeben oder eine Stammdatenzuordnung übernehmen.
2. Optional eine Notiz ergänzen.
3. **Timer starten** wählen.
4. Zum Ende der Arbeit **Stoppen & speichern** wählen.

Der Timer basiert auf dem gespeicherten Startzeitpunkt und läuft auch bei geschlossenem Fenster weiter. Während er läuft, lassen sich über **Manuell** weitere Zeiten buchen. Ein Timer, der über Mitternacht läuft, bleibt derzeit dem Datum seines Starts zugeordnet.

### Manuelle Erfassung

1. Zu **Manuell** wechseln.
2. Kunde, Projekt, Jira-Ticket und Dauer eintragen.
3. Das Datum ist automatisch auf heute gesetzt und kann geändert werden.
4. Notiz optional ergänzen und speichern.

## Stammdaten und Abrechnung

Unter **Stammdaten** werden Zuordnungen aus Kunde, Projekt und Abrechnungsticket hinterlegt.

- Eine Kunde/Projekt-Kombination kann nur einmal gespeichert werden und lässt sich direkt bearbeiten.
- Historische Dubletten werden klar markiert. Beim Bereinigen wird das zu behaltende Abrechnungsticket ausgewählt und die Löschung der anderen Einträge bestätigt.
- Aktive Zuordnungen werden während der Erfassung vorgeschlagen.
- Ein Stern markiert häufig verwendete Zuordnungen als Favorit.
- Archivierte Projekte können wieder aktiviert werden.
- Beim Abschließen wird ein passendes Abrechnungsticket automatisch übernommen.
- Fehlt ein Abrechnungsticket, lässt sich der Eintrag trotzdem abschließen.

Das Jira-Ticket gehört zum Zeiteintrag. Das Abrechnungsticket ist ein separates Feld für die spätere Abrechnung.

## Einträge und Übersicht

Die Liste zeigt offene, archivierte oder alle Einträge. Der CSV-Export verwendet immer genau die gefilterte Datenmenge. Die Datumsfilter schließen den ausgewählten Bis-Tag vollständig ein.

Die Übersicht enthält Tages- und Wochenstunden, Sollzeit, Kennzahlen, einen Monatskalender und den Wochenabschluss. Ein abgeschlossener Wochenstand enthält Zeitpunkt, Anzahl und Summe der zu diesem Zeitpunkt vorhandenen Einträge; er bleibt nach einem Neustart erhalten.

Tastaturkürzel:

- `⌘N` – manuelle Erfassung öffnen
- `Leertaste` – Timer starten
- `⌘1` – Zeiten
- `⌘2` – Übersicht
- `⌘3` – Stammdaten

## Daten, Sicherung und Wiederherstellung

Minuto speichert alle persönlichen Daten lokal unter:

```text
~/Library/Application Support/Minuto/
```

Wichtige Dateien:

- `minuto.json` – versionierter Gesamtbestand mit Einträgen, Stammdaten, Sollzeit und Wochenabschlüssen
- `Sicherungen/` – automatische Sicherungen vor Änderungen; die letzten 30 Versionen bleiben erhalten
- `zeiten.json` und `stammdaten.json` – frühere Datenformate, die beim ersten Start geprüft und in den Gesamtbestand migriert werden

Über **Daten** stehen diese Funktionen bereit:

- **Sicherung exportieren** erzeugt eine vollständige portable JSON-Sicherung.
- **Einträge importieren und zusammenführen** übernimmt Zeiteinträge und fügt neue Stammdaten hinzu. Widersprüchliche Abrechnungstickets für dieselbe Kunde/Projekt-Zuordnung brechen den Import ab.
- **Einträge wiederherstellen** ersetzt den Zeitbestand; bei vollständigen Minuto-Sicherungen werden auch Stammdaten, Sollzeit und Wochenabschlüsse wiederhergestellt.
- **Datenordner öffnen** öffnet den Speicherort im Finder.

Importdateien werden vor der Übernahme vollständig gelesen und validiert. Vor der resultierenden Änderung legt Minuto eine automatische Sicherung des bisherigen Gesamtbestands an.

## Entwicklung

### Voraussetzungen

- macOS 13 oder neuer
- Xcode Command Line Tools
- Apple Silicon für den gegenwärtigen lokalen Build

### Build und Tests

```bash
./test.sh
./build.sh
```

`test.sh` prüft Migration, Sicherungen, doppelte Stammdaten und Datumsgrenzen. `build.sh` erzeugt `build/Minuto.app`, bindet Icon und Metadaten ein und signiert lokal ad hoc. Der GitHub-Workflow führt Tests, Build, Plist- und Signaturprüfung bei Pushes und Pull Requests aus.

## Projektstruktur

```text
Sources/Models.swift                Datenmodelle und Sicherungsformat
Sources/MinutoDomain.swift          fachliche Datums- und Timerregeln
Sources/MinutoPersistence.swift     lokale Speicherung, Migration und Sicherungen
Sources/MinutoStore.swift           gemeinsamer UI-Status und Persistenzkoordination
Sources/Store/                      getrennte Store-Bereiche für Einträge, Stammdaten, Transfer und Übersicht
Sources/Views/Time/                 Erfassung, Liste/Filter und Bearbeitungsdialog
Sources/Views/                      übrige SwiftUI-Ansichten
Tests/                              ausführbare Persistenztests
.github/workflows/verify.yml        CI-Prüfung
Minuto.icns                         App-Icon für Finder und Dock
Info.plist                          macOS-App-Metadaten
build.sh                            lokaler macOS-Build
test.sh                             lokaler Testlauf
```

## Datenschutz und Release-Status

Minuto verarbeitet Daten ausschließlich lokal. Es gibt keine Anmeldung, Cloud-Synchronisierung oder Telemetrie.

Der Build ist ad hoc signiert. Eine Developer-ID-Signatur, Notarisierung und ein Release-Prozess für externe Macs sind noch nicht eingerichtet.
