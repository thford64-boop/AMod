import Foundation
import JavaScriptCore
import UIKit
import AVFoundation
import AudioToolbox
import MediaPlayer
import UserNotifications
import CoreLocation
import EventKit

enum LogKind: String {
    case out, info, warn, error, system, clear, image
}

/// Whoever is showing a running script: the run screen, or a headless Shortcuts run.
protocol EngineHost: AnyObject {
    var isInteractive: Bool { get }
    func engineLog(_ kind: LogKind, _ text: String)
    func engineRender(_ node: UINode?)
    /// Called on the main thread.
    func enginePresent(_ request: PromptRequest)
    func engineSetTitle(_ title: String)
    func engineOutput(_ value: String)
    func engineShowConsole()
    func engineDone()
    func engineClose()
}

/// A question the script is waiting on (alert, text input or menu).
final class PromptRequest: Identifiable {
    enum Kind {
        case alert(buttons: [String])
        case input(placeholder: String, defaultValue: String, secure: Bool)
        case menu(options: [String])
    }

    let id = UUID()
    let title: String
    let message: String
    let kind: Kind
    private var handler: ((Any?) -> Void)?

    init(title: String, message: String, kind: Kind, handler: @escaping (Any?) -> Void) {
        self.title = title
        self.message = message
        self.kind = kind
        self.handler = handler
    }

    var isInput: Bool {
        if case .input = kind { return true }
        return false
    }

    /// Answers the prompt. Only the first call counts.
    func resolve(_ value: Any?) {
        guard let h = handler else { return }
        handler = nil
        h(value)
    }
}

/// Runs one script in its own JSContext on a private queue. Blocking bridges
/// (alert, input, http, location…) park that queue while the main thread works,
/// so scripts can be written top to bottom like a shell script.
final class ScriptEngine {
    let script: Script
    let input: String
    weak var host: EngineHost?

    let queue = DispatchQueue(label: "amod.engine", qos: .userInitiated)
    private var context: JSContext?
    private(set) var stopped = false
    private var pending: PromptRequest?
    private let speech = AVSpeechSynthesizer()
    private let speechWaiter = SpeechWaiter()
    private var locationFetcher: LocationFetcher?
    private lazy var eventStore = EKEventStore()
    private let audio = AudioPlayer()

    init(script: Script, host: EngineHost, input: String = "") {
        self.script = script
        self.host = host
        self.input = input
        speech.delegate = speechWaiter
    }

    func start() {
        queue.async { [weak self] in self?.boot() }
    }

    func stop() {
        stopped = true
        DispatchQueue.main.async { [weak self] in
            self?.pending?.resolve(nil)
            self?.speech.stopSpeaking(at: .immediate)
            self?.audio.stop()
        }
        queue.async { [weak self] in self?.context = nil }
    }

    /// Calls a UI callback registered by the script (button tap, toggle change…).
    func invoke(_ id: String, _ value: Any?) {
        queue.async { [weak self] in
            guard let self, !self.stopped, let ctx = self.context else { return }
            ctx.objectForKeyedSubscript("__amod_invoke")?.call(withArguments: [id, value ?? NSNull()])
        }
    }

    // MARK: - Boot

    private func boot() {
        guard let ctx = JSContext() else { return }
        ctx.name = "AMod: \(script.name)"
        ctx.exceptionHandler = { [weak self] _, exception in
            guard let self, let exception else { return }
            let message = exception.toString() ?? "Unknown error"
            if message.contains("__amod_exit__") { return }
            let line = exception.objectForKeyedSubscript("line")?.toInt32() ?? 0
            self.host?.engineLog(.error, line > 0 ? "Line \(line): \(message)" : message)
        }

        let native = JSValue(newObjectIn: ctx)!
        installBridges(native)
        ctx.setObject(native, forKeyedSubscript: "__native" as NSString)
        ctx.setObject([
            "input": input,
            "name": script.name,
            "interactive": host?.isInteractive ?? false,
        ] as [String: Any], forKeyedSubscript: "args" as NSString)
        context = ctx

        ctx.evaluateScript(Prelude.source, withSourceURL: URL(string: "amod://prelude.js"))
        // Wrapped so scripts can use top-level `await`. Kept on the first line so line numbers match the editor.
        let wrapped = "(async () => {" + script.code + "\n})().then(() => __native.done(), (e) => { "
            + "if (!(e && e.message === '__amod_exit__')) { __native.log('error', __amod_errfmt(e)); } __native.done(); });"
        ctx.evaluateScript(wrapped, withSourceURL: URL(string: "amod://script.js"))
    }

    // MARK: - Bridge plumbing

    private typealias Fn = ([JSValue]) -> Any?

    private func def(_ obj: JSValue, _ name: String, _ fn: @escaping Fn) {
        let block: @convention(block) () -> Any? = {
            let args = (JSContext.currentArguments() as? [JSValue]) ?? []
            return fn(args)
        }
        obj.setObject(unsafeBitCast(block, to: AnyObject.self), forKeyedSubscript: name as NSString)
    }

    @discardableResult
    private func onMain<T>(_ work: () -> T) -> T {
        if Thread.isMainThread { return work() }
        return DispatchQueue.main.sync(execute: work)
    }

    /// Parks the script queue until `work` calls back.
    private func blocking<T>(_ fallback: T, onMainThread: Bool = true,
                             _ work: @escaping (@escaping (T) -> Void) -> Void) -> T {
        let semaphore = DispatchSemaphore(value: 0)
        let lock = NSLock()
        var result = fallback
        var finished = false
        let finish: (T) -> Void = { value in
            lock.lock()
            defer { lock.unlock() }
            guard !finished else { return }
            finished = true
            result = value
            semaphore.signal()
        }
        if onMainThread {
            DispatchQueue.main.async { work(finish) }
        } else {
            work(finish)
        }
        semaphore.wait()
        return result
    }

    private func prompt(_ title: String, _ message: String, _ kind: PromptRequest.Kind) -> Any? {
        guard host?.isInteractive == true, !stopped else { return nil }
        return blocking(nil as Any?) { [weak self] done in
            guard let self, let host = self.host, !self.stopped else { done(nil); return }
            let request = PromptRequest(title: title, message: message, kind: kind) { [weak self] value in
                self?.pending = nil
                done(value)
            }
            self.pending = request
            host.enginePresent(request)
        }
    }

    // MARK: - Bridges

    private func installBridges(_ n: JSValue) {
        // Core
        def(n, "log") { [weak self] a in
            self?.host?.engineLog(LogKind(rawValue: a.str(0)) ?? .out, a.str(1)); return nil
        }
        def(n, "done") { [weak self] _ in self?.host?.engineDone(); return nil }
        def(n, "exit") { [weak self] _ in self?.host?.engineDone(); return nil }
        def(n, "close") { [weak self] _ in self?.host?.engineClose(); return nil }
        def(n, "output") { [weak self] a in self?.host?.engineOutput(a.str(0)); return nil }
        def(n, "title") { [weak self] a in self?.host?.engineSetTitle(a.str(0)); return nil }
        def(n, "showConsole") { [weak self] _ in self?.host?.engineShowConsole(); return nil }
        def(n, "render") { [weak self] a in
            guard let data = a.str(0).data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) else { return nil }
            self?.host?.engineRender(UINode(obj))
            return nil
        }
        def(n, "after") { [weak self] a in
            let ms = a.num(0), id = a.num(1)
            self?.queue.asyncAfter(deadline: .now() + max(0, ms) / 1000) { [weak self] in
                guard let self, !self.stopped, let ctx = self.context else { return }
                ctx.objectForKeyedSubscript("__amod_fire")?.call(withArguments: [id])
            }
            return nil
        }
        def(n, "sleep") { [weak self] a in
            let end = Date().addingTimeInterval(a.num(0))
            while Date() < end, self?.stopped == false { Thread.sleep(forTimeInterval: 0.05) }
            return nil
        }

        // Haptics & sound
        def(n, "haptic") { [weak self] a in self?.haptic(a.str(0, "medium")); return nil }
        def(n, "vibrate") { _ in AudioServicesPlaySystemSound(kSystemSoundID_Vibrate); return nil }
        def(n, "playSound") { a in AudioServicesPlaySystemSound(SystemSoundID(a.num(0, 1007))); return nil }

        // Flashlight
        def(n, "torch") { a in Self.setTorch(a.bool(0), level: a.num(1, 1)) }
        def(n, "torchState") { _ in AVCaptureDevice.default(for: .video)?.torchMode == .on }

        // Screen & volume
        def(n, "getBrightness") { [weak self] _ in self?.onMain { Double(UIScreen.main.brightness) } }
        def(n, "setBrightness") { [weak self] a in
            let v = min(1, max(0, a.num(0)))
            self?.onMain { UIScreen.main.brightness = CGFloat(v) }
            return nil
        }
        def(n, "getVolume") { _ in Double(AVAudioSession.sharedInstance().outputVolume) }
        def(n, "setVolume") { a in Self.setVolume(Float(min(1, max(0, a.num(0))))); return nil }

        // Device
        def(n, "deviceInfo") { [weak self] _ in self?.onMain { () -> [String: Any] in
            let d = UIDevice.current
            d.isBatteryMonitoringEnabled = true
            let screen = UIScreen.main
            return [
                "name": d.name,
                "model": d.model,
                "system": d.systemName,
                "version": d.systemVersion,
                "battery": Double(d.batteryLevel),
                "charging": d.batteryState == .charging || d.batteryState == .full,
                "lowPowerMode": ProcessInfo.processInfo.isLowPowerModeEnabled,
                "brightness": Double(screen.brightness),
                "volume": Double(AVAudioSession.sharedInstance().outputVolume),
                "screenWidth": Double(screen.bounds.width),
                "screenHeight": Double(screen.bounds.height),
                "darkMode": UITraitCollection.current.userInterfaceStyle == .dark,
            ]
        } }

        // Clipboard
        def(n, "clipboardGet") { [weak self] _ in orNull(self?.onMain { UIPasteboard.general.string } ?? nil) }
        def(n, "clipboardSet") { [weak self] a in
            let text = a.str(0)
            self?.onMain { UIPasteboard.general.string = text }
            return nil
        }

        // URLs, Settings, Shortcuts
        def(n, "openURL") { [weak self] a in self?.open(a.str(0)) ?? false }
        def(n, "openSettings") { [weak self] a in self?.openSettings(a.str(0)) ?? false }
        def(n, "runShortcut") { [weak self] a in
            let name = a.str(0).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let text = a.str(1).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            var url = "shortcuts://x-callback-url/run-shortcut?name=\(name)&x-success=amod://"
            if !text.isEmpty { url += "&input=text&text=\(text)" }
            return self?.open(url) ?? false
        }

        // Speech
        def(n, "speak") { [weak self] a in
            guard let self else { return nil }
            let text = a.str(0)
            let opts = a.dict(1)
            _ = self.blocking(false) { done in
                let utterance = AVSpeechUtterance(string: text)
                if let lang = opts["language"] as? String { utterance.voice = AVSpeechSynthesisVoice(language: lang) }
                if let rate = opts["rate"] as? Double {
                    utterance.rate = Float(rate) * (AVSpeechUtteranceMaximumSpeechRate - AVSpeechUtteranceMinimumSpeechRate)
                        + AVSpeechUtteranceMinimumSpeechRate
                }
                if let pitch = opts["pitch"] as? Double { utterance.pitchMultiplier = Float(pitch) }
                self.speechWaiter.onFinish = { done(true) }
                self.speech.speak(utterance)
            }
            return nil
        }

        // Notifications
        def(n, "notify") { a in
            let title = a.str(0), body = a.str(1), delay = a.num(2)
            let center = UNUserNotificationCenter.current()
            center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                guard granted else { return }
                let content = UNMutableNotificationContent()
                content.title = title
                content.body = body
                content.sound = .default
                let trigger = delay > 0 ? UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false) : nil
                center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger))
            }
            return nil
        }

        // Prompts
        def(n, "alert") { [weak self] a in
            var buttons = a.strings(2)
            if buttons.isEmpty { buttons = ["OK"] }
            return self?.prompt(a.str(0), a.str(1), .alert(buttons: buttons)) ?? NSNull()
        }
        def(n, "input") { [weak self] a in
            self?.prompt(a.str(0), "", .input(placeholder: a.str(0), defaultValue: a.str(1), secure: a.bool(2))) ?? NSNull()
        }
        def(n, "menu") { [weak self] a in
            self?.prompt(a.str(0), "", .menu(options: a.strings(1))) ?? NSNull()
        }
        def(n, "share") { [weak self] a in
            guard let self, self.host?.isInteractive == true else { return false }
            let text = a.str(0)
            return self.blocking(false) { done in
                guard let top = UIHelpers.topViewController else { done(false); return }
                let vc = UIActivityViewController(activityItems: [text], applicationActivities: nil)
                vc.popoverPresentationController?.sourceView = top.view
                vc.popoverPresentationController?.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY, width: 0, height: 0)
                vc.completionWithItemsHandler = { _, completed, _, _ in done(completed) }
                top.present(vc, animated: true)
            }
        }

        // Network
        def(n, "http") { [weak self] a in
            let body: String? = (a.count > 3 && !a[3].isNull && !a[3].isUndefined) ? a[3].toString() : nil
            return self?.http(a.str(0, "GET"), a.str(1), a.dict(2), body, a.num(4, 30), base64: a.bool(5))
        }

        // Location
        def(n, "location") { [weak self] _ in
            guard let self else { return NSNull() }
            return self.blocking(nil as [String: Any]?) { done in
                let fetcher = LocationFetcher()
                self.locationFetcher = fetcher
                fetcher.fetch { location in
                    guard let l = location else { done(nil); return }
                    done([
                        "latitude": l.coordinate.latitude,
                        "longitude": l.coordinate.longitude,
                        "altitude": l.altitude,
                        "accuracy": l.horizontalAccuracy,
                        "speed": l.speed,
                    ])
                }
            }.map { $0 as Any } ?? NSNull()
        }

        // Files (the app's Documents folder, visible in the Files app)
        def(n, "fileRead") { [weak self] a in
            guard let url = self?.fileURL(a.str(0)) else { return NSNull() }
            return orNull(try? String(contentsOf: url, encoding: .utf8))
        }
        def(n, "fileWrite") { [weak self] a in
            guard let url = self?.fileURL(a.str(0)) else { return false }
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            if a.bool(2), let handle = try? FileHandle(forWritingTo: url) {
                handle.seekToEndOfFile()
                handle.write(Data(a.str(1).utf8))
                try? handle.close()
                return true
            }
            return (try? a.str(1).write(to: url, atomically: true, encoding: .utf8)) != nil
        }
        def(n, "fileList") { [weak self] a in
            guard let url = self?.fileURL(a.str(0)) else { return [String]() }
            return (try? FileManager.default.contentsOfDirectory(atPath: url.path))?.sorted() ?? [String]()
        }
        def(n, "fileExists") { [weak self] a in
            guard let url = self?.fileURL(a.str(0)) else { return false }
            return FileManager.default.fileExists(atPath: url.path)
        }
        def(n, "fileDelete") { [weak self] a in
            guard let url = self?.fileURL(a.str(0)) else { return false }
            return (try? FileManager.default.removeItem(at: url)) != nil
        }

        // Key-value storage (JSON strings)
        def(n, "kvGet") { a in orNull(UserDefaults.standard.string(forKey: "amod.kv." + a.str(0))) }
        def(n, "kvSet") { a in
            let key = "amod.kv." + a.str(0)
            if a.count > 1, !a[1].isNull, !a[1].isUndefined {
                UserDefaults.standard.set(a[1].toString(), forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
            return nil
        }

        // Calendar & reminders
        def(n, "addEvent") { [weak self] a in
            guard let self, self.requestAccess(.event),
                  let start = Self.parseDate(a.str(1)), let end = Self.parseDate(a.str(2)) else { return false }
            let event = EKEvent(eventStore: self.eventStore)
            event.title = a.str(0)
            event.startDate = start
            event.endDate = end
            event.notes = a.str(3).isEmpty ? nil : a.str(3)
            event.calendar = self.eventStore.defaultCalendarForNewEvents
            return (try? self.eventStore.save(event, span: .thisEvent)) != nil
        }
        def(n, "addReminder") { [weak self] a in
            guard let self, self.requestAccess(.reminder) else { return false }
            let reminder = EKReminder(eventStore: self.eventStore)
            reminder.title = a.str(0)
            reminder.notes = a.str(1).isEmpty ? nil : a.str(1)
            reminder.calendar = self.eventStore.defaultCalendarForNewReminders()
            if let due = Self.parseDate(a.str(2)) {
                reminder.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: due)
                reminder.addAlarm(EKAlarm(absoluteDate: due))
            }
            return (try? self.eventStore.save(reminder, commit: true)) != nil
        }

        // Base64
        def(n, "b64encode") { a in Data(a.str(0).utf8).base64EncodedString() }
        def(n, "b64decode") { a in orNull(Self.decodeBase64(a.str(0)).flatMap { String(data: $0, encoding: .utf8) }) }
        def(n, "fileReadBase64") { [weak self] a in
            guard let url = self?.fileURL(a.str(0)) else { return NSNull() }
            return orNull((try? Data(contentsOf: url))?.base64EncodedString())
        }
        def(n, "fileWriteBase64") { [weak self] a in
            guard let url = self?.fileURL(a.str(0)), let data = Self.decodeBase64(a.str(1)) else { return false }
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            return (try? data.write(to: url, options: .atomic)) != nil
        }

        // Audio
        def(n, "audioPlay") { [weak self] a in
            guard let self else { return false }
            let opts = a.dict(1)
            guard let data = self.audioData(a.str(0), base64: (opts["base64"] as? Bool) ?? false) else {
                self.host?.engineLog(.error, "audio: couldn't load \(a.str(0).prefix(60))")
                return false
            }
            return self.playAudio(data, opts)
        }
        def(n, "audioTone") { [weak self] a in
            guard let self else { return false }
            let opts = a.dict(2)
            let wav = AudioPlayer.toneWAV(frequency: a.num(0, 440), duration: a.num(1, 0.3),
                                          volume: (opts["volume"] as? Double) ?? 0.6,
                                          wave: (opts["wave"] as? String) ?? "sine")
            var playOpts = opts
            playOpts["volume"] = 1.0
            if playOpts["wait"] == nil { playOpts["wait"] = true }
            return self.playAudio(wav, playOpts)
        }
        def(n, "audioStop") { [weak self] _ in self?.onMain { self?.audio.stop() }; return nil }
        def(n, "audioToneBase64") { a in
            AudioPlayer.toneWAV(frequency: a.num(0, 440), duration: a.num(1, 0.3), volume: 0.6, wave: a.str(2, "sine"))
                .base64EncodedString()
        }

        // Other scripts
        def(n, "scriptCode") { [weak self] a in
            let name = a.str(0)
            return orNull(self?.onMain { ScriptStore.shared.script(named: name)?.code } ?? nil)
        }
        def(n, "scriptList") { [weak self] _ in
            self?.onMain { ScriptStore.shared.scripts.map(\.name) } ?? [String]()
        }
    }

    // MARK: - Implementations

    private func haptic(_ style: String) {
        onMain {
            switch style {
            case "success": UINotificationFeedbackGenerator().notificationOccurred(.success)
            case "warning": UINotificationFeedbackGenerator().notificationOccurred(.warning)
            case "error": UINotificationFeedbackGenerator().notificationOccurred(.error)
            case "selection": UISelectionFeedbackGenerator().selectionChanged()
            default:
                let styles: [String: UIImpactFeedbackGenerator.FeedbackStyle] = [
                    "light": .light, "medium": .medium, "heavy": .heavy, "soft": .soft, "rigid": .rigid,
                ]
                UIImpactFeedbackGenerator(style: styles[style] ?? .medium).impactOccurred()
            }
        }
    }

    static func setTorch(_ on: Bool, level: Double) -> Bool {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return false }
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            if on {
                try device.setTorchModeOn(level: Float(min(1, max(0.01, level))))
            } else {
                device.torchMode = .off
            }
            return true
        } catch {
            return false
        }
    }

    /// iOS has no public volume API; the standard trick is driving MPVolumeView's slider.
    static func setVolume(_ value: Float) {
        DispatchQueue.main.async {
            let volumeView = MPVolumeView(frame: CGRect(x: -2000, y: -2000, width: 10, height: 10))
            UIHelpers.keyWindow?.addSubview(volumeView)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                let slider = volumeView.subviews.first { $0 is UISlider } as? UISlider
                slider?.value = value
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { volumeView.removeFromSuperview() }
            }
        }
    }

    private func open(_ string: String) -> Bool {
        guard let url = URL(string: string) else { return false }
        return blocking(false) { done in
            UIApplication.shared.open(url, options: [:]) { done($0) }
        }
    }

    /// Settings pane ids. iOS has no public API for these, so AMod tries the known URL forms.
    static let settingsPaths: [String: String] = [
        "wifi": "WIFI",
        "bluetooth": "Bluetooth",
        "cellular": "MOBILE_DATA_SETTINGS_ID",
        "hotspot": "INTERNET_TETHERING",
        "vpn": "General&path=VPN",
        "notifications": "NOTIFICATIONS_ID",
        "sounds": "Sounds",
        "focus": "DO_NOT_DISTURB",
        "screentime": "SCREEN_TIME",
        "general": "General",
        "about": "General&path=About",
        "storage": "General&path=STORAGE_MGMT",
        "keyboard": "General&path=Keyboard",
        "display": "DISPLAY",
        "wallpaper": "Wallpaper",
        "accessibility": "ACCESSIBILITY",
        "battery": "BATTERY_USAGE",
        "privacy": "Privacy",
        "location": "Privacy&path=LOCATION",
        "siri": "SIRI",
        "faceid": "PASSCODE",
        "safari": "SAFARI",
        "airplane": "AIRPLANE_MODE",
        "controlcenter": "ControlCenter",
        "appstore": "STORE",
        "passwords": "PASSWORDS",
    ]

    /// Name of the user's helper shortcut that opens a URL (set in AMod → Settings). Empty = off.
    static var settingsShortcutName: String {
        UserDefaults.standard.string(forKey: "amod.settingsShortcut") ?? ""
    }

    static func settingsURL(for section: String) -> String {
        let key = section.lowercased().replacingOccurrences(of: "-", with: "").replacingOccurrences(of: " ", with: "")
        return Self.settingsPaths[key].map { "prefs:root=\($0)" } ?? "prefs:root"
    }

    private func openSettings(_ section: String) -> Bool {
        let key = section.lowercased().replacingOccurrences(of: "-", with: "").replacingOccurrences(of: " ", with: "")
        if key == "app" { return open(UIApplication.openSettingsURLString) }

        // Newer iOS versions only honour Settings links opened from the Shortcuts app.
        let helper = Self.settingsShortcutName
        if !helper.isEmpty {
            let name = helper.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let text = Self.settingsURL(for: key).addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
            return open("shortcuts://run-shortcut?name=\(name)&input=text&text=\(text)")
        }

        let candidates: [String]
        if let path = Self.settingsPaths[key] {
            candidates = ["App-prefs:\(path)", "App-prefs:root=\(path)", "prefs:root=\(path)"]
        } else {
            candidates = ["App-prefs:", "prefs:root"]
        }
        for candidate in candidates where open(candidate) { return true }
        host?.engineLog(.warn, "iOS blocked the Settings link. Set up the Settings helper shortcut in AMod → ⚙︎ Settings.")
        return false
    }

    // MARK: - Audio

    private func audioData(_ source: String, base64: Bool) -> Data? {
        if base64 || source.hasPrefix("data:") { return Self.decodeBase64(source) }
        if source.hasPrefix("http://") || source.hasPrefix("https://") {
            guard let url = URL(string: source) else { return nil }
            return blocking(nil as Data?, onMainThread: false) { done in
                URLSession.shared.dataTask(with: url) { data, _, _ in done(data) }.resume()
            }
        }
        guard let url = fileURL(source) else { return nil }
        return try? Data(contentsOf: url)
    }

    private func playAudio(_ data: Data, _ opts: [String: Any]) -> Bool {
        let volume = Float((opts["volume"] as? Double) ?? 1)
        let loop = (opts["loop"] as? Bool) ?? false
        let rate = Float((opts["rate"] as? Double) ?? 1)
        if (opts["wait"] as? Bool) == true, !loop {
            return blocking(false) { [audio = self.audio] done in
                if !audio.play(data, volume: volume, loop: false, rate: rate, onEnd: { done(true) }) { done(false) }
            }
        }
        return onMain { audio.play(data, volume: volume, loop: loop, rate: rate, onEnd: {}) }
    }

    /// Accepts plain base64 or a data: URL, with or without whitespace.
    static func decodeBase64(_ string: String) -> Data? {
        var s = string
        if s.hasPrefix("data:"), let comma = s.firstIndex(of: ",") { s = String(s[s.index(after: comma)...]) }
        s = s.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        let pad = s.filter { !$0.isWhitespace }.count % 4
        if pad > 0 { s += String(repeating: "=", count: 4 - pad) }
        return Data(base64Encoded: s, options: .ignoreUnknownCharacters)
    }

    private func http(_ method: String, _ urlString: String, _ headers: [String: Any],
                      _ body: String?, _ timeout: Double, base64: Bool = false) -> [String: Any] {
        guard let url = URL(string: urlString) else { return ["error": "Invalid URL: \(urlString)"] }
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = method.uppercased()
        for (key, value) in headers { request.setValue("\(value)", forHTTPHeaderField: key) }
        if let body { request.httpBody = Data(body.utf8) }

        return blocking(["error": "Request failed"] as [String: Any], onMainThread: false) { done in
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error { done(["error": error.localizedDescription]); return }
                let http = response as? HTTPURLResponse
                var responseHeaders: [String: String] = [:]
                for (key, value) in http?.allHeaderFields ?? [:] { responseHeaders["\(key)"] = "\(value)" }
                let status = http?.statusCode ?? 0
                var result: [String: Any] = [
                    "status": status,
                    "ok": (200..<300).contains(status),
                    "body": String(data: data ?? Data(), encoding: .utf8) ?? "",
                    "headers": responseHeaders,
                ]
                if base64 { result["base64"] = (data ?? Data()).base64EncodedString() }
                done(result)
            }.resume()
        }
    }

    static var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func fileURL(_ path: String) -> URL? {
        guard !path.contains("..") else { return nil }
        return path.isEmpty ? Self.documentsURL : Self.documentsURL.appendingPathComponent(path)
    }

    private func requestAccess(_ type: EKEntityType) -> Bool {
        blocking(false, onMainThread: false) { [eventStore = self.eventStore] done in
            if #available(iOS 17.0, *) {
                if type == .event {
                    eventStore.requestFullAccessToEvents { granted, _ in done(granted) }
                } else {
                    eventStore.requestFullAccessToReminders { granted, _ in done(granted) }
                }
            } else {
                eventStore.requestAccess(to: type) { granted, _ in done(granted) }
            }
        }
    }

    static func parseDate(_ string: String) -> Date? {
        guard !string.isEmpty else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }
}

// MARK: - Helpers

/// JS gets `null` for a missing value instead of `undefined`.
func orNull<T>(_ value: T?) -> Any {
    if let value { return value }
    return NSNull()
}

extension Array where Element == JSValue {
    func str(_ i: Int, _ fallback: String = "") -> String {
        guard i < count, !self[i].isUndefined, !self[i].isNull else { return fallback }
        return self[i].toString() ?? fallback
    }

    func num(_ i: Int, _ fallback: Double = 0) -> Double {
        guard i < count, self[i].isNumber else { return fallback }
        return self[i].toDouble()
    }

    func bool(_ i: Int, _ fallback: Bool = false) -> Bool {
        guard i < count, !self[i].isUndefined, !self[i].isNull else { return fallback }
        return self[i].toBool()
    }

    func strings(_ i: Int) -> [String] {
        guard i < count, self[i].isArray else { return [] }
        return (self[i].toArray() ?? []).map { "\($0)" }
    }

    func dict(_ i: Int) -> [String: Any] {
        guard i < count, self[i].isObject else { return [:] }
        return (self[i].toDictionary() as? [String: Any]) ?? [:]
    }
}

final class SpeechWaiter: NSObject, AVSpeechSynthesizerDelegate {
    var onFinish: (() -> Void)?

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let f = onFinish; onFinish = nil; f?()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        let f = onFinish; onFinish = nil; f?()
    }
}

/// One-shot location request. Create and use on the main thread.
final class LocationFetcher: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var completion: ((CLLocation?) -> Void)?

    func fetch(_ done: @escaping (CLLocation?) -> Void) {
        completion = done
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .denied, .restricted: finish(nil)
        default: manager.requestLocation()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard completion != nil else { return }
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse: manager.requestLocation()
        case .denied, .restricted: finish(nil)
        default: break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        finish(locations.last)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        finish(nil)
    }

    private func finish(_ location: CLLocation?) {
        let c = completion
        completion = nil
        c?(location)
    }
}

/// Plays audio data (any format AVAudioPlayer understands: mp3, m4a, wav, aiff, caf…). Main thread only.
final class AudioPlayer: NSObject, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?
    private var onEnd: (() -> Void)?

    @discardableResult
    func play(_ data: Data, volume: Float, loop: Bool, rate: Float, onEnd: @escaping () -> Void) -> Bool {
        stop()
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, options: [.mixWithOthers])
        try? session.setActive(true)
        guard let player = try? AVAudioPlayer(data: data) else { return false }
        player.delegate = self
        player.volume = volume
        player.numberOfLoops = loop ? -1 : 0
        if rate != 1 {
            player.enableRate = true
            player.rate = rate
        }
        self.player = player
        self.onEnd = onEnd
        guard player.play() else {
            self.player = nil
            self.onEnd = nil
            return false
        }
        return true
    }

    func stop() {
        player?.stop()
        player = nil
        let end = onEnd
        onEnd = nil
        end?()
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard player === self.player else { return }
        self.player = nil
        let end = onEnd
        onEnd = nil
        end?()
    }

    /// A 16-bit mono WAV of a single tone. wave: sine, square, saw, triangle, noise.
    static func toneWAV(frequency: Double, duration: Double, volume: Double, wave: String) -> Data {
        let sampleRate = 44_100
        let count = max(1, Int(Double(sampleRate) * min(max(duration, 0.01), 30)))
        let fade = 300.0
        var pcm = Data(capacity: count * 2)
        for i in 0..<count {
            let t = Double(i) / Double(sampleRate)
            let phase = t * frequency
            let v: Double
            switch wave {
            case "square": v = sin(2 * .pi * phase) >= 0 ? 1 : -1
            case "saw": v = 2 * (phase - (phase + 0.5).rounded(.down))
            case "triangle": v = 2 * abs(2 * (phase - (phase + 0.5).rounded(.down))) - 1
            case "noise": v = Double.random(in: -1...1)
            default: v = sin(2 * .pi * phase)
            }
            let envelope = min(1, Double(i) / fade, Double(count - i) / fade)
            var sample = Int16(max(-1, min(1, v * volume * envelope)) * 32_767).littleEndian
            withUnsafeBytes(of: &sample) { pcm.append(contentsOf: $0) }
        }
        var wav = Data()
        func u32(_ v: UInt32) { var x = v.littleEndian; withUnsafeBytes(of: &x) { wav.append(contentsOf: $0) } }
        func u16(_ v: UInt16) { var x = v.littleEndian; withUnsafeBytes(of: &x) { wav.append(contentsOf: $0) } }
        wav.append(contentsOf: Array("RIFF".utf8)); u32(UInt32(36 + pcm.count))
        wav.append(contentsOf: Array("WAVEfmt ".utf8)); u32(16); u16(1); u16(1)
        u32(UInt32(sampleRate)); u32(UInt32(sampleRate * 2)); u16(2); u16(16)
        wav.append(contentsOf: Array("data".utf8)); u32(UInt32(pcm.count))
        wav.append(pcm)
        return wav
    }
}
