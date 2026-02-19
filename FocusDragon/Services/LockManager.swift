import Foundation
import Combine

class LockManager: ObservableObject {
    static let shared = LockManager()

    @Published var currentLock: LockState = LockState(type: .none)
    @Published var configuration: LockConfiguration = .default

    private let userDefaults = UserDefaults.standard
    private let lockStateKey = "focusDragon.lockState"
    private let lockConfigKey = "focusDragon.lockConfig"

    private var updateTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    private init() {
        loadState()
        startUpdateTimer()

        // Auto-save on changes
        $currentLock
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.saveState()
            }
            .store(in: &cancellables)
    }

    // MARK: - Lock Creation

    func createTimerLock(duration: TimeInterval) throws {
        guard duration >= configuration.minTimerDuration,
              duration <= configuration.maxTimerDuration else {
            throw LockError.invalidDuration
        }

        let startTime = Date()
        var lock = LockState(type: .timer)
        lock.timerDuration = duration
        lock.remainingTime = duration
        lock.unlockAt = startTime.addingTimeInterval(duration)
        lock.lock()

        currentLock = lock

        // Persist timer to daemon-readable file for system-restart survival
        TimerPersistence.shared.save(startTime: startTime, duration: duration)

        notifyDaemon()
    }

    func createRandomTextLock() {
        let controller = RandomTextLockController()
        controller.activate()

        // Protect the random text from clipboard
        ClipboardProtection.shared.protect(controller.randomText)

        var lock = LockState(type: .randomText)
        lock.randomText = controller.randomText
        lock.maxAttempts = 5
        lock.lock()

        currentLock = lock
        notifyDaemon()
    }

    func createScheduleLock(start: Date, end: Date, days: Set<Int>) throws {
        guard start < end else {
            throw LockError.invalidSchedule
        }

        var lock = LockState(type: .schedule)
        lock.scheduleStart = start
        lock.scheduleEnd = end
        lock.scheduleDays = days
        lock.lock()

        currentLock = lock
        notifyDaemon()
    }

    func createRestartLock(numberOfRestarts: Int) throws {
        guard numberOfRestarts > 0, numberOfRestarts <= 10 else {
            throw LockError.invalidRestartCount
        }

        var lock = LockState(type: .restart)
        lock.restartLockCount = numberOfRestarts
        lock.remainingRestarts = numberOfRestarts
        lock.lock()

        currentLock = lock
        notifyDaemon()
    }

    func createBreakableLock(delay: TimeInterval) throws {
        guard delay >= 10, delay <= 900 else {
            throw LockError.invalidBreakDelay
        }

        var lock = LockState(type: .breakable)
        lock.breakDelay = delay
        lock.lock()

        BreakableLockController.shared.activate(delay: delay)

        currentLock = lock
        notifyDaemon()
    }

    // MARK: - Lock Verification

    func attemptUnlock(with text: String? = nil) -> UnlockResult {
        guard currentLock.isLocked else {
            return .success
        }

        let result: UnlockResult

        switch currentLock.type {
        case .none:
            currentLock.unlock()
            result = .success

        case .timer:
            if currentLock.canUnlock {
                currentLock.unlock()
                TimerPersistence.shared.clear()
                result = .success
            } else {
                return .failure(.timerNotExpired(remaining: currentLock.remainingTime ?? 0))
            }

        case .randomText:
            guard let inputText = text else {
                return .failure(.textRequired)
            }

            if inputText == currentLock.randomText {
                currentLock.unlock()
                ClipboardProtection.shared.clear()
                result = .success
            } else {
                currentLock.textAttempts += 1
                saveState()

                if currentLock.textAttempts >= currentLock.maxAttempts {
                    return .failure(.maxAttemptsReached)
                }

                return .failure(.incorrectText(remaining: currentLock.maxAttempts - currentLock.textAttempts))
            }

        case .schedule:
            if currentLock.canUnlock {
                currentLock.unlock()
                result = .success
            } else {
                return .failure(.scheduleLocked)
            }

        case .restart:
            if currentLock.canUnlock {
                currentLock.unlock()
                result = .success
            } else {
                return .failure(.restartsRemaining(count: currentLock.remainingRestarts ?? 0))
            }

        case .breakable:
            let breakController = BreakableLockController.shared
            if breakController.isReadyToUnlock {
                breakController.deactivate()
                currentLock.unlock()
                result = .success
            } else if breakController.isCountingDown {
                return .failure(.breakableCountingDown(remaining: breakController.remainingDelay))
            } else {
                // Start countdown
                breakController.startCountdown()
                return .failure(.breakableCountingDown(remaining: breakController.totalDelay))
            }
        }

        // Sync unlocked state to disk so daemon stops overriding isBlocking
        if result.isSuccess {
            notifyDaemon()
        }

        return result
    }

    func decrementRestartCounter() {
        guard currentLock.type == .restart,
              let remaining = currentLock.remainingRestarts,
              remaining > 0 else {
            return
        }

        currentLock.remainingRestarts = remaining - 1
        saveState()

        if currentLock.remainingRestarts == 0 {
            currentLock.unlock()
        }
    }

    // MARK: - Helpers

    private func generateRandomText() -> String {
        let characters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<configuration.randomTextLength).map { _ in
            characters.randomElement()!
        })
    }

    private func startUpdateTimer() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateTimerLock()
        }
    }

    private func updateTimerLock() {
        guard currentLock.type == .timer,
              currentLock.isLocked,
              let unlockAt = currentLock.unlockAt else {
            return
        }

        let remaining = unlockAt.timeIntervalSinceNow
        currentLock.remainingTime = max(0, remaining)

        if remaining <= 0 {
            // Timer expired - auto unlock
            currentLock.unlock()
            TimerPersistence.shared.clear()
            notifyDaemon()
        }
    }

    private func notifyDaemon() {
        // Signal daemon about lock state change
        let notification = Notification.Name("FocusDragonLockStateChanged")
        NotificationCenter.default.post(name: notification, object: currentLock)

        // Also write lock state to shared file so daemon can read it
        syncLockStateToDisk()
    }

    /// Write the current lock state to the shared file that the daemon reads.
    func syncLockStateToDisk() {
        let lockStatePath = "/Library/Application Support/FocusDragon/lock_state.json"

        struct DaemonReadableLockState: Codable {
            var lockType: String
            var isLocked: Bool
            var expiresAt: Date?
            var breakDelay: TimeInterval?
        }

        let daemonState = DaemonReadableLockState(
            lockType: currentLock.type.rawValue,
            isLocked: currentLock.isLocked,
            expiresAt: currentLock.unlockAt,
            breakDelay: currentLock.breakDelay
        )

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(daemonState)
            try data.write(to: URL(fileURLWithPath: lockStatePath))
        } catch {
            print("LockManager: Failed to sync lock state to disk: \(error)")
        }
    }

    // MARK: - Persistence

    private func saveState() {
        if let encoded = try? JSONEncoder().encode(currentLock) {
            userDefaults.set(encoded, forKey: lockStateKey)
        }

        if let configEncoded = try? JSONEncoder().encode(configuration) {
            userDefaults.set(configEncoded, forKey: lockConfigKey)
        }
    }

    private func loadState() {
        if let data = userDefaults.data(forKey: lockStateKey),
           let decoded = try? JSONDecoder().decode(LockState.self, from: data) {
            currentLock = decoded
        }

        // If timer lock was active, try recovering remaining time from
        // the daemon-readable file (survives system restarts)
        if currentLock.type == .timer, currentLock.isLocked {
            if let remaining = TimerPersistence.shared.getRemainingTime() {
                currentLock.remainingTime = remaining
                currentLock.unlockAt = Date().addingTimeInterval(remaining)
            } else {
                // Timer expired while app was closed
                currentLock.unlock()
                TimerPersistence.shared.clear()
            }
        }

        if let data = userDefaults.data(forKey: lockConfigKey),
           let decoded = try? JSONDecoder().decode(LockConfiguration.self, from: data) {
            configuration = decoded
        }
    }

    func reset() {
        currentLock = LockState(type: .none)
        saveState()
        notifyDaemon()
    }
}

// MARK: - Supporting Types

enum LockError: LocalizedError {
    case invalidDuration
    case invalidSchedule
    case invalidRestartCount
    case invalidBreakDelay
    case locked

    var errorDescription: String? {
        switch self {
        case .invalidDuration:
            return "Timer duration must be between 1 minute and 24 hours"
        case .invalidSchedule:
            return "Schedule end time must be after start time"
        case .invalidRestartCount:
            return "Restart count must be between 1 and 10"
        case .invalidBreakDelay:
            return "Break delay must be between 10 seconds and 15 minutes"
        case .locked:
            return "Cannot modify while locked"
        }
    }
}

enum UnlockResult {
    case success
    case failure(UnlockFailure)

    var isSuccess: Bool {
        if case .success = self {
            return true
        }
        return false
    }
}

enum UnlockFailure {
    case timerNotExpired(remaining: TimeInterval)
    case textRequired
    case incorrectText(remaining: Int)
    case maxAttemptsReached
    case scheduleLocked
    case restartsRemaining(count: Int)
    case breakableCountingDown(remaining: TimeInterval)

    var message: String {
        switch self {
        case .timerNotExpired(let time):
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = [.hour, .minute, .second]
            formatter.unitsStyle = .full
            return "Timer lock: \(formatter.string(from: time) ?? "") remaining"
        case .textRequired:
            return "Random text required to unlock"
        case .incorrectText(let remaining):
            return "Incorrect text. \(remaining) attempts remaining"
        case .maxAttemptsReached:
            return "Maximum attempts reached. Lock cannot be removed."
        case .scheduleLocked:
            return "Schedule lock is active"
        case .restartsRemaining(let count):
            return "\(count) restart(s) required before unlock"
        case .breakableCountingDown(let remaining):
            let secs = Int(ceil(remaining))
            return "Please wait \(secs) second\(secs == 1 ? "" : "s") before unlock"
        }
    }
}
