import Foundation
import IOKit.ps

/// Monitors power source changes (charger plug/unplug) and re-executes
/// clamshell control when needed.
///
/// On Apple Silicon MacBooks, plugging or unplugging the charger while the lid
/// is closed can cause the system to briefly reset its sleep state, undoing
/// `pmset disablesleep 1`. This monitor detects power source transitions and
/// re-executes the clamshell control script to maintain lid-closed wakefulness.
///
/// This is the same approach used by Amphetamine's "Power Protect" feature.
final class PowerEventMonitor {

    static let shared = PowerEventMonitor()

    // MARK: - Private

    private var runLoopSource: CFRunLoopSource?
    private var isMonitoring = false

    /// Whether clamshell should be kept active (set by SessionManager).
    private var shouldMaintainClamshell = false

    // MARK: - Init

    private init() {}

    // MARK: - Public API

    /// Start monitoring power source changes.
    ///
    /// When a power source change is detected and clamshell mode is active,
    /// re-executes `pmset disablesleep 1` via `ClamshellManager`.
    func startMonitoring() {
        guard !isMonitoring else { return }

        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        runLoopSource = IOPSNotificationCreateRunLoopSource(
            { context in
                guard let context = context else { return }
                let monitor = Unmanaged<PowerEventMonitor>.fromOpaque(context).takeUnretainedValue()
                DispatchQueue.main.async {
                    monitor.handlePowerSourceChange()
                }
            },
            context
        )?.takeRetainedValue()

        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
            isMonitoring = true
        }
    }

    /// Stop monitoring power source changes.
    func stopMonitoring() {
        guard isMonitoring, let source = runLoopSource else { return }

        CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
        runLoopSource = nil
        isMonitoring = false
    }

    /// Set whether clamshell mode should be maintained across power events.
    ///
    /// - Parameter active: `true` if clamshell keep-awake is currently enabled.
    func setClamshellActive(_ active: Bool) {
        shouldMaintainClamshell = active
    }

    // MARK: - Private

    /// Handle a power source change event.
    ///
    /// If clamshell mode is active, re-execute `pmset disablesleep 1` to
    /// counteract the Apple Silicon power-transition reset.
    private func handlePowerSourceChange() {
        guard shouldMaintainClamshell else { return }

        // Re-activate clamshell to ensure pmset disablesleep persists
        // across charger plug/unplug events
        let clamshell = ClamshellManager.shared
        if clamshell.isInstalled && clamshell.isActive {
            clamshell.activate()
        }
    }
}
