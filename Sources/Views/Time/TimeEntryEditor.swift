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
                    TextField("Kunde", text: $customer)
                    TextField("Projekt", text: $project)
                }
                GridRow {
                    TextField("Jira-Ticket", text: $ticket)
                    TextField("Minuten", value: $minutes, format: .number)
                }
                GridRow {
                    DatePicker("Datum", selection: $date, displayedComponents: .date)
                    EmptyView()
                }
            }
            TextField("Notiz", text: $note)
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
