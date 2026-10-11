import AppKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor final class MinutoStore: ObservableObject {
    @Published var entries: [TimeEntry] = []
    @Published var masters: [MasterData] = []
    @Published var dailyTarget = 8.0 { didSet { UserDefaults.standard.set(dailyTarget, forKey: "dailyTarget") } }
    @Published var error: String?
    private let folder: URL
    private var entriesURL: URL { folder.appendingPathComponent("zeiten.json") }
    private var mastersURL: URL { folder.appendingPathComponent("stammdaten.json") }

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        folder = support.appendingPathComponent("Minuto")
        let legacy = support.appendingPathComponent("Kundenzeit")
        do {
            if !FileManager.default.fileExists(atPath: folder.path), FileManager.default.fileExists(atPath: legacy.path) { try FileManager.default.copyItem(at: legacy, to: folder) }
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let loadedEntries = try Self.loadEntries(from: entriesURL)
            let loadedMasters = try Self.loadMasters(from: mastersURL)
            entries = loadedEntries.value
            masters = loadedMasters.value
            dailyTarget = UserDefaults.standard.object(forKey: "dailyTarget") as? Double ?? 8
            sort()
            if loadedEntries.migrated { try write(entries, to: entriesURL) }
            if loadedMasters.migrated { try write(masters, to: mastersURL) }
        } catch { self.error = error.localizedDescription }
    }
    private static let legacyDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    private static func loadEntries(from url: URL) throws -> (value: [TimeEntry], migrated: Bool) {
        guard FileManager.default.fileExists(atPath: url.path) else { return ([], false) }
        let data = try Data(contentsOf: url)
        if let current = try? JSONDecoder.minuto.decode([TimeEntry].self, from: data) { return (current, false) }
        let legacy = try JSONDecoder().decode([LegacyTimeEntry].self, from: data)
        return (legacy.map { item in
            TimeEntry(id: UUID(uuidString: item.id) ?? UUID(), customer: item.customer, project: item.project, ticket: item.ticket, date: legacyDateFormatter.date(from: item.date) ?? Date(), seconds: item.seconds, startedAt: item.started.map { Date(timeIntervalSince1970: $0 / 1000) }, billed: item.billed == 1, billingTicket: item.billingTicket, note: item.note)
        }, true)
    }
    private static func loadMasters(from url: URL) throws -> (value: [MasterData], migrated: Bool) {
        guard FileManager.default.fileExists(atPath: url.path) else { return ([], false) }
        let data = try Data(contentsOf: url)
        if let current = try? JSONDecoder.minuto.decode([MasterData].self, from: data) { return (current, false) }
        let legacy = try JSONDecoder().decode([LegacyMasterData].self, from: data)
        return (legacy.map { item in
            MasterData(id: UUID(uuidString: item.id) ?? UUID(), customer: item.customer, project: item.project, billingTicket: item.ticket, favorite: item.favorite == 1, active: item.active != 0)
        }, true)
    }
    private func write<T: Encodable>(_ value: T, to url: URL) throws {
        let data = try JSONEncoder.minuto.encode(value)
        try data.write(to: url, options: .atomic)
    }
    private func sort() { entries.sort { $0.date == $1.date ? $0.id.uuidString > $1.id.uuidString : $0.date > $1.date } }
    func saveEntries() { do { try write(entries, to: entriesURL) } catch { self.error = error.localizedDescription } }
    func saveMasters() { do { try write(masters, to: mastersURL) } catch { self.error = error.localizedDescription } }
    func add(_ entry: TimeEntry) { entries.append(entry); sort(); saveEntries() }
    func update(_ entry: TimeEntry) { guard let i = entries.firstIndex(where: { $0.id == entry.id }) else { return }; entries[i] = entry; sort(); saveEntries() }
    func delete(_ entry: TimeEntry) { entries.removeAll { $0.id == entry.id }; saveEntries() }
    func stop(_ entry: TimeEntry) { guard let i = entries.firstIndex(where: { $0.id == entry.id }), let start = entries[i].startedAt else { return }; entries[i].seconds = max(1, Int(Date().timeIntervalSince(start))); entries[i].startedAt = nil; saveEntries() }
    func close(_ entry: TimeEntry) { guard let i = entries.firstIndex(where: { $0.id == entry.id }) else { return }; entries[i].billed = true; entries[i].billingTicket = entry.billingTicket ?? masters.first(where: { $0.active && $0.customer == entry.customer && $0.project == entry.project })?.billingTicket; saveEntries() }
    func reopen(_ entry: TimeEntry) { guard let i = entries.firstIndex(where: { $0.id == entry.id }) else { return }; entries[i].billed = false; saveEntries() }
    func importEntries(replace: Bool) {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { let imported = try Self.loadEntries(from: url).value; if replace { entries = imported } else { var combined = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) }); imported.forEach { combined[$0.id] = $0 }; entries = Array(combined.values) }; sort(); saveEntries() } catch { self.error = "Import fehlgeschlagen: \(error.localizedDescription)" }
    }
    func export() {
        let panel = NSSavePanel(); panel.nameFieldStringValue = "Minuto-Sicherung.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try JSONEncoder.minuto.encode(entries).write(to: url) } catch { self.error = error.localizedDescription }
    }
    func exportCSV(_ selected: [TimeEntry]) {
        let panel = NSSavePanel(); panel.nameFieldStringValue = "Minuto-Zeiten.csv"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "de_DE"); formatter.dateFormat = "dd.MM.yyyy"
        let header = "Datum;Kunde;Projekt;Jira-Ticket;Abrechnungsticket;Dauer;Notiz\n"
        let records = selected.map { entry in
            [formatter.string(from: entry.date), entry.customer, entry.project, entry.ticket, entry.billingTicket ?? billingTicket(for: entry) ?? "", format(entry.seconds), entry.note ?? ""].map(csvField).joined(separator: ";")
        }.joined(separator: "\n")
        do { try (header + records + "\n").write(to: url, atomically: true, encoding: .utf8) } catch { self.error = error.localizedDescription }
    }
    func billingTicket(for entry: TimeEntry) -> String? { entry.billingTicket ?? masters.first(where: { $0.customer == entry.customer && $0.project == entry.project })?.billingTicket }
    func openFolder() { NSWorkspace.shared.open(folder) }
    var activeTimer: TimeEntry? { entries.first { $0.startedAt != nil } }
    var activeMasters: [MasterData] { masters.filter(\.active).sorted { $0.customer < $1.customer } }
}

extension JSONEncoder { static var minuto: JSONEncoder { let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601; encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; return encoder } }
extension JSONDecoder { static var minuto: JSONDecoder { let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601; return decoder } }
extension Notification.Name { static let minutoStartManualEntry = Notification.Name("minutoStartManualEntry") }
