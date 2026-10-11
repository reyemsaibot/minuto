import SwiftUI

struct OverviewView: View {
    @EnvironmentObject private var store: MinutoStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                timeSummary
                CalendarGrid(entries: store.entries)
                metrics
            }
            .padding(24)
        }
    }

    private var timeSummary: some View {
        let todayEntries = store.entries.filter {
            Calendar.current.isDateInToday($0.date) && $0.startedAt == nil
        }
        let weekEntries = store.entries.filter {
            Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .weekOfYear) && $0.startedAt == nil
        }

        return GroupBox("Tag und Woche") {
            HStack {
                Metric(title: "Heute", value: hours(todayEntries))
                Metric(title: "Woche", value: hours(weekEntries))
                VStack(alignment: .leading) {
                    Text("Sollzeit pro Tag")
                    TextField("Stunden", value: $store.dailyTarget, format: .number)
                        .frame(width: 80)
                }
            }
            .padding(4)
        }
    }

    private var metrics: some View {
        GroupBox("Kennzahlen") {
            HStack(alignment: .top) {
                MetricList(title: "Kunden", entries: store.entries, key: { $0.customer })
                MetricList(title: "Projekte", entries: store.entries, key: { $0.project })
                Spacer()
                WeekClosureControl()
            }
            .padding(4)
        }
    }
}

private struct WeekClosureControl: View {
    @EnvironmentObject private var store: MinutoStore
    private let date = Date()

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            if let closure = store.weekClosures.first(where: {
                Calendar.current.isDate($0.closedAt, equalTo: date, toGranularity: .weekOfYear)
            }) {
                Text("Woche abgeschlossen").font(.headline)
                Text("\(closure.entryCount) Einträge · \(format(closure.totalSeconds))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Woche offen").font(.headline)
            }
            Button(store.isWeekClosed(for: date) ? "Woche wieder öffnen" : "Woche abschließen") {
                store.toggleWeekClosure(for: date)
            }
        }
    }
}

struct CalendarGrid: View {
    var entries: [TimeEntry]
    @State private var month = Calendar.current.date(
        from: Calendar.current.dateComponents([.year, .month], from: Date())
    ) ?? Date()

    var body: some View {
        let calendar = Calendar.current
        let days = calendar.range(of: .day, in: .month, for: month) ?? 1..<2
        let total = entries
            .filter { calendar.isDate($0.date, equalTo: month, toGranularity: .month) }
            .reduce(0) { $0 + $1.seconds }

        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                calendarHeader(total: total)
                calendarDays(calendar: calendar, days: days)
            }
            .padding(4)
        } label: {
            Text("Kalender")
        }
    }

    private func calendarHeader(total: Int) -> some View {
        HStack {
            Button { moveMonth(-1) } label: { Image(systemName: "chevron.left") }
            Spacer()
            VStack(spacing: 1) {
                Text(month.formatted(.dateTime.month(.wide).year())).font(.headline)
                Text("\(format(total)) erfasst")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button { moveMonth(1) } label: { Image(systemName: "chevron.right") }
        }
    }

    private func calendarDays(calendar: Calendar, days: Range<Int>) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
            ForEach(["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"], id: \.self) {
                Text($0)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
            ForEach(0..<leadingEmptyDays(calendar), id: \.self) { _ in
                Color.clear.frame(height: 48)
            }
            ForEach(Array(days), id: \.self) { day in
                calendarDay(day, calendar: calendar)
            }
        }
    }

    private func calendarDay(_ day: Int, calendar: Calendar) -> some View {
        let date = calendar.date(bySetting: .day, value: day, of: month) ?? month
        let seconds = entries
            .filter { calendar.isDate($0.date, inSameDayAs: date) }
            .reduce(0) { $0 + $1.seconds }

        return VStack(spacing: 3) {
            Text("\(day)").font(.caption.bold())
            Text(seconds == 0 ? "" : format(seconds))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 48)
        .background(seconds > 0 ? Color.accentColor.opacity(0.16) : Color.clear, in: RoundedRectangle(cornerRadius: 7))
    }

    private func leadingEmptyDays(_ calendar: Calendar) -> Int {
        (calendar.component(.weekday, from: month) + 5) % 7
    }

    private func moveMonth(_ value: Int) {
        month = Calendar.current.date(byAdding: .month, value: value, to: month) ?? month
    }
}

struct Metric: View {
    var title: String
    var value: String

    var body: some View {
        VStack(alignment: .leading) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title2.bold())
        }
        .frame(minWidth: 130, alignment: .leading)
    }
}

struct MetricList: View {
    var title: String
    var entries: [TimeEntry]
    var key: (TimeEntry) -> String

    var body: some View {
        VStack(alignment: .leading) {
            Text(title).font(.headline)
            ForEach(topEntries, id: \.0) { name, seconds in
                HStack {
                    Text(name)
                    Spacer()
                    Text(format(seconds)).foregroundStyle(.secondary)
                }
            }
        }
        .frame(minWidth: 260)
    }

    private var topEntries: [(String, Int)] {
        Dictionary(grouping: entries.filter { $0.startedAt == nil }, by: key)
            .map { ($0.key, $0.value.reduce(0) { $0 + $1.seconds }) }
            .sorted { $0.1 > $1.1 }
            .prefix(5)
            .map { $0 }
    }
}
