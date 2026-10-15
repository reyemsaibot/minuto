import Foundation

enum MinutoDateRange {
    static func contains(_ date: Date, from: Date, to: Date, calendar: Calendar = .current) -> Bool {
        let firstDay = calendar.startOfDay(for: min(from, to))
        guard let dayAfterLast = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: max(from, to))) else { return false }
        return date >= firstDay && date < dayAfterLast
    }
}

enum MinutoTimerPolicy {
    /// Ein laufender Timer bleibt dem Kalendertag seines Starts zugeordnet.
    static let dateAssignment = "startDate"

    static func entryDate(for start: Date) -> Date { start }
}

enum MinutoManualEntryDatePolicy {
    /// Eine neue manuelle Erfassung verwendet immer den Beginn des aktuellen lokalen Kalendertags.
    static func defaultDate(now: Date = Date(), calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: now)
    }

    /// Ein vom Nutzer gewähltes Buchungsdatum bleibt auch beim Tageswechsel unverändert.
    static func shouldRefreshDefaultDate(dateWasChosenByUser: Bool) -> Bool {
        !dateWasChosenByUser
    }
}

struct MasterDataConflict: Identifiable, Hashable, Sendable {
    let id: String
    let customer: String
    let project: String
    let masters: [MasterData]
}

enum MasterDataRuleError: LocalizedError {
    case conflictingBillingTicket(customer: String, project: String)
    case unresolvedExistingConflicts

    var errorDescription: String? {
        switch self {
        case let .conflictingBillingTicket(customer, project):
            return "Für \(customer) · \(project) unterscheiden sich die Abrechnungstickets. Der Import wurde nicht übernommen."
        case .unresolvedExistingConflicts:
            return "Bitte bereinige vorhandene Stammdaten-Dubletten, bevor du weitere Stammdaten importierst."
        }
    }
}

enum MasterDataRules {
    static func conflicts(in masters: [MasterData]) -> [MasterDataConflict] {
        Dictionary(grouping: masters, by: \.normalizedKey).values
            .filter { $0.count > 1 }
            .compactMap { group in
                guard let first = group.first else { return nil }
                return MasterDataConflict(id: first.normalizedKey, customer: first.customer, project: first.project, masters: group)
            }
            .sorted { $0.customer.localizedCaseInsensitiveCompare($1.customer) == .orderedAscending }
    }

    static func merged(current: [MasterData], imported: [MasterData]) throws -> [MasterData] {
        guard conflicts(in: current).isEmpty else { throw MasterDataRuleError.unresolvedExistingConflicts }
        var result = current
        for master in imported {
            let matches = result.filter { $0.normalizedKey == master.normalizedKey }
            if let existing = matches.first {
                let sameTicket = existing.billingTicket.trimmingCharacters(in: .whitespacesAndNewlines)
                    .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                    == master.billingTicket.trimmingCharacters(in: .whitespacesAndNewlines)
                    .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                guard sameTicket else { throw MasterDataRuleError.conflictingBillingTicket(customer: master.customer, project: master.project) }
            } else {
                result.append(master)
            }
        }
        return result
    }
}
