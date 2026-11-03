import SwiftUI
import UIKit

/// The glyph for a script: custom photo, emoji, or SF Symbol.
struct ScriptGlyph: View {
    let script: Script
    var size: CGFloat = 26

    var body: some View {
        if let image = script.iconUIImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size * 1.4, height: size * 1.4)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.32, style: .continuous))
        } else if let emoji = script.emoji, !emoji.isEmpty {
            Text(emoji).font(.system(size: size))
        } else {
            Image(systemName: script.icon)
                .font(.system(size: size * 0.85, weight: .semibold))
                .foregroundColor(.white)
        }
    }
}

/// A full app-style icon tile (coloured square + glyph).
struct ScriptIconTile: View {
    let script: Script
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            if let image = script.iconUIImage {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Color(hex: script.color)
                ScriptGlyph(script: script, size: size * 0.5)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.225, style: .continuous))
    }
}

extension Script {
    var iconUIImage: UIImage? {
        guard let iconImage, !iconImage.isEmpty else { return nil }
        return ScriptImage.decode(iconImage)
    }
}

extension UIImage {
    /// Center-crops to a square and scales to `side` points, for script icons.
    func squareIcon(side: CGFloat = 256) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { _ in
            let scale = max(side / size.width, side / size.height)
            let w = size.width * scale, h = size.height * scale
            draw(in: CGRect(x: (side - w) / 2, y: (side - h) / 2, width: w, height: h))
        }
    }
}
