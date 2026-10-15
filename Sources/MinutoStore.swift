import Foundation
import SwiftUI

@MainActor final class MinutoStore: ObservableObject {
    @Published var entries: [TimeEntry] = []
    @Published var masters: [MasterData] = []
    @Published var weekClosures: [WeekClosure] = []
    @Published private(set) var dailyTarget = 8.0
    @Published var error: String?
    @Published private(set) var isLoading = true
    @Published private(set) var saveState: SaveState = .saved
    @Published var pendingImport: ImportPreview?

    let repository: MinutoRepository
    let dataFolder: URL
    private var saveTask: Task<Void, Never>?

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
        saveTask?.cancel()
        saveState = .saving
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            await save(snapshot, ignoresCancellation: false)
        }
    }

    func flushPendingSave() async {
        guard !isLoading else { return }
        saveTask?.cancel()
        if let saveTask { await saveTask.value }
        await save(currentSnapshot(), ignoresCancellation: true)
    }

    func setDailyTarget(_ value: Double) {
        let normalized = max(0, value)
        guard dailyTarget != normalized else { return }
        dailyTarget = normalized
        persist()
    }

    func restoreDailyTarget(_ value: Double) {
        dailyTarget = max(0, value)
    }

    private func save(_ snapshot: MinutoSnapshot, ignoresCancellation: Bool) async {
        do {
            try await repository.save(snapshot)
            guard ignoresCancellation || !Task.isCancelled else { return }
            saveState = .saved
        } catch {
            guard ignoresCancellation || !Task.isCancelled else { return }
            saveState = .failed
            self.error = "Änderung konnte nicht gesichert werden: \(Self.userMessage(for: error))"
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

enum SaveState: Equatable {
    case saved
    case saving
    case failed

    var title: String {
        switch self {
        case .saved: return "Gespeichert"
        case .saving: return "Wird gesichert …"
        case .failed: return "Speichern fehlgeschlagen"
        }
    }
}

extension Notification.Name {
    static let minutoStartManualEntry = Notification.Name("minutoStartManualEntry")
    static let minutoSelectArea = Notification.Name("minutoSelectArea")
}
