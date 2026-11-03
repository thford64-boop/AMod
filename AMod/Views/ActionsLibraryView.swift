import SwiftUI

struct ActionsLibraryView: View {
    let onPick: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    private var categories: [ActionCategory] {
        guard !search.isEmpty else { return ActionsCatalog.all }
        return ActionsCatalog.all.compactMap { category in
            let items = category.items.filter {
                $0.title.localizedCaseInsensitiveContains(search) || $0.code.localizedCaseInsensitiveContains(search)
            }
            return items.isEmpty ? nil : ActionCategory(name: category.name, icon: category.icon, color: category.color, items: items)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(categories) { category in
                    Section {
                        ForEach(category.items) { item in
                            Button {
                                onPick(item.code)
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: item.icon)
                                        .foregroundColor(.white)
                                        .frame(width: 32, height: 32)
                                        .background(Color(hex: category.color), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.title).foregroundColor(.primary)
                                        Text(item.code)
                                            .font(.system(.caption, design: .monospaced))
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
                    } header: {
                        Label(category.name, systemImage: category.icon)
                    }
                }
            }
            .searchable(text: $search, prompt: "Search actions")
            .navigationTitle("Actions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
        }
    }
}
