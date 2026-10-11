import SwiftUI

struct MasterDataView: View {
    @EnvironmentObject private var store: MinutoStore
    @State private var customer = ""
    @State private var project = ""
    @State private var billingTicket = ""

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
                if !duplicatePairs.isEmpty {
                    Label("Doppelte bestehende Stammdaten: \(duplicatePairs.joined(separator: ", ")). Bitte bereinigen, damit Abrechnungstickets eindeutig bleiben.", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                Divider()
                if store.masters.isEmpty {
                    Text("Noch keine Stammdaten hinterlegt.").foregroundStyle(.secondary).padding(.vertical, 10)
                }
                ForEach(store.masters) { master in
                    MasterDataRow(master: master)
                }
            }
            .padding(6)
        }
    }

    private var duplicatePairs: [String] {
        Dictionary(grouping: store.masters, by: \.normalizedKey).values
            .filter { $0.count > 1 }
            .compactMap { $0.first.map { "\($0.customer) · \($0.project)" } }
            .sorted()
    }
}

private struct MasterDataRow: View {
    @EnvironmentObject private var store: MinutoStore
    let master: MasterData

    var body: some View {
        HStack {
            Text(master.customer).frame(width: 180, alignment: .leading)
            Text(master.project).frame(width: 180, alignment: .leading)
            Text(master.billingTicket)
            Spacer()
            Button(master.favorite ? "★" : "☆") { var value = master; value.favorite.toggle(); store.updateMaster(value) }
                .help("Favorit")
            Button(master.active ? "Archivieren" : "Aktivieren") { var value = master; value.active.toggle(); store.updateMaster(value) }
            Button(role: .destructive) { store.deleteMaster(master) } label: { Image(systemName: "trash") }
                .help("Löschen")
        }
    }
}
