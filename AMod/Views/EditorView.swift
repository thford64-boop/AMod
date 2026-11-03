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
                        Image(systemName: draft.icon)
                            .font(.title3)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color(hex: draft.color), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
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
                StylePicker(icon: $draft.icon, color: $draft.color)
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

struct StylePicker: View {
    @Binding var icon: String
    @Binding var color: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Color").font(.headline)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(Palette.colors, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 40, height: 40)
                                .overlay(Circle().stroke(Color.primary, lineWidth: color == hex ? 3 : 0).padding(-4))
                                .onTapGesture { color = hex }
                        }
                    }
                    Text("Icon").font(.headline)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(Palette.icons, id: \.self) { name in
                            Image(systemName: name)
                                .font(.title3)
                                .frame(width: 44, height: 44)
                                .foregroundColor(icon == name ? .white : .primary)
                                .background(icon == name ? Color(hex: color) : Color.secondary.opacity(0.12),
                                            in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .onTapGesture { icon = name }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Icon & Color")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}
