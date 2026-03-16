import SwiftUI
import AppKit

/// The main popover panel shown when clicking the menu bar icon.
///
/// Contains:
/// - App title with icon
/// - Toggle switch for keep-awake
/// - Duration picker (radio-style)
/// - Countdown timer display (when a timed session is active)
/// - Quit button
struct PopoverView: View {
    @EnvironmentObject var sessionManager: SessionManager

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

            Divider()

            // Footer
            footerSection
        }
        .padding(16)
        .frame(width: 240)
    }

    // MARK: - Sections

    private var headerSection: some View {
        HStack(spacing: 8) {
            Image(systemName: sessionManager.isActive
                  ? "cup.and.saucer.fill"
                  : "cup.and.saucer")
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

    private var footerSection: some View {
        HStack {
            Spacer()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .font(.subheadline)
        }
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
