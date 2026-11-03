import SwiftUI

struct LogLine: Identifiable {
    let id = UUID()
    let kind: LogKind
    let text: String
    var image: UIImage?

    var color: Color {
        switch kind {
        case .out: return .white
        case .info: return .cyan
        case .warn: return .yellow
        case .error: return .red
        case .system, .clear, .image: return .gray
        }
    }
}

/// The interactive host for a running script: console output, GUI tree and prompts.
final class RunSession: ObservableObject, Identifiable, EngineHost {
    let id = UUID()
    let script: Script
    let input: String

    @Published var logs: [LogLine] = []
    @Published var tree: UINode?
    @Published var title: String
    @Published var prompt: PromptRequest?
    @Published var running = false
    @Published var showConsole = false
    @Published var shouldClose = false

    private var engine: ScriptEngine?

    init(script: Script, input: String = "") {
        self.script = script
        self.input = input
        self.title = script.name
    }

    var isInteractive: Bool { true }

    /// Text input prompts are shown inline in the console for CLI scripts.
    var inlinePrompt: PromptRequest? {
        guard let prompt, prompt.isInput, tree == nil || showConsole else { return nil }
        return prompt
    }

    func start() {
        guard engine == nil else { return }
        running = true
        let engine = ScriptEngine(script: script, host: self, input: input)
        self.engine = engine
        engine.start()
    }

    func stop() {
        engine?.stop()
        engine = nil
        let p = prompt
        prompt = nil
        p?.resolve(nil)
        running = false
    }

    func restart() {
        stop()
        logs = []
        tree = nil
        showConsole = false
        title = script.name
        start()
    }

    func invoke(_ id: String, _ value: Any?) {
        engine?.invoke(id, value)
    }

    func answer(_ value: Any?) {
        let p = prompt
        prompt = nil
        p?.resolve(value)
    }

    // MARK: EngineHost (called from the engine queue unless noted)

    func engineLog(_ kind: LogKind, _ text: String) {
        DispatchQueue.main.async {
            if kind == .clear {
                self.logs.removeAll()
                return
            }
            if kind == .image {
                let image = ScriptEngine.decodeBase64(text).flatMap { UIImage(data: $0) }
                self.logs.append(LogLine(kind: .image, text: image == nil ? "[invalid image]" : "", image: image))
            } else {
                self.logs.append(LogLine(kind: kind, text: text))
            }
            if self.logs.count > 5000 { self.logs.removeFirst(self.logs.count - 5000) }
        }
    }

    func engineRender(_ node: UINode?) {
        DispatchQueue.main.async { self.tree = node }
    }

    func enginePresent(_ request: PromptRequest) {
        prompt = request
    }

    func engineSetTitle(_ title: String) {
        DispatchQueue.main.async { self.title = title }
    }

    func engineOutput(_ value: String) {
        engineLog(.info, "Output: \(value)")
    }

    func engineShowConsole() {
        DispatchQueue.main.async { self.showConsole = true }
    }

    func engineDone() {
        DispatchQueue.main.async {
            guard self.running else { return }
            if self.tree == nil {
                self.running = false
                self.logs.append(LogLine(kind: .system, text: "— finished —"))
            }
        }
    }

    func engineClose() {
        DispatchQueue.main.async { self.shouldClose = true }
    }
}
