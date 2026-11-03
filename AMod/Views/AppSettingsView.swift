import SwiftUI

struct AppSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("amod.settingsShortcut") private var helperName = ""
    @State private var showGuide = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Shortcut name, e.g. AMod Settings", text: $helperName)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button {
                        open(helperName.isEmpty ? "App-prefs:WIFI" : helperURL(for: "wifi"))
                    } label: {
                        Label("Test (open Wi-Fi settings)", systemImage: "wifi")
                    }
                    Button {
                        UIApplication.shared.open(URL(string: "shortcuts://create-shortcut")!)
                    } label: {
                        Label("Create the shortcut", systemImage: "square.stack.3d.up.fill")
                    }
                } header: {
                    Text("Settings helper shortcut")
                } footer: {
                    Text("""
                    Newer iOS versions block apps from opening specific Settings pages, so `settings.open()` lands on AMod's own page. Shortcuts is still allowed to open them:
                    1. In Shortcuts, make a shortcut named **AMod Settings**.
                    2. Add **Open URLs** and set it to **Shortcut Input**.
                    3. Enter its name above and tap Test.
                    Leave the name empty to have AMod try the links directly.
                    """)
                }

                Section("Learn") {
                    Button { showGuide = true } label: { Label("Guide", systemImage: "book.fill") }
                    if let url = Guide.url {
                        ShareLink(item: url) { Label("Download GUIDE.md", systemImage: "arrow.down.doc.fill") }
                    }
                    Link(destination: AModLinks.site) { Label("Online tools & templates", systemImage: "safari.fill") }
                }

                Section("Your files") {
                    Button {
                        let path = ScriptEngine.documentsURL.path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
                        if let url = URL(string: "shareddocuments://\(path)") { UIApplication.shared.open(url) }
                    } label: {
                        Label("Open AMod folder in Files", systemImage: "folder.fill")
                    }
                }

                Section {
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .sheet(isPresented: $showGuide) { GuideView() }
        }
    }

    private func helperURL(for section: String) -> String {
        let name = helperName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let text = ScriptEngine.settingsURL(for: section).addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
        return "shortcuts://run-shortcut?name=\(name)&input=text&text=\(text)"
    }

    private func open(_ string: String) {
        guard let url = URL(string: string) else { return }
        UIApplication.shared.open(url)
    }
}

struct GuideView: View {
    @Environment(\.dismiss) private var dismiss

    /// Renders the guide line by line: headings big, code monospaced, the rest as inline Markdown.
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                        lineView(line)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if let url = Guide.url {
                        ShareLink(item: url) { Image(systemName: "square.and.arrow.down") }
                    }
                }
            }
        }
    }

    private enum Line {
        case heading(String, Int), code(String), text(String), rule
    }

    private var lines: [Line] {
        var result: [Line] = []
        var inCode = false
        var code: [String] = []
        for raw in Guide.text.components(separatedBy: "\n") {
            if raw.hasPrefix("```") {
                if inCode { result.append(.code(code.joined(separator: "\n"))); code = [] }
                inCode.toggle()
                continue
            }
            if inCode { code.append(raw); continue }
            if raw.hasPrefix("### ") { result.append(.heading(String(raw.dropFirst(4)), 3)) }
            else if raw.hasPrefix("## ") { result.append(.heading(String(raw.dropFirst(3)), 2)) }
            else if raw.hasPrefix("# ") { result.append(.heading(String(raw.dropFirst(2)), 1)) }
            else if raw == "---" { result.append(.rule) }
            else if !raw.trimmingCharacters(in: .whitespaces).isEmpty { result.append(.text(raw)) }
        }
        return result
    }

    @ViewBuilder
    private func lineView(_ line: Line) -> some View {
        switch line {
        case .heading(let text, let level):
            Text(text)
                .font(level == 1 ? .largeTitle.bold() : level == 2 ? .title2.bold() : .headline)
                .padding(.top, level == 1 ? 0 : 12)
        case .code(let text):
            Text(text)
                .font(.system(.footnote, design: .monospaced))
                .textSelection(.enabled)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
        case .text(let text):
            Text((try? AttributedString(markdown: text)) ?? AttributedString(text))
        case .rule:
            Divider()
        }
    }
}
