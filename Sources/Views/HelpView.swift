import SwiftUI

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Label("Hilfe", systemImage: "questionmark.circle").font(.title2.bold())
                Spacer()
                Button("Fertig") { dismiss() }.keyboardShortcut(.cancelAction)
            }

            GroupBox("Tastenkombinationen") {
                VStack(spacing: 10) {
                    ShortcutRow(keys: "⌘N", description: "Manuelle Zeiterfassung öffnen")
                    ShortcutRow(keys: "⌘1", description: "Bereich Zeiten öffnen")
                    ShortcutRow(keys: "⌘2", description: "Bereich Übersicht öffnen")
                    ShortcutRow(keys: "⌘3", description: "Bereich Stammdaten öffnen")
                    ShortcutRow(keys: "Esc", description: "Aktives Suchfeld leeren")
                    ShortcutRow(keys: "↩", description: "Änderungen im Bearbeitungsdialog speichern")
                }.padding(4)
            }

            GroupBox("Schnell arbeiten") {
                VStack(alignment: .leading, spacing: 9) {
                    HelpStep(number: "1", text: "Timer starten oder mit ⌘N eine Zeit manuell erfassen.")
                    HelpStep(number: "2", text: "Stammdaten übernehmen, um Kunde und Projekt schneller auszufüllen.")
                    HelpStep(number: "3", text: "Einträge über die Symbole bearbeiten, duplizieren oder abschließen.")
                    HelpStep(number: "4", text: "Suchfelder mit × leeren und Zeitraum oder Status direkt filtern.")
                }.padding(4)
            }

            Text("Die Daten bleiben auf diesem Mac und können über Daten gesichert oder exportiert werden.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(width: 520)
    }
}

private struct ShortcutRow: View {
    let keys: String
    let description: String

    var body: some View {
        HStack {
            Text(keys).font(.system(.body, design: .monospaced).weight(.semibold))
                .frame(width: 54, alignment: .leading)
            Text(description)
            Spacer()
        }
    }
}

private struct HelpStep: View {
    let number: String
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 9) {
            Text(number).font(.caption.bold()).foregroundStyle(.white).frame(width: 18, height: 18).background(Color.accentColor, in: Circle())
            Text(text)
        }
    }
}
