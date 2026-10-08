// CheckinNotifier — mostra la notifica di check-in (in alto a destra) con le azioni
// "Apri check-in", "Fatto", "Tra N min" e riporta la scelta a checkin-reminder.
//
// Uso (via LaunchServices, così la notifica sopravvive al processo che la lancia):
//   open -n -g -a CheckinNotifier.app --args post --title T --subtitle S --body B --url U --snooze 15
//   open -n -g -a CheckinNotifier.app --args auth      # chiede il permesso notifiche
//
// Se l'utente clicca quando l'app è già chiusa, macOS la rilancia e la risposta
// arriva al delegate: per questo url e percorso della CLI viaggiano nella notifica stessa.

import Cocoa
import UserNotifications

let kCategory = "CHECKIN"
let kNotificationID = "checkin-reminder"
let home = FileManager.default.homeDirectoryForCurrentUser

func stateDir() -> URL {
    let dir = home.appendingPathComponent("Library/Application Support/checkin-reminder", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}

func writeStatus(_ s: String) {
    try? (s + "\n").write(to: stateDir().appendingPathComponent("notifier_status"), atomically: true, encoding: .utf8)
}

struct Options {
    var command = ""
    var title = "Check-in"
    var subtitle = ""
    var body = "Sei in ufficio: ricordati di fare il check-in!"
    var url = ""
    var snooze = 15
    var cli = home.appendingPathComponent(".local/bin/checkin-reminder").path
}

func parseArgs() -> Options {
    var o = Options()
    var args = Array(CommandLine.arguments.dropFirst())
    args.removeAll { $0.hasPrefix("-psn_") }          // argomento aggiunto da LaunchServices
    if let first = args.first, !first.hasPrefix("--") {
        o.command = first
        args.removeFirst()
    }
    var i = 0
    while i < args.count {
        let key = args[i]
        let val = i + 1 < args.count ? args[i + 1] : ""
        switch key {
        case "--title":    o.title = val
        case "--subtitle": o.subtitle = val
        case "--body":     o.body = val
        case "--url":      o.url = val
        case "--snooze":   o.snooze = Int(val) ?? 15
        case "--cli":      o.cli = val
        default:           i += 1; continue
        }
        i += 2
    }
    return o
}

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    let center = UNUserNotificationCenter.current()
    let opts = parseArgs()

    func applicationWillFinishLaunching(_ notification: Notification) {
        // va impostato prima della fine del lancio, per ricevere il click che ha rilanciato l'app
        center.delegate = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let saved = UserDefaults.standard.integer(forKey: "snooze")
        registerCategory(snooze: opts.command == "post" ? opts.snooze : (saved > 0 ? saved : 15))

        switch opts.command {
        case "post":
            post()
        case "auth":
            requestAuth { granted in
                writeStatus(granted ? "ok" : "denied")
                self.quit(after: 0.5)
            }
        default:
            quit(after: 20)   // rilanciata da un click: attende la risposta e chiude
        }
    }

    func registerCategory(snooze: Int) {
        let open   = UNNotificationAction(identifier: "OPEN", title: "Apri check-in", options: [.foreground])
        let done   = UNNotificationAction(identifier: "DONE", title: "Fatto", options: [])
        let later  = UNNotificationAction(identifier: "SNOOZE", title: "Tra \(snooze) min", options: [])
        let cat = UNNotificationCategory(identifier: kCategory, actions: [open, done, later],
                                         intentIdentifiers: [], options: [])
        center.setNotificationCategories([cat])
    }

    func requestAuth(_ done: @escaping (Bool) -> Void) {
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            DispatchQueue.main.async { done(granted) }
        }
    }

    func post() {
        UserDefaults.standard.set(opts.snooze, forKey: "snooze")
        requestAuth { granted in
            guard granted else {
                writeStatus("denied")
                self.quit(after: 0)
                return
            }
            writeStatus("ok")

            let content = UNMutableNotificationContent()
            content.title = self.opts.title
            if !self.opts.subtitle.isEmpty { content.subtitle = self.opts.subtitle }
            content.body = self.opts.body
            content.sound = .default
            content.categoryIdentifier = kCategory
            content.userInfo = ["url": self.opts.url, "cli": self.opts.cli]

            // stesso identificativo: una notifica nuova sostituisce la precedente, niente doppioni
            self.center.removeDeliveredNotifications(withIdentifiers: [kNotificationID])
            let request = UNNotificationRequest(identifier: kNotificationID, content: content, trigger: nil)
            self.center.add(request) { error in
                DispatchQueue.main.async {
                    if let error = error {
                        writeStatus("error: \(error.localizedDescription)")
                        self.quit(after: 0)
                    } else {
                        self.quit(after: 600)   // resta in ascolto 10 minuti, poi macOS la rilancia al click
                    }
                }
            }
        }
    }

    // Mostra il banner anche se l'app risultasse in primo piano
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        if #available(macOS 11.0, *) {
            completionHandler([.banner, .list, .sound])
        } else {
            completionHandler([.alert, .sound])
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let info = response.notification.request.content.userInfo
        let url = info["url"] as? String ?? opts.url
        let cli = info["cli"] as? String ?? opts.cli

        switch response.actionIdentifier {
        case "OPEN", UNNotificationDefaultActionIdentifier:   // pulsante o click sul corpo
            if !url.isEmpty, let u = URL(string: url) { NSWorkspace.shared.open(u) }
            runCLI(cli, "done")
        case "DONE":
            runCLI(cli, "done")
        case "SNOOZE":
            runCLI(cli, "snooze")
        default:
            break   // chiusa senza scegliere: ci pensa il prossimo controllo
        }
        completionHandler()
        quit(after: 1)
    }

    func runCLI(_ cli: String, _ arg: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: cli)
        p.arguments = [arg]
        do {
            try p.run()
            p.waitUntilExit()
        } catch {
            writeStatus("cli error: \(error.localizedDescription)")
        }
    }

    func quit(after seconds: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { NSApp.terminate(nil) }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
