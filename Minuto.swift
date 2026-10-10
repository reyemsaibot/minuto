import SwiftUI
import AppKit

struct TimeEntry: Codable, Identifiable, Hashable {
    var id: UUID
    var customer: String
    var project: String
    var ticket: String
    var date: Date
    var seconds: Int
    var startedAt: Date?
    var billed: Bool
    var billingTicket: String?
    var note: String?
}

struct MasterData: Codable, Identifiable, Hashable {
    var id: UUID
    var customer: String
    var project: String
    var billingTicket: String
    var favorite = false
    var active = true
}

private struct LegacyTimeEntry: Codable {
    let id: String
    let customer: String
    let project: String
    let ticket: String
    let date: String
    let seconds: Int
    let started: Double?
    let billed: Int
    let billingTicket: String?
    let note: String?
}

private struct LegacyMasterData: Codable {
    let id: String
    let customer: String
    let project: String
    let ticket: String
    let favorite: Int?
    let active: Int?
}

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

@main struct MinutoApp: App {
    @StateObject private var store = MinutoStore()
    var body: some Scene { WindowGroup { RootView().environmentObject(store).frame(minWidth: 980, minHeight: 700) }.windowStyle(.titleBar) }
}

struct RootView: View {
    @EnvironmentObject private var store: MinutoStore
    @State private var selection = 0
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("Bereich", selection: $selection) { Text("Zeiten").tag(0); Text("Übersicht").tag(1) }.pickerStyle(.segmented).frame(width: 240)
                Spacer()
                Menu("Daten") {
                    Button("Sicherung exportieren") { store.export() }
                    Button("Einträge importieren und zusammenführen") { store.importEntries(replace: false) }
                    Button("Einträge wiederherstellen") { store.importEntries(replace: true) }
                    Divider()
                    Button("Datenordner öffnen") { store.openFolder() }
                }
            }.padding()
            Divider()
            if selection == 0 { TimeWorkspace() } else { OverviewView() }
        }.alert("Minuto", isPresented: .constant(store.error != nil), actions: { Button("OK") { store.error = nil } }, message: { Text(store.error ?? "") })
    }
}

struct TimeWorkspace: View {
    @EnvironmentObject private var store: MinutoStore
    var body: some View { ScrollView { VStack(alignment: .leading, spacing: 18) { TimeEntryForm(); MasterDataView(); EntryList() }.padding(24) } }
}

struct TimeEntryForm: View {
    @EnvironmentObject private var store: MinutoStore
    @State private var manual = false
    @State private var customer = ""
    @State private var project = ""
    @State private var ticket = ""
    @State private var note = ""
    @State private var minutes = 60.0
    @State private var date = Date()
    var body: some View {
        GroupBox { VStack(alignment: .leading, spacing: 14) {
            HStack { Picker("Art", selection: $manual) { Text("Timer").tag(false); Text("Manuell").tag(true) }.pickerStyle(.segmented).frame(width: 200); Spacer(); if let active = store.activeTimer { TimerText(start: active.startedAt!) } }
            if let active = store.activeTimer { HStack { VStack(alignment: .leading) { Text(active.customer).font(.headline); Text("\(active.project) · \(active.ticket)").foregroundStyle(.secondary) }; Spacer(); Button("Stoppen & speichern") { store.stop(active) }.buttonStyle(.borderedProminent) } }
            Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                GridRow { TextField("Kunde", text: $customer); TextField("Projekt", text: $project); TextField("Jira-Ticket", text: $ticket) }
                if manual { GridRow { DatePicker("Datum", selection: $date, displayedComponents: .date); TextField("Minuten", value: $minutes, format: .number); Button("Zeit speichern") { save() }.buttonStyle(.borderedProminent) } }
                else { GridRow { TextField("Notiz (optional)", text: $note); Button("Timer starten") { start() }.buttonStyle(.borderedProminent); EmptyView() } }
            }
            if manual { TextField("Notiz (optional)", text: $note); HStack { Spacer(); Button("Zeit speichern") { save() }.buttonStyle(.borderedProminent) } }
            if !store.activeMasters.isEmpty { Menu("Stammdaten übernehmen") { ForEach(store.activeMasters) { master in Button("\(master.favorite ? "★ " : "")\(master.customer) · \(master.project)") { customer = master.customer; project = master.project } } } }
        }.padding(4) } label: { Text("Zeiten erfassen").font(.headline) }
    }
    private func start() { guard !customer.isEmpty, !project.isEmpty, !ticket.isEmpty, store.activeTimer == nil else { return }; store.add(TimeEntry(id: UUID(), customer: customer, project: project, ticket: ticket, date: Date(), seconds: 0, startedAt: Date(), billed: false, billingTicket: nil, note: note.nilIfEmpty)); reset() }
    private func save() { guard !customer.isEmpty, !project.isEmpty, !ticket.isEmpty, minutes > 0 else { return }; store.add(TimeEntry(id: UUID(), customer: customer, project: project, ticket: ticket, date: date, seconds: Int(minutes * 60), startedAt: nil, billed: false, billingTicket: nil, note: note.nilIfEmpty)); reset() }
    private func reset() { customer = ""; project = ""; ticket = ""; note = ""; minutes = 60; date = Date() }
}

struct EntryList: View {
    @EnvironmentObject private var store: MinutoStore
    @State private var status = 0
    @State private var customer = ""
    @State private var ticket = ""
    @State private var note = ""
    @State private var from = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
    @State private var to = Date()
    var rows: [TimeEntry] { store.entries.filter { e in (status == 2 || (status == 0 ? !e.billed : e.billed)) && (customer.isEmpty || e.customer.localizedCaseInsensitiveContains(customer)) && (ticket.isEmpty || e.ticket.localizedCaseInsensitiveContains(ticket)) && (note.isEmpty || (e.note ?? "").localizedCaseInsensitiveContains(note)) && e.date >= Calendar.current.startOfDay(for: from) && e.date <= Calendar.current.date(byAdding: .day, value: 1, to: to)! } }
    var body: some View { GroupBox("Zeiteinträge") { VStack(alignment: .leading) {
        HStack { TextField("Kunde filtern", text: $customer); TextField("Jira-Ticket", text: $ticket); TextField("Notiz", text: $note); DatePicker("Von", selection: $from, displayedComponents: .date); DatePicker("Bis", selection: $to, displayedComponents: .date) }
        Picker("Status", selection: $status) { Text("Offen").tag(0); Text("Archiv").tag(1); Text("Alle").tag(2) }.pickerStyle(.segmented).frame(width: 280)
        HStack { Text("\(rows.count) Einträge · \(hours(rows))").foregroundStyle(.secondary); Spacer(); Button("CSV exportieren") { store.exportCSV(rows) } }
        Table(rows) { TableColumn("Kunde / Projekt") { Text("\($0.customer)\n\($0.project)") }; TableColumn("Jira-Ticket / Notiz") { Text("\($0.ticket)\n\($0.note ?? "")") }; TableColumn("Abrechnungsticket") { entry in Text(store.billingTicket(for: entry) ?? "–") }; TableColumn("Dauer") { Text(format($0.seconds)) }; TableColumn("Status") { Text($0.billed ? "Archiv" : "Offen") }; TableColumn("Aktionen") { row in HStack { if !row.billed { Button("⧉") { duplicate(row) }.help("Duplizieren"); Button("✓") { store.close(row) }.help("Abschließen") }; Button(row.billed ? "↺" : "✎") { if row.billed { store.reopen(row) } }.help(row.billed ? "Wieder öffnen" : "Bearbeiten folgt"); Button("🗑") { store.delete(row) }.help("Löschen") } } }.frame(minHeight: 260)
    }.padding(4) } }
    private func duplicate(_ e: TimeEntry) { store.add(TimeEntry(id: UUID(), customer: e.customer, project: e.project, ticket: e.ticket, date: Date(), seconds: e.seconds, startedAt: nil, billed: false, billingTicket: nil, note: e.note)) }
}

struct MasterDataView: View {
    @EnvironmentObject private var store: MinutoStore
    @State private var customer = ""
    @State private var project = ""
    @State private var billingTicket = ""
    var body: some View { DisclosureGroup("Stammdaten verwalten") { VStack(alignment: .leading) { HStack { TextField("Kunde", text: $customer); TextField("Projekt", text: $project); TextField("Abrechnungsticket", text: $billingTicket); Button("Hinzufügen") { guard !customer.isEmpty, !project.isEmpty, !billingTicket.isEmpty else { return }; store.masters.append(MasterData(id: UUID(), customer: customer, project: project, billingTicket: billingTicket)); store.saveMasters(); customer = ""; project = ""; billingTicket = "" } }
        ForEach(store.masters) { master in HStack { Text(master.customer).frame(width: 160, alignment: .leading); Text(master.project).frame(width: 160, alignment: .leading); Text(master.billingTicket); Spacer(); Button(master.favorite ? "★" : "☆") { toggleFavorite(master) }; Button(master.active ? "Archivieren" : "Aktivieren") { toggleActive(master) }; Button(role: .destructive) { store.masters.removeAll { $0.id == master.id }; store.saveMasters() } label: { Image(systemName: "trash") } } } }.padding(.top, 8) }
    }
    private func toggleFavorite(_ master: MasterData) { guard let i = store.masters.firstIndex(of: master) else { return }; store.masters[i].favorite.toggle(); store.saveMasters() }
    private func toggleActive(_ master: MasterData) { guard let i = store.masters.firstIndex(of: master) else { return }; store.masters[i].active.toggle(); store.saveMasters() }
}

struct OverviewView: View {
    @EnvironmentObject private var store: MinutoStore
    @State private var weekClosed = false
    var body: some View { ScrollView { VStack(alignment: .leading, spacing: 18) { let todayEntries = store.entries.filter { Calendar.current.isDateInToday($0.date) && $0.startedAt == nil }; let week = store.entries.filter { Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .weekOfYear) && $0.startedAt == nil }; GroupBox("Tag und Woche") { HStack { Metric(title: "Heute", value: hours(todayEntries)); Metric(title: "Woche", value: hours(week)); VStack(alignment: .leading) { Text("Sollzeit pro Tag"); TextField("Stunden", value: $store.dailyTarget, format: .number).frame(width: 80) } } .padding(4) }; CalendarGrid(entries: store.entries); GroupBox("Kennzahlen") { HStack(alignment: .top) { MetricList(title: "Kunden", entries: store.entries, key: { $0.customer }); MetricList(title: "Projekte", entries: store.entries, key: { $0.project }); Spacer(); VStack { Text(weekClosed ? "Woche abgeschlossen" : "Woche offen"); Button(weekClosed ? "Woche wieder öffnen" : "Woche abschließen") { weekClosed.toggle() } } }.padding(4) } }.padding(24) } }
}

struct CalendarGrid: View { var entries: [TimeEntry]; var body: some View { let calendar = Calendar.current; let range = calendar.range(of: .day, in: .month, for: Date())!; GroupBox(Date().formatted(.dateTime.month(.wide).year())) { LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7)) { ForEach(Array(range), id: \.self) { day in let date = calendar.date(bySetting: .day, value: day, of: Date())!; let seconds = entries.filter { calendar.isDate($0.date, inSameDayAs: date) }.reduce(0) { $0 + $1.seconds }; VStack { Text("\(day)").font(.caption.bold()); Text(seconds == 0 ? "" : format(seconds)).font(.caption2).foregroundStyle(.secondary) }.frame(maxWidth: .infinity, minHeight: 44).background(seconds > 0 ? Color.accentColor.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 6)) } } }.padding(4) } }

struct Metric: View { var title: String; var value: String; var body: some View { VStack(alignment: .leading) { Text(title).font(.caption).foregroundStyle(.secondary); Text(value).font(.title2.bold()) }.frame(minWidth: 130, alignment: .leading) } }
struct MetricList: View { var title: String; var entries: [TimeEntry]; var key: (TimeEntry) -> String; var body: some View { VStack(alignment: .leading) { Text(title).font(.headline); ForEach(Array(Dictionary(grouping: entries.filter { $0.startedAt == nil }, by: key).map { ($0.key, $0.value.reduce(0) { $0 + $1.seconds }) }.sorted { $0.1 > $1.1 }.prefix(5)), id: \.0) { name, seconds in HStack { Text(name); Spacer(); Text(format(seconds)).foregroundStyle(.secondary) } } }.frame(minWidth: 260) } }
struct TimerText: View { let start: Date; @State private var now = Date(); var body: some View { Text(format(Int(now.timeIntervalSince(start)))).font(.title2.monospacedDigit()).onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { now = $0 } } }
func format(_ seconds: Int) -> String { String(format: "%02d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60) }
func hours(_ entries: [TimeEntry]) -> String { String(format: "%.2f h", Double(entries.reduce(0) { $0 + $1.seconds }) / 3600) }
func csvField(_ value: String) -> String { "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
extension String { var nilIfEmpty: String? { isEmpty ? nil : self } }
