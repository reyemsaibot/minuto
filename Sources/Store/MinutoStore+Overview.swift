import Foundation

@MainActor extension MinutoStore {
    func isWeekClosed(for date: Date) -> Bool {
        weekClosures.contains { $0.weekIdentifier == Self.weekIdentifier(for: date) }
    }

    func toggleWeekClosure(for date: Date) {
        let identifier = Self.weekIdentifier(for: date)
        if let index = weekClosures.firstIndex(where: { $0.weekIdentifier == identifier }) {
            weekClosures.remove(at: index)
        } else {
            let calendar = Calendar.current
            let entriesForWeek = entries.filter {
                $0.startedAt == nil && calendar.isDate($0.date, equalTo: date, toGranularity: .weekOfYear)
            }
            weekClosures.append(
                WeekClosure(
                    weekIdentifier: identifier,
                    closedAt: Date(),
                    entryCount: entriesForWeek.count,
                    totalSeconds: entriesForWeek.reduce(0) { $0 + $1.seconds }
                )
            )
        }
        persist()
    }

    private static func weekIdentifier(for date: Date) -> String {
        let components = Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return "\(components.yearForWeekOfYear ?? 0)-W\(String(format: "%02d", components.weekOfYear ?? 0))"
    }
}
