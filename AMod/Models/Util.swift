import SwiftUI
import UIKit

extension UIColor {
    convenience init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
        guard s.count == 6 || s.count == 8, let v = UInt64(s, radix: 16) else { return nil }
        let hasAlpha = s.count == 8
        let r = CGFloat((v >> (hasAlpha ? 24 : 16)) & 0xFF) / 255
        let g = CGFloat((v >> (hasAlpha ? 16 : 8)) & 0xFF) / 255
        let b = CGFloat((v >> (hasAlpha ? 8 : 0)) & 0xFF) / 255
        let a = hasAlpha ? CGFloat(v & 0xFF) / 255 : 1
        self.init(red: r, green: g, blue: b, alpha: a)
    }
}

extension Color {
    init(hex: String) {
        self.init(uiColor: UIColor(hex: hex) ?? .systemBlue)
    }

    /// Named SwiftUI colors or hex strings, as used by scripts.
    static func named(_ value: Any?) -> Color {
        guard let name = value as? String else { return .primary }
        switch name.lowercased() {
        case "red": return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green": return .green
        case "mint": return .mint
        case "teal": return .teal
        case "cyan": return .cyan
        case "blue": return .blue
        case "indigo": return .indigo
        case "purple": return .purple
        case "pink": return .pink
        case "brown": return .brown
        case "gray", "grey": return .gray
        case "black": return .black
        case "white": return .white
        case "clear": return .clear
        case "primary": return .primary
        case "secondary": return .secondary
        case "accent", "accentcolor": return .accentColor
        case "background": return Color(uiColor: .systemBackground)
        case "groupedbackground": return Color(uiColor: .systemGroupedBackground)
        default: return Color(hex: name)
        }
    }
}

enum UIHelpers {
    static var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }

    static var topViewController: UIViewController? {
        var vc = keyWindow?.rootViewController
        while let presented = vc?.presentedViewController { vc = presented }
        return vc
    }
}

enum Palette {
    static let colors = ["#FF3B30", "#FF9500", "#FFCC00", "#34C759", "#00C7BE", "#30B0C7",
                         "#007AFF", "#5856D6", "#AF52DE", "#FF2D55", "#A2845E", "#8E8E93"]
    static let icons = [
        "chevron.left.forwardslash.chevron.right", "terminal", "bolt.fill", "flashlight.on.fill",
        "wand.and.stars", "sparkles", "star.fill", "heart.fill", "house.fill", "gearshape.fill",
        "wifi", "antenna.radiowaves.left.and.right", "battery.100", "sun.max.fill", "moon.fill",
        "speaker.wave.3.fill", "bell.fill", "music.note", "camera.fill", "photo", "map.fill",
        "location.fill", "cloud.sun.fill", "globe", "link", "doc.text.fill", "folder.fill",
        "tray.fill", "calendar", "checklist", "clock.fill", "timer", "alarm.fill",
        "message.fill", "envelope.fill", "phone.fill", "cart.fill", "creditcard.fill",
        "gamecontroller.fill", "dice.fill", "die.face.5.fill", "paintbrush.fill", "hammer.fill",
        "wrench.and.screwdriver.fill", "cpu", "keyboard", "iphone", "applewatch", "airplane",
        "car.fill", "figure.walk", "flame.fill", "drop.fill", "leaf.fill", "pawprint.fill",
        "brain.head.profile", "lock.fill", "key.fill", "eye.fill", "hand.tap.fill", "waveform",
    ]
}
