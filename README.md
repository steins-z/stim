# Stim ⚡

A minimal, elegant keep-awake utility for macOS. One click to keep your Mac awake — even with the lid closed.

## Features

- **Menu bar app** — no Dock icon, no clutter
- **One-click toggle** — instantly prevent sleep
- **Lid-close support** — keep running with the lid shut (Apple Silicon + Intel)
- **Timer sessions** — 30m / 1h / 2h / 4h / indefinite
- **Display control** — optionally keep the display on
- **Settings window** — Launch at Login, default duration, icon style, and more
- **Menu bar icon styles** — choose between Coffee Cup ☕, Dot ●, or Bolt ⚡
- **Expiry notifications** — get notified 5 minutes before a timed session ends
- **Low battery auto-stop** — automatically stops the session when battery drops below threshold (configurable, default 20%)
- **Apple Silicon power event resilience** — re-executes clamshell control when charger is plugged/unplugged
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

## Settings

Open Settings via the popover panel or `⌘,`:

**General:**
- Launch at Login (uses SMAppService)
- Auto-activate on launch
- Default session duration
- Menu bar icon style (Coffee Cup / Dot / Bolt)

**Advanced:**
- Low battery auto-stop threshold (10–50%, default 20%)
- Expiry notification toggle

## Project Structure

```
Stim/
├── Sources/
│   ├── StimApp.swift              # App entry point (MenuBarExtra + Settings)
│   ├── Core/
│   │   ├── PowerManager.swift     # IOKit Power Assertions
│   │   ├── ClamshellManager.swift # Lid-close control (pmset)
│   │   ├── SessionManager.swift   # Timer session management
│   │   ├── NotificationManager.swift  # Session expiry notifications
│   │   ├── BatteryMonitor.swift   # Battery level monitoring (IOPowerSources)
│   │   └── PowerEventMonitor.swift    # Power source change monitoring
│   └── UI/
│       ├── PopoverView.swift      # Menu bar panel UI
│       └── SettingsView.swift     # Settings window
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
