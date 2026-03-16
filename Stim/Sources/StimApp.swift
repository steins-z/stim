import SwiftUI

/// Stim — A minimal keep-awake utility for macOS.
///
/// Menu-bar-only app (no Dock icon, no main window).
/// Left-click the menu bar icon to toggle awake/sleep.
/// The popover panel provides duration picker and countdown display.
@main
struct StimApp: App {
    @StateObject private var sessionManager = SessionManager()
    @AppStorage("menuBarIconStyle") private var iconStyleRaw: String = MenuBarIconStyle.coffeeCup.rawValue

    /// Resolved icon style from user defaults.
    private var iconStyle: MenuBarIconStyle {
        MenuBarIconStyle(from: iconStyleRaw)
    }

    var body: some Scene {
        // Menu bar popover
        MenuBarExtra {
            PopoverView()
                .environmentObject(sessionManager)
        } label: {
            Image(systemName: sessionManager.isActive
                  ? iconStyle.activeIcon
                  : iconStyle.inactiveIcon)
        }
        .menuBarExtraStyle(.window)

        // Settings window (⌘,)
        Settings {
            SettingsView()
        }
    }
}
