import Foundation
import Combine

/// Represents the available session durations.
enum SessionDuration: Int, CaseIterable, Identifiable {
    case thirtyMinutes = 1800
    case oneHour = 3600
    case twoHours = 7200
    case fourHours = 14400
    case indefinite = 0

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .thirtyMinutes: return "30 min"
        case .oneHour:       return "1 hour"
        case .twoHours:      return "2 hours"
        case .fourHours:     return "4 hours"
        case .indefinite:    return "Indefinite"
        }
    }

    /// Duration in seconds, or `nil` for indefinite.
    var seconds: TimeInterval? {
        self == .indefinite ? nil : TimeInterval(rawValue)
    }
}

/// Manages awake sessions with optional countdown timers.
///
/// Coordinates with `PowerManager` to create/release IOKit power assertions
/// and drives a per-second countdown timer for timed sessions.
final class SessionManager: ObservableObject {

    // MARK: - Published State

    /// Whether a keep-awake session is currently active.
    @Published private(set) var isActive = false

    /// The selected duration for the next (or current) session.
    @Published var selectedDuration: SessionDuration = .indefinite

    /// Whether to prevent sleep when the lid is closed.
    @Published var clamshellEnabled = true

    /// Whether to keep the display on (not just system sleep).
    @Published var keepDisplayOn = false

    /// Seconds remaining in the current timed session. `nil` for indefinite.
    @Published private(set) var remainingSeconds: TimeInterval?

    /// The date/time when the current session will expire. `nil` for indefinite.
    @Published private(set) var endDate: Date?

    // MARK: - Private

    private var timer: AnyCancellable?
    private let powerManager = PowerManager.shared
    let clamshellManager = ClamshellManager.shared

    // MARK: - Public API

    /// Toggle the session on or off.
    func toggle() {
        if isActive {
            stop()
        } else {
            start()
        }
    }

    /// Start a keep-awake session with the currently selected duration.
    func start() {
        guard !isActive else { return }

        isActive = true
        powerManager.activate(keepDisplayOn: keepDisplayOn)

        if clamshellEnabled {
            clamshellManager.activate()
        }

        if let seconds = selectedDuration.seconds {
            endDate = Date().addingTimeInterval(seconds)
            remainingSeconds = seconds
            startTimer()
        } else {
            // Indefinite session — no timer
            endDate = nil
            remainingSeconds = nil
        }
    }

    /// Stop the current session and release power assertions.
    func stop() {
        isActive = false
        powerManager.deactivate()
        clamshellManager.deactivate()
        stopTimer()
        endDate = nil
        remainingSeconds = nil
    }

    /// Change the duration while a session is running.
    /// Restarts the timer with the new duration from now.
    func updateDuration(_ duration: SessionDuration) {
        selectedDuration = duration

        guard isActive else { return }

        stopTimer()

        if let seconds = duration.seconds {
            endDate = Date().addingTimeInterval(seconds)
            remainingSeconds = seconds
            startTimer()
        } else {
            endDate = nil
            remainingSeconds = nil
        }
    }

    // MARK: - Formatted Remaining Time

    /// Human-readable countdown string, e.g. "1:23:45".
    var formattedRemaining: String? {
        guard let remaining = remainingSeconds, remaining > 0 else { return nil }

        let totalSeconds = Int(remaining)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    // MARK: - Timer

    private func startTimer() {
        timer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }

    private func stopTimer() {
        timer?.cancel()
        timer = nil
    }

    private func tick() {
        guard let end = endDate else { return }

        let remaining = end.timeIntervalSinceNow

        if remaining <= 0 {
            // Session expired
            stop()
        } else {
            remainingSeconds = remaining
        }
    }
}
