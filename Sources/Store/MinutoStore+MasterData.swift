import Foundation

@MainActor extension MinutoStore {
    func addMaster(customer: String, project: String, billingTicket: String) {
        let master = normalizedMaster(id: UUID(), customer: customer, project: project, billingTicket: billingTicket)
        guard isComplete(master) else {
            error = "Bitte Kunde, Projekt und Abrechnungsticket ausfüllen."
            return
        }
        guard !masters.contains(where: { $0.normalizedKey == master.normalizedKey }) else {
            error = "Für \(master.customer) · \(master.project) existieren bereits Stammdaten."
            return
        }
        masters.append(master)
        persist()
    }

    @discardableResult
    func updateMaster(_ master: MasterData) -> Bool {
        guard let index = masters.firstIndex(where: { $0.id == master.id }) else { return false }
        let normalized = normalizedMaster(id: master.id, customer: master.customer, project: master.project, billingTicket: master.billingTicket, favorite: master.favorite, active: master.active)
        guard isComplete(normalized) else {
            error = "Bitte Kunde, Projekt und Abrechnungsticket ausfüllen."
            return false
        }
        guard !masters.enumerated().contains(where: { $0.offset != index && $0.element.normalizedKey == normalized.normalizedKey }) else {
            error = "Für \(normalized.customer) · \(normalized.project) existieren bereits Stammdaten."
            return false
        }
        masters[index] = normalized
        persist()
        return true
    }

    func deleteMaster(_ master: MasterData) {
        masters.removeAll { $0.id == master.id }
        persist()
    }

    func resolveMasterConflict(_ conflict: MasterDataConflict, keeping master: MasterData) {
        guard conflict.masters.contains(where: { $0.id == master.id }) else { return }
        masters.removeAll { $0.normalizedKey == conflict.id && $0.id != master.id }
        persist()
    }

    var masterConflicts: [MasterDataConflict] {
        MasterDataRules.conflicts(in: masters)
    }

    var activeMasters: [MasterData] {
        masters.filter(\.active).sorted {
            $0.customer.localizedCaseInsensitiveCompare($1.customer) == .orderedAscending
        }
    }

    func billingTicket(for entry: TimeEntry) -> String? {
        if let ticket = entry.billingTicket { return ticket }
        let matches = matchingMasters(for: entry)
        guard matches.count <= 1 else { return nil }
        return matches.first?.billingTicket
    }

    func hasMasterConflict(for entry: TimeEntry) -> Bool {
        entry.billingTicket == nil && matchingMasters(for: entry).count > 1
    }

    private func normalizedMaster(id: UUID, customer: String, project: String, billingTicket: String, favorite: Bool = false, active: Bool = true) -> MasterData {
        MasterData(
            id: id,
            customer: customer.trimmingCharacters(in: .whitespacesAndNewlines),
            project: project.trimmingCharacters(in: .whitespacesAndNewlines),
            billingTicket: billingTicket.trimmingCharacters(in: .whitespacesAndNewlines),
            favorite: favorite,
            active: active
        )
    }

    private func isComplete(_ master: MasterData) -> Bool {
        !master.customer.isEmpty && !master.project.isEmpty && !master.billingTicket.isEmpty
    }

    private func matchingMasters(for entry: TimeEntry) -> [MasterData] {
        let key = MasterData(id: UUID(), customer: entry.customer, project: entry.project, billingTicket: "").normalizedKey
        return masters.filter { $0.active && $0.normalizedKey == key }
    }
}
