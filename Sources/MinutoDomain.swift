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
}
