import SwiftUI

/// Handles `amod://` links and owns the currently running script.
///
///   amod://run?id=<uuid>            run a script by id (used by Home Screen icons)
///   amod://run?name=<name>&input=x  run a script by name with input
///   amod://edit?name=<name>         open a script in the editor
final class Router: ObservableObject {
    static let shared = Router()

    @Published var session: RunSession?
    @Published var editing: Script?

    func run(_ script: Script, input: String = "") {
        session?.stop()
        session = RunSession(script: script, input: input)
    }

    func handle(url: URL) {
        guard url.scheme?.lowercased() == "amod",
              let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
        var query: [String: String] = [:]
        for item in comps.queryItems ?? [] { query[item.name] = item.value ?? "" }

        let store = ScriptStore.shared
        var script: Script?
        if let id = query["id"].flatMap(UUID.init(uuidString:)) { script = store.script(id: id) }
        if script == nil, let name = query["name"] { script = store.script(named: name) }

        switch url.host?.lowercased() {
        case "run":
            if let script { run(script, input: query["input"] ?? "") }
        case "edit":
            if let script { editing = script }
        default:
            break
        }
    }
}
