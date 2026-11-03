import SwiftUI

struct TemplatesView: View {
    let onPick: (Script) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var preview: ScriptTemplate?

    private var filtered: [ScriptTemplate] {
        search.isEmpty ? ScriptTemplate.all : ScriptTemplate.all.filter {
            $0.name.localizedCaseInsensitiveContains(search) || $0.description.localizedCaseInsensitiveContains(search)
                || $0.category.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if ScriptTemplate.all.isEmpty {
                    Text("No templates bundled.").foregroundColor(.secondary)
                }
                ForEach(ScriptTemplate.categories, id: \.self) { category in
                    let items = filtered.filter { $0.category == category }
                    if !items.isEmpty {
                        Section(category) {
                            ForEach(items) { template in
                                Button { preview = template } label: { row(template) }
                            }
                        }
                    }
                }
                Section {
                    Link(destination: AModLinks.site) {
                        Label("More on the AMod online tools site", systemImage: "safari")
                    }
                }
            }
            .searchable(text: $search, prompt: "Search templates")
            .navigationTitle("Templates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
            .sheet(item: $preview) { template in
                TemplatePreview(template: template) {
                    preview = nil
                    dismiss()
                    onPick(template.makeScript())
                }
            }
        }
    }

    private func row(_ template: ScriptTemplate) -> some View {
        HStack(spacing: 12) {
            ScriptIconTile(script: template.makeScript(), size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(template.name).font(.headline).foregroundColor(.primary)
                Text(template.description).font(.caption).foregroundColor(.secondary).lineLimit(2)
            }
        }
    }
}

struct TemplatePreview: View {
    let template: ScriptTemplate
    let use: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 14) {
                        ScriptIconTile(script: template.makeScript(), size: 64)
                        VStack(alignment: .leading) {
                            Text(template.name).font(.title2.bold())
                            Text(template.category).foregroundColor(.secondary)
                        }
                    }
                    Text(template.description)
                    Text(template.code)
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                }
                .padding()
            }
            .safeAreaInset(edge: .bottom) {
                Button(action: use) {
                    Label("Use Template", systemImage: "plus.square.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding()
                .background(.bar)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Back") { dismiss() } }
            }
        }
    }
}
