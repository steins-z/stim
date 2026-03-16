import SwiftUI

/// Stim — A minimal keep-awake utility for macOS.
///
/// Menu-bar-only app (no Dock icon, no main window).
/// Left-click the menu bar icon to toggle awake/sleep.
/// The popover panel provides duration picker and countdown display.
@main
struct StimApp: App {
    @StateObject private var sessionManager = SessionManager()

    var body: some Scene {
        MenuBarExtra {
            PopoverView()
                .environmentObject(sessionManager)
        } label: {
            Image(systemName: sessionManager.isActive
                  ? "cup.and.saucer.fill"
                  : "cup.and.saucer")
        }
        .menuBarExtraStyle(.window)
    }
}
