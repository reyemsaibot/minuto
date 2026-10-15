import SwiftUI

struct MasterDataView: View {
    @EnvironmentObject private var store: MinutoStore
    @State private var customer = ""
    @State private var project = ""
    @State private var billingTicket = ""
    @State private var editing: MasterData?
    @State private var resolution: MasterDataResolution?
    @State private var masterPendingDeletion: MasterData?

    var body: some View {
        GroupBox("Kunde · Projekt · Abrechnungsticket") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    TextField("Kunde", text: $customer)
                    TextField("Projekt", text: $project)
                    TextField("Abrechnungsticket", text: $billingTicket)
                    Button("Hinzufügen") {
                        store.addMaster(customer: customer, project: project, billingTicket: billingTicket)
                        if store.error == nil { customer = ""; project = ""; billingTicket = "" }
                    }
                    .buttonStyle(.borderedProminent)
                }
                if !store.masterConflicts.isEmpty {
                    DuplicateMasterDataNotice(conflicts: store.masterConflicts) { conflict, master in
                        resolution = MasterDataResolution(conflict: conflict, keeping: master)
                    }
                }
                Divider()
                if store.masters.isEmpty {
                    Text("Noch keine Stammdaten hinterlegt.").foregroundStyle(.secondary).padding(.vertical, 10)
                }
                ForEach(store.masters) { master in
                    MasterDataRow(master: master, edit: { editing = master }, delete: { masterPendingDeletion = master })
                }
            }
            .padding(6)
        }
        .sheet(item: $editing) { MasterDataEditor(master: $0) }
        .confirmationDialog("Dubletten bereinigen", isPresented: Binding(get: { resolution != nil }, set: { if !$0 { resolution = nil } })) {
            if let resolution {
                Button("\(resolution.keeping.billingTicket) behalten, übrige löschen", role: .destructive) {
                    store.resolveMasterConflict(resolution.conflict, keeping: resolution.keeping)
                    self.resolution = nil
                }
                Button("Abbrechen", role: .cancel) { self.resolution = nil }
            }
        } message: {
            if let resolution { Text("Für \(resolution.conflict.customer) · \(resolution.conflict.project) bleibt nur das ausgewählte Abrechnungsticket erhalten. Die anderen \(resolution.conflict.masters.count - 1) Stammdaten werden gelöscht. Eine automatische Sicherung wird vorher erstellt.") }
        }
        .confirmationDialog(
            "Stammdaten löschen?",
            isPresented: Binding(get: { masterPendingDeletion != nil }, set: { if !$0 { masterPendingDeletion = nil } }),
            titleVisibility: .visible
        ) {
            Button("Endgültig löschen", role: .destructive) {
                if let masterPendingDeletion { store.deleteMaster(masterPendingDeletion) }
                masterPendingDeletion = nil
            }
            Button("Abbrechen", role: .cancel) { masterPendingDeletion = nil }
        } message: {
            if let masterPendingDeletion {
                Text("\(masterPendingDeletion.customer) · \(masterPendingDeletion.project) wird aus den Stammdaten gelöscht. Bestehende Zeiteinträge bleiben erhalten.")
            }
        }
    }
}

private struct MasterDataResolution: Identifiable {
    let conflict: MasterDataConflict
    let keeping: MasterData
    var id: String { "\(conflict.id)-\(keeping.id)" }
}

private struct DuplicateMasterDataNotice: View {
    let conflicts: [MasterDataConflict]
    let select: (MasterDataConflict, MasterData) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Doppelte Stammdaten müssen bereinigt werden, damit Abrechnungstickets eindeutig bleiben.", systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.orange)
            ForEach(conflicts) { conflict in
                HStack {
                    Text("\(conflict.customer) · \(conflict.project)").font(.caption.weight(.semibold))
                    Menu("Abrechnungsticket wählen") {
                        ForEach(conflict.masters) { master in
                            Button("\(master.billingTicket) behalten") { select(conflict, master) }
                        }
                    }
                    .controlSize(.small)
                }
            }
        }
        .padding(8)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct MasterDataRow: View {
    @EnvironmentObject private var store: MinutoStore
    let master: MasterData
    let edit: () -> Void
    let delete: () -> Void

    var body: some View {
        HStack {
            Text(master.customer).frame(width: 180, alignment: .leading)
            Text(master.project).frame(width: 180, alignment: .leading)
            Text(master.billingTicket)
            Spacer()
            Button(master.favorite ? "★" : "☆") { var value = master; value.favorite.toggle(); store.updateMaster(value) }
                .help("Favorit")
                .accessibilityLabel(master.favorite ? "Favorit entfernen" : "Als Favorit markieren")
            Button(master.active ? "Archivieren" : "Aktivieren") { var value = master; value.active.toggle(); store.updateMaster(value) }
            Button { edit() } label: { Image(systemName: "pencil") }
                .help("Stammdaten bearbeiten")
                .accessibilityLabel("Stammdaten bearbeiten")
            Button(role: .destructive, action: delete) { Image(systemName: "trash") }
                .help("Löschen")
                .accessibilityLabel("Stammdaten löschen")
        }
    }
}

private struct MasterDataEditor: View {
    @EnvironmentObject private var store: MinutoStore
    @Environment(\.dismiss) private var dismiss
    let master: MasterData
    @State private var customer: String
    @State private var project: String
    @State private var billingTicket: String
    @State private var favorite: Bool
    @State private var active: Bool

    init(master: MasterData) {
        self.master = master
        _customer = State(initialValue: master.customer)
        _project = State(initialValue: master.project)
        _billingTicket = State(initialValue: master.billingTicket)
        _favorite = State(initialValue: master.favorite)
        _active = State(initialValue: master.active)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Stammdaten bearbeiten").font(.title2.bold())
            TextField("Kunde", text: $customer)
            TextField("Projekt", text: $project)
            TextField("Abrechnungsticket", text: $billingTicket)
            Toggle("Favorit", isOn: $favorite)
            Toggle("Aktiv", isOn: $active)
            HStack {
                Spacer()
                Button("Abbrechen") { dismiss() }
                Button("Speichern") {
                    let value = MasterData(id: master.id, customer: customer, project: project, billingTicket: billingTicket, favorite: favorite, active: active)
                    if store.updateMaster(value) { dismiss() }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(minWidth: 460)
    }
}
