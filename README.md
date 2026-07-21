# Skrivbord

A native macOS menu bar app for controlling Bluetooth standing desks — built for the IKEA Idasen, and compatible with other desks using the same Linak BLE protocol.

No Dock icon, no window — just a menu bar item with your desk's live height and one-click Sit/Stand.

## Features

- Live height readout and connection status
- Sit / Stand presets with keyboard shortcuts (⌘1 / ⌘2)
- Save current height as Sit or Stand
- Launch at Login
- Shortcuts app and Siri support, plus a `skrivbord://sit` / `skrivbord://stand` URL scheme for scripting
- Yields automatically if you override a move using the desk's own physical controls

## Requirements

- macOS 13 (Ventura) or later
- A Bluetooth LE standing desk using the Linak DPG1C control protocol (IKEA Idasen and similar)

## Building

The same source builds two ways:

```sh
swift build              # or `swift run`, for fast local iteration
./Scripts/build-app.sh   # assembles a signed, runnable Skrivbord.app
```

```sh
xcodegen generate         # regenerates Skrivbord.xcodeproj from project.yml
open Skrivbord.xcodeproj  # the build used for signing, sandboxing, and App Store distribution
```

## Privacy

Skrivbord makes no network requests and collects no data. See [PRIVACY.md](PRIVACY.md).
