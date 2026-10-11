import Foundation

struct TimeEntry: Codable, Identifiable, Hashable, Sendable {
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

struct MasterData: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var customer: String
    var project: String
    var billingTicket: String
    var favorite = false
    var active = true

    var normalizedKey: String {
        [customer, project]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current) }
            .joined(separator: "\u{1F}")
    }
}

struct WeekClosure: Codable, Hashable, Sendable {
    var weekIdentifier: String
    var closedAt: Date
    var entryCount: Int
    var totalSeconds: Int
}

struct MinutoSnapshot: Codable, Sendable {
    static let currentSchemaVersion = 1
    var schemaVersion: Int
    var exportedAt: Date
    var entries: [TimeEntry]
    var masters: [MasterData]
    var dailyTarget: Double
    var weekClosures: [WeekClosure]

    init(entries: [TimeEntry] = [], masters: [MasterData] = [], dailyTarget: Double = 8, weekClosures: [WeekClosure] = []) {
        self.schemaVersion = Self.currentSchemaVersion
        self.exportedAt = Date()
        self.entries = entries
        self.masters = masters
        self.dailyTarget = dailyTarget
        self.weekClosures = weekClosures
    }
}

struct LegacyTimeEntry: Codable {
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

struct LegacyMasterData: Codable {
    let id: String
    let customer: String
    let project: String
    let ticket: String
    let favorite: Int?
    let active: Int?
}
