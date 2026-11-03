import Foundation

/// Runs a script without any UI (used by the Shortcuts "Run AMod Script" action)
/// and returns what it printed, or the value passed to `output(...)`.
enum HeadlessRunner {
    static func run(_ script: Script, input: String, timeout: TimeInterval = 25) async -> String {
        await withCheckedContinuation { continuation in
            let host = HeadlessHost { continuation.resume(returning: $0) }
            let engine = ScriptEngine(script: script, host: host, input: input)
            host.engine = engine
            engine.start()
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                host.engineLog(.warn, "Timed out after \(Int(timeout))s")
                host.finish()
            }
        }
    }
}

private final class HeadlessHost: EngineHost {
    var engine: ScriptEngine?
    private let lock = NSLock()
    private var lines: [String] = []
    private var explicitOutput: String?
    private var completion: ((String) -> Void)?

    init(completion: @escaping (String) -> Void) {
        self.completion = completion
    }

    var isInteractive: Bool { false }

    func engineLog(_ kind: LogKind, _ text: String) {
        lock.lock()
        defer { lock.unlock() }
        switch kind {
        case .clear: lines.removeAll()
        case .error: lines.append("Error: \(text)")
        default: lines.append(text)
        }
    }

    func engineOutput(_ value: String) {
        lock.lock()
        explicitOutput = value
        lock.unlock()
    }

    func engineRender(_ node: UINode?) {}
    func enginePresent(_ request: PromptRequest) { request.resolve(nil) }
    func engineSetTitle(_ title: String) {}
    func engineShowConsole() {}
    func engineDone() { finish() }
    func engineClose() { finish() }

    func finish() {
        lock.lock()
        let completion = self.completion
        self.completion = nil
        let result = explicitOutput ?? lines.joined(separator: "\n")
        lock.unlock()
        guard let completion else { return }
        engine?.stop()
        engine = nil
        completion(result)
    }
}
