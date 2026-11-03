import Foundation

struct Script: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var icon: String = "chevron.left.forwardslash.chevron.right"
    var color: String = "#007AFF"
    var code: String
    var created = Date()
    var modified = Date()

    var isGUI: Bool { code.contains("ui.render") }
    var kindLabel: String { isGUI ? "GUI script" : "CLI script" }
    var runURL: String { "amod://run?id=\(id.uuidString)" }
}
