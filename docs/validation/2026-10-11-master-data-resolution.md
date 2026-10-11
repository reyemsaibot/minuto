# Minuto – Prüfbericht Stammdatenbereinigung

Datum: 11.10.2026  
Bundle: `build/Minuto.app`

## Änderung

- Stammdaten können direkt bearbeitet werden.
- Bestehende Dubletten werden gruppiert angezeigt.
- Vor der Bereinigung wird das Abrechnungsticket gewählt, das erhalten bleibt.
- Erst nach Bestätigung werden die übrigen Dubletten gelöscht; die normale automatische Sicherung schützt den vorherigen Bestand.
- Einträge mit mehrdeutigen Stammdaten zeigen in der Liste einen sichtbaren Konflikt.
- Ein Zusammenführungsimport wird vollständig abgebrochen, wenn bestehende oder importierte Abrechnungstickets widersprüchlich sind.

## Prüfung

- `./test.sh`: **bestanden**. Enthält Konflikterkennung, konfliktfreie Zusammenführung und Ablehnung abweichender Abrechnungstickets.
- `./build.sh`: **bestanden**.
- `plutil -lint`: **bestanden**.
- `codesign --verify --deep --strict`: **bestanden**.

## Noch ungeprüft

- **NOT TESTED — ENVIRONMENT LIMITATION:** Direkte Bedienung der Bearbeitungs- und Bereinigungsdialoge im nativen Bundle. Die native Accessibility-Verbindung schließt beim Zugriff auf den Build-Pfad.
