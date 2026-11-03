import Foundation

struct Script: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var icon: String = "chevron.left.forwardslash.chevron.right"
    var color: String = "#007AFF"
    /// Custom icon picked from Photos (square PNG, base64). Wins over emoji and symbol.
    var iconImage: String? = nil
    /// Emoji icon. Wins over the SF Symbol.
    var emoji: String? = nil
    var code: String
    var created = Date()
    var modified = Date()

    var isGUI: Bool { code.contains("ui.render") }
    var kindLabel: String { isGUI ? "GUI script" : "CLI script" }
    var runURL: String { "amod://run?id=\(id.uuidString)" }
}
