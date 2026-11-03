import SwiftUI

struct DocsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("""
                    AMod scripts are **JavaScript** with a built-in iPhone API. A script is either:
                    • **CLI** — runs top to bottom in a terminal (`print`, `input`, `menu`…)
                    • **GUI** — calls `ui.render(() => VStack(...))` with SwiftUI-style views.
                    Long-press any script to add it to your Home Screen. Use the ⊞ button in the editor to insert Shortcuts-style actions.
                    """)
                }
                ForEach(DocsContent.sections, id: \.title) { section in
                    Section(section.title) {
                        ForEach(section.entries, id: \.0) { entry in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.0)
                                    .font(.system(.callout, design: .monospaced))
                                    .foregroundColor(.accentColor)
                                    .textSelection(.enabled)
                                Text(entry.1).font(.subheadline).foregroundColor(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .navigationTitle("AMod Reference")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}

enum DocsContent {
    struct DocSection {
        let title: String
        let entries: [(String, String)]
    }

    static let sections: [DocSection] = [
        DocSection(title: "Basics", entries: [
            ("print(...values)", "Write to the console. Objects are shown as JSON."),
            ("console.log / info / warn / error / clear", "Coloured console output."),
            ("input(prompt, default?, {secure})", "Ask for text. Returns a string, or null if cancelled."),
            ("alert(title, message?, buttons?)", "Show an alert. Returns the tapped button index."),
            ("confirm(title, message?)", "OK / Cancel. Returns true or false."),
            ("menu(title, options)", "Choose from a list. Returns the chosen option or null."),
            ("sleep(seconds)", "Pause the script."),
            ("await wait(seconds)", "Pause without blocking timers or the GUI."),
            ("setTimeout / setInterval / clearTimeout", "Timers, like on the web."),
            ("exit()", "Stop the script."),
            ("args.input", "Input passed from Shortcuts or an amod:// link."),
            ("output(value)", "The value returned to Shortcuts by “Run AMod Script”."),
        ]),
        DocSection(title: "Device", entries: [
            ("vibrate()", "Vibrate the phone."),
            ("haptic(style)", "light, medium, heavy, soft, rigid, success, warning, error, selection."),
            ("flashlight.on(level?) / off() / toggle() / isOn", "Control the torch. level is 0–1."),
            ("device.brightness = 0.5", "Get or set screen brightness (0–1)."),
            ("device.volume = 0.5", "Get or set media volume (0–1)."),
            ("device.battery", "Battery level 0–1."),
            ("device.info()", "name, model, version, battery, charging, lowPowerMode, darkMode, screen size…"),
            ("device.playSound(id)", "Play an iOS system sound by id."),
        ]),
        DocSection(title: "Settings & Shortcuts", entries: [
            ("settings.open(section)", "Open a Settings page: wifi, bluetooth, cellular, hotspot, vpn, notifications, sounds, focus, screentime, general, about, storage, keyboard, display, wallpaper, accessibility, battery, privacy, location, siri, faceid, safari, app."),
            ("settings.brightness(v) / settings.volume(v) / settings.flashlight(on)", "Change those settings directly."),
            ("shortcuts.run(name, input?)", "Run a shortcut from the Shortcuts app. Use this for anything only Shortcuts can do: toggling Wi-Fi, Bluetooth, Low Power Mode, Focus, Airplane Mode, sending messages…"),
            ("scripts.run(name, input?)", "Run another AMod script."),
            ("require(name)", "Load another script as a module (it sets module.exports)."),
            ("openURL(url)", "Open a website, app link or URL scheme."),
        ]),
        DocSection(title: "Text, Speech & Notifications", entries: [
            ("clipboard.get() / clipboard.set(text)", "Read or write the clipboard."),
            ("speak(text, {rate, pitch, language})", "Speak text aloud. Waits until done."),
            ("notify(title, body, {delay})", "Show a notification, now or after delay seconds."),
            ("share(text)", "Open the share sheet."),
        ]),
        DocSection(title: "Web, Location & Calendar", entries: [
            ("http.get(url, {headers}) / post(url, body) / put / delete", "HTTP requests. Returns {status, ok, body, headers, json()}."),
            ("fetchJSON(url)", "GET and parse JSON."),
            ("location()", "Current {latitude, longitude, altitude, accuracy, speed} or null."),
            ("calendar.addEvent(title, start, end?, notes?)", "Add a calendar event."),
            ("reminders.add(title, {notes, due})", "Add a reminder."),
        ]),
        DocSection(title: "Files & Storage", entries: [
            ("files.read / write / append / list / exists / delete", "Files in AMod's folder (visible in the Files app)."),
            ("storage.get(key, fallback) / set(key, value) / remove(key)", "Save any JSON value between runs."),
        ]),
        DocSection(title: "GUI: Views", entries: [
            ("ui.render(() => view)", "Show a GUI. The function re-runs after every interaction."),
            ("state({...})", "An object that re-renders the GUI when you change it."),
            ("ui.title(text) / ui.close() / ui.console()", "Set the title, close the window, show the console."),
            ("VStack / HStack / ZStack({spacing, alignment}, ...views)", "Stacks. The options object is optional."),
            ("List(...) / Form(...) / Section(title, ...) / ScrollView(...)", "Containers."),
            ("Text(string)", "Text."),
            ("Button(label | view, action)", "A button."),
            ("Image(\"sf.symbol\") / Image({url})", "SF Symbol or remote image."),
            ("Label(title, systemImage)", "Icon + text."),
            ("Toggle(label, isOn, onChange)", "A switch."),
            ("Slider(value, onChange, {min, max, step})", "A slider."),
            ("Stepper(label, value, onChange, {step, min, max})", "A stepper."),
            ("TextField / SecureField(placeholder, text, onChange, onSubmit?)", "Text input."),
            ("Picker(label, options, selection, onChange)", "A pop-up menu picker."),
            ("ProgressView(value?, total?)", "Progress bar, or a spinner with no value."),
            ("Spacer() / Divider() / Color(\"red\") / Link(label, url)", "Layout helpers."),
            ("ForEach(array, item => view)", "Map an array to views."),
        ]),
        DocSection(title: "GUI: Modifiers", entries: [
            (".padding(n?) / .padding(\"horizontal\", n)", "Padding."),
            (".font(\"title\" | size, weight?, design?)", "largeTitle…caption2, or a point size; design: rounded, monospaced, serif."),
            (".bold() .italic() .fontWeight(w) .monospaced()", "Text styling."),
            (".foregroundColor(c) .background(c) .tint(c)", "Colours: names (red, blue…) or hex \"#FF8800\"."),
            (".frame({width, height, maxWidth: Infinity, alignment})", "Size."),
            (".cornerRadius(r) .clipShape(\"circle\"|\"capsule\") .border(c, w, r) .shadow(r)", "Shape."),
            (".opacity(o) .rotationEffect(deg) .scaleEffect(s) .offset(x, y)", "Effects."),
            (".buttonStyle(\"borderedProminent\"|\"bordered\"|\"plain\")", "Button style."),
            (".textFieldStyle(\"roundedBorder\") .listStyle(\"plain\"|\"insetGrouped\")", "Control styles."),
            (".onTapGesture(fn) .disabled(bool) .lineLimit(n)", "Behaviour."),
        ]),
        DocSection(title: "Links", entries: [
            ("amod://run?name=Flashlight", "Run a script from anywhere (Safari, Shortcuts, NFC tags…)."),
            ("amod://run?id=<uuid>&input=hello", "Run by id with input (Home Screen icons use this)."),
            ("amod://edit?name=Flashlight", "Open a script in the editor."),
        ]),
    ]
}
