import UIKit
import Network

/// Puts a script on the Home Screen as a Web Clip whose URL is `amod://run?id=…`.
/// iOS only installs Web Clips from configuration profiles downloaded in Safari,
/// so AMod serves the profile from a short-lived server on 127.0.0.1 and opens it in Safari.
enum HomeScreenInstaller {
    static func icon(for script: Script, size: CGFloat = 180) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format).image { ctx in
            let base = UIColor(hex: script.color) ?? .systemBlue
            let colors = [base.withAlphaComponent(0.8).cgColor, base.cgColor] as CFArray
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                ctx.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size, y: size), options: [])
            }
            if let custom = script.iconUIImage {
                custom.squareIcon(side: size).draw(in: CGRect(x: 0, y: 0, width: size, height: size))
            } else if let emoji = script.emoji, !emoji.isEmpty {
                let text = emoji as NSString
                let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: size * 0.55)]
                let s = text.size(withAttributes: attrs)
                text.draw(at: CGPoint(x: (size - s.width) / 2, y: (size - s.height) / 2), withAttributes: attrs)
            } else {
                let config = UIImage.SymbolConfiguration(pointSize: size * 0.42, weight: .semibold)
                if let symbol = UIImage(systemName: script.icon, withConfiguration: config)?
                    .withTintColor(.white, renderingMode: .alwaysOriginal) {
                    let s = symbol.size
                    symbol.draw(in: CGRect(x: (size - s.width) / 2, y: (size - s.height) / 2, width: s.width, height: s.height))
                }
            }
        }
    }

    static func profile(for script: Script) -> Data? {
        guard let iconData = icon(for: script).pngData() else { return nil }
        let clip: [String: Any] = [
            "PayloadType": "com.apple.webClip.managed",
            "PayloadVersion": 1,
            "PayloadIdentifier": "com.amod.webclip.\(script.id.uuidString)",
            "PayloadUUID": script.id.uuidString,
            "PayloadDisplayName": script.name,
            "PayloadDescription": "Runs the AMod script \"\(script.name)\".",
            "Label": script.name,
            "URL": script.runURL,
            "Icon": iconData,
            "IsRemovable": true,
            "FullScreen": true,
            "Precomposed": true,
        ]
        let profile: [String: Any] = [
            "PayloadType": "Configuration",
            "PayloadVersion": 1,
            "PayloadIdentifier": "com.amod.shortcut.\(script.id.uuidString)",
            "PayloadUUID": UUID().uuidString,
            "PayloadDisplayName": "AMod: \(script.name)",
            "PayloadDescription": "Adds \"\(script.name)\" to your Home Screen. Tapping it runs the script in AMod.",
            "PayloadOrganization": "AMod",
            "PayloadRemovalDisallowed": false,
            "PayloadContent": [clip],
        ]
        return try? PropertyListSerialization.data(fromPropertyList: profile, format: .xml, options: 0)
    }

    static func install(_ script: Script, completion: @escaping (Bool) -> Void) {
        guard let data = profile(for: script) else { completion(false); return }
        ProfileServer.shared.serve(data, name: "AMod-\(script.name).mobileconfig") { url in
            guard let url else { completion(false); return }
            // Keep the server alive while Safari fetches the profile.
            let task = Box(UIBackgroundTaskIdentifier.invalid)
            task.value = UIApplication.shared.beginBackgroundTask(withName: "amod.profile") {
                UIApplication.shared.endBackgroundTask(task.value)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 25) {
                UIApplication.shared.endBackgroundTask(task.value)
            }
            UIApplication.shared.open(url, options: [:]) { completion($0) }
        }
    }
}

final class ProfileServer {
    static let shared = ProfileServer()
    private var listener: NWListener?
    private var payload = Data()

    func serve(_ data: Data, name: String, ready: @escaping (URL?) -> Void) {
        listener?.cancel()
        payload = data
        let fileName = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "profile.mobileconfig"
        do {
            let params = NWParameters.tcp
            params.requiredInterfaceType = .loopback
            let listener = try NWListener(using: params, on: .any)
            let reported = Box(false)
            listener.newConnectionHandler = { [weak self] connection in self?.handle(connection) }
            listener.stateUpdateHandler = { state in
                DispatchQueue.main.async {
                    guard !reported.value else { return }
                    switch state {
                    case .ready:
                        reported.value = true
                        ready(listener.port.flatMap { URL(string: "http://127.0.0.1:\($0.rawValue)/\(fileName)") })
                    case .failed, .cancelled:
                        reported.value = true
                        ready(nil)
                    default:
                        break
                    }
                }
            }
            listener.start(queue: .global(qos: .userInitiated))
            self.listener = listener
        } catch {
            ready(nil)
        }
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .userInitiated))
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] _, _, _, _ in
            guard let self else { connection.cancel(); return }
            let header = "HTTP/1.1 200 OK\r\n"
                + "Content-Type: application/x-apple-aspen-config\r\n"
                + "Content-Length: \(self.payload.count)\r\n"
                + "Cache-Control: no-store\r\n"
                + "Connection: close\r\n\r\n"
            var response = Data(header.utf8)
            response.append(self.payload)
            connection.send(content: response, completion: .contentProcessed { _ in connection.cancel() })
        }
    }
}

/// Mutable state shared with escaping callbacks. Only touched on the main thread here.
final class Box<T> {
    var value: T
    init(_ value: T) { self.value = value }
}
