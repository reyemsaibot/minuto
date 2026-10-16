# Zeitenbereich: Fensterhöhe und Tagesanzeige – 16.10.2026

Status: **gebaut; native UI-Abnahme ungeprüft**

## Anforderung

- Die Zeiteintragsliste soll bei größerem Hauptfenster vertikal mitwachsen.
- Die Erfassung soll den aktuellen Wochentag sichtbar zeigen; bei manueller Erfassung auch den Wochentag des gewählten Datums.

## Umsetzung

- `TimeWorkspace` verwendet keinen äußeren vertikalen Scrollcontainer mehr. Die Erfassung behält ihre natürliche Höhe; `EntryList` erhält den verbleibenden Platz.
- Tabellen- und Container-Frames erlauben eine unbegrenzte Maximalhöhe bei einer Mindesthöhe von 320 Punkten.
- Der Erfassungsbereich zeigt „Heute“ mit Wochentag und Datum. Das manuelle Datumsfeld ergänzt seinen Wochentag.

## Automatisierte Prüfung

| Prüfung | Ergebnis |
| --- | --- |
| `./test.sh` | bestanden |
| `./build.sh` | bestanden; Bundle: `build/Minuto.app` |
| `plutil -lint build/Minuto.app/Contents/Info.plist` | bestanden |
| `codesign --verify --deep --strict build/Minuto.app` | bestanden |
| `git diff --check` | bestanden |

## Nicht geprüft

**NOT TESTED — ENVIRONMENT LIMITATION:** Die native UI-Automation konnte nicht verwendet werden. Resize, sichtbare Tagesanzeige und die Bedienung bei Mindestfenstergröße müssen im gestarteten Bundle manuell geprüft werden.
