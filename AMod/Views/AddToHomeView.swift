import SwiftUI

struct AddToHomeView: View {
    let script: Script
    @Environment(\.dismiss) private var dismiss
    @State private var status: String?
    @State private var copied = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(uiImage: HomeScreenInstaller.icon(for: script, size: 120))
                                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                                .shadow(radius: 6)
                            Text(script.name).font(.footnote)
                        }
                        Spacer()
                    }
                    .padding(.vertical)
                }

                Section {
                    Button {
                        HomeScreenInstaller.install(script) { ok in
                            status = ok ? nil : "Couldn't open Safari. Try again."
                        }
                    } label: {
                        Label("Add to Home Screen", systemImage: "plus.app.fill").font(.headline)
                    }
                    if let status { Text(status).foregroundColor(.red) }
                } footer: {
                    Text("""
                    1. Safari opens and asks to download a profile — tap **Allow**.
                    2. Open **Settings → Profile Downloaded → Install**.
                    3. The icon appears on your Home Screen. Tapping it runs this script straight away.
                    Remove it any time from Settings → General → VPN & Device Management.
                    """)
                }

                Section {
                    Button {
                        UIPasteboard.general.string = script.runURL
                        copied = true
                    } label: {
                        Label(copied ? "Copied!" : "Copy Run Link", systemImage: copied ? "checkmark" : "link")
                    }
                    Button {
                        UIApplication.shared.open(URL(string: "shortcuts://create-shortcut")!)
                    } label: {
                        Label("Open Shortcuts", systemImage: "square.stack.3d.up.fill")
                    }
                } header: {
                    Text("Or use Shortcuts")
                } footer: {
                    Text("Make a shortcut with an **Open URL** action set to the run link, or use the **Run AMod Script** action, then choose Add to Home Screen from the shortcut's share menu.")
                }
            }
            .navigationTitle("Home Screen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}
