import Foundation
import IOKit.ps
import Combine

/// Monitors battery level and charging state via IOKit power sources.
///
/// Publishes battery percentage and charging status, enabling auto-stop of
/// keep-awake sessions when the battery drops below a user-defined threshold.
///
/// Uses `IOPSNotificationCreateRunLoopSource` to receive real-time updates
/// when battery state changes — no polling required.
final class BatteryMonitor: ObservableObject {

    static let shared = BatteryMonitor()

    // MARK: - Published State

    /// Current battery level as a percentage (0–100), or `nil` if unavailable (e.g., desktop Mac).
    @Published private(set) var batteryLevel: Int?

    /// Whether the Mac is currently charging (plugged in).
    @Published private(set) var isCharging: Bool = false

    /// Whether the Mac is running on battery power (not plugged in).
    @Published private(set) var isOnBattery: Bool = false

    /// Whether the battery is below the low-battery threshold.
    @Published private(set) var isBelowThreshold: Bool = false

    // MARK: - Callback

    /// Called when battery drops below threshold while on battery power.
    /// SessionManager sets this to auto-stop the session.
    var onLowBattery: (() -> Void)?

    // MARK: - Private

    private var runLoopSource: CFRunLoopSource?
    private var isMonitoring = false

    // MARK: - Init

    private init() {
        updateBatteryState()
    }

    // MARK: - Public API

    /// Start monitoring battery state changes.
    func startMonitoring() {
        guard !isMonitoring else { return }

        // Create a run loop source for power source change notifications
        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        runLoopSource = IOPSNotificationCreateRunLoopSource(
            { context in
                guard let context = context else { return }
                let monitor = Unmanaged<BatteryMonitor>.fromOpaque(context).takeUnretainedValue()
                DispatchQueue.main.async {
                    monitor.updateBatteryState()
                }
            },
            context
        )?.takeRetainedValue()

        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
            isMonitoring = true
        }

        // Initial state update
        updateBatteryState()
    }

    /// Stop monitoring battery state changes.
    func stopMonitoring() {
        guard isMonitoring, let source = runLoopSource else { return }

        CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
        runLoopSource = nil
        isMonitoring = false
    }

    // MARK: - Battery State

    /// Read the current battery state from IOKit power sources.
    private func updateBatteryState() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [Any],
              let firstSource = sources.first
        else {
            // No battery (desktop Mac or unavailable)
            batteryLevel = nil
            isCharging = false
            isOnBattery = false
            isBelowThreshold = false
            return
        }

        guard let description = IOPSGetPowerSourceDescription(snapshot, firstSource as CFTypeRef)?
            .takeUnretainedValue() as? [String: Any]
        else {
            return
        }

        // Extract battery level
        if let capacity = description[kIOPSCurrentCapacityKey] as? Int {
            batteryLevel = capacity
        }

        // Extract power source type
        if let powerSource = description[kIOPSPowerSourceStateKey] as? String {
            isOnBattery = (powerSource == kIOPSBatteryPowerValue)
            isCharging = (powerSource == kIOPSACPowerValue)
        }

        // Check charging state more precisely
        if let chargingState = description[kIOPSIsChargingKey] as? Bool {
            isCharging = chargingState
        }

        // Evaluate low battery threshold
        evaluateThreshold()
    }

    /// Check if battery is below threshold and trigger callback if needed.
    private func evaluateThreshold() {
        guard let level = batteryLevel, isOnBattery else {
            isBelowThreshold = false
            return
        }

        let threshold = UserDefaults.standard.object(forKey: "lowBatteryThreshold") as? Int ?? 20
        let wasBelow = isBelowThreshold
        isBelowThreshold = level <= threshold

        // Fire callback only on transition from above to below threshold
        if isBelowThreshold && !wasBelow {
            onLowBattery?()
        }
    }
}
