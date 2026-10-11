import AppKit
import UniformTypeIdentifiers

@MainActor extension MinutoStore {
    func importBackup(replace: Bool) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }

        Task {
            do {
                let imported = try await repository.readImport(from: url)
                apply(imported, replace: replace)
            } catch {
                self.error = "Import fehlgeschlagen: \(Self.userMessage(for: error))"
            }
        }
    }

    func exportBackup() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Minuto-Sicherung.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let snapshot = currentSnapshot()

        Task {
            do {
                try await repository.export(snapshot, to: url)
            } catch {
                self.error = "Sicherung fehlgeschlagen: \(Self.userMessage(for: error))"
            }
        }
    }

    func exportCSV(_ selected: [TimeEntry]) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Minuto-Zeiten.csv"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "dd.MM.yyyy"
        let header = "Datum;Kunde;Projekt;Jira-Ticket;Abrechnungsticket;Dauer;Notiz\n"
        let records = selected.map { csvRecord(for: $0, dateFormatter: formatter) }.joined(separator: "\n")

        do {
            try (header + records + "\n").write(to: url, atomically: true, encoding: .utf8)
        } catch {
            self.error = "CSV-Export fehlgeschlagen: \(Self.userMessage(for: error))"
        }
    }

    func openFolder() {
        NSWorkspace.shared.open(dataFolder)
    }

    private func apply(_ imported: MinutoImport, replace: Bool) {
        if replace {
            entries = imported.snapshot.entries
            if imported.includesAllData {
                masters = imported.snapshot.masters
                dailyTarget = imported.snapshot.dailyTarget
                weekClosures = imported.snapshot.weekClosures
            }
        } else {
            var combined = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
            imported.snapshot.entries.forEach { combined[$0.id] = $0 }
            entries = Array(combined.values)

            if imported.includesAllData {
                do {
                    masters = try MasterDataRules.merged(current: masters, imported: imported.snapshot.masters)
                } catch {
                    self.error = "Import fehlgeschlagen: \(Self.userMessage(for: error))"
                    return
                }
            }
        }
        sortEntries()
        persist()
    }

    private func csvRecord(for entry: TimeEntry, dateFormatter: DateFormatter) -> String {
        [
            dateFormatter.string(from: entry.date),
            entry.customer,
            entry.project,
            entry.ticket,
            entry.billingTicket ?? billingTicket(for: entry) ?? "",
            format(entry.seconds),
            entry.note ?? ""
        ]
        .map(csvField)
        .joined(separator: ";")
    }
}
