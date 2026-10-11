import SwiftUI

struct MasterDataView: View {
    @EnvironmentObject private var store: MinutoStore
    @State private var customer = ""
    @State private var project = ""
    @State private var billingTicket = ""
    var body: some View { GroupBox("Kunde · Projekt · Abrechnungsticket") { VStack(alignment: .leading, spacing: 12) { HStack { TextField("Kunde", text: $customer); TextField("Projekt", text: $project); TextField("Abrechnungsticket", text: $billingTicket); Button("Hinzufügen") { guard !customer.isEmpty, !project.isEmpty, !billingTicket.isEmpty else { return }; store.masters.append(MasterData(id: UUID(), customer: customer, project: project, billingTicket: billingTicket)); store.saveMasters(); customer = ""; project = ""; billingTicket = "" }.buttonStyle(.borderedProminent) }
        Divider()
        if store.masters.isEmpty { Text("Noch keine Stammdaten hinterlegt.").foregroundStyle(.secondary).padding(.vertical, 10) }
        ForEach(store.masters) { master in HStack { Text(master.customer).frame(width: 180, alignment: .leading); Text(master.project).frame(width: 180, alignment: .leading); Text(master.billingTicket); Spacer(); Button(master.favorite ? "★" : "☆") { toggleFavorite(master) }.help("Favorit"); Button(master.active ? "Archivieren" : "Aktivieren") { toggleActive(master) }; Button(role: .destructive) { store.masters.removeAll { $0.id == master.id }; store.saveMasters() } label: { Image(systemName: "trash") }.help("Löschen") } } }.padding(6) }
    }
    private func toggleFavorite(_ master: MasterData) { guard let i = store.masters.firstIndex(of: master) else { return }; store.masters[i].favorite.toggle(); store.saveMasters() }
    private func toggleActive(_ master: MasterData) { guard let i = store.masters.firstIndex(of: master) else { return }; store.masters[i].active.toggle(); store.saveMasters() }
}
