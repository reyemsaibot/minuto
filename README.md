# Minuto

Minuto ist eine lokale macOS-App zur persönlichen Zeiterfassung. Zeiten werden Kunden, Projekten und Jira-Tickets zugeordnet und für die spätere Abrechnung vorbereitet. Die App benötigt weder Benutzerkonto noch Internetverbindung.

## Funktionen

- Timer sowie manuelle Erfassung mit Datum, Dauer und optionaler Notiz
- Manuelle Buchungen auch bei laufendem Timer
- Kunden, Projekte, Jira-Tickets und Abrechnungstickets
- Stammdaten für `Kunde → Projekt → Abrechnungsticket`
- Favoriten und archivierte Projekte
- Einträge bearbeiten, duplizieren, abschließen und löschen
- Filter für Kunde, Jira-Ticket, Notiz und Zeitraum
- CSV-Export der aktuell gefilterten Einträge
- JSON-Datensicherung, Import und Wiederherstellung
- Tages- und Wochenübersicht mit konfigurierbarer Sollzeit
- Kalender, Kennzahlen und Wochenabschluss
- Lokale Erinnerung für Arbeitstage ohne Zeiterfassung

## Installation

Die gebaute App liegt unter `build/Minuto.app`.

1. `Minuto.app` in den Ordner **Programme** kopieren.
2. Per Doppelklick starten.
3. Falls macOS den ersten Start blockiert: Im Finder bei gedrückter `ctrl`-Taste auf die App klicken und **Öffnen** wählen.

Minuto ist lokal signiert, wird aber nicht über den Mac App Store verteilt.

## Zeiten erfassen

### Timer

1. Kunde, Projekt und Jira-Ticket eingeben oder aus den Vorschlägen wählen.
2. Optional eine Notiz ergänzen.
3. **Timer starten** wählen.
4. Zum Ende der Arbeit **Stoppen & speichern** wählen.

Der Timer läuft auch bei geschlossenem Fenster weiter. Während er läuft, lassen sich über den Reiter **Manuell** weitere Zeiten buchen.

### Manuelle Erfassung

1. Zum Reiter **Manuell** wechseln.
2. Kunde, Projekt, Jira-Ticket und Dauer eintragen.
3. Das Datum wird automatisch auf den heutigen Tag gesetzt und kann geändert werden.
4. Notiz optional ergänzen und speichern.

## Stammdaten und Abrechnung

Unter **Stammdaten verwalten** werden Zuordnungen aus Kunde, Projekt und Abrechnungsticket hinterlegt.

- Aktive Kunden und Projekte werden bei der Erfassung vorgeschlagen.
- Ein Stern markiert häufig verwendete Zuordnungen als Favorit.
- Das Status-Symbol archiviert Projekte; archivierte Projekte können wieder aktiviert werden.
- Beim Abschließen wird ein passendes Abrechnungsticket automatisch übernommen.
- Fehlt eine Zuordnung, kann der Eintrag dennoch abgeschlossen werden.

Das **Jira-Ticket** gehört zum Zeiteintrag. Das **Abrechnungsticket** ist ein separates Feld für die spätere Abrechnung.

## Einträge verwalten

Die Listenansichten sind:

- **Offen** – noch nicht abgeschlossene Einträge
- **Archiv** – abgeschlossene Einträge
- **Alle** – vollständiger Bestand

Aktionen für offene Einträge:

- `⧉` als Vorlage duplizieren
- Stift: bearbeiten
- Haken: abschließen
- Papierkorb: löschen

Der CSV-Export berücksichtigt immer die aktuell gesetzten Filter.

## Übersicht

Der Reiter **Übersicht** enthält Tages- und Wochenstunden, die Sollzeit pro Tag, Kennzahlen nach Kunde und Projekt, einen Monatskalender und den Wochenabschluss.

Tastaturkürzel:

- `N` – manuelle Erfassung öffnen
- Leertaste – Timer-Modus öffnen

## Daten, Sicherung und Wiederherstellung

Minuto speichert alle persönlichen Daten lokal unter:

```text
~/Library/Application Support/Kundenzeit/
```

Wichtige Dateien:

- `zeiten.json` – Zeiteinträge
- `stammdaten.json` – Stammdaten
- `Sicherungen/` – automatische Sicherungen vor Änderungen

Über die Fußzeile stehen diese Funktionen bereit:

- **Datensicherung** exportiert den aktuellen Zeitbestand als JSON-Datei.
- **Importieren** führt JSON-Zeiteinträge mit dem vorhandenen Bestand zusammen.
- **Wiederherstellen** ersetzt den Zeitbestand nach Bestätigung durch eine JSON-Sicherung.
- **Datenordner** öffnet den lokalen Speicherort im Finder.

Vor Import und Wiederherstellung wird automatisch eine Sicherung angelegt.

## Entwicklung

### Voraussetzungen

- macOS 13 oder neuer
- Xcode Command Line Tools
- Node.js

### Build

```bash
./build.sh
```

Das Build-Skript installiert Abhängigkeiten, baut die Weboberfläche, kompiliert den nativen Swift-Host, führt einen Selbsttest aus und erstellt `build/Minuto.app`.

### Selbsttest

```bash
build/Minuto.app/Contents/MacOS/Minuto --self-test
```

Der Selbsttest nutzt einen eigenen temporären Ordner und verändert keine persönlichen Daten.

## Projektstruktur

```text
src/             React-Oberfläche
components/      UI-Komponenten
main.swift       Datenhaltung und macOS-WebKit-Host
assets/          Icon-Quellen
build.sh         lokaler macOS-Build
```

## Datenschutz

Minuto verarbeitet Daten ausschließlich lokal. Es gibt keine Anmeldung, keine Cloud-Synchronisierung und keine Telemetrie.
