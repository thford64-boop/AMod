import SwiftUI

struct RunView: View {
    @ObservedObject var session: RunSession
    @Environment(\.dismiss) private var dismiss

    private var sheetPrompt: Binding<PromptRequest?> {
        Binding(
            get: { session.inlinePrompt == nil ? session.prompt : nil },
            set: { _ in }
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                if let tree = session.tree, !session.showConsole {
                    NodeView(node: tree, session: session)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                } else {
                    ConsoleView(session: session)
                }
            }
            .navigationTitle(session.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        session.stop()
                        dismiss()
                    }
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if session.tree != nil {
                        Button {
                            session.showConsole.toggle()
                        } label: {
                            Image(systemName: session.showConsole ? "rectangle.3.group" : "terminal")
                        }
                    }
                    Button { session.restart() } label: { Image(systemName: "arrow.clockwise") }
                }
            }
            .sheet(item: sheetPrompt) { request in
                PromptSheet(request: request) { session.answer($0) }
            }
        }
        .onAppear { session.start() }
        .onDisappear { session.stop() }
        .onChange(of: session.shouldClose) { close in
            if close {
                session.stop()
                dismiss()
            }
        }
    }
}

struct ConsoleView: View {
    @ObservedObject var session: RunSession

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 3) {
                        Text("$ amod run \"\(session.script.name)\"")
                            .foregroundColor(.green)
                        ForEach(session.logs) { line in
                            Group {
                                if let image = line.image {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxHeight: 260)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                } else {
                                    Text(line.text)
                                        .foregroundColor(line.color)
                                        .textSelection(.enabled)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(line.id)
                        }
                        if session.running && session.inlinePrompt == nil && session.prompt == nil && session.tree == nil {
                            Text("▍").foregroundColor(.green)
                        }
                    }
                    .font(.system(.callout, design: .monospaced))
                    .padding()
                }
                .onChange(of: session.logs.count) { _ in
                    if let last = session.logs.last {
                        withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }
            if let request = session.inlinePrompt {
                InlineInputBar(request: request, session: session)
                    .id(request.id)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .environment(\.colorScheme, .dark)
    }
}

struct InlineInputBar: View {
    let request: PromptRequest
    @ObservedObject var session: RunSession
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !request.title.isEmpty {
                Text(request.title).foregroundColor(.cyan)
            }
            HStack {
                Text(">").foregroundColor(.green)
                field
                    .focused($focused)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit(submit)
                Button("Cancel") {
                    session.engineLog(.system, "> (cancelled)")
                    session.answer(nil)
                }
                .font(.caption)
            }
        }
        .font(.system(.callout, design: .monospaced))
        .padding(12)
        .background(Color(white: 0.1))
        .onAppear {
            if case .input(_, let defaultValue, _) = request.kind { text = defaultValue }
            focused = true
        }
    }

    private var isSecure: Bool {
        if case .input(_, _, let secure) = request.kind { return secure }
        return false
    }

    @ViewBuilder
    private var field: some View {
        if isSecure {
            SecureField("password", text: $text)
        } else {
            TextField("type here…", text: $text)
        }
    }

    private func submit() {
        session.engineLog(.system, "> " + (isSecure ? String(repeating: "•", count: text.count) : text))
        session.answer(text)
    }
}

struct PromptSheet: View {
    let request: PromptRequest
    let answer: (Any?) -> Void
    @State private var text = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if !request.message.isEmpty {
                        Text(request.message).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    switch request.kind {
                    case .alert(let buttons):
                        ForEach(buttons.indices, id: \.self) { i in
                            Button {
                                answer(i)
                            } label: {
                                Text(buttons[i]).frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                        }
                    case .input(let placeholder, _, let secure):
                        Group {
                            if secure {
                                SecureField(placeholder, text: $text)
                            } else {
                                TextField(placeholder, text: $text)
                            }
                        }
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { answer(text) }
                        Button {
                            answer(text)
                        } label: {
                            Text("Done").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    case .menu(let options):
                        ForEach(options.indices, id: \.self) { i in
                            Button {
                                answer(i)
                            } label: {
                                HStack {
                                    Text(options[i])
                                    Spacer()
                                    Image(systemName: "chevron.right").foregroundColor(.secondary)
                                }
                                .padding()
                                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(request.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { answer(nil) }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled()
        .onAppear {
            if case .input(_, let defaultValue, _) = request.kind { text = defaultValue }
        }
    }
}
