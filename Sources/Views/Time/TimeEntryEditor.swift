import SwiftUI

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
    @State private var showValidation = false
    @FocusState private var focusedField: EntryField?

    private enum EntryField: Hashable {
        case customer
        case project
        case ticket
        case minutes
    }

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
            Text("Zeiteintrag bearbeiten")
                .font(.title2.bold())
            Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                GridRow {
                    TextField("Kunde", text: $customer).focused($focusedField, equals: .customer)
                    TextField("Projekt", text: $project).focused($focusedField, equals: .project)
                }
                GridRow {
                    TextField("Jira-Ticket", text: $ticket).focused($focusedField, equals: .ticket)
                    TextField("Minuten", value: $minutes, format: .number).focused($focusedField, equals: .minutes)
                }
                GridRow {
                    DatePicker("Datum", selection: $date, displayedComponents: .date)
                    EmptyView()
                }
            }
            TextField("Notiz", text: $note)
            if showValidation, !missingFields.isEmpty {
                Label("Bitte ergänzen: \(missingFields.joined(separator: ", "))", systemImage: "exclamationmark.circle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .accessibilityLabel("Fehlende Pflichtfelder: \(missingFields.joined(separator: ", "))")
            }
            HStack {
                Spacer()
                Button("Abbrechen") { dismiss() }
                Button("Speichern") { save() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 520)
    }

    private func save() {
        guard validateRequiredFields() else { return }
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

    private var missingFields: [String] {
        var fields: [String] = []
        if customer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { fields.append("Kunde") }
        if project.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { fields.append("Projekt") }
        if ticket.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { fields.append("Jira-Ticket") }
        if minutes <= 0 { fields.append("Dauer") }
        return fields
    }

    private func validateRequiredFields() -> Bool {
        guard !missingFields.isEmpty else {
            showValidation = false
            return true
        }
        showValidation = true
        if customer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { focusedField = .customer }
        else if project.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { focusedField = .project }
        else if ticket.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { focusedField = .ticket }
        else { focusedField = .minutes }
        return false
    }
}
