# Stim ⚡

A minimal, elegant keep-awake utility for macOS. One click to keep your Mac awake — even with the lid closed.

## Features

- **Menu bar app** — no Dock icon, no clutter
- **One-click toggle** — instantly prevent sleep
- **Lid-close support** — keep running with the lid shut (Apple Silicon + Intel)
- **Timer sessions** — 30m / 1h / 2h / 4h / indefinite
- **Display control** — optionally keep the display on
- **Zero dependencies** — pure Swift + SwiftUI

## Requirements

- macOS 13 Ventura or later
- Apple Silicon or Intel Mac

## Build & Run

```bash
cd Stim
swift build
swift run
```

Or open `Stim/Package.swift` in Xcode.

## Lid-Close Setup

The lid-close feature requires a one-time helper installation (needs admin password / Touch ID). The app will guide you through this on first use.

## Project Structure

```
Stim/
├── Sources/
│   ├── StimApp.swift              # App entry point (MenuBarExtra)
│   ├── Core/
│   │   ├── PowerManager.swift     # IOKit Power Assertions
│   │   ├── ClamshellManager.swift # Lid-close control (pmset)
│   │   └── SessionManager.swift   # Timer session management
│   └── UI/
│       └── PopoverView.swift      # Menu bar panel UI
├── Resources/
│   └── clamshellControl.sh        # Lid-close helper script
├── Package.swift
└── Info.plist
```

## Docs

- [PRD](docs/PRD.md) — Product requirements & technical design
- [M1 Verification](docs/m1-verification-record.md) — IOKit feasibility testing record

## License

TBD
