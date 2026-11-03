import SwiftUI

/// A view tree sent from a script's `ui.render(...)`.
struct UINode {
    let type: String
    let props: [String: Any]
    let mods: [[Any]]
    let children: [UINode]

    init?(_ object: Any) {
        guard let dict = object as? [String: Any], let type = dict["type"] as? String else { return nil }
        self.type = type
        props = dict["props"] as? [String: Any] ?? [:]
        mods = dict["mods"] as? [[Any]] ?? []
        children = (dict["children"] as? [Any] ?? []).compactMap { UINode($0) }
    }

    func str(_ key: String, _ fallback: String = "") -> String {
        if let s = props[key] as? String { return s }
        if let n = props[key] as? NSNumber { return n.stringValue }
        return fallback
    }

    func num(_ key: String) -> Double? { (props[key] as? NSNumber)?.doubleValue }
    func cg(_ key: String) -> CGFloat? { num(key).map { CGFloat($0) } }
    func bool(_ key: String) -> Bool { (props[key] as? NSNumber)?.boolValue ?? false }
    func callback(_ key: String) -> String? { (props[key] as? [String: Any])?["__cb"] as? String }
}

/// Turns a UINode tree into real SwiftUI views.
struct NodeView: View {
    let node: UINode
    let session: RunSession

    var body: some View { build(node) }

    private func build(_ n: UINode) -> AnyView {
        applyMods(content(n), n)
    }

    @ViewBuilder
    private func children(_ n: UINode) -> some View {
        ForEach(Array(n.children.enumerated()), id: \.offset) { item in
            NodeView(node: item.element, session: session)
        }
    }

    private func call(_ n: UINode, _ key: String, _ value: Any? = nil) {
        if let id = n.callback(key) { session.invoke(id, value) }
    }

    private func content(_ n: UINode) -> AnyView {
        switch n.type {
        case "text":
            return AnyView(Text(n.str("text")))
        case "vstack":
            return AnyView(VStack(alignment: NodeLayout.horizontal(n.str("alignment")), spacing: n.cg("spacing")) { children(n) })
        case "hstack":
            return AnyView(HStack(alignment: NodeLayout.vertical(n.str("alignment")), spacing: n.cg("spacing")) { children(n) })
        case "zstack":
            return AnyView(ZStack(alignment: NodeLayout.alignment(n.str("alignment"))) { children(n) })
        case "scroll":
            return AnyView(ScrollView {
                VStack(alignment: NodeLayout.horizontal(n.str("alignment")), spacing: n.cg("spacing")) { children(n) }
                    .frame(maxWidth: .infinity)
            })
        case "list":
            return AnyView(List { children(n) })
        case "section":
            let title = n.str("title")
            if title.isEmpty { return AnyView(Section { children(n) }) }
            return AnyView(Section { children(n) } header: { Text(title) })
        case "button":
            if n.children.isEmpty {
                return AnyView(Button(n.str("label")) { call(n, "action") })
            }
            return AnyView(Button { call(n, "action") } label: { children(n) })
        case "image":
            return AnyView(ScriptImage(node: n))
        case "label":
            return AnyView(Label(n.str("title"), systemImage: n.str("system", "circle")))
        case "spacer":
            return AnyView(Spacer(minLength: n.cg("min")))
        case "divider":
            return AnyView(Divider())
        case "toggle":
            return AnyView(BoundToggle(label: n.str("label"), value: n.bool("value")) { call(n, "onChange", $0) })
        case "slider":
            let lo = n.num("min") ?? 0, hi = max(n.num("max") ?? 1, lo + 0.0001)
            return AnyView(BoundSlider(value: n.num("value") ?? 0, range: lo...hi, step: n.num("step") ?? 0) {
                call(n, "onChange", $0)
            })
        case "stepper":
            let value = n.num("value") ?? 0, step = n.num("step") ?? 1
            let lo = n.num("min") ?? -.infinity, hi = n.num("max") ?? .infinity
            return AnyView(Stepper(n.str("label"),
                                   onIncrement: { call(n, "onChange", min(hi, value + step)) },
                                   onDecrement: { call(n, "onChange", max(lo, value - step)) }))
        case "textfield":
            return AnyView(BoundTextField(placeholder: n.str("placeholder"), value: n.str("value"), secure: n.bool("secure"),
                                          onChange: { call(n, "onChange", $0) },
                                          onSubmit: { call(n, "onSubmit", $0) }))
        case "picker":
            let options = (n.props["options"] as? [Any] ?? []).map { "\($0)" }
            let selection = Binding<String>(get: { n.str("value") }, set: { call(n, "onChange", $0) })
            return AnyView(Picker(n.str("label"), selection: selection) {
                ForEach(options, id: \.self) { Text($0).tag($0) }
            }.pickerStyle(.menu))
        case "progress":
            if let value = n.num("value") {
                return AnyView(ProgressView(value: value, total: max(n.num("total") ?? 1, 0.0001)))
            }
            return AnyView(ProgressView())
        case "color":
            return AnyView(Color.named(n.props["color"]))
        case "link":
            if let url = URL(string: n.str("url")) {
                return AnyView(Link(n.str("label"), destination: url))
            }
            return AnyView(Text(n.str("label")))
        case "grid":
            let spacing = n.cg("spacing") ?? 12
            let columns: [GridItem]
            if let minWidth = n.cg("minWidth") {
                columns = [GridItem(.adaptive(minimum: minWidth), spacing: spacing)]
            } else {
                columns = Array(repeating: GridItem(.flexible(), spacing: spacing), count: max(1, Int(n.num("columns") ?? 2)))
            }
            return AnyView(LazyVGrid(columns: columns, spacing: spacing) { children(n) })
        case "shape":
            switch n.str("shape") {
            case "circle": return AnyView(Circle())
            case "capsule": return AnyView(Capsule())
            case "rounded": return AnyView(RoundedRectangle(cornerRadius: n.cg("radius") ?? 12, style: .continuous))
            default: return AnyView(Rectangle())
            }
        case "gradient":
            return AnyView(NodeLayout.gradient(n.props["colors"], n.str("direction")))
        case "gauge":
            return AnyView(GaugeView(node: n))
        case "datepicker":
            return AnyView(BoundDatePicker(node: n) { call(n, "onChange", $0) })
        case "colorpicker":
            return AnyView(BoundColorPicker(label: n.str("label"), value: n.str("value")) { call(n, "onChange", $0) })
        case "texteditor":
            return AnyView(BoundTextEditor(value: n.str("value")) { call(n, "onChange", $0) })
        case "menu":
            let label = n.str("label")
            if label.isEmpty, let first = n.children.first {
                let rest = Array(n.children.dropFirst())
                return AnyView(Menu {
                    ForEach(Array(rest.enumerated()), id: \.offset) { NodeView(node: $0.element, session: session) }
                } label: {
                    NodeView(node: first, session: session)
                })
            }
            return AnyView(Menu(label) { children(n) })
        case "disclosure":
            return AnyView(DisclosureGroup(n.str("label")) { children(n) })
        case "groupbox":
            let title = n.str("title")
            if title.isEmpty { return AnyView(GroupBox { children(n) }) }
            return AnyView(GroupBox { children(n) } label: { Text(title) })
        case "tab":
            return AnyView(VStack { children(n) })
        case "tabview":
            return AnyView(TabView {
                ForEach(Array(n.children.enumerated()), id: \.offset) { item in
                    NodeView(node: item.element, session: session)
                        .tabItem { Label(item.element.str("title"), systemImage: item.element.str("system", "circle")) }
                        .tag(item.offset)
                }
            })
        case "navlink":
            guard n.children.count >= 2 else { return AnyView(EmptyView()) }
            return AnyView(NavigationLink {
                ScrollView { NodeView(node: n.children[1], session: session).padding() }
            } label: {
                NodeView(node: n.children[0], session: session)
            })
        case "chart":
            return AnyView(ChartView(node: n))
        case "map":
            return AnyView(MapNodeView(node: n))
        case "web":
            return AnyView(ScriptWebView(url: n.str("url"), html: n.str("html")))
        default:
            return AnyView(Text("Unknown view: \(n.type)").foregroundColor(.red))
        }
    }

    private func applyMods(_ view: AnyView, _ n: UINode) -> AnyView {
        var v = view
        for mod in n.mods {
            guard let name = mod.first as? String else { continue }
            let a = Array(mod.dropFirst())
            let first: Any? = a.first
            switch name {
            case "padding":
                if let edges = first as? String {
                    v = AnyView(v.padding(NodeLayout.edges(edges), NodeLayout.cg(a.count > 1 ? a[1] : nil) ?? 16))
                } else {
                    v = AnyView(v.padding(NodeLayout.cg(first) ?? 16))
                }
            case "font":
                v = AnyView(v.font(NodeLayout.font(a)))
            case "fontWeight":
                v = AnyView(v.fontWeight(NodeLayout.weight(first as? String) ?? .regular))
            case "bold":
                v = AnyView(v.bold())
            case "italic":
                v = AnyView(v.italic())
            case "monospaced":
                v = AnyView(v.font(.system(.body, design: .monospaced)))
            case "foregroundColor", "foregroundStyle":
                v = AnyView(v.foregroundColor(Color.named(first)))
            case "background":
                v = AnyView(v.background(Color.named(first)))
            case "cornerRadius":
                v = AnyView(v.clipShape(RoundedRectangle(cornerRadius: NodeLayout.cg(first) ?? 8, style: .continuous)))
            case "clipShape":
                if (first as? String) == "circle" {
                    v = AnyView(v.clipShape(Circle()))
                } else if (first as? String) == "capsule" {
                    v = AnyView(v.clipShape(Capsule()))
                }
            case "frame":
                let d = first as? [String: Any] ?? [:]
                let align = NodeLayout.alignment(d["alignment"] as? String ?? "")
                if d["width"] != nil || d["height"] != nil {
                    v = AnyView(v.frame(width: NodeLayout.dim(d["width"]), height: NodeLayout.dim(d["height"]), alignment: align))
                }
                if d["minWidth"] != nil || d["maxWidth"] != nil || d["minHeight"] != nil || d["maxHeight"] != nil {
                    v = AnyView(v.frame(minWidth: NodeLayout.dim(d["minWidth"]), maxWidth: NodeLayout.dim(d["maxWidth"]),
                                        minHeight: NodeLayout.dim(d["minHeight"]), maxHeight: NodeLayout.dim(d["maxHeight"]),
                                        alignment: align))
                }
            case "opacity":
                v = AnyView(v.opacity(Double(NodeLayout.cg(first) ?? 1)))
            case "tint":
                v = AnyView(v.tint(Color.named(first)))
            case "onTapGesture":
                if let id = (first as? [String: Any])?["__cb"] as? String {
                    v = AnyView(v.onTapGesture { session.invoke(id, nil) })
                }
            case "shadow":
                v = AnyView(v.shadow(radius: NodeLayout.cg(first) ?? 4))
            case "border":
                let color = Color.named(first ?? "gray")
                let width = NodeLayout.cg(a.count > 1 ? a[1] : nil) ?? 1
                let radius = NodeLayout.cg(a.count > 2 ? a[2] : nil) ?? 0
                v = AnyView(v.overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(color, lineWidth: width)))
            case "rotationEffect":
                v = AnyView(v.rotationEffect(.degrees(Double(NodeLayout.cg(first) ?? 0))))
            case "scaleEffect":
                v = AnyView(v.scaleEffect(NodeLayout.cg(first) ?? 1))
            case "offset":
                v = AnyView(v.offset(x: NodeLayout.cg(first) ?? 0, y: NodeLayout.cg(a.count > 1 ? a[1] : nil) ?? 0))
            case "multilineTextAlignment":
                let align: TextAlignment = (first as? String) == "center" ? .center : (first as? String) == "trailing" ? .trailing : .leading
                v = AnyView(v.multilineTextAlignment(align))
            case "lineLimit":
                v = AnyView(v.lineLimit((first as? NSNumber)?.intValue))
            case "disabled":
                v = AnyView(v.disabled((first as? NSNumber)?.boolValue ?? true))
            case "buttonStyle":
                switch first as? String {
                case "borderedProminent": v = AnyView(v.buttonStyle(.borderedProminent))
                case "bordered": v = AnyView(v.buttonStyle(.bordered))
                case "borderless": v = AnyView(v.buttonStyle(.borderless))
                case "plain": v = AnyView(v.buttonStyle(.plain))
                default: break
                }
            case "textFieldStyle":
                if (first as? String) == "roundedBorder" { v = AnyView(v.textFieldStyle(.roundedBorder)) }
            case "listStyle":
                switch first as? String {
                case "plain": v = AnyView(v.listStyle(.plain))
                case "grouped": v = AnyView(v.listStyle(.grouped))
                case "inset": v = AnyView(v.listStyle(.inset))
                default: v = AnyView(v.listStyle(.insetGrouped))
                }
            case "navigationTitle":
                v = AnyView(v.navigationTitle((first as? String) ?? ""))
            case "ignoresSafeArea":
                v = AnyView(v.ignoresSafeArea())
            case "fill":
                v = AnyView(v.foregroundColor(Color.named(first)))
            case "gradient":
                v = AnyView(v.background(NodeLayout.gradient(first, (a.count > 1 ? a[1] as? String : nil) ?? "")))
            case "blur":
                v = AnyView(v.blur(radius: NodeLayout.cg(first) ?? 4))
            case "grayscale":
                v = AnyView(v.grayscale(Double(NodeLayout.cg(first) ?? 1)))
            case "saturation":
                v = AnyView(v.saturation(Double(NodeLayout.cg(first) ?? 1)))
            case "brightness":
                v = AnyView(v.brightness(Double(NodeLayout.cg(first) ?? 0)))
            case "contrast":
                v = AnyView(v.contrast(Double(NodeLayout.cg(first) ?? 1)))
            case "aspectRatio":
                let mode: ContentMode = ((a.count > 1 ? a[1] : first) as? String) == "fill" ? .fill : .fit
                v = AnyView(v.aspectRatio(NodeLayout.cg(first), contentMode: mode))
            case "onLongPressGesture":
                if let id = (first as? [String: Any])?["__cb"] as? String {
                    v = AnyView(v.onLongPressGesture { session.invoke(id, nil) })
                }
            case "contextMenu":
                let items = (first as? [Any] ?? []).compactMap { $0 as? [String: Any] }
                v = AnyView(v.contextMenu {
                    ForEach(Array(items.enumerated()), id: \.offset) { item in
                        let d = item.element
                        Button(role: (d["destructive"] as? Bool) == true ? .destructive : nil) {
                            if let id = (d["action"] as? [String: Any])?["__cb"] as? String { session.invoke(id, nil) }
                        } label: {
                            Label((d["title"] as? String) ?? "", systemImage: (d["icon"] as? String) ?? "circle")
                        }
                    }
                })
            case "badge":
                if let count = first as? NSNumber {
                    v = AnyView(v.badge(count.intValue))
                } else {
                    v = AnyView(v.badge((first as? String).map { Text($0) }))
                }
            case "hidden":
                if (first as? NSNumber)?.boolValue ?? true { v = AnyView(v.hidden()) }
            case "refreshable":
                if let id = (first as? [String: Any])?["__cb"] as? String {
                    v = AnyView(v.refreshable {
                        session.invoke(id, nil)
                        try? await Task.sleep(nanoseconds: 600_000_000)
                    })
                }
            case "imageScale":
                let scale: Image.Scale = (first as? String) == "small" ? .small : (first as? String) == "large" ? .large : .medium
                v = AnyView(v.imageScale(scale))
            case "toggleStyle":
                if (first as? String) == "button" { v = AnyView(v.toggleStyle(.button)) } else { v = AnyView(v.toggleStyle(.switch)) }
            case "pickerStyle":
                switch first as? String {
                case "segmented": v = AnyView(v.pickerStyle(.segmented))
                case "wheel": v = AnyView(v.pickerStyle(.wheel))
                case "inline": v = AnyView(v.pickerStyle(.inline))
                default: v = AnyView(v.pickerStyle(.menu))
                }
            case "controlSize":
                let sizes: [String: ControlSize] = ["mini": .mini, "small": .small, "regular": .regular, "large": .large]
                v = AnyView(v.controlSize(sizes[(first as? String) ?? ""] ?? .regular))
            case "fixedSize":
                v = AnyView(v.fixedSize())
            case "labelsHidden":
                v = AnyView(v.labelsHidden())
            case "zIndex":
                v = AnyView(v.zIndex(Double(NodeLayout.cg(first) ?? 0)))
            case "animation":
                v = AnyView(v.animation((first as? String) == "none" ? nil : .spring(response: 0.35, dampingFraction: 0.8)))
            case "symbolRenderingMode":
                switch first as? String {
                case "multicolor": v = AnyView(v.symbolRenderingMode(.multicolor))
                case "hierarchical": v = AnyView(v.symbolRenderingMode(.hierarchical))
                case "palette": v = AnyView(v.symbolRenderingMode(.palette))
                default: v = AnyView(v.symbolRenderingMode(.monochrome))
                }
            case "overlay":
                if let text = first as? String {
                    v = AnyView(v.overlay(alignment: NodeLayout.alignment((a.count > 1 ? a[1] as? String : nil) ?? "")) { Text(text) })
                }
            case "listRowBackground":
                v = AnyView(v.listRowBackground(Color.named(first)))
            case "scrollContentBackground":
                v = AnyView(v.scrollContentBackground((first as? String) == "visible" ? .visible : .hidden))
            case "containerBackground":
                v = AnyView(v.background(Color.named(first).ignoresSafeArea()))
            case "minimumScaleFactor":
                v = AnyView(v.minimumScaleFactor(NodeLayout.cg(first) ?? 0.5))
            case "truncationMode":
                let mode: Text.TruncationMode = (first as? String) == "head" ? .head : (first as? String) == "middle" ? .middle : .tail
                v = AnyView(v.truncationMode(mode))
            case "tracking":
                v = AnyView(v.tracking(NodeLayout.cg(first) ?? 1))
            case "underline":
                v = AnyView(v.underline())
            case "strikethrough":
                v = AnyView(v.strikethrough())
            case "shadowColor":
                v = AnyView(v.shadow(color: Color.named(first).opacity(0.5), radius: NodeLayout.cg(a.count > 1 ? a[1] : nil) ?? 8,
                                     x: NodeLayout.cg(a.count > 2 ? a[2] : nil) ?? 0, y: NodeLayout.cg(a.count > 3 ? a[3] : nil) ?? 4))
            case "glass":
                v = AnyView(v.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: NodeLayout.cg(first) ?? 16, style: .continuous)))
            default:
                break
            }
        }
        return v
    }
}

enum NodeLayout {
    static func gradient(_ colors: Any?, _ direction: String) -> LinearGradient {
        let list = (colors as? [Any] ?? ["blue", "purple"]).map { Color.named($0) }
        let points: (UnitPoint, UnitPoint)
        switch direction {
        case "horizontal": points = (.leading, .trailing)
        case "diagonal": points = (.topLeading, .bottomTrailing)
        default: points = (.top, .bottom)
        }
        return LinearGradient(colors: list, startPoint: points.0, endPoint: points.1)
    }

    static func cg(_ value: Any?) -> CGFloat? {
        (value as? NSNumber).map { CGFloat($0.doubleValue) }
    }

    /// Like `cg`, but accepts "inf"/"max" (scripts pass `Infinity`).
    static func dim(_ value: Any?) -> CGFloat? {
        if let s = value as? String, ["inf", "infinity", "max"].contains(s.lowercased()) { return .infinity }
        return cg(value)
    }

    static func horizontal(_ s: String) -> HorizontalAlignment {
        switch s {
        case "leading": return .leading
        case "trailing": return .trailing
        default: return .center
        }
    }

    static func vertical(_ s: String) -> VerticalAlignment {
        switch s {
        case "top": return .top
        case "bottom": return .bottom
        case "firstTextBaseline": return .firstTextBaseline
        default: return .center
        }
    }

    static func alignment(_ s: String) -> Alignment {
        switch s {
        case "leading": return .leading
        case "trailing": return .trailing
        case "top": return .top
        case "bottom": return .bottom
        case "topLeading": return .topLeading
        case "topTrailing": return .topTrailing
        case "bottomLeading": return .bottomLeading
        case "bottomTrailing": return .bottomTrailing
        default: return .center
        }
    }

    static func edges(_ s: String) -> Edge.Set {
        switch s {
        case "horizontal": return .horizontal
        case "vertical": return .vertical
        case "top": return .top
        case "bottom": return .bottom
        case "leading": return .leading
        case "trailing": return .trailing
        default: return .all
        }
    }

    static func weight(_ s: String?) -> Font.Weight? {
        switch s {
        case "ultraLight": return .ultraLight
        case "thin": return .thin
        case "light": return .light
        case "regular": return .regular
        case "medium": return .medium
        case "semibold": return .semibold
        case "bold": return .bold
        case "heavy": return .heavy
        case "black": return .black
        default: return nil
        }
    }

    /// font("title"), font("title", "bold"), font(28), font(28, "semibold", "rounded")
    static func font(_ args: [Any]) -> Font {
        let w = weight(args.count > 1 ? args[1] as? String : nil)
        let designName = args.count > 2 ? args[2] as? String : nil
        let design: Font.Design = designName == "monospaced" ? .monospaced
            : designName == "rounded" ? .rounded
            : designName == "serif" ? .serif : .default
        if let size = args.first as? NSNumber {
            return .system(size: CGFloat(size.doubleValue), weight: w ?? .regular, design: design)
        }
        let styles: [String: Font.TextStyle] = [
            "largeTitle": .largeTitle, "title": .title, "title2": .title2, "title3": .title3,
            "headline": .headline, "subheadline": .subheadline, "body": .body, "callout": .callout,
            "footnote": .footnote, "caption": .caption, "caption2": .caption2,
        ]
        var font = Font.system(styles[args.first as? String ?? "body"] ?? .body, design: design)
        if let w { font = font.weight(w) }
        return font
    }
}

// MARK: - Controls that keep local state so typing/dragging stays smooth while the script re-renders.

struct BoundToggle: View {
    let label: String
    let value: Bool
    let onChange: (Bool) -> Void
    @State private var isOn = false

    var body: some View {
        Toggle(label, isOn: $isOn)
            .onAppear { isOn = value }
            .onChange(of: value) { isOn = $0 }
            .onChange(of: isOn) { if $0 != value { onChange($0) } }
    }
}

struct BoundSlider: View {
    let value: Double
    let range: ClosedRange<Double>
    let step: Double
    let onChange: (Double) -> Void
    @State private var current = 0.0
    @State private var editing = false

    var body: some View {
        Group {
            if step > 0 {
                Slider(value: $current, in: range, step: step) { editing = $0 }
            } else {
                Slider(value: $current, in: range) { editing = $0 }
            }
        }
        .onAppear { current = value }
        .onChange(of: value) { if !editing { current = $0 } }
        .onChange(of: current) { if $0 != value { onChange($0) } }
    }
}

struct BoundTextField: View {
    let placeholder: String
    let value: String
    let secure: Bool
    let onChange: (String) -> Void
    let onSubmit: (String) -> Void
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        Group {
            if secure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
            }
        }
        .focused($focused)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .onAppear { text = value }
        .onChange(of: value) { if !focused { text = $0 } }
        .onChange(of: text) { if $0 != value { onChange($0) } }
        .onSubmit { onSubmit(text) }
    }
}
