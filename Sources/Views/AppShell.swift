import AppKit
import SwiftUI

enum AppSection: Int, CaseIterable, Identifiable {
    case time
    case overview
    case masterData

    var id: Int { rawValue }
    var title: String {
        switch self {
        case .time: return "Zeiten"
        case .overview: return "Übersicht"
        case .masterData: return "Stammdaten"
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var store: MinutoStore
    @State private var selection: AppSection = .time
    @State private var showManualEntry = false
    @State private var showHelp = false

    var body: some View {
        VStack(spacing: 0) {
            applicationHeader
            Divider()

            if let activeTimer = store.activeTimer {
                ActiveTimerBanner(entry: activeTimer)
            }

            content
        }
        .onReceive(NotificationCenter.default.publisher(for: .minutoStartManualEntry)) { _ in
            selection = .time
            showManualEntry = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .minutoSelectArea)) { notification in
            if let area = notification.object as? AppSection {
                selection = area
            }
        }
        .sheet(isPresented: $showHelp) {
            HelpView()
        }
        .alert(
            "Minuto",
            isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } }),
            actions: { Button("OK") { store.error = nil } },
            message: { Text(store.error ?? "") }
        )
        .confirmationDialog(
            store.pendingImport?.title ?? "Daten importieren",
            isPresented: Binding(get: { store.pendingImport != nil }, set: { if !$0 { store.cancelPendingImport() } }),
            titleVisibility: .visible
        ) {
            if store.pendingImport?.replacesExistingData == true {
                Button("Wiederherstellen", role: .destructive) { store.confirmPendingImport() }
            } else {
                Button("Importieren") { store.confirmPendingImport() }
            }
            Button("Abbrechen", role: .cancel) { store.cancelPendingImport() }
        } message: {
            Text(store.pendingImport?.summary ?? "")
        }
    }

    private var applicationHeader: some View {
        HStack {
            AppBrandView()
            Spacer()
            Picker("Bereich", selection: $selection) {
                ForEach(AppSection.allCases) { area in
                    Text(area.title).tag(area)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 360)
            .accessibilityIdentifier("main-navigation")
            Spacer()
            saveState
            dataMenu
            Button {
                showHelp = true
            } label: {
                Label("Hilfe", systemImage: "questionmark.circle")
            }
            .buttonStyle(.bordered)
            .help("Hilfe und Tastenkombinationen")
            .accessibilityIdentifier("help-button")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(.bar)
    }

    private var saveState: some View {
        Text(store.saveState.title)
            .font(.caption)
            .foregroundStyle(store.saveState == .failed ? .red : .secondary)
            .accessibilityLabel("Datenstatus: \(store.saveState.title)")
            .frame(minWidth: 112, alignment: .trailing)
    }

    private var dataMenu: some View {
        Menu("Daten") {
            Button("Sicherung exportieren") { store.exportBackup() }
            Button("Einträge importieren und zusammenführen") { store.importBackup(replace: false) }
            Button("Einträge wiederherstellen") { store.importBackup(replace: true) }
            Divider()
            Button("Datenordner öffnen") { store.openFolder() }
        }
        .accessibilityIdentifier("data-menu")
    }

    @ViewBuilder
    private var content: some View {
        if store.isLoading {
            Spacer()
            ProgressView("Daten werden geladen …")
            Spacer()
        } else if selection == .time {
            TimeWorkspace(showManualEntry: $showManualEntry)
        } else if selection == .overview {
            OverviewView()
        } else {
            MasterDataWorkspace()
        }
    }
}

struct AppBrandView: View {
    private let appIcon = Bundle.main.url(forResource: "Minuto", withExtension: "icns").flatMap(NSImage.init(contentsOf:))

    var body: some View {
        HStack(spacing: 9) {
            if let appIcon {
                Image(nsImage: appIcon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 28, height: 28)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: "timer")
                    .font(.title3)
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
            }
            Text("Minuto").font(.headline.weight(.semibold))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Minuto")
    }
}

struct ActiveTimerBanner: View {
    @EnvironmentObject private var store: MinutoStore
    let entry: TimeEntry

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "timer").foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 1) {
                Text("Timer läuft")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Text("\(entry.customer) · \(entry.project) · \(entry.ticket)")
                    .lineLimit(1)
            }
            Spacer()
            TimerText(start: entry.startedAt ?? Date())
            Button("Stoppen & speichern") { store.stop(entry) }
                .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 9)
        .background(Color.accentColor.opacity(0.10))
        .accessibilityIdentifier("active-timer")
    }
}

struct TimeWorkspace: View {
    @Binding var showManualEntry: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                TimeEntryForm(showManualEntry: $showManualEntry)
                EntryList()
            }
            .padding(24)
        }
    }
}

struct MasterDataWorkspace: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Stammdaten").font(.largeTitle.bold())
                Text("Kunden, Projekte und Abrechnungstickets für die schnelle Zeiterfassung verwalten.")
                    .foregroundStyle(.secondary)
                MasterDataView()
            }
            .padding(24)
        }
    }
}
