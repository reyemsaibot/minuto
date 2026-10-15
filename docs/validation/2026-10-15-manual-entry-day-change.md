# Prüfung – manueller Eintrag nach Tageswechsel

Datum: 15.10.2026  
Status: **implementiert – native Mitternachtsprüfung ungeprüft**

## Fehlerbild und Ursache

Eine offene Erfassungsansicht konnte nach Mitternacht den bisherigen Standardwert im DatePicker behalten. Das Datum wurde nicht aktualisiert, wenn der Nutzer danach erst auf **Manuell** wechselte.

## Korrektur

- Standarddatum ist der Beginn des aktuellen lokalen Kalendertags.
- Beim Wechsel auf **Manuell** und beim macOS-Ereignis zum Tageswechsel wird nur dieser Standard aktualisiert.
- Ein vom Nutzer gewähltes Datum bleibt für rückwirkende Buchungen erhalten.

## Automatisierte Prüfung

| Prüfung | Ergebnis |
| --- | --- |
| Berliner Tageswechsel 14.10.2026 23:59 → 15.10.2026 00:01 | bestanden |
| Bewusst gewähltes Buchungsdatum bleibt erhalten | bestanden |
| `./test.sh` | bestanden |
| `./build.sh` | bestanden |
| Plist- und Signaturprüfung | bestanden |

## Offen

Ein echter Tageswechsel mit offener manueller Erfassung im nativen Bundle ist **ungeprüft**, weil dafür keine zuverlässige native UI-Automation verfügbar war.
