import Foundation

enum Examples {
    static let cliTemplate = Script(name: "New CLI Script", icon: "terminal", code: #"""
// CLI script: runs top to bottom in a terminal.
const name = input("What's your name?", "friend")
print(`Hello, ${name}!`)
haptic("success")
"""#)

    static let guiTemplate = Script(name: "New GUI Script", icon: "rectangle.3.group", code: #"""
// GUI script: ui.render() re-runs after every tap, like a SwiftUI body.
const s = state({ count: 0 })

ui.render(() =>
  VStack({ spacing: 20 },
    Text(`${s.count}`).font(64, "bold", "rounded"),
    Button("Tap me", () => { s.count++; haptic("light") })
      .buttonStyle("borderedProminent")
  ).padding().frame({ maxWidth: Infinity, maxHeight: Infinity })
)
"""#)

    static let blankTemplate = Script(name: "Untitled", code: "")

    static var all: [Script] {
        [
            Script(name: "Hello World", icon: "hand.wave.fill", color: "#FF9500", code: #"""
// A CLI script. print() writes to the console, input() asks a question.
print("Welcome to AMod 👋")

const name = input("What's your name?")
if (name) {
  print(`Nice to meet you, ${name}!`)
  speak(`Hello ${name}`)
}

const pick = menu("Pick a vibe", ["Chill", "Hype", "Spooky"])
print("You picked:", pick)
haptic(pick === "Hype" ? "heavy" : "soft")

const info = device.info()
print(`${info.model} running iOS ${info.version}, battery ${Math.round(info.battery * 100)}%`)
"""#),

            Script(name: "Flashlight", icon: "flashlight.on.fill", color: "#FFCC00", code: #"""
// Toggle the flashlight. Add this one to your Home Screen!
flashlight.toggle()
haptic("rigid")
print("Flashlight is", flashlight.isOn ? "ON" : "OFF")
"""#),

            Script(name: "Control Center", icon: "switch.2", color: "#007AFF", code: #"""
// A GUI script with SwiftUI-style views that change real settings.
const s = state({
  torch: flashlight.isOn,
  brightness: device.brightness,
  volume: device.volume,
})

ui.render(() =>
  List(
    Section("Quick toggles",
      Toggle("Flashlight", s.torch, (on) => { s.torch = on; settings.flashlight(on); haptic("light") }),
      HStack(Image("sun.min"), Slider(s.brightness, (v) => { s.brightness = v; device.brightness = v }), Image("sun.max.fill")),
      HStack(Image("speaker.fill"), Slider(s.volume, (v) => { s.volume = v; device.volume = v }), Image("speaker.wave.3.fill")),
    ),
    Section("Open settings",
      ForEach([
        ["Wi-Fi", "wifi", "wifi"],
        ["Bluetooth", "bluetooth", "antenna.radiowaves.left.and.right"],
        ["Cellular", "cellular", "antenna.radiowaves.left.and.right.circle"],
        ["Battery", "battery", "battery.100"],
        ["Focus", "focus", "moon.fill"],
      ], ([title, key, icon]) =>
        Button(Label(title, icon), () => settings.open(key))
      )
    ),
    Section("Fun",
      Button(Label("Vibrate", "iphone.radiowaves.left.and.right"), () => vibrate()),
      Button(Label("Say hi", "waveform"), () => speak("Hi from AMod")),
    ),
  ).listStyle("insetGrouped")
)
"""#),

            Script(name: "Counter", icon: "plus.forwardslash.minus", color: "#34C759", code: #"""
const s = state({ count: storage.get("count", 0) })
const save = () => storage.set("count", s.count)

ui.render(() =>
  VStack({ spacing: 24 },
    Spacer(),
    Text(String(s.count)).font(80, "bold", "rounded").foregroundColor(s.count < 0 ? "red" : "primary"),
    HStack({ spacing: 16 },
      Button(Image("minus").font("title").frame({ width: 70, height: 70 }), () => { s.count--; save(); haptic("light") })
        .background("#FF3B30").foregroundColor("white").clipShape("circle"),
      Button(Image("plus").font("title").frame({ width: 70, height: 70 }), () => { s.count++; save(); haptic("light") })
        .background("#34C759").foregroundColor("white").clipShape("circle"),
    ),
    Button("Reset", () => { s.count = 0; save(); haptic("warning") }).buttonStyle("bordered"),
    Spacer(),
  ).frame({ maxWidth: Infinity, maxHeight: Infinity })
)
"""#),

            Script(name: "SOS Flash", icon: "light.beacon.max.fill", color: "#FF3B30", code: #"""
// Blinks SOS in Morse code with the flashlight and vibration.
const dot = 0.2, dash = 0.6
const blink = (len) => { flashlight.on(); vibrate(); sleep(len); flashlight.off(); sleep(0.2) }

for (let round = 0; round < 3; round++) {
  for (const len of [dot, dot, dot, dash, dash, dash, dot, dot, dot]) blink(len)
  sleep(1)
  print("SOS round", round + 1)
}
"""#),

            Script(name: "Weather", icon: "cloud.sun.fill", color: "#30B0C7", code: #"""
// Uses your location + a free weather API (no key needed).
const loc = location()
if (!loc) { alert("Location unavailable", "Allow location access for AMod in Settings."); exit() }

const url = `https://api.open-meteo.com/v1/forecast?latitude=${loc.latitude}&longitude=${loc.longitude}&current=temperature_2m,wind_speed_10m`
const data = fetchJSON(url)
const t = data.current.temperature_2m, w = data.current.wind_speed_10m

print(`🌡  ${t}°C   💨 ${w} km/h`)
output(`${t}°C, wind ${w} km/h`) // returned to Shortcuts when run from there
speak(`It is ${Math.round(t)} degrees outside`)
"""#),

            Script(name: "Quick Note", icon: "note.text", color: "#AF52DE", code: #"""
// Appends a timestamped note to Notes.txt (see it in the Files app → On My iPhone → AMod).
const text = args.input || input("Note")
if (!text) exit()

files.append("Notes.txt", `[${new Date().toLocaleString()}] ${text}\n`)
haptic("success")
notify("Saved", text)
print(files.read("Notes.txt"))
"""#),

            Script(name: "Remind Me", icon: "checklist", color: "#FF2D55", code: #"""
const what = input("Remind me to…")
if (!what) exit()
const choice = menu("When?", ["In 10 minutes", "In 1 hour", "Tomorrow 9am"])
const due = new Date()
if (choice === "In 10 minutes") due.setMinutes(due.getMinutes() + 10)
else if (choice === "In 1 hour") due.setHours(due.getHours() + 1)
else { due.setDate(due.getDate() + 1); due.setHours(9, 0, 0, 0) }

if (reminders.add(what, { due })) { haptic("success"); print("Reminder set for", due.toLocaleString()) }
else print("Couldn't save — allow Reminders access in Settings.")
"""#),

            Script(name: "Shortcut Bridge", icon: "square.stack.3d.up.fill", color: "#5856D6", code: #"""
// AMod can hand off to the Shortcuts app for anything iOS only lets Shortcuts do
// (toggle Wi-Fi/Bluetooth/Low Power, set Focus, send messages…).
// Make a shortcut called "Low Power On" with the "Set Low Power Mode" action, then:
const name = input("Shortcut to run", "Low Power On")
if (name) shortcuts.run(name)
"""#),
        ]
    }
}
