import Foundation

enum LockType: String, Codable {
    case none = "none"
    case timer = "timer"
    case randomText = "random_text"
    case schedule = "schedule"
    case restart = "restart"
    case breakable = "breakable"

    var displayName: String {
        switch self {
        case .none: return "No Lock"
        case .timer: return "Timer Lock"
        case .randomText: return "Random Text Lock"
        case .schedule: return "Schedule Lock"
        case .restart: return "Restart Lock"
        case .breakable: return "Breakable Lock"
        }
    }
}

struct LockState: Codable, Equatable {
    var type: LockType
    var isLocked: Bool
    var createdAt: Date
    var unlockAt: Date?

    // Timer lock properties
    var timerDuration: TimeInterval?
    var remainingTime: TimeInterval?

    // Random text lock properties
    var randomText: String?
    var textAttempts: Int = 0
    var maxAttempts: Int = 5

    // Schedule lock properties
    var scheduleStart: Date?
    var scheduleEnd: Date?
    var scheduleDays: Set<Int>? // 1-7 for Monday-Sunday

    // Restart lock properties
    var restartLockCount: Int?
    var remainingRestarts: Int?

    // Breakable lock properties
    var breakDelay: TimeInterval?
    var breakCountdownStarted: Bool = false

    init(type: LockType) {
        self.type = type
        self.isLocked = false
        self.createdAt = Date()
    }

    mutating func lock() {
        isLocked = true
        createdAt = Date()
    }

    mutating func unlock() {
        isLocked = false
        type = .none
        unlockAt = Date()
    }

    var canUnlock: Bool {
        guard isLocked else { return true }

        switch type {
        case .none:
            return true
        case .timer:
            return isTimerExpired
        case .randomText:
            return textAttempts < maxAttempts
        case .schedule:
            return !isInSchedule
        case .restart:
            return (remainingRestarts ?? 0) <= 0
        case .breakable:
            return BreakableLockController.shared.isReadyToUnlock
        }
    }

    private var isTimerExpired: Bool {
        guard let unlockAt = unlockAt else { return false }
        return Date() >= unlockAt
    }

    private var isInSchedule: Bool {
        guard let start = scheduleStart,
              let end = scheduleEnd else {
            return false
        }

        let now = Date()
        let calendar = Calendar.current
        let currentWeekday = calendar.component(.weekday, from: now)

        // Check if today is in scheduled days
        if let days = scheduleDays, !days.contains(currentWeekday) {
            return false
        }

        return now >= start && now < end
    }
}

struct LockConfiguration: Codable {
    var allowedLockTypes: Set<LockType> = [.timer, .randomText, .schedule, .restart, .breakable]
    var minTimerDuration: TimeInterval = 60 // 1 minute
    var maxTimerDuration: TimeInterval = 86400 // 24 hours
    var randomTextLength: Int = 8
    var maxTextAttempts: Int = 5

    static let `default` = LockConfiguration()
}
