import Foundation

enum AModLinks {
    /// GitHub Pages site built from /docs (online tools, templates, guide).
    static let site = URL(string: "https://thford64-boop.github.io/AMod/")!
}

/// A starter script from templates.json (shared with the online tools site).
struct ScriptTemplate: Identifiable, Decodable {
    let id: String
    let name: String
    let category: String
    let icon: String
    let color: String
    let description: String
    let code: String
    let emoji: String?

    func makeScript() -> Script {
        Script(name: name, icon: icon, color: color, emoji: emoji, code: code)
    }

    static let all: [ScriptTemplate] = {
        guard let url = Bundle.main.url(forResource: "templates", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([ScriptTemplate].self, from: data) else { return [] }
        return list
    }()

    static var categories: [String] {
        var seen = Set<String>()
        return all.map(\.category).filter { seen.insert($0).inserted }
    }
}

enum Guide {
    static var url: URL? { Bundle.main.url(forResource: "GUIDE", withExtension: "md") }
    static var text: String { url.flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? "Guide not found." }
}
