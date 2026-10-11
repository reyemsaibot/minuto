import SwiftUI

struct EntryList: View {
    @EnvironmentObject private var store: MinutoStore
    @State private var status = EntryStatus.open
    @State private var customer = ""
    @State private var ticket = ""
    @State private var note = ""
    @State private var from = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
    @State private var to = Date()
    @State private var entryBeingEdited: TimeEntry?

    var body: some View {
        GroupBox("Zeiteinträge") {
            VStack(alignment: .leading, spacing: 10) {
                searchFilters
                quickFilters
                listSummary
                entriesTable
            }
            .padding(4)
        }
        .sheet(item: $entryBeingEdited) { entry in
            TimeEntryEditor(entry: entry)
        }
    }

    private var rows: [TimeEntry] {
        store.entries.filter { entry in
            status.includes(entry)
                && (customer.isEmpty || entry.customer.localizedCaseInsensitiveContains(customer))
                && (ticket.isEmpty || entry.ticket.localizedCaseInsensitiveContains(ticket))
                && (note.isEmpty || (entry.note ?? "").localizedCaseInsensitiveContains(note))
                && MinutoDateRange.contains(entry.date, from: from, to: to)
        }
    }

    private var searchFilters: some View {
        HStack {
            ClearableSearchField("Kunde filtern", text: $customer)
            ClearableSearchField("Jira-Ticket", text: $ticket)
            ClearableSearchField("Notiz", text: $note)
            DatePicker("Von", selection: $from, displayedComponents: .date)
            DatePicker("Bis", selection: $to, displayedComponents: .date)
        }
    }

    private var quickFilters: some View {
        HStack(spacing: 0) {
            HStack(spacing: 12) {
                Text("Zeitraum").foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    Button("Heute") { applyQuickRange(.today) }
                    Button("Diese Woche") { applyQuickRange(.week) }
                    Button("Letzte 30 Tage") { applyQuickRange(.lastThirtyDays) }
                    Button("Alles") { applyQuickRange(.all) }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Divider()
                .frame(height: 28)
                .padding(.horizontal, 24)

            HStack(spacing: 12) {
                Text("Status").foregroundStyle(.secondary)
                Picker("Status", selection: $status) {
                    ForEach(EntryStatus.allCases) { status in
                        Text(status.title).tag(status)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 280)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }

    private var listSummary: some View {
        HStack {
            Text("\(rows.count) Einträge · \(hours(rows))")
                .foregroundStyle(.secondary)
            Spacer()
            Button("CSV exportieren") {
                store.exportCSV(rows)
            }
        }
    }

    private var entriesTable: some View {
        Table(rows) {
            TableColumn("Kunde / Projekt") {
                Text("\($0.customer)\n\($0.project)")
            }
            TableColumn("Jira-Ticket / Notiz") {
                Text("\($0.ticket)\n\($0.note ?? "")")
            }
            TableColumn("Abrechnungsticket") { entry in
                if store.hasMasterConflict(for: entry) {
                    Label("Konflikt", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                } else {
                    Text(store.billingTicket(for: entry) ?? "–")
                }
            }
            TableColumn("Dauer") {
                Text(format($0.seconds))
            }
            TableColumn("Status") {
                Text($0.billed ? "Archiv" : "Offen")
            }
            TableColumn("Aktionen") { row in
                EntryActions(
                    row: row,
                    duplicate: { duplicate(row) },
                    edit: { entryBeingEdited = row },
                    close: { store.close(row) },
                    reopen: { store.reopen(row) },
                    delete: { store.delete(row) }
                )
            }
        }
        .frame(minHeight: 260)
    }

    private func duplicate(_ entry: TimeEntry) {
        store.add(
            TimeEntry(
                id: UUID(),
                customer: entry.customer,
                project: entry.project,
                ticket: entry.ticket,
                date: Date(),
                seconds: entry.seconds,
                startedAt: nil,
                billed: false,
                billingTicket: nil,
                note: entry.note
            )
        )
    }

    private func applyQuickRange(_ range: QuickRange) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        switch range {
        case .today:
            from = today
            to = today
        case .week:
            let interval = calendar.dateInterval(of: .weekOfYear, for: today)
            from = interval?.start ?? today
            to = calendar.date(byAdding: .day, value: -1, to: interval?.end ?? today) ?? today
        case .lastThirtyDays:
            from = calendar.date(byAdding: .day, value: -29, to: today) ?? today
            to = today
        case .all:
            from = store.entries.map(\.date).min() ?? today
            to = store.entries.map(\.date).max() ?? today
        }
    }
}

private enum EntryStatus: Int, CaseIterable, Identifiable {
    case open
    case archive
    case all

    var id: Int { rawValue }
    var title: String {
        switch self {
        case .open: return "Offen"
        case .archive: return "Archiv"
        case .all: return "Alle"
        }
    }

    func includes(_ entry: TimeEntry) -> Bool {
        switch self {
        case .open: return !entry.billed
        case .archive: return entry.billed
        case .all: return true
        }
    }
}

private enum QuickRange {
    case today
    case week
    case lastThirtyDays
    case all
}

private struct EntryActions: View {
    let row: TimeEntry
    let duplicate: () -> Void
    let edit: () -> Void
    let close: () -> Void
    let reopen: () -> Void
    let delete: () -> Void

    var body: some View {
        HStack(spacing: 9) {
            if !row.billed {
                Button(action: duplicate) { Image(systemName: "plus.square.on.square") }
                    .help("Duplizieren")
                if row.startedAt == nil {
                    Button(action: edit) { Image(systemName: "pencil") }
                        .help("Bearbeiten")
                }
                Button(action: close) { Image(systemName: "checkmark") }
                    .help("Abschließen")
            } else {
                Button(action: reopen) { Image(systemName: "arrow.counterclockwise") }
                    .help("Wieder öffnen")
            }
            Button(role: .destructive, action: delete) {
                Image(systemName: "trash")
            }
            .help("Löschen")
        }
        .labelStyle(.iconOnly)
    }
}

struct ClearableSearchField: View {
    let placeholder: String
    @Binding var text: String

    init(_ placeholder: String, text: Binding<String>) {
        self.placeholder = placeholder
        _text = text
    }

    var body: some View {
        HStack(spacing: 6) {
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("\(placeholder) löschen")
                .accessibilityLabel("\(placeholder) löschen")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary, lineWidth: 1))
        .onExitCommand {
            if !text.isEmpty { text = "" }
        }
    }
}
