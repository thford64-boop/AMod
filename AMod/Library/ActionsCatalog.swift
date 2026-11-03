import Foundation

/// Shortcuts-style building blocks. Tapping one inserts its code at the cursor.
struct ActionItem: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let code: String
}

struct ActionCategory: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let color: String
    let items: [ActionItem]
}

enum ActionsCatalog {
    static let all: [ActionCategory] = [
        ActionCategory(name: "Device", icon: "iphone", color: "#8E8E93", items: [
            ActionItem(title: "Vibrate", icon: "iphone.radiowaves.left.and.right", code: "vibrate()"),
            ActionItem(title: "Haptic Feedback", icon: "hand.tap.fill", code: #"haptic("medium") // light, medium, heavy, soft, rigid, success, warning, error, selection"#),
            ActionItem(title: "Flashlight On", icon: "flashlight.on.fill", code: "flashlight.on(1.0)"),
            ActionItem(title: "Flashlight Off", icon: "flashlight.off.fill", code: "flashlight.off()"),
            ActionItem(title: "Toggle Flashlight", icon: "flashlight.on.fill", code: "flashlight.toggle()"),
            ActionItem(title: "Get Battery Level", icon: "battery.75", code: "const battery = device.battery // 0.0 – 1.0"),
            ActionItem(title: "Get Device Details", icon: "info.circle", code: "const info = device.info()\nprint(info)"),
            ActionItem(title: "Play System Sound", icon: "speaker.wave.2.fill", code: "device.playSound(1007)"),
        ]),
        ActionCategory(name: "Settings", icon: "gearshape.fill", color: "#636366", items: [
            ActionItem(title: "Set Brightness", icon: "sun.max.fill", code: "device.brightness = 0.5"),
            ActionItem(title: "Set Volume", icon: "speaker.wave.3.fill", code: "device.volume = 0.5"),
            ActionItem(title: "Open Wi-Fi Settings", icon: "wifi", code: #"settings.open("wifi")"#),
            ActionItem(title: "Open Bluetooth Settings", icon: "antenna.radiowaves.left.and.right", code: #"settings.open("bluetooth")"#),
            ActionItem(title: "Open Cellular Settings", icon: "antenna.radiowaves.left.and.right.circle", code: #"settings.open("cellular")"#),
            ActionItem(title: "Open Battery Settings", icon: "battery.100", code: #"settings.open("battery")"#),
            ActionItem(title: "Open Focus Settings", icon: "moon.fill", code: #"settings.open("focus")"#),
            ActionItem(title: "Open Any Settings Page", icon: "gearshape.2", code: #"settings.open(menu("Open", settings.sections))"#),
            ActionItem(title: "Is Low Power Mode On", icon: "battery.25", code: "const lowPower = device.info().lowPowerMode"),
            ActionItem(title: "Is Dark Mode On", icon: "circle.lefthalf.filled", code: "const dark = device.info().darkMode"),
        ]),
        ActionCategory(name: "Shortcuts", icon: "square.stack.3d.up.fill", color: "#5856D6", items: [
            ActionItem(title: "Run Shortcut", icon: "play.square.stack.fill", code: #"shortcuts.run("My Shortcut", "optional input")"#),
            ActionItem(title: "Open Shortcuts App", icon: "square.stack.3d.up", code: "shortcuts.open()"),
            ActionItem(title: "Run Another AMod Script", icon: "arrow.triangle.branch", code: #"scripts.run("Flashlight")"#),
            ActionItem(title: "Import Script as Module", icon: "shippingbox.fill", code: #"const lib = require("My Library") // that script sets module.exports"#),
            ActionItem(title: "Get Shortcut Input", icon: "arrow.down.square", code: "const shortcutInput = args.input"),
            ActionItem(title: "Return Output to Shortcuts", icon: "arrow.up.square", code: "output(result)"),
        ]),
        ActionCategory(name: "Scripting", icon: "curlybraces", color: "#FF9500", items: [
            ActionItem(title: "Ask for Input", icon: "text.cursor", code: #"const answer = input("Question?", "default")"#),
            ActionItem(title: "Ask for Password", icon: "lock.fill", code: #"const secret = input("Password", "", { secure: true })"#),
            ActionItem(title: "Show Alert", icon: "exclamationmark.bubble.fill", code: #"alert("Title", "Message")"#),
            ActionItem(title: "Ask Yes/No", icon: "questionmark.circle.fill", code: "if (confirm(\"Continue?\")) {\n  \n}"),
            ActionItem(title: "Choose from Menu", icon: "list.bullet", code: "const choice = menu(\"Pick one\", [\"One\", \"Two\", \"Three\"])\nif (choice === \"One\") {\n  \n}"),
            ActionItem(title: "Wait", icon: "hourglass", code: "sleep(1) // seconds"),
            ActionItem(title: "Repeat", icon: "repeat", code: "for (let i = 0; i < 3; i++) {\n  \n}"),
            ActionItem(title: "Repeat with Each", icon: "repeat.circle", code: "for (const item of [\"a\", \"b\", \"c\"]) {\n  print(item)\n}"),
            ActionItem(title: "If / Otherwise", icon: "arrow.triangle.branch", code: "if (condition) {\n  \n} else {\n  \n}"),
            ActionItem(title: "Print", icon: "text.alignleft", code: #"print("Hello")"#),
            ActionItem(title: "Stop Script", icon: "stop.fill", code: "exit()"),
            ActionItem(title: "Run Every N Seconds", icon: "timer", code: "const timer = setInterval(() => {\n  print(new Date().toLocaleTimeString())\n}, 1000)"),
        ]),
        ActionCategory(name: "Text & Media", icon: "textformat", color: "#FF2D55", items: [
            ActionItem(title: "Get Clipboard", icon: "doc.on.clipboard", code: "const clip = clipboard.get()"),
            ActionItem(title: "Copy to Clipboard", icon: "doc.on.doc", code: #"clipboard.set("text")"#),
            ActionItem(title: "Speak Text", icon: "waveform", code: #"speak("Hello", { rate: 0.5, language: "en-US" })"#),
            ActionItem(title: "Share", icon: "square.and.arrow.up", code: #"share("text to share")"#),
            ActionItem(title: "Show Notification", icon: "bell.badge.fill", code: #"notify("Title", "Body")"#),
            ActionItem(title: "Schedule Notification", icon: "bell.and.waves.left.and.right", code: #"notify("Reminder", "Stretch!", { delay: 60 })"#),
        ]),
        ActionCategory(name: "Web", icon: "globe", color: "#007AFF", items: [
            ActionItem(title: "Open URL", icon: "safari.fill", code: #"openURL("https://apple.com")"#),
            ActionItem(title: "Get Contents of URL", icon: "arrow.down.circle.fill", code: #"const res = http.get("https://example.com")\#nprint(res.status, res.body)"#),
            ActionItem(title: "Get JSON", icon: "curlybraces.square.fill", code: #"const json = fetchJSON("https://api.github.com/zen")"#),
            ActionItem(title: "POST JSON", icon: "arrow.up.circle.fill", code: #"const res = http.post("https://httpbin.org/post", { hello: "world" })\#nprint(res.json())"#),
        ]),
        ActionCategory(name: "Location & Calendar", icon: "location.fill", color: "#34C759", items: [
            ActionItem(title: "Get Current Location", icon: "location.fill", code: "const loc = location() // { latitude, longitude, altitude, accuracy, speed }"),
            ActionItem(title: "Open in Maps", icon: "map.fill", code: #"openURL(`maps://?ll=${loc.latitude},${loc.longitude}`)"#),
            ActionItem(title: "Add Calendar Event", icon: "calendar.badge.plus", code: #"calendar.addEvent("Meeting", new Date(Date.now() + 3600e3))"#),
            ActionItem(title: "Add Reminder", icon: "checklist", code: #"reminders.add("Buy milk", { due: new Date(Date.now() + 3600e3) })"#),
        ]),
        ActionCategory(name: "Files & Storage", icon: "folder.fill", color: "#00C7BE", items: [
            ActionItem(title: "Read File", icon: "doc.text", code: #"const text = files.read("notes.txt")"#),
            ActionItem(title: "Write File", icon: "square.and.pencil", code: #"files.write("notes.txt", "Hello")"#),
            ActionItem(title: "Append to File", icon: "text.append", code: #"files.append("log.txt", "line\n")"#),
            ActionItem(title: "List Files", icon: "list.bullet.rectangle", code: "print(files.list())"),
            ActionItem(title: "Save Value", icon: "tray.and.arrow.down.fill", code: #"storage.set("key", { any: "json" })"#),
            ActionItem(title: "Load Value", icon: "tray.and.arrow.up.fill", code: #"const saved = storage.get("key", null)"#),
        ]),
        ActionCategory(name: "Sound", icon: "speaker.wave.3.fill", color: "#FF9500", items: [
            ActionItem(title: "Play Tone", icon: "waveform", code: "audio.tone(440, 0.3) // Hz, seconds"),
            ActionItem(title: "Play Note", icon: "music.note", code: #"audio.note("C5", 0.25, { wave: "square" })"#),
            ActionItem(title: "Play Melody", icon: "music.note.list", code: #"audio.melody([["C4", .2], ["E4", .2], ["G4", .4]])"#),
            ActionItem(title: "Play Audio from URL", icon: "link", code: #"audio.play("https://example.com/sound.mp3", { wait: true })"#),
            ActionItem(title: "Play Audio File", icon: "doc.fill", code: #"audio.play("sound.m4a", { volume: 0.8 })"#),
            ActionItem(title: "Play Base64 Audio", icon: "text.badge.checkmark", code: #"audio.playBase64("PASTE_BASE64_HERE", { wait: true })"#),
            ActionItem(title: "Loop Audio", icon: "repeat", code: #"audio.play("music.mp3", { loop: true })"#),
            ActionItem(title: "Stop Audio", icon: "stop.fill", code: "audio.stop()"),
            ActionItem(title: "System Sound", icon: "bell.fill", code: "playSound(1007)"),
        ]),
        ActionCategory(name: "Images & Base64", icon: "photo.fill", color: "#FF2D55", items: [
            ActionItem(title: "Show Image in Console", icon: "photo", code: #"showImage("https://picsum.photos/400")"#),
            ActionItem(title: "Base64 Image View", icon: "photo.on.rectangle", code: #"Image({ base64: "PASTE_BASE64_HERE" }).frame({ height: 200 }),"#),
            ActionItem(title: "Image from File", icon: "folder", code: #"Image({ file: "picture.jpg" }).cornerRadius(12),"#),
            ActionItem(title: "Download as Base64", icon: "arrow.down.circle", code: #"const b64 = base64.fromURL("https://picsum.photos/400")"#),
            ActionItem(title: "Save Base64 to File", icon: "square.and.arrow.down", code: #"files.writeBase64("picture.jpg", b64)"#),
            ActionItem(title: "Read File as Base64", icon: "doc.text.magnifyingglass", code: #"const data = files.readBase64("picture.jpg")"#),
            ActionItem(title: "Encode Text", icon: "lock.doc", code: #"const encoded = base64.encode("hello")"#),
            ActionItem(title: "Decode Text", icon: "lock.open", code: #"const decoded = base64.decode("aGVsbG8=")"#),
        ]),
        ActionCategory(name: "More GUI", icon: "square.grid.3x3.fill", color: "#5856D6", items: [
            ActionItem(title: "Tabs", icon: "rectangle.split.3x1.fill", code: "TabView(\n  Tab(\"Home\", \"house\", Text(\"Home\")),\n  Tab(\"Settings\", \"gear\", Text(\"Settings\")),\n)"),
            ActionItem(title: "Grid", icon: "square.grid.2x2", code: "Grid({ columns: 3 },\n  \n),"),
            ActionItem(title: "Card", icon: "rectangle.fill", code: #"Card(Text("Title").font("headline"), Text("Body")),"#),
            ActionItem(title: "Chart", icon: "chart.bar.xaxis", code: #"Chart([{ x: "Mon", y: 3 }, { x: "Tue", y: 5 }], { type: "bar" }),"#),
            ActionItem(title: "Gauge", icon: "gauge.with.dots.needle.67percent", code: #"Gauge(0.7, { style: "circular", color: "green" }),"#),
            ActionItem(title: "Date Picker", icon: "calendar", code: "DatePicker(\"When\", s.date, d => s.date = d),"),
            ActionItem(title: "Color Picker", icon: "eyedropper", code: "ColorPicker(\"Color\", s.color, c => s.color = c),"),
            ActionItem(title: "Menu", icon: "ellipsis.circle", code: "Menu(\"More\",\n  Button(\"One\", () => {}),\n  Button(\"Two\", () => {}),\n),"),
            ActionItem(title: "Navigation Link", icon: "chevron.right.circle", code: #"NavigationLink("Details", Text("Another page")),"#),
            ActionItem(title: "Text Editor", icon: "text.alignleft", code: "TextEditor(s.text, v => s.text = v),"),
            ActionItem(title: "Map", icon: "map", code: #"Map({ latitude: 37.33, longitude: -122.01, pins: [{ latitude: 37.33, longitude: -122.01, title: "Here" }] }),"#),
            ActionItem(title: "Web View", icon: "safari", code: #"WebView("https://example.com"),"#),
            ActionItem(title: "Shapes", icon: "circle.square", code: #"HStack(Circle().fill("red"), RoundedRectangle(12).fill("blue")).frame({ height: 50 }),"#),
            ActionItem(title: "Gradient", icon: "paintbrush", code: #"LinearGradient(["pink", "purple"], "diagonal").frame({ height: 120 }).cornerRadius(20),"#),
            ActionItem(title: "Context Menu", icon: "hand.tap", code: #".contextMenu([{ title: "Copy", icon: "doc.on.doc", action: () => {} }])"#),
        ]),
        ActionCategory(name: "Interface (GUI)", icon: "rectangle.3.group.fill", color: "#AF52DE", items: [
            ActionItem(title: "GUI Script Skeleton", icon: "rectangle.3.group", code: "const s = state({ })\n\nui.render(() =>\n  VStack(\n    Text(\"Hello\").font(\"largeTitle\")\n  ).padding()\n)"),
            ActionItem(title: "Text", icon: "textformat", code: #"Text("Hello").font("title", "bold").foregroundColor("blue"),"#),
            ActionItem(title: "Button", icon: "button.programmable", code: #"Button("Tap", () => { haptic() }).buttonStyle("borderedProminent"),"#),
            ActionItem(title: "Toggle", icon: "switch.2", code: #"Toggle("Enabled", s.on, v => s.on = v),"#),
            ActionItem(title: "Slider", icon: "slider.horizontal.3", code: "Slider(s.value, v => s.value = v, { min: 0, max: 100 }),"),
            ActionItem(title: "Stepper", icon: "plusminus", code: #"Stepper(`Count: ${s.n}`, s.n, v => s.n = v),"#),
            ActionItem(title: "Text Field", icon: "character.cursor.ibeam", code: #"TextField("Name", s.name, v => s.name = v).textFieldStyle("roundedBorder"),"#),
            ActionItem(title: "Picker", icon: "filemenu.and.selection", code: #"Picker("Size", ["S", "M", "L"], s.size, v => s.size = v),"#),
            ActionItem(title: "Image (SF Symbol)", icon: "star.fill", code: #"Image("star.fill").font(40).foregroundColor("yellow"),"#),
            ActionItem(title: "Image (URL)", icon: "photo", code: #"Image({ url: "https://picsum.photos/400" }).frame({ height: 200 }),"#),
            ActionItem(title: "HStack", icon: "rectangle.split.3x1", code: "HStack({ spacing: 8 },\n  \n),"),
            ActionItem(title: "VStack", icon: "rectangle.split.1x2", code: "VStack({ spacing: 8, alignment: \"leading\" },\n  \n),"),
            ActionItem(title: "List + Section", icon: "list.bullet.rectangle.portrait", code: "List(\n  Section(\"Title\",\n    Text(\"Row\"),\n  ),\n),"),
            ActionItem(title: "Spacer", icon: "arrow.up.and.down", code: "Spacer(),"),
            ActionItem(title: "Progress Bar", icon: "chart.bar.fill", code: "ProgressView(0.5),"),
            ActionItem(title: "Close Window", icon: "xmark.circle", code: "ui.close()"),
        ]),
    ]
}
