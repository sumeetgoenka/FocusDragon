import Foundation
import Combine

/// Controller for breakable locks — adds friction via a non-skippable countdown before unlock.
class BreakableLockController: ObservableObject {
    static let shared = BreakableLockController()

    @Published var isCountingDown: Bool = false
    @Published var remainingDelay: TimeInterval = 0
    @Published var totalDelay: TimeInterval = 60
    @Published var isReadyToUnlock: Bool = false

    private var timer: Timer?
    private let userDefaults = UserDefaults.standard
    private let breakableStateKey = "focusDragon.breakableLockState"

    // MARK: - Configuration

    /// Available delay presets in seconds
    static let delayPresets: [(label: String, seconds: TimeInterval)] = [
        ("30 seconds", 30),
        ("1 minute", 60),
        ("2 minutes", 120),
        ("5 minutes", 300),
        ("10 minutes", 600),
        ("15 minutes", 900),
    ]

    private init() {
        loadState()
    }

    // MARK: - Activation

    func activate(delay: TimeInterval) {
        totalDelay = delay
        remainingDelay = 0
        isCountingDown = false
        isReadyToUnlock = false
        saveState()

        NotificationHelper.shared.showBreakableLockActivated(delay: delay)
    }

    // MARK: - Countdown

    /// Begin the non-skippable countdown. Called when user presses "Request Unlock".
    func startCountdown() {
        guard !isCountingDown else { return }

        isCountingDown = true
        remainingDelay = totalDelay
        isReadyToUnlock = false
        saveState()

        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            self.remainingDelay -= 0.1

            if self.remainingDelay <= 0 {
                self.remainingDelay = 0
                self.isCountingDown = false
                self.isReadyToUnlock = true
                self.timer?.invalidate()
                self.timer = nil
                self.saveState()

                NotificationHelper.shared.showBreakableLockReady()
            }
        }
    }

    /// Cancel the countdown — only allowed if the lock itself is being removed externally.
    func cancelCountdown() {
        timer?.invalidate()
        timer = nil
        isCountingDown = false
        remainingDelay = 0
        isReadyToUnlock = false
        saveState()
    }

    func deactivate() {
        cancelCountdown()
        saveState()
    }

    // MARK: - Display Helpers

    var progress: Double {
        guard totalDelay > 0 else { return 1.0 }
        return 1.0 - (remainingDelay / totalDelay)
    }

    var formattedRemaining: String {
        let total = Int(ceil(remainingDelay))
        let minutes = total / 60
        let seconds = total % 60

        if minutes > 0 {
            return String(format: "%d:%02d", minutes, seconds)
        } else {
            return "\(seconds)s"
        }
    }

    // MARK: - Persistence

    private struct BreakableState: Codable {
        var totalDelay: TimeInterval
        var isReadyToUnlock: Bool
        var countdownStartedAt: Date?
    }

    private func saveState() {
        let state = BreakableState(
            totalDelay: totalDelay,
            isReadyToUnlock: isReadyToUnlock,
            countdownStartedAt: isCountingDown ? Date().addingTimeInterval(-totalDelay + remainingDelay) : nil
        )

        if let encoded = try? JSONEncoder().encode(state) {
            userDefaults.set(encoded, forKey: breakableStateKey)
        }
    }

    private func loadState() {
        guard let data = userDefaults.data(forKey: breakableStateKey),
              let state = try? JSONDecoder().decode(BreakableState.self, from: data) else {
            return
        }

        totalDelay = state.totalDelay
        isReadyToUnlock = state.isReadyToUnlock

        // Resume countdown if it was running
        if let startedAt = state.countdownStartedAt {
            let elapsed = Date().timeIntervalSince(startedAt)
            let remaining = totalDelay - elapsed

            if remaining > 0 {
                remainingDelay = remaining
                isCountingDown = true
                startCountdown()
            } else {
                // Countdown has completed while app was closed
                isReadyToUnlock = true
                isCountingDown = false
                remainingDelay = 0
            }
        }
    }
}
