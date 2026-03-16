import Foundation
import IOKit.pwr_mgt

/// Manages IOKit power assertions to prevent system and display sleep.
///
/// Uses `IOPMAssertionCreateWithName` with:
/// - `PreventUserIdleSystemSleep` — prevents the system from sleeping due to idle
/// - `PreventUserIdleDisplaySleep` — additionally prevents the display from dimming
///
/// Both assertion types are sandbox-safe (verified in M1).
final class PowerManager {

    // MARK: - Properties

    private var systemAssertionID: IOPMAssertionID = 0
    private var displayAssertionID: IOPMAssertionID = 0

    private(set) var isSystemAssertionActive = false
    private(set) var isDisplayAssertionActive = false

    private let reasonString: CFString = "Stim: Keeping Mac awake" as CFString

    // MARK: - Singleton

    static let shared = PowerManager()
    private init() {}

    // MARK: - Public API

    /// Activate power assertions to keep the system awake.
    ///
    /// - Parameter keepDisplayOn: If `true`, also prevents display sleep.
    ///   Defaults to `false` (only prevents system idle sleep).
    func activate(keepDisplayOn: Bool = false) {
        activateSystemAssertion()
        if keepDisplayOn {
            activateDisplayAssertion()
        }
    }

    /// Release all active power assertions, allowing the system to sleep normally.
    func deactivate() {
        releaseSystemAssertion()
        releaseDisplayAssertion()
    }

    /// Update whether the display assertion is active without changing the system assertion.
    func setDisplayAssertionEnabled(_ enabled: Bool) {
        if enabled {
            activateDisplayAssertion()
        } else {
            releaseDisplayAssertion()
        }
    }

    // MARK: - Private Helpers

    private func activateSystemAssertion() {
        guard !isSystemAssertionActive else { return }

        let result = IOPMAssertionCreateWithName(
            "PreventUserIdleSystemSleep" as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reasonString,
            &systemAssertionID
        )

        if result == kIOReturnSuccess {
            isSystemAssertionActive = true
        }
    }

    private func activateDisplayAssertion() {
        guard !isDisplayAssertionActive else { return }

        let result = IOPMAssertionCreateWithName(
            "PreventUserIdleDisplaySleep" as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reasonString,
            &displayAssertionID
        )

        if result == kIOReturnSuccess {
            isDisplayAssertionActive = true
        }
    }

    private func releaseSystemAssertion() {
        guard isSystemAssertionActive else { return }
        IOPMAssertionRelease(systemAssertionID)
        systemAssertionID = 0
        isSystemAssertionActive = false
    }

    private func releaseDisplayAssertion() {
        guard isDisplayAssertionActive else { return }
        IOPMAssertionRelease(displayAssertionID)
        displayAssertionID = 0
        isDisplayAssertionActive = false
    }
}
