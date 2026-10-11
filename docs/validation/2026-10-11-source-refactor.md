# Minuto – Prüfbericht Quellcode-Refactor

Datum: 11.10.2026  
Bundle: `build/Minuto.app`

## Ziel

Ohne Produkt- oder Datenformatänderung wurden große Sammeldateien in fachlich getrennte Swift-Dateien überführt.

## Struktur nach dem Refactor

- `Sources/MinutoStore.swift`: gemeinsamer UI-Zustand, Laden und persistenter Snapshot.
- `Sources/Store/`: Einträge, Stammdaten, Datentransfer und Wochenübersicht.
- `Sources/Views/Time/`: Erfassung, Eintragsliste mit Filtern und Bearbeitungsdialog.
- `Sources/Support/Presentation.swift`: gemeinsame Darstellungshilfen.

## Bewusst unverändert

- Datenformat und Schema-Version.
- Speicherorte, Sicherungs- und Migrationsablauf.
- Timer-Regel, manuelle Erfassung, Filtergrenzen und CSV-Spalten.
- Tastaturkürzel, Stammdatenbereinigung, Import- und Wiederherstellungsverhalten.

## Prüfung

- Quellvergleich der vorherigen Zeiterfassungsansicht gegen die drei neuen Ansichten: alle bestehenden Ansichten und Aktionen vorhanden.
- `./test.sh`: **bestanden**.
- `./build.sh`: **bestanden**.
- `plutil -lint`: **bestanden**.
- Ausführbare Datei und Icon-Ressource: **vorhanden**.
- `codesign --verify --deep --strict`: **bestanden**.
- `git diff --check`: **bestanden**.

## Noch ungeprüft

- **NOT TESTED — ENVIRONMENT LIMITATION:** Native Klick-Abnahme im fertigen Bundle, insbesondere Eintragseditor, Timer, Filter und Stammdatenbereinigung. Die native Accessibility-Verbindung zum Bundlepfad ist in dieser Umgebung nicht verfügbar.
