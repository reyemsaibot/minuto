import AppKit
import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: MinutoStore
    @State private var selection = 0
    @State private var showManualEntry = false
    @State private var showHelp = false
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                AppBrandView()
                Spacer()
                Picker("Bereich", selection: $selection) { Text("Zeiten").tag(0); Text("Übersicht").tag(1); Text("Stammdaten").tag(2) }
                    .pickerStyle(.segmented)
                    .frame(width: 360)
                    .accessibilityIdentifier("main-navigation")
                Spacer()
                Menu("Daten") {
                    Button("Sicherung exportieren") { store.exportBackup() }
                    Button("Einträge importieren und zusammenführen") { store.importBackup(replace: false) }
                    Button("Einträge wiederherstellen") { store.importBackup(replace: true) }
                    Divider()
                    Button("Datenordner öffnen") { store.openFolder() }
                }.accessibilityIdentifier("data-menu")
                Button { showHelp = true } label: { Label("Hilfe", systemImage: "questionmark.circle") }
                    .buttonStyle(.bordered)
                    .help("Hilfe und Tastenkombinationen")
                    .accessibilityIdentifier("help-button")
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(.bar)
            Divider()
            if let activeTimer = store.activeTimer { ActiveTimerBanner(entry: activeTimer) }
            if store.isLoading {
                Spacer()
                ProgressView("Daten werden geladen …")
                Spacer()
            } else if selection == 0 { TimeWorkspace(showManualEntry: $showManualEntry) }
            else if selection == 1 { OverviewView() }
            else { MasterDataWorkspace() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .minutoStartManualEntry)) { _ in
            selection = 0
            showManualEntry = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .minutoSelectArea)) { notification in
            if let area = notification.object as? Int { selection = area }
        }
        .sheet(isPresented: $showHelp) { HelpView() }
        .alert("Minuto", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } }), actions: { Button("OK") { store.error = nil } }, message: { Text(store.error ?? "") })
    }
}

struct AppBrandView: View {
    private let appIcon = Bundle.main.url(forResource: "Minuto", withExtension: "icns").flatMap(NSImage.init(contentsOf:))

    var body: some View {
        HStack(spacing: 9) {
            if let appIcon { Image(nsImage: appIcon).resizable().interpolation(.high).frame(width: 28, height: 28).accessibilityHidden(true) }
            else { Image(systemName: "timer").font(.title3).foregroundStyle(.tint).accessibilityHidden(true) }
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
                Text("Timer läuft").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                Text("\(entry.customer) · \(entry.project) · \(entry.ticket)").lineLimit(1)
            }
            Spacer()
            TimerText(start: entry.startedAt ?? Date())
            Button("Stoppen & speichern") { store.stop(entry) }.buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 9)
        .background(Color.accentColor.opacity(0.10))
        .accessibilityIdentifier("active-timer")
    }
}

struct TimeWorkspace: View {
    @Binding var showManualEntry: Bool
    var body: some View { ScrollView { VStack(alignment: .leading, spacing: 18) { TimeEntryForm(showManualEntry: $showManualEntry); EntryList() }.padding(24) } }
}

struct MasterDataWorkspace: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Stammdaten").font(.largeTitle.bold())
                Text("Kunden, Projekte und Abrechnungstickets für die schnelle Zeiterfassung verwalten.").foregroundStyle(.secondary)
                MasterDataView()
            }.padding(24)
        }
    }
}
