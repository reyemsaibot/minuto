import Foundation

struct MinutoImport: Sendable {
    var snapshot: MinutoSnapshot
    var includesAllData: Bool
}

enum MinutoPersistenceError: LocalizedError {
    case unsupportedSchema(Int)
    case duplicateEntryID
    case duplicateMasterData(String)
    case invalidMasterData
    case invalidDailyTarget

    var errorDescription: String? {
        switch self {
        case .unsupportedSchema(let version): return "Diese Sicherung verwendet das nicht unterstützte Datenformat \(version)."
        case .duplicateEntryID: return "Die Sicherung enthält doppelte Zeiteinträge."
        case .duplicateMasterData(let pair): return "Die Sicherung enthält die Stammdatenzuordnung \(pair) mehrfach."
        case .invalidMasterData: return "Eine Stammdatenzuordnung ist unvollständig."
        case .invalidDailyTarget: return "Die Sollzeit darf nicht negativ sein."
        }
    }
}

actor MinutoRepository {
    private let folder: URL
    private let legacyFolder: URL
    private var dataURL: URL { folder.appendingPathComponent("minuto.json") }
    private var entriesURL: URL { folder.appendingPathComponent("zeiten.json") }
    private var mastersURL: URL { folder.appendingPathComponent("stammdaten.json") }
    private var backupFolder: URL { folder.appendingPathComponent("Sicherungen") }

    init(folder: URL, legacyFolder: URL) {
        self.folder = folder
        self.legacyFolder = legacyFolder
    }

    func load(defaultDailyTarget: Double) throws -> MinutoSnapshot {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: dataURL.path) {
            let snapshot = try decodeSnapshot(from: dataURL)
            try validate(snapshot)
            return snapshot
        }

        let entries = try loadEntries(from: entriesURL, fallback: legacyFolder.appendingPathComponent("zeiten.json"))
        let masters = try loadMasters(from: mastersURL, fallback: legacyFolder.appendingPathComponent("stammdaten.json"))
        let snapshot = MinutoSnapshot(entries: entries, masters: masters, dailyTarget: defaultDailyTarget)
        if !entries.isEmpty || !masters.isEmpty {
            try writeBackup(snapshot, reason: "migration")
            try write(snapshot, to: dataURL)
        }
        return snapshot
    }

    func save(_ snapshot: MinutoSnapshot, createBackup: Bool = true) throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try validate(snapshot)
        if createBackup, FileManager.default.fileExists(atPath: dataURL.path) {
            try writeBackup(try decodeSnapshot(from: dataURL), reason: "auto")
        }
        var copy = snapshot
        copy.exportedAt = Date()
        try write(copy, to: dataURL)
        try pruneBackups()
    }

    func export(_ snapshot: MinutoSnapshot, to url: URL) throws {
        try validate(snapshot)
        var copy = snapshot
        copy.exportedAt = Date()
        try write(copy, to: url)
    }

    func readImport(from url: URL) throws -> MinutoImport {
        let data = try Data(contentsOf: url)
        if let snapshot = try? JSONDecoder.minuto.decode(MinutoSnapshot.self, from: data) {
            try validate(snapshot, validateMasters: true)
            return MinutoImport(snapshot: snapshot, includesAllData: true)
        }
        if let entries = try? JSONDecoder.minuto.decode([TimeEntry].self, from: data) {
            try validate(MinutoSnapshot(entries: entries), validateMasters: false)
            return MinutoImport(snapshot: MinutoSnapshot(entries: entries), includesAllData: false)
        }
        let legacy = try JSONDecoder().decode([LegacyTimeEntry].self, from: data)
        let entries = legacy.map(Self.convert)
        try validate(MinutoSnapshot(entries: entries), validateMasters: false)
        return MinutoImport(snapshot: MinutoSnapshot(entries: entries), includesAllData: false)
    }

    private func loadEntries(from current: URL, fallback: URL) throws -> [TimeEntry] {
        let source = FileManager.default.fileExists(atPath: current.path) ? current : fallback
        guard FileManager.default.fileExists(atPath: source.path) else { return [] }
        let data = try Data(contentsOf: source)
        if let entries = try? JSONDecoder.minuto.decode([TimeEntry].self, from: data) { return entries }
        return try JSONDecoder().decode([LegacyTimeEntry].self, from: data).map(Self.convert)
    }

    private func loadMasters(from current: URL, fallback: URL) throws -> [MasterData] {
        let source = FileManager.default.fileExists(atPath: current.path) ? current : fallback
        guard FileManager.default.fileExists(atPath: source.path) else { return [] }
        let data = try Data(contentsOf: source)
        if let masters = try? JSONDecoder.minuto.decode([MasterData].self, from: data) { return masters }
        return try JSONDecoder().decode([LegacyMasterData].self, from: data).map {
            MasterData(id: UUID(uuidString: $0.id) ?? UUID(), customer: $0.customer, project: $0.project, billingTicket: $0.ticket, favorite: $0.favorite == 1, active: $0.active != 0)
        }
    }

    private func decodeSnapshot(from url: URL) throws -> MinutoSnapshot {
        let snapshot = try JSONDecoder.minuto.decode(MinutoSnapshot.self, from: Data(contentsOf: url))
        guard snapshot.schemaVersion == MinutoSnapshot.currentSchemaVersion else { throw MinutoPersistenceError.unsupportedSchema(snapshot.schemaVersion) }
        return snapshot
    }

    private func validate(_ snapshot: MinutoSnapshot, validateMasters: Bool = false) throws {
        guard Set(snapshot.entries.map(\.id)).count == snapshot.entries.count else { throw MinutoPersistenceError.duplicateEntryID }
        guard snapshot.dailyTarget >= 0 else { throw MinutoPersistenceError.invalidDailyTarget }
        guard !validateMasters || snapshot.masters.allSatisfy({ !$0.customer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !$0.project.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !$0.billingTicket.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else { throw MinutoPersistenceError.invalidMasterData }
        if validateMasters {
            var seen: Set<String> = []
            for master in snapshot.masters where !seen.insert(master.normalizedKey).inserted {
                throw MinutoPersistenceError.duplicateMasterData("\(master.customer) · \(master.project)")
            }
        }
    }

    private func writeBackup(_ snapshot: MinutoSnapshot, reason: String) throws {
        try FileManager.default.createDirectory(at: backupFolder, withIntermediateDirectories: true)
        let stamp = Self.backupDateFormatter.string(from: Date())
        try write(snapshot, to: backupFolder.appendingPathComponent("Minuto-\(reason)-\(stamp)-\(UUID().uuidString.prefix(6)).json"))
    }

    private func pruneBackups() throws {
        guard FileManager.default.fileExists(atPath: backupFolder.path) else { return }
        let files = try FileManager.default.contentsOfDirectory(at: backupFolder, includingPropertiesForKeys: [.creationDateKey], options: [.skipsHiddenFiles])
        let dated = files.map { url -> (URL, Date) in
            let date = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            return (url, date)
        }.sorted { $0.1 > $1.1 }
        for (url, _) in dated.dropFirst(30) { try FileManager.default.removeItem(at: url) }
    }

    private func write<T: Encodable>(_ value: T, to url: URL) throws {
        let data = try JSONEncoder.minuto.encode(value)
        try data.write(to: url, options: .atomic)
    }

    private static func convert(_ item: LegacyTimeEntry) -> TimeEntry {
        TimeEntry(id: UUID(uuidString: item.id) ?? UUID(), customer: item.customer, project: item.project, ticket: item.ticket, date: legacyDateFormatter.date(from: item.date) ?? Date(), seconds: item.seconds, startedAt: item.started.map { Date(timeIntervalSince1970: $0 / 1000) }, billed: item.billed == 1, billingTicket: item.billingTicket, note: item.note)
    }

    private static let legacyDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let backupDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()
}

extension JSONEncoder {
    static var minuto: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

extension JSONDecoder {
    static var minuto: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
