import AppKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor final class MinutoStore: ObservableObject {
    @Published var entries: [TimeEntry] = []
    @Published var masters: [MasterData] = []
    @Published var weekClosures: [WeekClosure] = []
    @Published var dailyTarget = 8.0 { didSet { if !isLoading { persist() } } }
    @Published var error: String?
    @Published private(set) var isLoading = true

    private let repository: MinutoRepository
    private let dataFolder: URL

    init(folder: URL? = nil, legacyFolder: URL? = nil) {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let current = folder ?? support.appendingPathComponent("Minuto")
        let legacy = legacyFolder ?? support.appendingPathComponent("Kundenzeit")
        dataFolder = current
        repository = MinutoRepository(folder: current, legacyFolder: legacy)
        let migratedTarget = UserDefaults.standard.object(forKey: "dailyTarget") as? Double ?? 8
        Task { await load(defaultDailyTarget: migratedTarget) }
    }

    func add(_ entry: TimeEntry) { entries.append(entry); sort(); persist() }
    func update(_ entry: TimeEntry) { guard let i = entries.firstIndex(where: { $0.id == entry.id }) else { return }; entries[i] = entry; sort(); persist() }
    func delete(_ entry: TimeEntry) { entries.removeAll { $0.id == entry.id }; persist() }
    func stop(_ entry: TimeEntry) {
        guard let i = entries.firstIndex(where: { $0.id == entry.id }), let start = entries[i].startedAt else { return }
        entries[i].seconds = max(1, Int(Date().timeIntervalSince(start)))
        entries[i].startedAt = nil
        persist()
    }
    func close(_ entry: TimeEntry) {
        guard let i = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[i].billed = true
        entries[i].billingTicket = entry.billingTicket ?? billingTicket(for: entry)
        persist()
    }
    func reopen(_ entry: TimeEntry) { guard let i = entries.firstIndex(where: { $0.id == entry.id }) else { return }; entries[i].billed = false; persist() }

    func addMaster(customer: String, project: String, billingTicket: String) {
        let master = MasterData(id: UUID(), customer: customer.trimmingCharacters(in: .whitespacesAndNewlines), project: project.trimmingCharacters(in: .whitespacesAndNewlines), billingTicket: billingTicket.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !master.customer.isEmpty, !master.project.isEmpty, !master.billingTicket.isEmpty else { error = "Bitte Kunde, Projekt und Abrechnungsticket ausfüllen."; return }
        guard !masters.contains(where: { $0.normalizedKey == master.normalizedKey }) else { error = "Für \(master.customer) · \(master.project) existieren bereits Stammdaten."; return }
        masters.append(master)
        persist()
    }

    func updateMaster(_ master: MasterData) {
        guard let index = masters.firstIndex(where: { $0.id == master.id }) else { return }
        guard !masters.enumerated().contains(where: { $0.offset != index && $0.element.normalizedKey == master.normalizedKey }) else { error = "Für \(master.customer) · \(master.project) existieren bereits Stammdaten."; return }
        masters[index] = master
        persist()
    }

    func deleteMaster(_ master: MasterData) { masters.removeAll { $0.id == master.id }; persist() }

    func importBackup(replace: Bool) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task {
            do {
                let imported = try await repository.readImport(from: url)
                apply(imported, replace: replace)
            } catch { self.error = "Import fehlgeschlagen: \(Self.userMessage(for: error))" }
        }
    }

    func exportBackup() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Minuto-Sicherung.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let snapshot = currentSnapshot()
        Task {
            do { try await repository.export(snapshot, to: url) }
            catch { self.error = "Sicherung fehlgeschlagen: \(Self.userMessage(for: error))" }
        }
    }

    func exportCSV(_ selected: [TimeEntry]) {
        let panel = NSSavePanel(); panel.nameFieldStringValue = "Minuto-Zeiten.csv"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "de_DE"); formatter.dateFormat = "dd.MM.yyyy"
        let header = "Datum;Kunde;Projekt;Jira-Ticket;Abrechnungsticket;Dauer;Notiz\n"
        let records = selected.map { entry in [formatter.string(from: entry.date), entry.customer, entry.project, entry.ticket, entry.billingTicket ?? billingTicket(for: entry) ?? "", format(entry.seconds), entry.note ?? ""].map(csvField).joined(separator: ";") }.joined(separator: "\n")
        do { try (header + records + "\n").write(to: url, atomically: true, encoding: .utf8) }
        catch { self.error = "CSV-Export fehlgeschlagen: \(Self.userMessage(for: error))" }
    }

    func billingTicket(for entry: TimeEntry) -> String? {
        if let ticket = entry.billingTicket { return ticket }
        let key = MasterData(id: UUID(), customer: entry.customer, project: entry.project, billingTicket: "").normalizedKey
        let matches = masters.filter { $0.active && $0.normalizedKey == key }
        guard matches.count <= 1 else { return nil }
        return matches.first?.billingTicket
    }

    func isWeekClosed(for date: Date) -> Bool { weekClosures.contains { $0.weekIdentifier == Self.weekIdentifier(for: date) } }
    func toggleWeekClosure(for date: Date) {
        let identifier = Self.weekIdentifier(for: date)
        if let index = weekClosures.firstIndex(where: { $0.weekIdentifier == identifier }) { weekClosures.remove(at: index) }
        else {
            let calendar = Calendar.current
            let entriesForWeek = entries.filter { $0.startedAt == nil && calendar.isDate($0.date, equalTo: date, toGranularity: .weekOfYear) }
            weekClosures.append(WeekClosure(weekIdentifier: identifier, closedAt: Date(), entryCount: entriesForWeek.count, totalSeconds: entriesForWeek.reduce(0) { $0 + $1.seconds }))
        }
        persist()
    }

    func openFolder() { NSWorkspace.shared.open(dataFolder) }

    var activeTimer: TimeEntry? { entries.first { $0.startedAt != nil } }
    var activeMasters: [MasterData] { masters.filter(\.active).sorted { $0.customer.localizedCaseInsensitiveCompare($1.customer) == .orderedAscending } }

    private func load(defaultDailyTarget: Double) async {
        do {
            let snapshot = try await repository.load(defaultDailyTarget: defaultDailyTarget)
            entries = snapshot.entries
            masters = snapshot.masters
            dailyTarget = snapshot.dailyTarget
            weekClosures = snapshot.weekClosures
            sort()
        } catch { self.error = "Daten konnten nicht geladen werden: \(Self.userMessage(for: error))" }
        isLoading = false
    }

    private func apply(_ imported: MinutoImport, replace: Bool) {
        if replace {
            entries = imported.snapshot.entries
            if imported.includesAllData { masters = imported.snapshot.masters; dailyTarget = imported.snapshot.dailyTarget; weekClosures = imported.snapshot.weekClosures }
        } else {
            var combined = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
            imported.snapshot.entries.forEach { combined[$0.id] = $0 }
            entries = Array(combined.values)
            if imported.includesAllData {
                for master in imported.snapshot.masters where !masters.contains(where: { $0.normalizedKey == master.normalizedKey }) { masters.append(master) }
            }
        }
        sort()
        persist()
    }

    private func currentSnapshot() -> MinutoSnapshot { MinutoSnapshot(entries: entries, masters: masters, dailyTarget: dailyTarget, weekClosures: weekClosures) }
    private func persist() {
        guard !isLoading else { return }
        let snapshot = currentSnapshot()
        Task {
            do { try await repository.save(snapshot) }
            catch { self.error = "Änderung konnte nicht gesichert werden: \(Self.userMessage(for: error))" }
        }
    }
    private func sort() { entries.sort { $0.date == $1.date ? $0.id.uuidString > $1.id.uuidString : $0.date > $1.date } }
    private static func weekIdentifier(for date: Date) -> String { let c = Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date); return "\(c.yearForWeekOfYear ?? 0)-W\(String(format: "%02d", c.weekOfYear ?? 0))" }
    private static func userMessage(for error: Error) -> String { (error as? LocalizedError)?.errorDescription ?? "Bitte prüfe die gewählte Sicherungsdatei und versuche es erneut." }
}


extension Notification.Name {
    static let minutoStartManualEntry = Notification.Name("minutoStartManualEntry")
    static let minutoSelectArea = Notification.Name("minutoSelectArea")
}
