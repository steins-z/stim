import SwiftUI
import AppKit

/// The main popover panel shown when clicking the menu bar icon.
///
/// Contains:
/// - App title with icon (respects icon style preference)
/// - Toggle switch for keep-awake
/// - Duration picker (radio-style)
/// - Options (clamshell, display)
/// - Countdown timer display (when a timed session is active)
/// - Battery warning (when low battery auto-stop is imminent)
/// - Settings button and Quit button
struct PopoverView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @AppStorage("menuBarIconStyle") private var iconStyleRaw: String = MenuBarIconStyle.coffeeCup.rawValue

    /// Resolved icon style from user defaults.
    private var iconStyle: MenuBarIconStyle {
        MenuBarIconStyle(from: iconStyleRaw)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            headerSection

            Divider()

            // Toggle
            toggleSection

            Divider()

            // Duration picker
            durationSection

            Divider()

            // Options
            optionsSection

            // Countdown (only shown during timed sessions)
            if let formatted = sessionManager.formattedRemaining, sessionManager.isActive {
                Divider()
                countdownSection(formatted)
            }

            // Battery warning
            if let warning = batteryWarningMessage {
                Divider()
                batteryWarningSection(warning)
            }

            Divider()

            // Footer
            footerSection
        }
        .padding(16)
        .frame(width: 240)
    }

    // MARK: - Battery Warning

    /// Returns a warning message if battery is low, or `nil` if no warning is needed.
    private var batteryWarningMessage: String? {
        let monitor = sessionManager.batteryMonitor

        // Show "was stopped" message after low-battery auto-stop
        if sessionManager.wasStoppedByLowBattery {
            return "Session stopped — low battery."
        }

        // Show warning when battery is approaching threshold
        if sessionManager.isActive,
           monitor.isOnBattery,
           let level = monitor.batteryLevel,
           monitor.isBelowThreshold {
            return "Battery at \(level)% — session will auto-stop."
        }

        return nil
    }

    // MARK: - Sections

    private var headerSection: some View {
        HStack(spacing: 8) {
            Image(systemName: sessionManager.isActive
                  ? iconStyle.activeIcon
                  : iconStyle.inactiveIcon)
                .font(.title2)
                .foregroundColor(sessionManager.isActive ? .accentColor : .secondary)

            Text("Stim")
                .font(.headline)

            Spacer()
        }
    }

    private var toggleSection: some View {
        Toggle(isOn: Binding(
            get: { sessionManager.isActive },
            set: { _ in sessionManager.toggle() }
        )) {
            Text("Keep Awake")
                .font(.body)
        }
        .toggleStyle(.switch)
    }

    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Duration")
                .font(.subheadline)
                .foregroundColor(.secondary)

            ForEach(SessionDuration.allCases) { duration in
                DurationRow(
                    duration: duration,
                    isSelected: sessionManager.selectedDuration == duration,
                    onSelect: {
                        sessionManager.updateDuration(duration)
                    }
                )
            }
        }
    }

    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Options")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Toggle("Keep awake on lid close", isOn: $sessionManager.clamshellEnabled)
                .toggleStyle(.checkbox)
                .font(.body)

            if sessionManager.clamshellEnabled && !sessionManager.clamshellManager.isInstalled {
                Button("Install Helper…") {
                    sessionManager.clamshellManager.install { success in
                        if success {
                            // If session is active, activate clamshell now
                            if sessionManager.isActive {
                                sessionManager.clamshellManager.activate()
                            }
                        }
                    }
                }
                .font(.caption)
                .foregroundColor(.accentColor)
            }

            Toggle("Keep display on", isOn: $sessionManager.keepDisplayOn)
                .toggleStyle(.checkbox)
                .font(.body)
                .onChange(of: sessionManager.keepDisplayOn) { newValue in
                    if sessionManager.isActive {
                        PowerManager.shared.setDisplayAssertionEnabled(newValue)
                    }
                }
        }
    }

    private func countdownSection(_ formatted: String) -> some View {
        HStack {
            Text("Remaining:")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            Text(formatted)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.primary)
        }
    }

    /// Warning banner shown when battery is low or session was auto-stopped.
    private func batteryWarningSection(_ message: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "battery.25")
                .foregroundColor(.orange)
                .font(.subheadline)

            Text(message)
                .font(.caption)
                .foregroundColor(.orange)

            Spacer()
        }
    }

    private var footerSection: some View {
        HStack {
            Button("Settings…") {
                openSettings()
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .font(.subheadline)

            Spacer()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .font(.subheadline)
        }
    }

    // MARK: - Helpers

    /// Open the app's Settings window.
    private func openSettings() {
        // On macOS 14+, the selector changed to showSettingsWindow:.
        // For macOS 13 compatibility, try the legacy selector first.
        if NSApp.responds(to: Selector(("showSettingsWindow:"))) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }

        // Bring the settings window to front
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - Duration Row

/// A single row in the duration picker, styled as a radio button.
private struct DurationRow: View {
    let duration: SessionDuration
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "circle.inset.filled" : "circle")
                    .font(.caption)
                    .foregroundColor(isSelected ? .accentColor : .secondary)

                Text(duration.label)
                    .font(.body)
                    .foregroundColor(.primary)

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
