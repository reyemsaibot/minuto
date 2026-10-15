# Prüfung – UI- und Code-Härtung

Datum: 12.10.2026  
Status: **teilweise bestanden – native UI-Abnahme ungeprüft**

## Umfang

- Löschbestätigung für Zeiteinträge und Stammdaten
- Pflichtfeldhinweise im Bearbeitungsdialog
- Import-/Wiederherstellungsvorschau und Konfliktprüfung vor Bestätigung
- adaptive Filterzeile, eine zentrale Speichern-Aktion und präzisere Stammdatenvorschläge
- typisierte Bereichsnavigation, Speicherrückmeldung, Sollzeitbegrenzung und Accessibility-Beschriftungen

## Automatisiert

| Prüfung | Ergebnis |
| --- | --- |
| `./test.sh` | bestanden: Persistenztests einschließlich negativer Sollzeit |
| `./build.sh` | bestanden: `build/Minuto.app` erzeugt |
| `plutil -lint build/Minuto.app/Contents/Info.plist` | bestanden |
| `codesign --verify --deep --strict build/Minuto.app` | bestanden |
| `git diff --check` | bestanden |

## Native Bedienprüfung

Das Bundle wurde über Computer Use zur Prüfung geöffnet. Die native Accessibility-Verbindung wurde vor einer Antwort geschlossen (`Sky Computer Use native pipe closed before response`). Damit sind sichtbare Darstellung, Klicks und Tastatureingaben **ungeprüft**.

Folgende Schritte sind im Bundle manuell nachzuholen: Löschen abbrechen/bestätigen, Bearbeiten mit leeren Feldern, Importvorschau, Filter bei schmalem Fenster, `⌘N`, Leertaste und Speichernachricht.
