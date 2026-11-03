import SwiftUI
import PhotosUI

/// Pick a script's colour and icon: SF Symbol, emoji, or a photo.
struct StylePicker: View {
    @Binding var script: Script
    @Environment(\.dismiss) private var dismiss
    @State private var tab = 0
    @State private var search = ""
    @State private var customEmoji = ""
    @State private var photo: PhotosPickerItem?

    private let grid = [GridItem(.adaptive(minimum: 48), spacing: 10)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Spacer()
                        ScriptIconTile(script: script, size: 88).shadow(radius: 4)
                        Spacer()
                    }
                    Text("Color").font(.headline)
                    LazyVGrid(columns: grid, spacing: 10) {
                        ForEach(Palette.colors, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 38, height: 38)
                                .overlay(Circle().stroke(Color.primary, lineWidth: script.color == hex ? 3 : 0).padding(-4))
                                .onTapGesture { script.color = hex }
                        }
                        ColorPicker("", selection: Binding(
                            get: { Color(hex: script.color) },
                            set: { script.color = UIColor($0).hexString }
                        ), supportsOpacity: false)
                        .labelsHidden()
                    }

                    Picker("Icon type", selection: $tab) {
                        Text("Symbols").tag(0)
                        Text("Emoji").tag(1)
                        Text("Photo").tag(2)
                    }
                    .pickerStyle(.segmented)

                    switch tab {
                    case 0: symbols
                    case 1: emojis
                    default: photoPicker
                    }
                }
                .padding()
            }
            .navigationTitle("Icon & Color")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .onChange(of: photo) { item in
                Task {
                    guard let item, let data = try? await item.loadTransferable(type: Data.self),
                          let image = UIImage(data: data),
                          let png = image.squareIcon(side: 256).pngData() else { return }
                    await MainActor.run { script.iconImage = png.base64EncodedString() }
                }
            }
        }
    }

    private var symbols: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField("Search symbols (e.g. bolt, music, wifi)", text: $search)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            ForEach(Palette.iconGroups, id: \.0) { group in
                let names = search.isEmpty ? group.1 : group.1.filter { $0.localizedCaseInsensitiveContains(search) }
                if !names.isEmpty {
                    Text(group.0).font(.subheadline.bold()).foregroundColor(.secondary)
                    LazyVGrid(columns: grid, spacing: 10) {
                        ForEach(names, id: \.self) { name in
                            let selected = script.icon == name && script.emoji == nil && script.iconImage == nil
                            Image(systemName: name)
                                .font(.title3)
                                .frame(width: 48, height: 48)
                                .foregroundColor(selected ? .white : .primary)
                                .background(selected ? Color(hex: script.color) : Color.secondary.opacity(0.12),
                                            in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                                .onTapGesture {
                                    script.icon = name
                                    script.emoji = nil
                                    script.iconImage = nil
                                }
                        }
                    }
                }
            }
        }
    }

    private var emojis: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                TextField("Type any emoji", text: $customEmoji)
                    .textFieldStyle(.roundedBorder)
                Button("Use") {
                    if let first = customEmoji.first {
                        script.emoji = String(first)
                        script.iconImage = nil
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            LazyVGrid(columns: grid, spacing: 10) {
                ForEach(Palette.emojis, id: \.self) { emoji in
                    Text(emoji)
                        .font(.system(size: 28))
                        .frame(width: 48, height: 48)
                        .background(script.emoji == emoji ? Color(hex: script.color).opacity(0.35) : Color.secondary.opacity(0.12),
                                    in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                        .onTapGesture {
                            script.emoji = emoji
                            script.iconImage = nil
                        }
                }
            }
        }
    }

    private var photoPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            PhotosPicker(selection: $photo, matching: .images) {
                Label("Choose a Photo", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            if script.iconImage != nil {
                Button(role: .destructive) {
                    script.iconImage = nil
                } label: {
                    Label("Remove Photo Icon", systemImage: "trash").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            Text("The photo is cropped to a square and also used for the Home Screen icon.")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }
}
