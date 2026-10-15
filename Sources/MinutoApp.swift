import AppKit
import SwiftUI

final class MinutoApplicationDelegate: NSObject, NSApplicationDelegate {
    weak var store: MinutoStore?

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let store else { return .terminateNow }
        Task { @MainActor in
            await store.flushPendingSave()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}

@main struct MinutoApp: App {
    @StateObject private var store = MinutoStore()
    @NSApplicationDelegateAdaptor(MinutoApplicationDelegate.self) private var applicationDelegate
    var body: some Scene {
        WindowGroup("Minuto") {
            RootView()
                .environmentObject(store)
                .frame(minWidth: 1120, minHeight: 700)
                .onAppear { applicationDelegate.store = store }
        }
            .windowStyle(.titleBar)
            .commands {
                CommandGroup(replacing: .newItem) {
                    Button("Manuelle Zeiterfassung") { NotificationCenter.default.post(name: .minutoStartManualEntry, object: nil) }
                        .keyboardShortcut("n", modifiers: .command)
                }
                CommandMenu("Bereiche") {
                    Button("Zeiten") { selectArea(.time) }.keyboardShortcut("1", modifiers: .command)
                    Button("Übersicht") { selectArea(.overview) }.keyboardShortcut("2", modifiers: .command)
                    Button("Stammdaten") { selectArea(.masterData) }.keyboardShortcut("3", modifiers: .command)
                }
            }
    }

    private func selectArea(_ area: AppSection) {
        NotificationCenter.default.post(name: .minutoSelectArea, object: area)
    }
}
