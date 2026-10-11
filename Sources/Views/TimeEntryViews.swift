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
    @State private var showValidation = false
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
            if showValidation, !missingFields.isEmpty {
                Label("Bitte ergänzen: \(missingFields.joined(separator: ", "))", systemImage: "exclamationmark.circle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .accessibilityLabel("Fehlende Pflichtfelder: \(missingFields.joined(separator: ", "))")
            }
            if !suggestedMasters.isEmpty {
                MasterDataSuggestions(masters: suggestedMasters) { master in
                    customer = master.customer
                    project = master.project
                }
            }
        }.padding(4) } label: { Text("Zeiten erfassen").font(.headline) }
        .task(id: showManualEntry) { consumeManualEntryRequest() }
    }
    private var missingFields: [String] {
        var fields: [String] = []
        if customer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { fields.append("Kunde") }
        if project.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { fields.append("Projekt") }
        if ticket.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { fields.append("Jira-Ticket") }
        if manual && minutes <= 0 { fields.append("Dauer") }
        return fields
    }
    private var suggestedMasters: [MasterData] {
        let searchTerms = [customer, project].map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !searchTerms.isEmpty else { return [] }
        return store.activeMasters.filter { master in
            searchTerms.allSatisfy { term in
                master.customer.localizedCaseInsensitiveContains(term) || master.project.localizedCaseInsensitiveContains(term)
            }
        }.prefix(5).map { $0 }
    }
    private func start() {
        guard validateRequiredFields(), store.activeTimer == nil else { return }
        let startedAt = Date()
        store.add(TimeEntry(id: UUID(), customer: customer, project: project, ticket: ticket, date: MinutoTimerPolicy.entryDate(for: startedAt), seconds: 0, startedAt: startedAt, billed: false, billingTicket: nil, note: note.nilIfEmpty))
        reset()
    }
    private func save() {
        guard validateRequiredFields() else { return }
        store.add(TimeEntry(id: UUID(), customer: customer, project: project, ticket: ticket, date: date, seconds: Int(minutes * 60), startedAt: nil, billed: false, billingTicket: nil, note: note.nilIfEmpty))
        reset()
    }
    private func validateRequiredFields() -> Bool {
        guard missingFields.isEmpty else {
            showValidation = true
            if customer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { focusedField = .customer }
            else if project.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { focusedField = .project }
            else if ticket.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { focusedField = .ticket }
            return false
        }
        showValidation = false
        return true
    }
    private func reset() { customer = ""; project = ""; ticket = ""; note = ""; minutes = 60; date = Date(); showValidation = false }
    private func consumeManualEntryRequest() { guard showManualEntry else { return }; manual = true; date = Date(); showManualEntry = false; DispatchQueue.main.async { focusedField = .customer } }
}

struct MasterDataSuggestions: View {
    let masters: [MasterData]
    let onSelect: (MasterData) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Vorschläge aus Stammdaten").font(.caption).foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(masters) { master in
                        Button {
                            onSelect(master)
                        } label: {
                            Label("\(master.customer) · \(master.project)", systemImage: master.favorite ? "star.fill" : "person.crop.circle")
                        }
                        .buttonStyle(.bordered)
                        .help("\(master.customer), \(master.project) übernehmen")
                    }
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
        return store.entries.filter { entry in
            (status == 2 || (status == 0 ? !entry.billed : entry.billed)) &&
            (customer.isEmpty || entry.customer.localizedCaseInsensitiveContains(customer)) &&
            (ticket.isEmpty || entry.ticket.localizedCaseInsensitiveContains(ticket)) &&
            (note.isEmpty || (entry.note ?? "").localizedCaseInsensitiveContains(note)) &&
            MinutoDateRange.contains(entry.date, from: from, to: to)
        }
    }
    var body: some View { GroupBox("Zeiteinträge") { VStack(alignment: .leading, spacing: 10) {
        HStack {
            ClearableSearchField("Kunde filtern", text: $customer)
            ClearableSearchField("Jira-Ticket", text: $ticket)
            ClearableSearchField("Notiz", text: $note)
            DatePicker("Von", selection: $from, displayedComponents: .date)
            DatePicker("Bis", selection: $to, displayedComponents: .date)
        }
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
        Text(text).foregroundStyle(.secondary)
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
