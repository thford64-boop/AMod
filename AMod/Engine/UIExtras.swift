import SwiftUI
import Charts
import MapKit
import WebKit

/// Image({system | url | base64 | file | emoji, contentMode: "fit"|"fill", resizable})
struct ScriptImage: View {
    let node: UINode

    private static let cache = NSCache<NSString, UIImage>()

    private var contentMode: ContentMode { node.str("contentMode") == "fill" ? .fill : .fit }

    static func decode(_ base64: String) -> UIImage? {
        let key = base64 as NSString
        if let cached = cache.object(forKey: key) { return cached }
        guard let data = ScriptEngine.decodeBase64(base64), let image = UIImage(data: data) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }

    var body: some View {
        if !node.str("emoji").isEmpty {
            Text(node.str("emoji"))
        } else if !node.str("base64").isEmpty {
            bitmap(Self.decode(node.str("base64")))
        } else if !node.str("file").isEmpty {
            bitmap(UIImage(contentsOfFile: ScriptEngine.documentsURL.appendingPathComponent(node.str("file")).path))
        } else if let url = URL(string: node.str("url")), !node.str("url").isEmpty {
            AsyncImage(url: url) { image in
                image.resizable().aspectRatio(contentMode: contentMode)
            } placeholder: {
                ProgressView()
            }
        } else if node.bool("resizable") {
            Image(systemName: node.str("system", "questionmark")).resizable().aspectRatio(contentMode: contentMode)
        } else {
            Image(systemName: node.str("system", "questionmark"))
        }
    }

    @ViewBuilder
    private func bitmap(_ image: UIImage?) -> some View {
        if let image {
            Image(uiImage: image).resizable().aspectRatio(contentMode: contentMode)
        } else {
            Image(systemName: "photo.badge.exclamationmark").foregroundColor(.secondary)
        }
    }
}

struct GaugeView: View {
    let node: UINode

    var body: some View {
        let lo = node.num("min") ?? 0
        let hi = max(node.num("max") ?? 1, lo + 0.0001)
        let value = min(max(node.num("value") ?? 0, lo), hi)
        let tint = node.props["color"] == nil ? Color.accentColor : Color.named(node.props["color"])
        let gauge = Gauge(value: value, in: lo...hi) { Text(node.str("label")) }
        if node.str("style") == "circular" {
            gauge.gaugeStyle(.accessoryCircular).tint(tint)
        } else {
            gauge.gaugeStyle(.linearCapacity).tint(tint)
        }
    }
}

private let isoFormatter: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()

struct BoundDatePicker: View {
    let node: UINode
    let onChange: (String) -> Void
    @State private var date = Date()

    private var components: DatePickerComponents {
        switch node.str("mode") {
        case "date": return [.date]
        case "time": return [.hourAndMinute]
        default: return [.date, .hourAndMinute]
        }
    }

    var body: some View {
        let picker = DatePicker(node.str("label"), selection: $date, displayedComponents: components)
        Group {
            switch node.str("style") {
            case "graphical": picker.datePickerStyle(.graphical)
            case "wheel": picker.datePickerStyle(.wheel)
            default: picker.datePickerStyle(.compact)
            }
        }
        .onAppear { date = ScriptEngine.parseDate(node.str("value")) ?? Date() }
        .onChange(of: date) { newDate in
            let iso = isoFormatter.string(from: newDate)
            if iso != node.str("value") { onChange(iso) }
        }
    }
}

struct BoundColorPicker: View {
    let label: String
    let value: String
    let onChange: (String) -> Void
    @State private var color = Color.blue

    var body: some View {
        ColorPicker(label, selection: $color, supportsOpacity: false)
            .onAppear { color = Color(hex: value) }
            .onChange(of: color) { newColor in
                let hex = UIColor(newColor).hexString
                if hex.lowercased() != value.lowercased() { onChange(hex) }
            }
    }
}

struct BoundTextEditor: View {
    let value: String
    let onChange: (String) -> Void
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextEditor(text: $text)
            .focused($focused)
            .frame(minHeight: 120)
            .onAppear { text = value }
            .onChange(of: value) { if !focused { text = $0 } }
            .onChange(of: text) { if $0 != value { onChange($0) } }
    }
}

struct ChartPoint: Identifiable {
    let id: Int
    let x: String
    let y: Double
    let series: String
}

struct ChartView: View {
    let node: UINode

    private var points: [ChartPoint] {
        (node.props["data"] as? [Any] ?? []).enumerated().compactMap { index, item in
            guard let d = item as? [String: Any] else { return nil }
            return ChartPoint(id: index, x: (d["x"] as? String) ?? "\(index)",
                              y: (d["y"] as? NSNumber)?.doubleValue ?? 0,
                              series: (d["s"] as? String) ?? "")
        }
    }

    var body: some View {
        let data = points
        let hasSeries = data.contains { !$0.series.isEmpty }
        chart(data)
            .chartLegend(hasSeries ? .visible : .hidden)
            .frame(minHeight: 200)
    }

    @ViewBuilder
    private func chart(_ data: [ChartPoint]) -> some View {
        switch node.str("type") {
        case "line":
            Chart(data) { LineMark(x: .value("X", $0.x), y: .value("Y", $0.y)).foregroundStyle(by: .value("Series", $0.series)) }
        case "area":
            Chart(data) { AreaMark(x: .value("X", $0.x), y: .value("Y", $0.y)).foregroundStyle(by: .value("Series", $0.series)) }
        case "point":
            Chart(data) { PointMark(x: .value("X", $0.x), y: .value("Y", $0.y)).foregroundStyle(by: .value("Series", $0.series)) }
        default:
            Chart(data) { BarMark(x: .value("X", $0.x), y: .value("Y", $0.y)).foregroundStyle(by: .value("Series", $0.series)) }
        }
    }
}

struct MapPin: Identifiable {
    let id: Int
    let coordinate: CLLocationCoordinate2D
    let title: String
}

struct MapNodeView: View {
    let node: UINode
    @State private var region = MKCoordinateRegion()

    private var pins: [MapPin] {
        (node.props["pins"] as? [Any] ?? []).enumerated().compactMap { index, item in
            guard let d = item as? [String: Any],
                  let lat = (d["latitude"] as? NSNumber)?.doubleValue,
                  let lon = (d["longitude"] as? NSNumber)?.doubleValue else { return nil }
            return MapPin(id: index, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon), title: (d["title"] as? String) ?? "")
        }
    }

    var body: some View {
        Map(coordinateRegion: $region, annotationItems: pins) { pin in
            MapMarker(coordinate: pin.coordinate, tint: .red)
        }
        .frame(minHeight: 240)
        .onAppear {
            let span = node.num("span") ?? 0.05
            region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: node.num("latitude") ?? 0, longitude: node.num("longitude") ?? 0),
                span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span))
        }
    }
}

/// WebView("https://…") or WebView("<h1>HTML</h1>") — handy for online tools inside a GUI script.
struct ScriptWebView: UIViewRepresentable {
    let url: String
    let html: String

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let view = WKWebView()
        view.allowsBackForwardNavigationGestures = true
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        let source = url + "\u{0}" + html
        guard context.coordinator.loaded != source else { return }
        context.coordinator.loaded = source
        if let u = URL(string: url), !url.isEmpty {
            view.load(URLRequest(url: u))
        } else {
            view.loadHTMLString(html, baseURL: nil)
        }
    }

    final class Coordinator {
        var loaded = ""
    }
}
