import SwiftUI

struct TimeEntryForm: View {
    @EnvironmentObject private var store: MinutoStore
    @Binding var showManualEntry: Bool
    @State private var manual = false
    @State private var customer = ""
    @State private var project = ""
    @State private var ticket = ""
    @State private var note = ""
    @State private var minutes = 60.0
    @State private var date = Date()
    @FocusState private var focusedField: EntryField?

    private enum EntryField: Hashable { case customer, project, ticket, note }

    var body: some View {
        GroupBox { VStack(alignment: .leading, spacing: 14) {
            HStack { Picker("Art", selection: $manual) { Text("Timer").tag(false); Text("Manuell").tag(true) }.pickerStyle(.segmented).frame(width: 200); Spacer(); if store.activeTimer != nil { Label("Timer läuft", systemImage: "timer").foregroundStyle(.secondary) } }
            Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                GridRow {
                    TextField("Kunde", text: $customer).focused($focusedField, equals: .customer)
                    TextField("Projekt", text: $project).focused($focusedField, equals: .project)
                    TextField("Jira-Ticket", text: $ticket).focused($focusedField, equals: .ticket)
                }
                if manual { GridRow { DatePicker("Datum", selection: $date, displayedComponents: .date); TextField("Minuten", value: $minutes, format: .number); Button("Zeit speichern") { save() }.buttonStyle(.borderedProminent) } }
                else { GridRow { TextField("Notiz (optional)", text: $note).focused($focusedField, equals: .note); Button("Timer starten") { start() }.buttonStyle(.borderedProminent); EmptyView() } }
            }
            if manual { TextField("Notiz (optional)", text: $note).focused($focusedField, equals: .note); HStack { Spacer(); Button("Zeit speichern") { save() }.buttonStyle(.borderedProminent) } }
            MasterDataPicker { master in customer = master.customer; project = master.project }
        }.padding(4) } label: { Text("Zeiten erfassen").font(.headline) }
        .task(id: showManualEntry) { consumeManualEntryRequest() }
    }
    private func start() { guard !customer.isEmpty, !project.isEmpty, !ticket.isEmpty, store.activeTimer == nil else { return }; store.add(TimeEntry(id: UUID(), customer: customer, project: project, ticket: ticket, date: Date(), seconds: 0, startedAt: Date(), billed: false, billingTicket: nil, note: note.nilIfEmpty)); reset() }
    private func save() { guard !customer.isEmpty, !project.isEmpty, !ticket.isEmpty, minutes > 0 else { return }; store.add(TimeEntry(id: UUID(), customer: customer, project: project, ticket: ticket, date: date, seconds: Int(minutes * 60), startedAt: nil, billed: false, billingTicket: nil, note: note.nilIfEmpty)); reset() }
    private func reset() { customer = ""; project = ""; ticket = ""; note = ""; minutes = 60; date = Date() }
    private func consumeManualEntryRequest() { guard showManualEntry else { return }; manual = true; date = Date(); showManualEntry = false; DispatchQueue.main.async { focusedField = .customer } }
}

struct MasterDataPicker: View {
    @EnvironmentObject private var store: MinutoStore
    @State private var expanded = false
    @State private var query = ""
    let onSelect: (MasterData) -> Void

    private var matches: [MasterData] {
        store.activeMasters.filter { query.isEmpty || "\($0.customer) \($0.project) \($0.billingTicket)".localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        if !store.activeMasters.isEmpty {
            DisclosureGroup("Stammdaten auswählen", isExpanded: $expanded) {
                TextField("Kunde oder Projekt suchen", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .padding(.vertical, 4)
                ForEach(matches.prefix(8)) { master in
                    Button {
                        onSelect(master)
                        expanded = false
                    } label: {
                        HStack {
                            if master.favorite { Image(systemName: "star.fill").foregroundStyle(.yellow) }
                            Text(master.customer).fontWeight(.medium)
                            Text("· \(master.project)").foregroundStyle(.secondary)
                            Spacer()
                            Text(master.billingTicket).foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 3)
                }
            }
        }
    }
}

struct EntryList: View {
    @EnvironmentObject private var store: MinutoStore
    @State private var status = 0
    @State private var customer = ""
    @State private var ticket = ""
    @State private var note = ""
    @State private var from = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
    @State private var to = Date()
    @State private var entryBeingEdited: TimeEntry?
    var rows: [TimeEntry] {
        let calendar = Calendar.current
        let firstDay = calendar.startOfDay(for: min(from, to))
        let dayAfterLast = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: max(from, to)))!
        return store.entries.filter { entry in
            (status == 2 || (status == 0 ? !entry.billed : entry.billed)) &&
            (customer.isEmpty || entry.customer.localizedCaseInsensitiveContains(customer)) &&
            (ticket.isEmpty || entry.ticket.localizedCaseInsensitiveContains(ticket)) &&
            (note.isEmpty || (entry.note ?? "").localizedCaseInsensitiveContains(note)) &&
            entry.date >= firstDay && entry.date < dayAfterLast
        }
    }
    var body: some View { GroupBox("Zeiteinträge") { VStack(alignment: .leading, spacing: 10) {
        HStack { TextField("Kunde filtern", text: $customer); TextField("Jira-Ticket", text: $ticket); TextField("Notiz", text: $note); DatePicker("Von", selection: $from, displayedComponents: .date); DatePicker("Bis", selection: $to, displayedComponents: .date) }
        HStack(spacing: 0) {
            HStack(spacing: 12) {
                filterLabel("Zeitraum")
                HStack(spacing: 10) {
                    Button("Heute") { applyQuickRange(.today) }
                    Button("Diese Woche") { applyQuickRange(.week) }
                    Button("Letzte 30 Tage") { applyQuickRange(.lastThirtyDays) }
                    Button("Alles") { applyQuickRange(.all) }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            Divider().frame(height: 28).padding(.horizontal, 24)
            HStack(spacing: 12) {
                filterLabel("Status")
                Picker("Status", selection: $status) { Text("Offen").tag(0); Text("Archiv").tag(1); Text("Alle").tag(2) }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 280)
            }
            Spacer(minLength: 0)
        }.padding(.vertical, 2)
        HStack { Text("\(rows.count) Einträge · \(hours(rows))").foregroundStyle(.secondary); Spacer(); Button("CSV exportieren") { store.exportCSV(rows) } }
        Table(rows) {
            TableColumn("Kunde / Projekt") { Text("\($0.customer)\n\($0.project)") }
            TableColumn("Jira-Ticket / Notiz") { Text("\($0.ticket)\n\($0.note ?? "")") }
            TableColumn("Abrechnungsticket") { entry in Text(store.billingTicket(for: entry) ?? "–") }
            TableColumn("Dauer") { Text(format($0.seconds)) }
            TableColumn("Status") { Text($0.billed ? "Archiv" : "Offen") }
            TableColumn("Aktionen") { row in
                HStack(spacing: 9) {
                    if !row.billed {
                        Button { duplicate(row) } label: { Image(systemName: "plus.square.on.square") }.help("Duplizieren")
                        if row.startedAt == nil { Button { entryBeingEdited = row } label: { Image(systemName: "pencil") }.help("Bearbeiten") }
                        Button { store.close(row) } label: { Image(systemName: "checkmark") }.help("Abschließen")
                    } else {
                        Button { store.reopen(row) } label: { Image(systemName: "arrow.counterclockwise") }.help("Wieder öffnen")
                    }
                    Button(role: .destructive) { store.delete(row) } label: { Image(systemName: "trash") }.help("Löschen")
                }
                .labelStyle(.iconOnly)
            }
        }.frame(minHeight: 260)
    }.padding(4) }
    .sheet(item: $entryBeingEdited) { entry in TimeEntryEditor(entry: entry) }
    }
    private func duplicate(_ e: TimeEntry) { store.add(TimeEntry(id: UUID(), customer: e.customer, project: e.project, ticket: e.ticket, date: Date(), seconds: e.seconds, startedAt: nil, billed: false, billingTicket: nil, note: e.note)) }
    @ViewBuilder private func filterLabel(_ text: String) -> some View {
        Text(text).foregroundStyle(.secondary).frame(width: 88, alignment: .trailing)
    }
    private enum QuickRange { case today, week, lastThirtyDays, all }
    private func applyQuickRange(_ range: QuickRange) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        switch range {
        case .today: from = today; to = today
        case .week:
            let interval = calendar.dateInterval(of: .weekOfYear, for: today)
            from = interval?.start ?? today
            to = calendar.date(byAdding: .day, value: -1, to: interval?.end ?? today) ?? today
        case .lastThirtyDays: from = calendar.date(byAdding: .day, value: -29, to: today) ?? today; to = today
        case .all: from = store.entries.map(\.date).min() ?? today; to = store.entries.map(\.date).max() ?? today
        }
    }
}

struct TimeEntryEditor: View {
    @EnvironmentObject private var store: MinutoStore
    @Environment(\.dismiss) private var dismiss
    let entry: TimeEntry
    @State private var customer: String
    @State private var project: String
    @State private var ticket: String
    @State private var note: String
    @State private var minutes: Double
    @State private var date: Date

    init(entry: TimeEntry) {
        self.entry = entry
        _customer = State(initialValue: entry.customer)
        _project = State(initialValue: entry.project)
        _ticket = State(initialValue: entry.ticket)
        _note = State(initialValue: entry.note ?? "")
        _minutes = State(initialValue: Double(entry.seconds) / 60)
        _date = State(initialValue: entry.date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Zeiteintrag bearbeiten").font(.title2.bold())
            Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                GridRow { TextField("Kunde", text: $customer); TextField("Projekt", text: $project) }
                GridRow { TextField("Jira-Ticket", text: $ticket); TextField("Minuten", value: $minutes, format: .number) }
                GridRow { DatePicker("Datum", selection: $date, displayedComponents: .date); EmptyView() }
            }
            TextField("Notiz", text: $note)
            MasterDataPicker { master in customer = master.customer; project = master.project }
            HStack { Spacer(); Button("Abbrechen") { dismiss() }; Button("Speichern") { save() }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction) }
        }
        .padding(24)
        .frame(width: 520)
    }

    private func save() {
        guard !customer.isEmpty, !project.isEmpty, !ticket.isEmpty, minutes > 0 else { return }
        var updated = entry
        updated.customer = customer
        updated.project = project
        updated.ticket = ticket
        updated.note = note.nilIfEmpty
        updated.date = date
        updated.seconds = Int((minutes * 60).rounded())
        store.update(updated)
        dismiss()
    }
}
