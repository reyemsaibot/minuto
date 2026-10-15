# Review und UI-Abnahme – 15.10.2026

Status: **Code Review bestanden; native UI-Abnahme ungeprüft**

## Selbstreview des aktuellen Arbeitsstands

Geprüft wurden Persistenz, Sicherung, Import/Wiederherstellung, Navigation,
Zeitformular, Tabellenansicht und die neuen Löschdialoge.

| Befund | Korrektur | Status |
| --- | --- | --- |
| Entprelltes Speichern konnte beim sofortigen Beenden noch ausstehen. | AppKit-Lifecycle hält das Beenden an und schreibt den aktuellen Snapshot mit `flushPendingSave()`. | gebaut, UI-Ablauf ungeprüft |
| Tabellenzellen begrenzten Inhalte weiter auf eine Zeile. | `lineLimit(1)` entfernt; Zellen können vertikal wachsen, Tabelle bleibt horizontal scrollbar. | gebaut, sichtbare Darstellung ungeprüft |

## Automatisierte Prüfung

| Prüfung | Ergebnis |
| --- | --- |
| `./test.sh` | bestanden |
| `./build.sh` | bestanden; Bundle: `build/Minuto.app` |
| `plutil -lint build/Minuto.app/Contents/Info.plist` | bestanden |
| `codesign --verify --deep --strict build/Minuto.app` | bestanden |
| `git diff --check` | bestanden |

## Native UI-Abnahme

Der Zugriff auf den gestarteten Build wurde erneut über Computer Use versucht.
Die native Pipe schloss vor dem ersten Accessibility-Snapshot (`Sky Computer Use
native pipe closed before response`). Deshalb wurden keine Klicks, Shortcuts,
Resize- oder Beendigungsabläufe als bestanden markiert.

## Offene manuelle Abnahme

- Tabelle bei langem Kunde/Projekt, kleiner und großer Fensterbreite
- `⌘N`, Leertaste, Bereichswechsel und Löschen abbrechen/bestätigen
- Importvorschau und Wiederherstellung mit synthetischer Sicherung
- Änderung vor dem Beenden und Neustart: letzte Änderung ist erhalten
- offene manuelle Erfassung über einen Tageswechsel
