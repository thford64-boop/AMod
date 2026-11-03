import SwiftUI

struct EditorView: View {
    @EnvironmentObject private var store: ScriptStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Script
    @State private var showActions = false
    @State private var showStyle = false
    @State private var showDocs = false
    @State private var runSession: RunSession?
    @StateObject private var editor = EditorController()

    init(script: Script) {
        _draft = State(initialValue: script)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Button { showStyle = true } label: {
                        ScriptIconTile(script: draft, size: 44)
                    }
                    TextField("Script name", text: $draft.name)
                        .font(.title3.bold())
                    Text(draft.isGUI ? "GUI" : "CLI")
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.15), in: Capsule())
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                Divider()
                CodeEditor(text: $draft.code, controller: editor)
            }
            .navigationTitle("Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        save()
                        dismiss()
                    }
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button { showDocs = true } label: { Image(systemName: "book") }
                    Button { showActions = true } label: { Image(systemName: "square.grid.2x2") }
                    Button {
                        save()
                        runSession = RunSession(script: draft)
                    } label: {
                        Image(systemName: "play.fill")
                    }
                }
            }
            .sheet(isPresented: $showActions) {
                ActionsLibraryView { snippet in
                    editor.insert(snippet)
                }
            }
            .sheet(isPresented: $showStyle) {
                StylePicker(script: $draft)
            }
            .sheet(isPresented: $showDocs) { DocsView() }
            .fullScreenCover(item: $runSession) { session in
                RunView(session: session)
            }
        }
        .onDisappear(perform: save)
    }

    private func save() {
        if draft.name.trimmingCharacters(in: .whitespaces).isEmpty { draft.name = "Untitled" }
        store.upsert(draft)
    }
}
