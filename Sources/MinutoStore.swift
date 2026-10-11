import Foundation
import SwiftUI

@MainActor final class MinutoStore: ObservableObject {
    @Published var entries: [TimeEntry] = []
    @Published var masters: [MasterData] = []
    @Published var weekClosures: [WeekClosure] = []
    @Published var dailyTarget = 8.0 {
        didSet {
            if !isLoading { persist() }
        }
    }
    @Published var error: String?
    @Published private(set) var isLoading = true

    let repository: MinutoRepository
    let dataFolder: URL

    init(folder: URL? = nil, legacyFolder: URL? = nil) {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let current = folder ?? support.appendingPathComponent("Minuto")
        let legacy = legacyFolder ?? support.appendingPathComponent("Kundenzeit")
        dataFolder = current
        repository = MinutoRepository(folder: current, legacyFolder: legacy)
        let migratedTarget = UserDefaults.standard.object(forKey: "dailyTarget") as? Double ?? 8

        Task { await load(defaultDailyTarget: migratedTarget) }
    }

    func load(defaultDailyTarget: Double) async {
        do {
            let snapshot = try await repository.load(defaultDailyTarget: defaultDailyTarget)
            entries = snapshot.entries
            masters = snapshot.masters
            dailyTarget = snapshot.dailyTarget
            weekClosures = snapshot.weekClosures
            sortEntries()
        } catch {
            self.error = "Daten konnten nicht geladen werden: \(Self.userMessage(for: error))"
        }
        isLoading = false
    }

    func currentSnapshot() -> MinutoSnapshot {
        MinutoSnapshot(entries: entries, masters: masters, dailyTarget: dailyTarget, weekClosures: weekClosures)
    }

    func persist() {
        guard !isLoading else { return }
        let snapshot = currentSnapshot()
        Task {
            do {
                try await repository.save(snapshot)
            } catch {
                self.error = "Änderung konnte nicht gesichert werden: \(Self.userMessage(for: error))"
            }
        }
    }

    func sortEntries() {
        entries.sort {
            $0.date == $1.date ? $0.id.uuidString > $1.id.uuidString : $0.date > $1.date
        }
    }

    static func userMessage(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? "Bitte prüfe die gewählte Sicherungsdatei und versuche es erneut."
    }
}

extension Notification.Name {
    static let minutoStartManualEntry = Notification.Name("minutoStartManualEntry")
    static let minutoSelectArea = Notification.Name("minutoSelectArea")
}
