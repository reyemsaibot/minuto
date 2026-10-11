import SwiftUI

@main struct MinutoApp: App {
    @StateObject private var store = MinutoStore()
    var body: some Scene {
        WindowGroup("Minuto") { RootView().environmentObject(store).frame(minWidth: 1120, minHeight: 700) }
            .windowStyle(.titleBar)
            .commands {
                CommandGroup(after: .newItem) {
                    Button("Manuelle Zeiterfassung") { NotificationCenter.default.post(name: .minutoStartManualEntry, object: nil) }
                        .keyboardShortcut("n", modifiers: .command)
                }
                CommandMenu("Bereiche") {
                    Button("Zeiten") { selectArea(0) }.keyboardShortcut("1", modifiers: .command)
                    Button("Übersicht") { selectArea(1) }.keyboardShortcut("2", modifiers: .command)
                    Button("Stammdaten") { selectArea(2) }.keyboardShortcut("3", modifiers: .command)
                }
            }
    }

    private func selectArea(_ area: Int) {
        NotificationCenter.default.post(name: .minutoSelectArea, object: area)
    }
}
