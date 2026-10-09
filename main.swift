import Cocoa
import WebKit
import Darwin

struct Entry: Codable {
    var id: String
    var customer: String
    var project: String
    var ticket: String
    var date: String
    var seconds: Int
    var started: Double?
    var active: Int?
    var billed: Int
    var billingTicket: String?
    var note: String?
}
struct MasterData: Codable, Equatable {
    var id: String
    var customer: String
    var project: String
    var ticket: String
    var favorite: Int?
    var active: Int?
}
struct AppError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
final class EntryStore {
    let directory: URL
    let file: URL
    let masterFile: URL
    private let encoder = JSONEncoder()
    private var lockFD: Int32 = -1
    init(directory: URL, seed: URL?) throws {
        self.directory = directory
        self.file = directory.appendingPathComponent("zeiten.json")
        self.masterFile = directory.appendingPathComponent("stammdaten.json")
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        lockFD = open(directory.appendingPathComponent(".lock").path, O_CREAT | O_RDWR, 0o600)
        guard lockFD >= 0, flock(lockFD, LOCK_EX | LOCK_NB) == 0 else { throw AppError(message: "Minuto ist bereits geöffnet. Bitte das vorhandene Fenster verwenden.") }
        if !FileManager.default.fileExists(atPath: file.path) {
            let initial: [Entry] = try seed.map { try JSONDecoder().decode([Entry].self, from: Data(contentsOf: $0)) } ?? []
            try encoder.encode(initial).write(to: file, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
        }
        if !FileManager.default.fileExists(atPath: masterFile.path) {
            try encoder.encode([MasterData]()).write(to: masterFile, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: masterFile.path)
        }
        _ = try read()
    }
    deinit { if lockFD >= 0 { flock(lockFD, LOCK_UN); close(lockFD) } }
    func read() throws -> [Entry] {
        do { return try JSONDecoder().decode([Entry].self, from: Data(contentsOf: file)).sorted { $0.date == $1.date ? $0.id > $1.id : $0.date > $1.date } }
        catch { throw AppError(message: "Die lokale Datendatei kann nicht gelesen werden. Sie wurde nicht überschrieben. Bitte zeiten.json im Datenordner prüfen oder eine Sicherung wiederherstellen.") }
    }
    func persist(_ entries: [Entry]) throws {
        let data = try encoder.encode(entries)
        let backups = directory.appendingPathComponent("Sicherungen")
        try FileManager.default.createDirectory(at: backups, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let name = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-") + "-" + UUID().uuidString + ".json"
        try Data(contentsOf: file).write(to: backups.appendingPathComponent(name), options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: backups.appendingPathComponent(name).path)
        try data.write(to: file, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
    }
    func mutate(_ p: [String: Any]) throws -> [Entry] {
        guard let action = p["action"] as? String, let id = p["id"] as? String, !id.isEmpty, id.count <= 100 else { throw AppError(message: "Ungültiger Eintrag.") }
        var entries = try read()
        let index = entries.firstIndex { $0.id == id }
        switch action {
        case "delete":
            if let i = index {
                guard entries[i].started == nil else { throw AppError(message: "Bitte den Timer zuerst stoppen.") }
                entries.remove(at: i)
            } else { return entries }
        case "bill":
            guard let i = index, entries[i].started == nil, let billed = p["billed"] as? Int, [0,1].contains(billed) else { throw AppError(message: "Der Status kann nicht geändert werden.") }
            if billed == 1 {
                if let raw = p["billingTicket"] as? String {
                    let billingTicket = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard billingTicket.count <= 160 else { throw AppError(message: "Das Abrechnungsticket ist zu lang.") }
                    entries[i].billingTicket = billingTicket.isEmpty ? nil : billingTicket
                }
            } else { entries[i].billingTicket = nil }
            entries[i].billed = billed
        case "stop":
            guard let i = index else { throw AppError(message: "Timer nicht gefunden.") }
            if let started = entries[i].started {
                entries[i].seconds = max(1, Int((Date().timeIntervalSince1970 * 1000 - started) / 1000))
                entries[i].started = nil; entries[i].active = nil
            } else { return entries }
        case "start", "add", "edit":
            func required(_ key: String) throws -> String {
                guard let value = p[key] as? String else { throw AppError(message: "Bitte Kunde, Projekt und Ticket ausfüllen.") }
                let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !clean.isEmpty, clean.count <= 160 else { throw AppError(message: "Bitte Kunde, Projekt und Ticket ausfüllen (maximal 160 Zeichen).") }
                return clean
            }
            let customer = try required("customer"), project = try required("project"), ticket = try required("ticket")
            let note = (p["note"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard note.count <= 1000 else { throw AppError(message: "Die Notiz darf maximal 1000 Zeichen lang sein.") }
            guard let date = p["date"] as? String else { throw AppError(message: "Ungültiges Datum.") }
            let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.dateFormat = "yyyy-MM-dd"; formatter.isLenient = false
            guard let parsed = formatter.date(from: date), formatter.string(from: parsed) == date else { throw AppError(message: "Ungültiges Datum.") }
            let seconds = (p["seconds"] as? NSNumber)?.doubleValue ?? 0
            guard action == "start" || (seconds.isFinite && seconds.rounded() == seconds && seconds >= 1 && seconds <= 86400) else { throw AppError(message: "Die Dauer muss zwischen einer Sekunde und 24 Stunden liegen.") }
            if action == "edit" {
                guard let i = index, entries[i].billed == 0, entries[i].started == nil else { throw AppError(message: "Dieser Eintrag kann nicht bearbeitet werden.") }
                entries[i].customer = customer; entries[i].project = project; entries[i].ticket = ticket; entries[i].date = date; entries[i].seconds = Int(seconds); entries[i].note = note.isEmpty ? nil : note
            } else {
                if index != nil { return entries }
                guard action != "start" || !entries.contains(where: { $0.started != nil }) else { throw AppError(message: "Es läuft bereits ein Timer.") }
                entries.append(Entry(id: id, customer: customer, project: project, ticket: ticket, date: date, seconds: action == "start" ? 0 : Int(seconds), started: action == "start" ? Date().timeIntervalSince1970 * 1000 : nil, active: action == "start" ? 1 : nil, billed: 0, billingTicket: nil, note: note.isEmpty ? nil : note))
            }
        default: throw AppError(message: "Unbekannte Aktion.")
        }
        try persist(entries)
        return try read()
    }
    func json(_ entries: [Entry]) throws -> Any {
        var rows = try JSONSerialization.jsonObject(with: encoder.encode(entries)) as! [[String: Any]]
        for i in rows.indices { if rows[i]["started"] == nil { rows[i]["started"] = NSNull() }; if rows[i]["active"] == nil { rows[i]["active"] = NSNull() } }
        return rows
    }
    func readMasters() throws -> [MasterData] {
        do { return try JSONDecoder().decode([MasterData].self, from: Data(contentsOf: masterFile)).sorted { ($0.customer, $0.project, $0.ticket) < ($1.customer, $1.project, $1.ticket) } }
        catch { throw AppError(message: "Die Stammdaten können nicht gelesen werden. Sie wurden nicht überschrieben.") }
    }
    func masterJSON() throws -> Any {
        try JSONSerialization.jsonObject(with: encoder.encode(readMasters()))
    }
    func mutateMaster(_ p: [String: Any]) throws -> Any {
        guard let action = p["action"] as? String else { throw AppError(message: "Ungültige Stammdaten-Aktion.") }
        var masters = try readMasters()
        if action == "delete" {
            guard let id = p["id"] as? String else { throw AppError(message: "Ungültige Zuordnung.") }
            masters.removeAll { $0.id == id }
        } else if action == "favorite" {
            guard let id = p["id"] as? String, let index = masters.firstIndex(where: { $0.id == id }) else { throw AppError(message: "Zuordnung nicht gefunden.") }
            masters[index].favorite = masters[index].favorite == 1 ? 0 : 1
        } else if action == "projectStatus" {
            guard let id = p["id"] as? String, let index = masters.firstIndex(where: { $0.id == id }) else { throw AppError(message: "Projekt nicht gefunden.") }
            masters[index].active = masters[index].active == 0 ? 1 : 0
        } else if action == "add" {
            func value(_ key: String) throws -> String {
                guard let raw = p[key] as? String else { throw AppError(message: "Bitte Kunde, Projekt und Abrechnungsticket ausfüllen.") }
                let clean = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !clean.isEmpty, clean.count <= 160 else { throw AppError(message: "Bitte Kunde, Projekt und Abrechnungsticket ausfüllen (maximal 160 Zeichen).") }
                return clean
            }
            let customer = try value("customer"), project = try value("project"), ticket = try value("ticket")
            if !masters.contains(where: { $0.customer.caseInsensitiveCompare(customer) == .orderedSame && $0.project.caseInsensitiveCompare(project) == .orderedSame && $0.ticket.caseInsensitiveCompare(ticket) == .orderedSame }) {
                masters.append(MasterData(id: UUID().uuidString, customer: customer, project: project, ticket: ticket, favorite: 0, active: 1))
            }
        } else { throw AppError(message: "Unbekannte Stammdaten-Aktion.") }
        try encoder.encode(masters).write(to: masterFile, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: masterFile.path)
        return try masterJSON()
    }
    func importEntries(_ imported: [Entry], replace: Bool) throws -> [Entry] {
        guard imported.allSatisfy({ !$0.id.isEmpty && !$0.customer.isEmpty && !$0.project.isEmpty && !$0.ticket.isEmpty && $0.seconds >= 0 }) else { throw AppError(message: "Die Datei enthält ungültige Zeiteinträge.") }
        let current = try read()
        let result: [Entry]
        if replace { result = imported }
        else {
            var byId = Dictionary(uniqueKeysWithValues: current.map { ($0.id, $0) })
            for entry in imported { byId[entry.id] = entry }
            result = Array(byId.values)
        }
        try persist(result)
        return try read()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, WKScriptMessageHandler, WKNavigationDelegate {
    var window: NSWindow!
    var webView: WKWebView!
    var store: EntryStore!
    var resources: URL!
    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            resources = Bundle.main.resourceURL!
            let args = CommandLine.arguments
            let directory: URL
            if let i = args.firstIndex(of: "--data-dir"), args.count > i + 1 { directory = URL(fileURLWithPath: args[i+1]) }
            else {
                let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                let minuto = support.appendingPathComponent("Minuto")
                let legacy = support.appendingPathComponent("Kundenzeit")
                if !FileManager.default.fileExists(atPath: minuto.path), FileManager.default.fileExists(atPath: legacy.path) {
                    try FileManager.default.copyItem(at: legacy, to: minuto)
                }
                directory = minuto
            }
            store = try EntryStore(directory: directory, seed: resources.appendingPathComponent("initial-entries.json"))
            let config = WKWebViewConfiguration()
            config.userContentController.add(self, name: "minuto")
            config.websiteDataStore = .nonPersistent()
            webView = WKWebView(frame: .zero, configuration: config)
            webView.navigationDelegate = self
            window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1220, height: 860), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = "Minuto"; window.minSize = NSSize(width: 640, height: 600); window.contentView = webView; window.center()
            setupMenu()
            webView.loadFileURL(resources.appendingPathComponent("web/index.html"), allowingReadAccessTo: resources.appendingPathComponent("web"))
            window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
        } catch {
            let alert = NSAlert(); alert.messageText = "Minuto konnte nicht geöffnet werden"; alert.informativeText = error.localizedDescription; alert.runModal(); NSApp.terminate(nil)
        }
    }
    func setupMenu() {
        let menu = NSMenu(); let appItem = NSMenuItem(); menu.addItem(appItem)
        let appMenu = NSMenu(); appItem.submenu = appMenu
        appMenu.addItem(withTitle: "Minuto beenden", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let editItem = NSMenuItem(); editItem.title = "Bearbeiten"; menu.addItem(editItem); let editMenu = NSMenu(title: "Bearbeiten"); editItem.submenu = editMenu
        for (title, action, key) in [("Widerrufen", "undo:", "z"), ("Ausschneiden", "cut:", "x"), ("Kopieren", "copy:", "c"), ("Einfügen", "paste:", "v"), ("Alles auswählen", "selectAll:", "a")] { editMenu.addItem(withTitle: title, action: Selector(action), keyEquivalent: key) }
        NSApp.mainMenu = menu
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url, url.isFileURL, url.standardizedFileURL.path.hasPrefix(resources.appendingPathComponent("web").path + "/") else { decisionHandler(.cancel); return }
        decisionHandler(.allow)
    }
    func respond(_ id: String, result: Any = NSNull(), error: String? = nil) {
        do { let encoded = try JSONSerialization.data(withJSONObject: [id, result, error as Any? ?? NSNull()]); let arguments = String(data: encoded, encoding: .utf8)!; webView.evaluateJavaScript("window.nativeResult(...\(arguments))", completionHandler: nil) }
        catch { NSLog("Bridge response failed: %@", error.localizedDescription) }
    }
    func savePanel(id: String, name: String, data: Data) {
        let panel = NSSavePanel(); panel.nameFieldStringValue = name; panel.canCreateDirectories = true
        panel.beginSheetModal(for: window) { response in
            guard response == .OK, let url = panel.url else { self.respond(id, result: ["saved": false]); return }
            do { try data.write(to: url, options: .atomic); self.respond(id, result: ["saved": true]) } catch { self.respond(id, error: error.localizedDescription) }
        }
    }
    func openImportPanel(id: String, replace: Bool) {
        let panel = NSOpenPanel(); panel.canChooseFiles = true; panel.canChooseDirectories = false; panel.allowsMultipleSelection = false
        panel.beginSheetModal(for: window) { response in
            guard response == .OK, let url = panel.url else { self.respond(id, result: ["imported": false]); return }
            do {
                let entries = try JSONDecoder().decode([Entry].self, from: Data(contentsOf: url))
                self.respond(id, result: try self.store.json(self.store.importEntries(entries, replace: replace)))
            } catch { self.respond(id, error: "Datei konnte nicht übernommen werden: \(error.localizedDescription)") }
        }
    }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame, let url = message.frameInfo.request.url, url.isFileURL,
              let body = message.body as? [String: Any], let id = body["id"] as? String, let method = body["method"] as? String else { return }
        let payload = body["payload"] as? [String: Any] ?? [:]
        do {
            switch method {
            case "list": respond(id, result: try store.json(store.read()))
            case "mutate": respond(id, result: try store.json(store.mutate(payload)))
            case "masterList": respond(id, result: try store.masterJSON())
            case "masterMutate": respond(id, result: try store.mutateMaster(payload))
            case "settings":
                let defaults = UserDefaults.standard
                if let hours = payload["dailyTargetHours"] as? NSNumber { defaults.set(hours.doubleValue, forKey: "dailyTargetHours") }
                respond(id, result: ["dailyTargetHours": defaults.object(forKey: "dailyTargetHours") as? Double ?? 8.0])
            case "weekClose":
                guard let week = payload["week"] as? String else { throw AppError(message: "Ungültige Woche.") }
                let key = "closedWeek_" + week
                if let closed = payload["closed"] as? Bool { UserDefaults.standard.set(closed, forKey: key) }
                respond(id, result: ["closed": UserDefaults.standard.bool(forKey: key)])
            case "export":
                guard let text = payload["text"] as? String, let name = payload["filename"] as? String, name.hasSuffix(".csv") else { throw AppError(message: "Ungültiger Export.") }
                savePanel(id: id, name: URL(fileURLWithPath: name).lastPathComponent, data: Data(text.utf8))
            case "backup": savePanel(id: id, name: "Minuto-Sicherung.json", data: try Data(contentsOf: store.file))
            case "import": openImportPanel(id: id, replace: false)
            case "restore": openImportPanel(id: id, replace: true)
            case "showData": NSWorkspace.shared.open(store.directory); respond(id, result: true)
            default: throw AppError(message: "Unbekannte Funktion.")
            }
        } catch { respond(id, error: error.localizedDescription) }
    }
}

func check(_ condition: Bool) { precondition(condition) }
func selfTest() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("Minuto-Test-" + UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: dir) }
    var store: EntryStore? = try EntryStore(directory: dir, seed: nil)
    let base: [String: Any] = ["id":"test", "action":"add", "customer":"Test", "project":"Projekt", "ticket":"T-1", "date":"2026-09-29", "seconds":3600]
    _ = try store!.mutate(base); _ = try store!.mutate(base); check(try store!.read().count == 1)
    var edit = base; edit["action"] = "edit"; edit["seconds"] = 5400; _ = try store!.mutate(edit)
    _ = try store!.mutate(["action":"bill", "id":"test", "billed":1, "billingTicket":"ABR-1"])
    do { _ = try store!.mutate(edit); throw AppError(message:"Billed edit unexpectedly allowed") } catch let e as AppError { assert(e.message == "Dieser Eintrag kann nicht bearbeitet werden.") }
    store = nil; store = try EntryStore(directory: dir, seed: nil); check(try store!.read().first!.seconds == 5400)
    var start = base; start["action"] = "start"; start["id"] = "timer"; _ = try store!.mutate(start)
    store = nil; store = try EntryStore(directory: dir, seed: nil); check(try store!.read().contains { $0.started != nil })
    do { _ = try store!.mutate(["action":"delete", "id":"timer"]); throw AppError(message:"Running delete unexpectedly allowed") } catch let e as AppError { assert(e.message == "Bitte den Timer zuerst stoppen.") }
    start["id"] = "second"
    do { _ = try store!.mutate(start); throw AppError(message:"Second timer unexpectedly allowed") } catch let e as AppError { assert(e.message == "Es läuft bereits ein Timer.") }
    _ = try store!.mutate(["action":"stop", "id":"timer"])
    _ = try store!.mutate(["action":"delete", "id":"test"]); _ = try store!.mutate(["action":"delete", "id":"timer"]); check(try store!.read().isEmpty)
    check(try FileManager.default.contentsOfDirectory(atPath: dir.appendingPathComponent("Sicherungen").path).count >= 6)
    try Data("invalid".utf8).write(to: store!.file)
    do { _ = try store!.read(); throw AppError(message:"Corruption was ignored") } catch let e as AppError { assert(e.message.contains("nicht überschrieben")) }
    print("PASS: add, deduplication, edit, billing guard, persistence, timer restart, single timer, stop, delete, backups, corruption handling")
}
if CommandLine.arguments.contains("--self-test") {
    do { try selfTest() } catch { fputs("TEST FAILED: \(error)\n", stderr); exit(1) }
} else {
    let app = NSApplication.shared
    app.setActivationPolicy(.regular)
    let delegate = AppDelegate(); app.delegate = delegate; app.run()
}
