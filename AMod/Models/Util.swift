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

extension UIColor {
    var hexString: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        let clamp = { (v: CGFloat) in Int((min(max(v, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", clamp(r), clamp(g), clamp(b))
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
        case "secondarybackground": return Color(uiColor: .secondarySystemBackground)
        case "tertiarybackground": return Color(uiColor: .tertiarySystemBackground)
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
    static var icons: [String] { iconGroups.flatMap(\.1) }

    static let iconGroups: [(String, [String])] = [
        ("Coding", ["chevron.left.forwardslash.chevron.right", "terminal", "terminal.fill", "curlybraces", "curlybraces.square.fill",
                    "function", "cpu", "cpu.fill", "memorychip", "server.rack", "externaldrive.fill", "keyboard", "command",
                    "option", "hammer.fill", "wrench.and.screwdriver.fill", "gearshape.fill", "gearshape.2.fill", "ladybug.fill",
                    "ant.fill", "puzzlepiece.extension.fill", "cube.fill", "shippingbox.fill", "number", "textformat",
                    "app.badge.fill", "apps.iphone", "square.grid.2x2.fill", "rectangle.3.group.fill", "macwindow"]),
        ("Device", ["iphone", "ipad", "applewatch", "airpods", "homepod.fill", "appletv.fill", "laptopcomputer", "desktopcomputer",
                    "flashlight.on.fill", "flashlight.off.fill", "battery.100", "battery.25", "bolt.fill", "bolt.circle.fill",
                    "powerplug.fill", "sun.max.fill", "sun.min.fill", "moon.fill", "moon.stars.fill", "speaker.wave.3.fill",
                    "speaker.slash.fill", "iphone.radiowaves.left.and.right", "hand.tap.fill", "camera.fill", "mic.fill",
                    "lock.fill", "lock.open.fill", "faceid", "touchid", "key.fill", "qrcode", "barcode.viewfinder", "sensor.fill"]),
        ("Connectivity", ["wifi", "wifi.slash", "antenna.radiowaves.left.and.right", "airplane", "personalhotspot",
                          "network", "globe", "globe.americas.fill", "link", "icloud.fill", "icloud.and.arrow.down.fill",
                          "arrow.down.circle.fill", "arrow.up.circle.fill", "arrow.triangle.2.circlepath", "dot.radiowaves.left.and.right",
                          "cellularbars", "location.fill", "location.north.fill", "map.fill", "mappin.and.ellipse", "safari.fill"]),
        ("Media", ["music.note", "music.note.list", "music.mic", "headphones", "play.fill", "pause.fill", "stop.fill",
                   "forward.fill", "backward.fill", "shuffle", "repeat", "waveform", "waveform.circle.fill", "metronome.fill",
                   "pianokeys", "guitars.fill", "film.fill", "tv.fill", "photo.fill", "photo.on.rectangle", "camera.aperture",
                   "video.fill", "paintpalette.fill", "paintbrush.fill", "pencil.and.outline", "scribble.variable", "wand.and.stars",
                   "sparkles", "theatermasks.fill", "megaphone.fill", "radio.fill", "mic.circle.fill"]),
        ("Communication", ["message.fill", "bubble.left.and.bubble.right.fill", "envelope.fill", "paperplane.fill",
                           "phone.fill", "video.bubble.left.fill", "person.fill", "person.2.fill", "person.crop.circle.fill",
                           "at", "bell.fill", "bell.badge.fill", "quote.bubble.fill", "hand.wave.fill", "hand.thumbsup.fill",
                           "heart.fill", "star.fill", "flag.fill", "bookmark.fill", "tag.fill", "gift.fill", "party.popper.fill"]),
        ("Productivity", ["doc.text.fill", "doc.on.clipboard.fill", "note.text", "list.bullet", "checklist", "checkmark.circle.fill",
                          "calendar", "calendar.badge.plus", "clock.fill", "alarm.fill", "timer", "stopwatch.fill", "hourglass",
                          "folder.fill", "tray.full.fill", "archivebox.fill", "book.fill", "books.vertical.fill", "graduationcap.fill",
                          "briefcase.fill", "chart.bar.fill", "chart.pie.fill", "chart.line.uptrend.xyaxis", "percent",
                          "plus.forwardslash.minus", "x.squareroot", "sum", "ruler.fill", "pencil", "square.and.pencil",
                          "magnifyingglass", "trash.fill", "printer.fill", "scanner.fill", "signature"]),
        ("Lifestyle", ["house.fill", "building.2.fill", "cart.fill", "bag.fill", "creditcard.fill", "dollarsign.circle.fill",
                       "bitcoinsign.circle.fill", "car.fill", "bus.fill", "tram.fill", "bicycle", "figure.walk", "figure.run",
                       "dumbbell.fill", "sportscourt.fill", "fork.knife", "cup.and.saucer.fill", "takeoutbag.and.cup.and.straw.fill",
                       "birthday.cake.fill", "bed.double.fill", "heart.text.square.fill", "cross.case.fill", "pills.fill",
                       "leaf.fill", "tree.fill", "pawprint.fill", "fish.fill", "bird.fill", "tortoise.fill", "hare.fill"]),
        ("Weather & Nature", ["cloud.sun.fill", "cloud.rain.fill", "cloud.bolt.rain.fill", "cloud.snow.fill", "snowflake",
                              "wind", "tornado", "thermometer.sun.fill", "drop.fill", "flame.fill", "sunrise.fill", "sunset.fill",
                              "rainbow", "sparkle", "moon.zzz.fill", "globe.europe.africa.fill", "mountain.2.fill", "water.waves"]),
        ("Games & Fun", ["gamecontroller.fill", "dice.fill", "die.face.5.fill", "suit.heart.fill", "suit.spade.fill",
                         "suit.club.fill", "suit.diamond.fill", "puzzlepiece.fill", "trophy.fill", "crown.fill", "medal.fill",
                         "target", "scope", "atom", "brain.head.profile", "eye.fill", "face.smiling.fill", "theatermask.and.paintbrush.fill",
                         "rocket.fill", "airplane.departure", "sailboat.fill", "binoculars.fill", "light.beacon.max.fill", "bolt.heart.fill"]),
        ("Symbols", ["circle.fill", "square.fill", "triangle.fill", "diamond.fill", "hexagon.fill", "seal.fill", "shield.fill",
                     "checkmark.shield.fill", "exclamationmark.triangle.fill", "questionmark.circle.fill", "info.circle.fill",
                     "plus.circle.fill", "minus.circle.fill", "xmark.circle.fill", "arrow.right.circle.fill", "arrowshape.turn.up.right.fill",
                     "infinity", "power", "switch.2", "slider.horizontal.3", "dial.max.fill", "gauge.with.dots.needle.67percent",
                     "eyedropper.full", "lasso", "scissors", "paperclip", "pin.fill", "hand.raised.fill", "nosign"]),
    ]

    static let emojis = ["⚡️", "🔦", "🔥", "✨", "🚀", "💡", "🎵", "🎧", "🔊", "📸", "🎮", "🎲", "🧠", "🤖", "👾", "💻",
                         "📱", "⌚️", "🔋", "📶", "🌐", "📡", "🛰️", "🗺️", "🌤️", "🌧️", "❄️", "🌈", "🌙", "☀️", "⏰", "⏱️",
                         "📅", "📝", "📚", "📦", "🗂️", "🔒", "🔑", "🛠️", "⚙️", "🧪", "🧬", "💊", "❤️", "💬", "📣", "🔔",
                         "🎉", "🎁", "🏠", "🚗", "✈️", "🍕", "☕️", "🐶", "🐱", "🦊", "🐸", "🌵", "🌸", "💎", "👑", "🎯"]
}
