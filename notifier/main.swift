// CheckinNotifier — l'app di supporto di checkin-reminder.
//
//  post    mostra la notifica (in alto a destra) con le azioni e riporta la scelta alla CLI
//  locate  legge la posizione e dice se sei in un ufficio Reply
//  auth    chiede i permessi (notifiche + posizione)
//
// Lanciata via LaunchServices, così sopravvive al processo che la avvia:
//   open -n -g -a CheckinNotifier.app --args post --title T --subtitle S --body B --url U --snooze 15
//   open -W -n -g -a CheckinNotifier.app --args locate --offices F1,F2 --cache C --out O --radius 250
//
// Se l'utente clicca quando l'app è già chiusa, macOS la rilancia e la risposta arriva al
// delegate: per questo url e percorso della CLI viaggiano dentro la notifica.

import Cocoa
import CoreLocation
import UserNotifications

let kCategory = "CHECKIN"
let kNotificationID = "checkin-reminder"
let home = FileManager.default.homeDirectoryForCurrentUser

func stateDir() -> URL {
    let dir = home.appendingPathComponent("Library/Application Support/checkin-reminder", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}

func writeFile(_ url: URL, _ s: String) {
    try? (s + "\n").write(to: url, atomically: true, encoding: .utf8)
}

func writeStatus(_ name: String, _ s: String) {
    writeFile(stateDir().appendingPathComponent(name), s)
}

// MARK: - Argomenti

struct Options {
    var command = ""
    var title = "Check-in"
    var subtitle = ""
    var body = "Sei in ufficio: ricordati di fare il check-in!"
    var url = ""
    var snooze = 15
    var cli = home.appendingPathComponent(".local/bin/checkin-reminder").path
    var offices: [String] = []
    var cache = stateDir().appendingPathComponent("geocache.tsv").path
    var out = stateDir().appendingPathComponent("location").path
    var radius = 250.0
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
        case "--offices":  o.offices = val.split(separator: ",").map(String.init)
        case "--cache":    o.cache = val
        case "--out":      o.out = val
        case "--radius":   o.radius = Double(val) ?? 250
        default:           i += 1; continue
        }
        i += 2
    }
    return o
}

// MARK: - Uffici e geocoding

struct Office {
    let name: String
    let address: String
    var coordinate: CLLocationCoordinate2D?
}

func loadOffices(_ paths: [String]) -> [Office] {
    var result: [Office] = []
    for path in paths {
        guard let text = try? String(contentsOfFile: path, encoding: .utf8) else { continue }
        for line in text.split(separator: "\n") where !line.hasPrefix("#") {
            let f = line.split(separator: "\t", omittingEmptySubsequences: false).map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            guard f.count >= 2, !f[0].isEmpty else { continue }
            var coord: CLLocationCoordinate2D?
            if f.count >= 4, let lat = Double(f[2]), let lon = Double(f[3]) {
                coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            }
            result.append(Office(name: f[0], address: f[1], coordinate: coord))
        }
    }
    return result
}

final class GeoCache {
    let path: String
    var entries: [String: CLLocationCoordinate2D] = [:]

    init(path: String) {
        self.path = path
        guard let text = try? String(contentsOfFile: path, encoding: .utf8) else { return }
        for line in text.split(separator: "\n") {
            let f = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            if f.count == 3, let lat = Double(f[1]), let lon = Double(f[2]) {
                entries[f[0]] = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            }
        }
    }

    func save() {
        let text = entries.map { "\($0.key)\t\($0.value.latitude)\t\($0.value.longitude)" }.sorted().joined(separator: "\n")
        try? text.write(toFile: path, atomically: true, encoding: .utf8)
    }
}

/// Ricava (una volta sola, poi in cache) le coordinate degli uffici che non le hanno.
/// Le richieste vanno in sequenza, come chiede Apple per CLGeocoder.
final class OfficeResolver {
    let geocoder = CLGeocoder()
    let cache: GeoCache
    var offices: [Office]
    var pending: [Int] = []

    init(offices: [Office], cache: GeoCache) {
        self.offices = offices
        self.cache = cache
        for (i, o) in offices.enumerated() where o.coordinate == nil {
            if let c = cache.entries[o.address] { self.offices[i].coordinate = c } else { pending.append(i) }
        }
    }

    func resolve(_ done: @escaping ([Office]) -> Void) {
        guard !pending.isEmpty else { cache.save(); done(offices); return }
        let i = pending.removeFirst()
        geocoder.geocodeAddressString(offices[i].address) { placemarks, _ in
            DispatchQueue.main.async {
                if let c = placemarks?.first?.location?.coordinate {
                    self.offices[i].coordinate = c
                    self.cache.entries[self.offices[i].address] = c
                }
                self.resolve(done)
            }
        }
    }
}

// MARK: - Posizione

final class Locator: NSObject, CLLocationManagerDelegate {
    let manager = CLLocationManager()
    var completion: ((CLLocation?, String) -> Void)?
    var finished = false

    func start(timeout: TimeInterval = 20, _ done: @escaping (CLLocation?, String) -> Void) {
        completion = done
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        guard CLLocationManager.locationServicesEnabled() else { finish(nil, "DISABLED"); return }
        handle(manager.authorizationStatus)
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { self.finish(nil, "TIMEOUT") }
    }

    func handle(_ status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined:          manager.requestWhenInUseAuthorization()   // risposta nel delegate
        case .denied, .restricted:    finish(nil, "DENIED")
        default:                      manager.requestLocation()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus != .notDetermined { handle(manager.authorizationStatus) }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        finish(locations.last, "OK")
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if (error as? CLError)?.code == .denied { finish(nil, "DENIED") } else { finish(nil, "ERROR") }
    }

    func finish(_ loc: CLLocation?, _ status: String) {
        guard !finished else { return }
        finished = true
        completion?(loc, status)
    }
}

// MARK: - App

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    let center = UNUserNotificationCenter.current()
    let opts = parseArgs()
    let locator = Locator()
    var resolver: OfficeResolver?

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
        case "locate":
            locate()
        case "auth":
            requestAuth { granted in
                writeStatus("notifier_status", granted ? "ok" : "denied")
                // 2 minuti per rispondere all'avviso di macOS sulla posizione
                self.locator.start(timeout: 120) { _, status in
                    writeStatus("location_status", status)
                    self.quit(after: 0.5)
                }
            }
        default:
            quit(after: 20)   // rilanciata da un click: attende la risposta e chiude
        }
    }

    // MARK: notifiche

    func registerCategory(snooze: Int) {
        let open  = UNNotificationAction(identifier: "OPEN", title: "Lo faccio ora", options: [.foreground])
        let done  = UNNotificationAction(identifier: "DONE", title: "Già fatto, giuro", options: [])
        let later = UNNotificationAction(identifier: "SNOOZE", title: "Tra \(snooze) min", options: [])
        let cat = UNNotificationCategory(identifier: kCategory, actions: [open, done, later],
                                         intentIdentifiers: [], options: [])
        center.setNotificationCategories([cat])
    }

    func requestAuth(_ done: @escaping (Bool) -> Void) {
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            DispatchQueue.main.async { done(granted) }
        }
    }

    /// L'immagine dell'ispettore, copiata in un file temporaneo (macOS sposta l'allegato nel suo archivio).
    func inspectorAttachment() -> UNNotificationAttachment? {
        guard let src = Bundle.main.url(forResource: "inspector", withExtension: "png") else { return nil }
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("inspector-\(UUID().uuidString).png")
        do {
            try FileManager.default.copyItem(at: src, to: tmp)
            return try UNNotificationAttachment(identifier: "inspector", url: tmp, options: nil)
        } catch {
            return nil
        }
    }

    func post() {
        UserDefaults.standard.set(opts.snooze, forKey: "snooze")
        requestAuth { granted in
            guard granted else {
                writeStatus("notifier_status", "denied")
                self.quit(after: 0)
                return
            }
            writeStatus("notifier_status", "ok")

            let content = UNMutableNotificationContent()
            content.title = self.opts.title
            if !self.opts.subtitle.isEmpty { content.subtitle = self.opts.subtitle }
            content.body = self.opts.body
            content.sound = .default
            content.categoryIdentifier = kCategory
            content.userInfo = ["url": self.opts.url, "cli": self.opts.cli]
            if let a = self.inspectorAttachment() { content.attachments = [a] }

            // stesso identificativo: una notifica nuova sostituisce la precedente, niente doppioni
            self.center.removeDeliveredNotifications(withIdentifiers: [kNotificationID])
            let request = UNNotificationRequest(identifier: kNotificationID, content: content, trigger: nil)
            self.center.add(request) { error in
                DispatchQueue.main.async {
                    if let error = error {
                        writeStatus("notifier_status", "error: \(error.localizedDescription)")
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
        completionHandler([.banner, .list, .sound])
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
            writeStatus("notifier_status", "cli error: \(error.localizedDescription)")
        }
    }

    // MARK: posizione

    /// Scrive in --out una riga:  STATO<TAB>ufficio<TAB>distanza_m<TAB>precisione_m<TAB>epoch
    /// STATO = IN | OUT | DENIED | DISABLED | TIMEOUT | ERROR | NOOFFICES
    func locate() {
        let out = URL(fileURLWithPath: opts.out)
        let epoch = Int(Date().timeIntervalSince1970)
        let offices = loadOffices(opts.offices)
        guard !offices.isEmpty else {
            writeFile(out, "NOOFFICES\t\t\t\t\(epoch)")
            quit(after: 0)
            return
        }

        let resolver = OfficeResolver(offices: offices, cache: GeoCache(path: opts.cache))
        self.resolver = resolver
        var resolved: [Office]?
        var located: (CLLocation?, String)?

        func complete() {
            guard let resolvedOffices = resolved, let fix = located else { return }
            let (loc, status) = fix
            guard let here = loc else {
                writeFile(out, "\(status)\t\t\t\t\(epoch)")
                writeStatus("location_status", status)
                quit(after: 0)
                return
            }
            writeStatus("location_status", "OK")
            var best: (Office, Double)?
            for o in resolvedOffices {
                guard let c = o.coordinate else { continue }
                let d = here.distance(from: CLLocation(latitude: c.latitude, longitude: c.longitude))
                if best == nil || d < best!.1 { best = (o, d) }
            }
            let acc = here.horizontalAccuracy
            if let match = best {
                let (o, d) = match
                // tolleranza: raggio + l'imprecisione del fix, senza superare il doppio del raggio
                let inside = d <= opts.radius + min(max(acc, 0), opts.radius)
                writeFile(out, "\(inside ? "IN" : "OUT")\t\(o.name)\t\(Int(d))\t\(Int(acc))\t\(epoch)")
            } else {
                writeFile(out, "NOOFFICES\t\t\t\(Int(acc))\t\(epoch)")
            }
            quit(after: 0)
        }

        resolver.resolve { offices in resolved = offices; complete() }
        locator.start { loc, status in located = (loc, status); complete() }
        quit(after: 45)   // rete di sicurezza
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
