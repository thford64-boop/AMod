# AMod Guide

AMod is a scripting app for iPhone. You write small JavaScript programs, called scripts, that can control the phone, play sounds, show images, call online tools and build real native interfaces. Think of it as Shortcuts, but with code.

---

## 1. Your first script

1. Open AMod and tap **+** → **New CLI Script**.
2. Replace the code with:
   ```js
   const name = input("What's your name?")
   print(`Hi ${name}!`)
   haptic("success")
   ```
3. Tap **▶︎** to run it.

Tap a script's tile to run it. Tap **⋯** on the tile to edit it. **Long-press** a tile for more options.

## 2. CLI scripts and GUI scripts

| | CLI script | GUI script |
|---|---|---|
| Looks like | a terminal | a native iOS screen |
| Use | `print`, `input`, `menu`, `alert` | `ui.render(() => VStack(...))` |
| Good for | quick actions and automations | tools, dashboards, games |

A script becomes a GUI script as soon as it calls `ui.render`. While a GUI is open, the **terminal** button in the top bar switches to the console.

## 3. Building a GUI

```js
const s = state({ count: 0 })

ui.render(() =>
  VStack({ spacing: 20 },
    Text(`${s.count}`).font(64, "bold", "rounded"),
    Button("Add one", () => { s.count++; haptic("light") })
      .buttonStyle("borderedProminent"),
  ).padding()
)
```

- `state({...})` holds your data. When you change it, the screen updates.
- The function you pass to `ui.render` runs again after every tap. It works like a SwiftUI `body`.
- Views take a list of children. The first argument can be an options object such as `{ spacing, alignment }`.
- Modifiers chain just like in SwiftUI: `.font()`, `.padding()`, `.foregroundColor()` and so on.

### Views

| View | Example |
|---|---|
| Text | `Text("Hello")` |
| Button | `Button("Tap", () => {})` or `Button(Image("star"), fn)` |
| Image | `Image("star.fill")`, `Image("https://…")`, `Image({ base64 })`, `Image({ file: "pic.png" })`, `Image({ emoji: "🔥" })` |
| Stacks | `VStack`, `HStack`, `ZStack`, `Grid({ columns: 3 }, …)` |
| Containers | `List`, `Form`, `Section("Title", …)`, `ScrollView`, `GroupBox`, `Card` |
| Navigation | `TabView(Tab("Home", "house", …), …)`, `NavigationLink("Open", …page)` |
| Inputs | `Toggle`, `Slider`, `Stepper`, `TextField`, `SecureField`, `TextEditor`, `Picker`, `DatePicker`, `ColorPicker` |
| Menus | `Menu("More", Button(…), Button(…))`, `DisclosureGroup("Details", …)` |
| Data | `Chart(data, { type: "bar" \| "line" \| "area" \| "point" })`, `Gauge(0.7, { style: "circular" })`, `ProgressView(0.5)` |
| Shapes | `Circle()`, `Rectangle()`, `RoundedRectangle(16)`, `Capsule()`, `LinearGradient(["red", "blue"])` |
| Extras | `Map({ latitude, longitude, pins })`, `WebView("https://…")`, `Label`, `Badge`, `Emoji`, `Spacer`, `Divider`, `Link` |

Here is how each input control reports changes:

```js
Toggle("Wi-Fi", s.on, v => s.on = v)
Slider(s.level, v => s.level = v, { min: 0, max: 100, step: 1 })
Stepper(`${s.n} items`, s.n, v => s.n = v, { min: 0 })
TextField("Name", s.name, v => s.name = v)
Picker("Size", ["S", "M", "L"], s.size, v => s.size = v).pickerStyle("segmented")
DatePicker("When", s.date, d => s.date = d, { mode: "date" })
ColorPicker("Color", s.hex, c => s.hex = c)
```

### Modifiers

- **Text:** `.font("title" | size, weight?, design?)`, `.bold()`, `.italic()`, `.monospaced()`, `.underline()`, `.tracking(n)`, `.lineLimit(n)`
- **Colour:** `.foregroundColor(c)`, `.background(c)`, `.fill(c)`, `.tint(c)`, `.gradient([c1, c2], "diagonal")`, `.glass()`
- **Layout:** `.padding(n)`, `.padding("horizontal", n)`, `.frame({ width, height, maxWidth: Infinity })`, `.aspectRatio(1, "fill")`, `.offset(x, y)`, `.zIndex(n)`
- **Shape:** `.cornerRadius(r)`, `.clipShape("circle" | "capsule")`, `.border(c, width, radius)`, `.shadow(r)`, `.shadowColor(c, r, x, y)`
- **Effects:** `.opacity()`, `.blur()`, `.grayscale()`, `.rotationEffect(deg)`, `.scaleEffect(s)`, `.animation()`
- **Interaction:** `.onTapGesture(fn)`, `.onLongPressGesture(fn)`, `.contextMenu([{ title, icon, action, destructive }])`, `.refreshable(fn)`, `.disabled(true)`, `.badge(3)`
- **Styles:** `.buttonStyle("borderedProminent")`, `.pickerStyle("segmented")`, `.toggleStyle("button")`, `.listStyle("plain")`, `.controlSize("large")`

Colours can be names (`red`, `blue`, `mint`, `secondaryBackground`, …) or hex codes such as `"#FF8800"`.

## 4. Sound

```js
playSound(1007)                          // iOS system sound by number
audio.play("https://…/song.mp3")         // from a URL (waits until it's loaded)
audio.play("clip.m4a", { wait: true })   // from AMod's files
audio.playBase64(myBase64)               // from base64 text or a data: URL
audio.tone(440, 0.3)                     // generate a tone: frequency (Hz), seconds
audio.note("C5", 0.2, { wave: "square" })// waves: sine, square, saw, triangle, noise
audio.melody([["C4", .2], ["E4", .2], ["-", .1], ["G4", .4]])
audio.stop()
```

Options: `{ wait, volume, loop, rate }`. Audio still plays when the silent switch is on.

`audio.toneBase64("A4", 0.5)` gives you a WAV file as base64, which you can save with `files.writeBase64("a.wav", b64)`.

## 5. Images and base64

```js
showImage(base64OrDataURL)                    // show an image in the console
Image({ base64: b64 }).frame({ height: 200 }) // show an image in a GUI
const b64 = base64.fromURL("https://…/pic.jpg") // download as base64
files.writeBase64("pic.jpg", b64)               // save to Files
Image({ file: "pic.jpg" })                      // show a saved file
base64.encode("hello") / base64.decode("aGVsbG8=")  // also btoa / atob
http.get(url, { base64: true }).base64          // any download as base64
```

To turn your own pictures or audio into base64, use the [AMod online tools](https://thford64-boop.github.io/AMod/).

## 6. Device and settings

```js
vibrate(); haptic("heavy")
flashlight.on(0.5); flashlight.off(); flashlight.toggle()
device.brightness = 0.8
device.volume = 0.4
device.info()     // battery, charging, lowPowerMode, darkMode, model, version…
settings.open("wifi")  // also: bluetooth, cellular, hotspot, battery, display, focus, privacy…
```

### Making `settings.open()` work on new iOS

On recent iOS versions, Apple may block apps from opening a specific Settings page, and you end up on AMod's own page instead. The Shortcuts app is still allowed to open them, so AMod can send the link through a small helper shortcut:

1. Open **Shortcuts** → **+** and name the new shortcut **AMod Settings**.
2. Add the **Open URLs** action and set its URL to **Shortcut Input**.
3. In the shortcut's settings (ⓘ), turn on **Show in Share Sheet** and set *Receive* to **Text** (or any input).
4. In AMod, go to **⚙︎ Settings → Settings helper shortcut** and enter `AMod Settings`. Tap **Test**.

After that, `settings.open("bluetooth")` goes straight to the Bluetooth page.

Switches like Wi-Fi, Bluetooth, Airplane Mode and Low Power can only be flipped by Shortcuts. Make a shortcut that does it, then call `shortcuts.run("Its Name")`.

## 7. Online tools and the web

```js
const res = http.get("https://api.github.com/zen")   // { status, ok, body, headers, json() }
const data = fetchJSON("https://api.open-meteo.com/…")
http.post(url, { any: "json" })
WebView("https://fast.com")                         // a web page inside your GUI
openURL("https://apple.com")
```

The templates include several free online tools: QR codes, weather, crypto prices, a dictionary, IP lookup and jokes.

## 8. Files, storage and more

```js
files.write("notes.txt", "hi"); files.append(...); files.read(...); files.list()
storage.set("score", 10); storage.get("score", 0)
clipboard.get(); clipboard.set("text")
speak("Hello", { rate: 0.5 }); notify("Title", "Body", { delay: 60 })
location(); reminders.add("Milk", { due: new Date() }); calendar.addEvent("Lunch", date)
alert("Hi"); confirm("Sure?"); input("Name?"); menu("Pick", ["A", "B"])
sleep(1); await wait(1); setInterval(fn, 1000)
require("My Library"); scripts.run("Other Script")
```

Files are saved in **Files → On My iPhone → AMod**.

## 9. Templates

Tap **+** → **From Template** to start from a ready-made script. The categories are Sound, Images, Online Tools, Utilities, Fun and System. The [online tools page](https://thford64-boop.github.io/AMod/) has the same templates, and its **Open in AMod** buttons install them straight into the app.

## 10. Home Screen, Shortcuts and links

- **Long-press a script → Add to Home Screen.** Safari downloads a small profile. Install it in **Settings → Profile Downloaded**, and the icon then runs your script in one tap.
- **Icons:** in the editor, tap the icon to choose a colour and an SF Symbol, emoji or photo.
- **Shortcuts app:** use *Run AMod Script* (runs in the background and returns `output(...)`) or *Open AMod Script* (shows the UI).
- **Links:** `amod://run?name=Piano`, `amod://run?name=Note&input=hello`, `amod://edit?name=Piano`, `amod://import?name=X&code=<base64>`

## 11. Tips

- `args.input` contains whatever Shortcuts or a link passed in.
- When a script errors, the console shows the line number.
- Use `exit()` to stop a script early, and `ui.close()` to close a GUI.
- The **⊞** button in the editor inserts ready-made actions, just like Shortcuts actions.
- Smart quotes are turned off in the editor, so code you paste stays valid.
