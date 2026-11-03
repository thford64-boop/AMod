import Foundation

/// Persists scripts as JSON in Application Support. Access from the main thread.
final class ScriptStore: ObservableObject {
    static let shared = ScriptStore()

    @Published private(set) var scripts: [Script] = []
    private let fileURL: URL

    private init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AMod", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("scripts.json")
        load()
    }

    private func load() {
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([Script].self, from: data) {
            scripts = decoded
        } else {
            scripts = Examples.all
            save()
        }
    }

    func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(scripts) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    func upsert(_ script: Script) {
        var script = script
        script.modified = Date()
        if let i = scripts.firstIndex(where: { $0.id == script.id }) {
            scripts[i] = script
        } else {
            scripts.insert(script, at: 0)
        }
        save()
    }

    func delete(_ script: Script) {
        scripts.removeAll { $0.id == script.id }
        save()
    }

    @discardableResult
    func duplicate(_ script: Script) -> Script {
        var copy = script
        copy.id = UUID()
        copy.name += " Copy"
        copy.created = Date()
        copy.modified = Date()
        let index = (scripts.firstIndex(where: { $0.id == script.id }) ?? -1) + 1
        scripts.insert(copy, at: index)
        save()
        return copy
    }

    func script(id: UUID) -> Script? {
        scripts.first { $0.id == id }
    }

    func script(named name: String) -> Script? {
        scripts.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }
}
