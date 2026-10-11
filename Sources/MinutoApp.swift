import SwiftUI

@main struct MinutoApp: App {
    @StateObject private var store = MinutoStore()
    var body: some Scene {
        WindowGroup("Minuto") { RootView().environmentObject(store).frame(minWidth: 980, minHeight: 700) }
            .windowStyle(.titleBar)
            .commands {
                CommandGroup(after: .newItem) {
                    Button("Manuelle Zeiterfassung") { NotificationCenter.default.post(name: .minutoStartManualEntry, object: nil) }
                        .keyboardShortcut("n", modifiers: .command)
                }
            }
    }
}
