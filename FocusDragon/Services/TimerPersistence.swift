import Foundation

class TimerPersistence {
    static let shared = TimerPersistence()

    private let timerFile = "/Library/Application Support/FocusDragon/timer_lock.json"

    struct TimerState: Codable {
        let startTime: Date
        let duration: TimeInterval
        let isActive: Bool
    }

    func save(startTime: Date, duration: TimeInterval) {
        let state = TimerState(
            startTime: startTime,
            duration: duration,
            isActive: true
        )

        guard let data = try? JSONEncoder().encode(state) else { return }

        try? FileManager.default.createDirectory(
            atPath: (timerFile as NSString).deletingLastPathComponent,
            withIntermediateDirectories: true
        )

        try? data.write(to: URL(fileURLWithPath: timerFile))
    }

    func load() -> TimerState? {
        guard FileManager.default.fileExists(atPath: timerFile),
              let data = try? Data(contentsOf: URL(fileURLWithPath: timerFile)),
              let state = try? JSONDecoder().decode(TimerState.self, from: data) else {
            return nil
        }

        return state
    }

    func clear() {
        try? FileManager.default.removeItem(atPath: timerFile)
    }

    func getRemainingTime() -> TimeInterval? {
        guard let state = load() else { return nil }

        let elapsed = Date().timeIntervalSince(state.startTime)
        let remaining = state.duration - elapsed

        return remaining > 0 ? remaining : nil
    }
}
