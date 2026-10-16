import Foundation

@main struct MinutoRepositoryTests {
    static func main() async {
        do {
            try await migrationUsesMissingFilesFromLegacyFolder()
            try await backupsContainEveryDataKind()
            try await rejectDuplicateMastersDuringImport()
            try await rejectNegativeDailyTarget()
            try dateRangeUsesInclusiveCalendarDays()
            try timerRetainsItsStartDate()
            try manualEntryRefreshesItsDefaultDateAfterMidnight()
            try masterDataConflictsRequireAnExplicitResolution()
            try projectFilterMatchesCaseInsensitively()
            print("Alle Minuto-Persistenztests bestanden.")
        } catch {
            FileHandle.standardError.write("TEST FEHLGESCHLAGEN: \(error)\n".data(using: .utf8)!)
            Foundation.exit(1)
        }
    }

    static func migrationUsesMissingFilesFromLegacyFolder() async throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let current = root.appendingPathComponent("Minuto")
        let legacy = root.appendingPathComponent("Kundenzeit")
        try FileManager.default.createDirectory(at: current, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: legacy, withIntermediateDirectories: true)
        let entry = fixtureEntry()
        let master = fixtureMaster()
        try JSONEncoder.minuto.encode([entry]).write(to: legacy.appendingPathComponent("zeiten.json"))
        try JSONEncoder.minuto.encode([master]).write(to: legacy.appendingPathComponent("stammdaten.json"))
        let repository = MinutoRepository(folder: current, legacyFolder: legacy)
        let snapshot = try await repository.load(defaultDailyTarget: 7.5)
        try require(snapshot.entries == [entry], "Migration übernimmt Zeiteinträge aus dem alten Ordner.")
        try require(snapshot.masters == [master], "Migration übernimmt Stammdaten aus dem alten Ordner.")
        try require(snapshot.dailyTarget == 7.5, "Migration übernimmt die Sollzeit.")
        try require(FileManager.default.fileExists(atPath: current.appendingPathComponent("minuto.json").path), "Migration schreibt den neuen Gesamtbestand.")
        let backups = try FileManager.default.contentsOfDirectory(at: current.appendingPathComponent("Sicherungen"), includingPropertiesForKeys: nil)
        try require(!backups.isEmpty, "Migration legt eine Sicherung an.")
    }

    static func backupsContainEveryDataKind() async throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let folder = root.appendingPathComponent("Minuto")
        let repository = MinutoRepository(folder: folder, legacyFolder: root.appendingPathComponent("Kundenzeit"))
        let closure = WeekClosure(weekIdentifier: "2026-W41", closedAt: Date(timeIntervalSince1970: 1_760_000_000), entryCount: 1, totalSeconds: 3600)
        let initial = MinutoSnapshot(entries: [fixtureEntry()], masters: [fixtureMaster()], dailyTarget: 7.5, weekClosures: [closure])
        try await repository.save(initial, createBackup: false)
        var changed = initial
        changed.dailyTarget = 8
        try await repository.save(changed)
        let backups = try FileManager.default.contentsOfDirectory(at: folder.appendingPathComponent("Sicherungen"), includingPropertiesForKeys: nil)
        let imported = try await repository.readImport(from: try require(backups.first, "Automatische Sicherung vorhanden."))
        try require(imported.includesAllData, "Sicherung enthält einen vollständigen Datenbestand.")
        try require(imported.snapshot.entries == initial.entries && imported.snapshot.masters == initial.masters && imported.snapshot.dailyTarget == initial.dailyTarget && imported.snapshot.weekClosures == initial.weekClosures, "Sicherung enthält Einträge, Stammdaten, Sollzeit und Wochenabschluss.")
    }

    static func rejectDuplicateMastersDuringImport() async throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("duplikat.json")
        let master = fixtureMaster()
        let duplicate = MasterData(id: UUID(), customer: master.customer.lowercased(), project: master.project, billingTicket: "ANDERES")
        try JSONEncoder.minuto.encode(MinutoSnapshot(masters: [master, duplicate])).write(to: url)
        let repository = MinutoRepository(folder: root.appendingPathComponent("Minuto"), legacyFolder: root.appendingPathComponent("Kundenzeit"))
        do {
            _ = try await repository.readImport(from: url)
            throw TestFailure("Doppelte Stammdaten wurden akzeptiert.")
        } catch is MinutoPersistenceError { }
    }

    static func rejectNegativeDailyTarget() async throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = MinutoRepository(folder: root.appendingPathComponent("Minuto"), legacyFolder: root.appendingPathComponent("Kundenzeit"))
        do {
            try await repository.save(MinutoSnapshot(dailyTarget: -0.25), createBackup: false)
            throw TestFailure("Negative Sollzeit wurde akzeptiert.")
        } catch is MinutoPersistenceError { }
    }

    static func dateRangeUsesInclusiveCalendarDays() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        let formatter = ISO8601DateFormatter()
        let date = formatter.date(from: "2026-10-06T21:30:00Z")!
        let day = formatter.date(from: "2026-10-06T10:00:00Z")!
        let nextDay = formatter.date(from: "2026-10-07T10:00:00Z")!
        try require(MinutoDateRange.contains(date, from: day, to: day, calendar: calendar), "Der Bis-Tag ist vollständig enthalten.")
        try require(!MinutoDateRange.contains(nextDay, from: day, to: day, calendar: calendar), "Der Folgetag ist ausgeschlossen.")
    }

    static func masterDataConflictsRequireAnExplicitResolution() throws {
        let current = fixtureMaster()
        let matching = MasterData(id: UUID(), customer: current.customer.lowercased(), project: current.project, billingTicket: current.billingTicket)
        let conflicting = MasterData(id: UUID(), customer: current.customer, project: current.project, billingTicket: "ABR-NEU")
        try require(MasterDataRules.conflicts(in: [current, conflicting]).count == 1, "Historische Stammdaten-Dubletten werden erkannt.")
        let merged = try MasterDataRules.merged(current: [current], imported: [matching])
        try require(merged.count == 1, "Gleiche Abrechnungstickets werden beim Import nicht dupliziert.")
        do {
            _ = try MasterDataRules.merged(current: [current], imported: [conflicting])
            throw TestFailure("Widersprüchliche Abrechnungstickets wurden beim Import akzeptiert.")
        } catch is MasterDataRuleError { }
    }

    static func timerRetainsItsStartDate() throws {
        let start = Date(timeIntervalSince1970: 1_760_000_000)
        try require(MinutoTimerPolicy.entryDate(for: start) == start, "Ein Timer bleibt dem Datum seines Starts zugeordnet.")
    }

    static func manualEntryRefreshesItsDefaultDateAfterMidnight() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        let formatter = ISO8601DateFormatter()
        let afterMidnight = formatter.date(from: "2026-10-14T22:01:00Z")!
        let expected = calendar.date(from: DateComponents(timeZone: calendar.timeZone, year: 2026, month: 10, day: 15))!
        try require(MinutoManualEntryDatePolicy.defaultDate(now: afterMidnight, calendar: calendar) == expected, "Eine neue manuelle Erfassung erhält nach Mitternacht den aktuellen lokalen Kalendertag.")
        try require(!MinutoManualEntryDatePolicy.shouldRefreshDefaultDate(dateWasChosenByUser: true), "Ein bewusst gewähltes Buchungsdatum bleibt erhalten.")
    }

    static func projectFilterMatchesCaseInsensitively() throws {
        try require(MinutoTextFilter.matches("BW Migration", query: "migration"), "Projektfilter findet Teiltexte ohne Beachtung der Groß- und Kleinschreibung.")
        try require(!MinutoTextFilter.matches("BW Migration", query: "UC44"), "Projektfilter schließt nicht passende Projekte aus.")
        try require(MinutoTextFilter.matches("BW Migration", query: ""), "Ein leerer Projektfilter lässt alle Projekte durch.")
    }

    static func fixtureEntry() -> TimeEntry { TimeEntry(id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!, customer: "ENERCON", project: "UC44", ticket: "ITDS-1780", date: Date(timeIntervalSince1970: 1_760_000_000), seconds: 3600, startedAt: nil, billed: false, billingTicket: nil, note: "Test") }
    static func fixtureMaster() -> MasterData { MasterData(id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!, customer: "ENERCON", project: "UC44", billingTicket: "ABR-44") }
    static func temporaryRoot() throws -> URL { let url = FileManager.default.temporaryDirectory.appendingPathComponent("MinutoTests-\(UUID().uuidString)"); try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true); return url }
    static func require(_ condition: @autoclosure () -> Bool, _ message: String) throws { guard condition() else { throw TestFailure(message) } }
    static func require<T>(_ value: T?, _ message: String) throws -> T { guard let value else { throw TestFailure(message) }; return value }
}

struct TestFailure: Error, LocalizedError { let message: String; init(_ message: String) { self.message = message }; var errorDescription: String? { message } }
