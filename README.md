# AMod

<img src="AMod/Assets.xcassets/AppIcon.appiconset/icon.png" width="96" align="right" alt="AMod icon">

**AMod is a scripting app for iPhone.** It's like Shortcuts, but you write code. Scripts are JavaScript with a built-in iPhone API, so they can vibrate, use the flashlight, change brightness and volume, open Settings pages, run Shortcuts, make HTTP requests, read your location, add reminders, and more. You can also build native SwiftUI-style interfaces.

- **CLI scripts** run top to bottom in a terminal, using `print`, `input` and `menu`.
- **GUI scripts** use SwiftUI-like calls: `VStack`, `Button`, `Toggle`, `Slider`, `.font()`, `.padding()` and so on.
- **Long-press a script → Add to Home Screen** to get a real Home Screen icon that runs it.
- **Action library:** Shortcuts-style building blocks you can tap to insert, covering device, settings, Shortcuts, scripting, web, files and GUI.
- **Shortcuts integration:** two actions, *Run AMod Script* (runs in the background and returns output) and *Open AMod Script*.
- **Links:** `amod://run?name=Flashlight&input=hi`

```js
// CLI
const name = input("What's your name?")
print(`Hi ${name}!`)
flashlight.toggle()
haptic("success")
```

```js
// GUI
const s = state({ count: 0, torch: false })

ui.render(() =>
  VStack({ spacing: 20 },
    Text(`${s.count}`).font(64, "bold", "rounded"),
    Button("Tap", () => { s.count++; vibrate() }).buttonStyle("borderedProminent"),
    Toggle("Flashlight", s.torch, on => { s.torch = on; settings.flashlight(on) }),
    Slider(device.brightness, v => device.brightness = v),
  ).padding()
)
```

The in-app book icon opens the full API reference.

## Getting the IPA

GitHub Actions builds an unsigned `AMod.ipa` on every push.

1. Push this folder to a GitHub repo.
2. Open the **Actions** tab, select the latest **Build IPA** run, and download the **AMod-ipa** artifact.
3. To publish a release with the IPA attached, push a tag:
   ```sh
   git tag v1.0.0 && git push --tags
   ```

The IPA is **unsigned**. Install it with a sideloading tool that signs it for you, such as AltStore, SideStore, Sideloadly or TrollStore, or sign it with your own Apple developer certificate.

## Building locally (macOS)

```sh
brew install xcodegen
xcodegen generate
open AMod.xcodeproj
```

Set your team under *Signing & Capabilities* and run it on your phone.

## Project layout

```
project.yml              XcodeGen spec (the .xcodeproj is generated, not committed)
Config/Info.plist        permissions, amod:// URL scheme
.github/workflows/       CI that builds AMod.ipa
AMod/
  App/                   app entry and amod:// router
  Engine/                JavaScriptCore engine, native bridges, prelude API, SwiftUI renderer
  Views/                 script grid, editor, run/console, docs, action library
  HomeScreen/            "Add to Home Screen" (Web Clip profile served locally)
  Intents/               Shortcuts actions (App Intents)
  Library/               example scripts, action catalog
```

## What iOS does and doesn't allow

Apple's sandbox applies to every app, so AMod has the same limits:

| Feature | How AMod does it |
|---|---|
| Flashlight, vibration, haptics, brightness, speech, clipboard, notifications, location, reminders, calendar, HTTP, files | Directly |
| Volume | Through the system volume slider (`MPVolumeView`) |
| Wi-Fi, Bluetooth, Airplane Mode, Low Power Mode, Focus, cellular toggles | No public API exists. `settings.open("wifi")` jumps to the Settings page, or `shortcuts.run("name")` runs a shortcut that changes the setting |
| Home Screen icons | A Web Clip configuration profile. Safari downloads it, then you install it in Settings |
| Running in the background | Use the *Run AMod Script* action in Shortcuts or in automations |

The `App-prefs:` deep links that `settings.open()` uses are undocumented. They work on current iOS versions, but Apple could change them.
