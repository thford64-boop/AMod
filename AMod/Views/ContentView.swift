import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: ScriptStore
    @EnvironmentObject private var router: Router
    @State private var search = ""
    @State private var homeScreenScript: Script?
    @State private var showDocs = false
    @State private var deleting: Script?

    private let columns = [GridItem(.adaptive(minimum: 155), spacing: 12)]

    private var filtered: [Script] {
        search.isEmpty ? store.scripts : store.scripts.filter {
            $0.name.localizedCaseInsensitiveContains(search) || $0.code.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if store.scripts.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "chevron.left.forwardslash.chevron.right").font(.system(size: 48))
                        Text("No scripts yet").font(.title3.bold())
                        Text("Tap + to make your first one.").foregroundColor(.secondary)
                    }
                    .padding(.top, 120)
                }
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(filtered) { script in
                        ScriptTile(script: script) { router.editing = script }
                            .onTapGesture {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                router.run(script)
                            }
                            .contextMenu { menu(for: script) }
                    }
                }
                .padding()
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("AMod")
            .searchable(text: $search, prompt: "Search scripts")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showDocs = true } label: { Image(systemName: "book") }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button { create(Examples.cliTemplate) } label: { Label("New CLI Script", systemImage: "terminal") }
                        Button { create(Examples.guiTemplate) } label: { Label("New GUI Script", systemImage: "rectangle.3.group") }
                        Button { create(Examples.blankTemplate) } label: { Label("Blank Script", systemImage: "doc") }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(item: $router.editing) { script in
                EditorView(script: script)
            }
            .sheet(item: $homeScreenScript) { script in
                AddToHomeView(script: script)
            }
            .sheet(isPresented: $showDocs) { DocsView() }
            .fullScreenCover(item: $router.session) { session in
                RunView(session: session)
            }
            .confirmationDialog("Delete \(deleting?.name ?? "script")?", isPresented: Binding(
                get: { deleting != nil }, set: { if !$0 { deleting = nil } }
            ), titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let deleting { store.delete(deleting) }
                    deleting = nil
                }
            }
        }
    }

    @ViewBuilder
    private func menu(for script: Script) -> some View {
        Button { router.run(script) } label: { Label("Run", systemImage: "play.fill") }
        Button { router.editing = script } label: { Label("Edit", systemImage: "pencil") }
        Button { homeScreenScript = script } label: { Label("Add to Home Screen", systemImage: "plus.app") }
        Button {
            UIPasteboard.general.string = script.runURL
        } label: { Label("Copy Run Link", systemImage: "link") }
        Button { store.duplicate(script) } label: { Label("Duplicate", systemImage: "plus.square.on.square") }
        Button {
            UIPasteboard.general.string = script.code
        } label: { Label("Copy Code", systemImage: "doc.on.doc") }
        Divider()
        Button(role: .destructive) { deleting = script } label: { Label("Delete", systemImage: "trash") }
    }

    private func create(_ template: Script) {
        var script = template
        script.id = UUID()
        script.created = Date()
        script.color = Palette.colors.randomElement() ?? script.color
        store.upsert(script)
        router.editing = script
    }
}

struct ScriptTile: View {
    let script: Script
    var onEdit: () -> Void

    var body: some View {
        let color = Color(hex: script.color)
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Image(systemName: script.icon)
                    .font(.title2)
                    .foregroundColor(.white)
                Spacer()
                Button(action: onEdit) {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.title3)
                        .foregroundColor(Color.white.opacity(0.9))
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 18)
            Text(script.name)
                .font(.headline)
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Text(script.kindLabel)
                .font(.caption)
                .foregroundColor(Color.white.opacity(0.75))
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 116, alignment: .leading)
        .background(
            LinearGradient(colors: [color.opacity(0.8), color], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 22, style: .continuous))
        .contentShape(Rectangle())
    }
}
