import Foundation

@MainActor extension MinutoStore {
    func add(_ entry: TimeEntry) {
        entries.append(entry)
        sortEntries()
        persist()
    }

    func update(_ entry: TimeEntry) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[index] = entry
        sortEntries()
        persist()
    }

    func delete(_ entry: TimeEntry) {
        entries.removeAll { $0.id == entry.id }
        persist()
    }

    func stop(_ entry: TimeEntry) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }), let start = entries[index].startedAt else { return }
        entries[index].seconds = max(1, Int(Date().timeIntervalSince(start)))
        entries[index].startedAt = nil
        persist()
    }

    func close(_ entry: TimeEntry) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[index].billed = true
        entries[index].billingTicket = entry.billingTicket ?? billingTicket(for: entry)
        persist()
    }

    func reopen(_ entry: TimeEntry) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[index].billed = false
        persist()
    }

    var activeTimer: TimeEntry? {
        entries.first { $0.startedAt != nil }
    }
}
