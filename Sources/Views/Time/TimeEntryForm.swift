import Combine
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
    @State private var date = MinutoManualEntryDatePolicy.defaultDate()
    @State private var dateWasChosenByUser = false
    @State private var wasManual = false
    @State private var showValidation = false
    @FocusState private var focusedField: EntryField?

    private enum EntryField: Hashable {
        case customer
        case project
        case ticket
        case note
    }

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 14) {
                captureTypePicker
                entryFields
                manualNoteAndSave
                validationMessage
                masterDataSuggestions
            }
            .padding(4)
        } label: {
            Text("Zeiten erfassen").font(.headline)
        }
        .task(id: showManualEntry) {
            consumeManualEntryRequest()
        }
        .onReceive(Just(manual)) { isManual in
            defer { wasManual = isManual }
            guard isManual, !wasManual, MinutoManualEntryDatePolicy.shouldRefreshDefaultDate(dateWasChosenByUser: dateWasChosenByUser) else { return }
            date = MinutoManualEntryDatePolicy.defaultDate()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            guard manual, MinutoManualEntryDatePolicy.shouldRefreshDefaultDate(dateWasChosenByUser: dateWasChosenByUser) else { return }
            date = MinutoManualEntryDatePolicy.defaultDate()
        }
    }

    private var captureTypePicker: some View {
        HStack {
            Picker("Art", selection: $manual) {
                Text("Timer").tag(false)
                Text("Manuell").tag(true)
            }
            .pickerStyle(.segmented)
            .frame(width: 200)

            Spacer()

            if store.activeTimer != nil {
                Label("Timer läuft", systemImage: "timer")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var entryFields: some View {
        Grid(horizontalSpacing: 12, verticalSpacing: 12) {
            GridRow {
                labeledTextField("Kunde", text: $customer, field: .customer)
                labeledTextField("Projekt", text: $project, field: .project)
                labeledTextField("Jira-Ticket", text: $ticket, field: .ticket)
            }

            if manual {
                GridRow {
                    dateField
                    TextField("Minuten", value: $minutes, format: .number)
                        .accessibilityLabel("Dauer in Minuten")
                    EmptyView()
                }
            } else {
                GridRow {
                    TextField("Notiz (optional)", text: $note)
                        .focused($focusedField, equals: .note)
                    Button("Timer starten") { start() }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(" ", modifiers: [])
                        .help("Timer starten (Leertaste)")
                    EmptyView()
                }
            }
        }
    }

    @ViewBuilder
    private var manualNoteAndSave: some View {
        if manual {
            TextField("Notiz (optional)", text: $note)
                .focused($focusedField, equals: .note)
            HStack {
                Spacer()
                Button("Zeit speichern") { save() }
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    private var dateField: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Datum")
                .font(.caption)
                .foregroundStyle(.secondary)
            DatePicker("Datum", selection: Binding(
                get: { date },
                set: { selectedDate in
                    date = selectedDate
                    dateWasChosenByUser = true
                }
            ), displayedComponents: .date)
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var validationMessage: some View {
        if showValidation, !missingFields.isEmpty {
            Label("Bitte ergänzen: \(missingFields.joined(separator: ", "))", systemImage: "exclamationmark.circle")
                .font(.caption)
                .foregroundStyle(.orange)
                .accessibilityLabel("Fehlende Pflichtfelder: \(missingFields.joined(separator: ", "))")
        }
    }

    @ViewBuilder
    private var masterDataSuggestions: some View {
        if !suggestedMasters.isEmpty {
            MasterDataSuggestions(masters: suggestedMasters) { master in
                customer = master.customer
                project = master.project
            }
        }
    }

    private func labeledTextField(_ title: String, text: Binding<String>, field: EntryField) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(title, text: text)
                .focused($focusedField, equals: field)
        }
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
        let customerTerm = customer.trimmingCharacters(in: .whitespacesAndNewlines)
        let projectTerm = project.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !customerTerm.isEmpty || !projectTerm.isEmpty else { return [] }

        return store.activeMasters.filter { master in
            (customerTerm.isEmpty || master.customer.localizedCaseInsensitiveContains(customerTerm))
                && (projectTerm.isEmpty || master.project.localizedCaseInsensitiveContains(projectTerm))
        }
        .prefix(5)
        .map { $0 }
    }

    private func start() {
        guard validateRequiredFields(), store.activeTimer == nil else { return }
        let startedAt = Date()
        store.add(
            TimeEntry(
                id: UUID(),
                customer: customer,
                project: project,
                ticket: ticket,
                date: MinutoTimerPolicy.entryDate(for: startedAt),
                seconds: 0,
                startedAt: startedAt,
                billed: false,
                billingTicket: nil,
                note: note.nilIfEmpty
            )
        )
        reset()
    }

    private func save() {
        guard validateRequiredFields() else { return }
        store.add(
            TimeEntry(
                id: UUID(),
                customer: customer,
                project: project,
                ticket: ticket,
                date: date,
                seconds: Int(minutes * 60),
                startedAt: nil,
                billed: false,
                billingTicket: nil,
                note: note.nilIfEmpty
            )
        )
        reset()
    }

    private func validateRequiredFields() -> Bool {
        guard missingFields.isEmpty else {
            showValidation = true
            if customer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                focusedField = .customer
            } else if project.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                focusedField = .project
            } else if ticket.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                focusedField = .ticket
            }
            return false
        }
        showValidation = false
        return true
    }

    private func reset() {
        customer = ""
        project = ""
        ticket = ""
        note = ""
        minutes = 60
        resetManualDateToToday()
        showValidation = false
    }

    private func consumeManualEntryRequest() {
        guard showManualEntry else { return }
        manual = true
        resetManualDateToToday()
        showManualEntry = false
        DispatchQueue.main.async {
            focusedField = .customer
        }
    }

    private func resetManualDateToToday() {
        date = MinutoManualEntryDatePolicy.defaultDate()
        dateWasChosenByUser = false
    }
}

struct MasterDataSuggestions: View {
    let masters: [MasterData]
    let onSelect: (MasterData) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Vorschläge aus Stammdaten")
                .font(.caption)
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(masters) { master in
                        Button {
                            onSelect(master)
                        } label: {
                            Label(
                                "\(master.customer) · \(master.project)",
                                systemImage: master.favorite ? "star.fill" : "person.crop.circle"
                            )
                        }
                        .buttonStyle(.bordered)
                        .help("\(master.customer), \(master.project) übernehmen")
                    }
                }
            }
        }
    }
}
