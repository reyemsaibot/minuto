# Projektfilter – 16.10.2026

Status: **gebaut; native UI-Abnahme ungeprüft**

## Anforderung

Die Zeiteintragsliste soll nach Projekt filterbar sein.

## Umsetzung

- Neues leeres Suchfeld „Projekt filtern“ in der Filterleiste.
- Projektname wird mit den bestehenden Kunden-, Ticket-, Notiz-, Status- und Datumsfiltern kombiniert.
- Die Suche ist nicht zwischen Groß- und Kleinschreibung unterscheidend und unterstützt Teiltexte.

## Automatisierte Prüfung

| Prüfung | Ergebnis |
| --- | --- |
| `projectFilterMatchesCaseInsensitively` | bestanden |
| `./test.sh` | bestanden |
| `./build.sh` | bestanden; Bundle: `build/Minuto.app` |
| `plutil -lint build/Minuto.app/Contents/Info.plist` | bestanden |
| `codesign --verify --deep --strict build/Minuto.app` | bestanden |
| `git diff --check` | bestanden |

## Nicht geprüft

**NOT TESTED — ENVIRONMENT LIMITATION:** Das Filterfeld und die Trefferliste müssen im gestarteten Bundle manuell geprüft werden.
