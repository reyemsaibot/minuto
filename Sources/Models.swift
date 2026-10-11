import Foundation

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
