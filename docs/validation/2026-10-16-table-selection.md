# Tabellen-Auswahl – 16.10.2026

Status: **gebaut; native UI-Abnahme ungeprüft**

## Anforderung

Zeiteinträge in der Liste markieren können.

## Umsetzung

- Die Tabelle verwendet eine native Mehrfachauswahl über die stabilen UUIDs der Einträge.
- Die Anzahl der aktuell sichtbaren ausgewählten Einträge wird oberhalb der Tabelle angezeigt.
- Es gibt keine Zwischenablage-Funktion, keinen Kopierbutton und kein zusätzliches Kontextmenü.

## Automatisierte Prüfung

| Prüfung | Ergebnis |
| --- | --- |
| `./test.sh` | bestanden |
| `./build.sh` | bestanden; Bundle: `build/Minuto.app` |
| `plutil -lint build/Minuto.app/Contents/Info.plist` | bestanden |
| `codesign --verify --deep --strict build/Minuto.app` | bestanden |
| `git diff --check` | bestanden |

## Nicht geprüft

**NOT TESTED — ENVIRONMENT LIMITATION:** Auswahlmarkierung und Mehrfachauswahl müssen im gestarteten Bundle geprüft werden.
