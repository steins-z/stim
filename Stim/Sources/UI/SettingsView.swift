import SwiftUI
import ServiceManagement

/// The available menu bar icon styles.
///
/// Each case maps to an SF Symbol pair (inactive/active).
enum MenuBarIconStyle: String, CaseIterable, Identifiable {
    case coffeeCup = "coffeeCup"
    case dot = "dot"
    case bolt = "bolt"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .coffeeCup: return "Coffee Cup"
        case .dot:       return "Dot"
        case .bolt:      return "Bolt"
        }
    }

    /// SF Symbol name for the inactive (idle) state.
    var inactiveIcon: String {
        switch self {
        case .coffeeCup: return "cup.and.saucer"
        case .dot:       return "circle"
        case .bolt:      return "bolt"
        }
    }

    /// SF Symbol name for the active (awake) state.
    var activeIcon: String {
        switch self {
        case .coffeeCup: return "cup.and.saucer.fill"
        case .dot:       return "circle.fill"
        case .bolt:      return "bolt.fill"
        }
    }

    /// Initialize from a stored raw value, defaulting to `.coffeeCup`.
    init(from rawValue: String) {
        self = MenuBarIconStyle(rawValue: rawValue) ?? .coffeeCup
    }
}

/// macOS Settings window using SwiftUI Settings scene.
///
/// Organized into two sections:
/// - **General:** Launch at Login, auto-activate, default duration, icon style
/// - **Advanced:** Low battery threshold, expiry notification toggle
struct SettingsView: View {

    // MARK: - General Settings

    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("autoActivateOnLaunch") private var autoActivateOnLaunch = false
    @AppStorage("defaultDuration") private var defaultDuration: Int = SessionDuration.indefinite.rawValue
    @AppStorage("menuBarIconStyle") private var iconStyleRaw: String = MenuBarIconStyle.coffeeCup.rawValue

    // MARK: - Advanced Settings

    @AppStorage("lowBatteryThreshold") private var lowBatteryThreshold: Int = 20
    @AppStorage("expiryNotificationEnabled") private var expiryNotificationEnabled = true

    // MARK: - Private

    /// Binding wrapper for the icon style picker.
    private var iconStyle: Binding<MenuBarIconStyle> {
        Binding(
            get: { MenuBarIconStyle(from: iconStyleRaw) },
            set: { iconStyleRaw = $0.rawValue }
        )
    }

    /// Binding wrapper for the default duration picker.
    private var defaultDurationSelection: Binding<SessionDuration> {
        Binding(
            get: { SessionDuration(rawValue: defaultDuration) ?? .indefinite },
            set: { defaultDuration = $0.rawValue }
        )
    }

    // MARK: - Body

    var body: some View {
        Form {
            // General Section
            generalSection

            // Advanced Section
            advancedSection
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 380)
    }

    // MARK: - General Section

    private var generalSection: some View {
        Section("General") {
            // Launch at Login
            Toggle("Launch at Login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { newValue in
                    setLaunchAtLogin(newValue)
                }

            // Auto-activate on launch
            Toggle("Auto-activate on launch", isOn: $autoActivateOnLaunch)

            // Default duration
            Picker("Default duration", selection: defaultDurationSelection) {
                ForEach(SessionDuration.allCases) { duration in
                    Text(duration.label).tag(duration)
                }
            }

            // Menu bar icon style
            Picker("Menu bar icon", selection: iconStyle) {
                ForEach(MenuBarIconStyle.allCases) { style in
                    Label(style.label, systemImage: style.activeIcon)
                        .tag(style)
                }
            }
        }
    }

    // MARK: - Advanced Section

    private var advancedSection: some View {
        Section("Advanced") {
            // Low battery threshold
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Low battery auto-stop")
                    Spacer()
                    Text("\(lowBatteryThreshold)%")
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }

                Slider(
                    value: Binding(
                        get: { Double(lowBatteryThreshold) },
                        set: { lowBatteryThreshold = Int($0) }
                    ),
                    in: 10...50,
                    step: 5
                )

                Text("Automatically stop the keep-awake session when battery drops below this level.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Expiry notification
            Toggle("Notify before session expires", isOn: $expiryNotificationEnabled)

            Text("Show a notification 5 minutes before a timed session ends.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Launch at Login

    /// Register or unregister the app for Launch at Login using SMAppService.
    private func setLaunchAtLogin(_ enabled: Bool) {
        let service = SMAppService.mainApp
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            print("[Stim] Launch at Login error: \(error.localizedDescription)")
            // Revert the toggle on failure
            DispatchQueue.main.async {
                launchAtLogin = !enabled
            }
        }
    }
}
