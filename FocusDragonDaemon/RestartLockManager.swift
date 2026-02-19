import Foundation

/// Lightweight daemon-side restart lock manager.
/// Reads/writes restart lock state from the shared file-based persistence
/// so the daemon can enforce restart locks independently.
class RestartLockManager {
    static let shared = RestartLockManager()

    private let statePath = "/Library/Application Support/FocusDragon/restart_lock.json"

    struct RestartLockState: Codable {
        var isActive: Bool
        var requiredRestarts: Int
        var remainingRestarts: Int
        var lastBootTime: TimeInterval
        var createdAt: TimeInterval?

        // Computed to match app-side schema
        var completedRestarts: Int {
            return requiredRestarts - remainingRestarts
        }
    }

    private(set) var state: RestartLockState?

    var isActive: Bool {
        return state?.isActive ?? false
    }

    var canUnlock: Bool {
        guard let state = state, state.isActive else { return true }
        return state.remainingRestarts <= 0
    }

    var remainingRestarts: Int {
        return state?.remainingRestarts ?? 0
    }

    private init() {
        loadState()
    }

    func loadState() {
        guard FileManager.default.fileExists(atPath: statePath),
              let data = try? Data(contentsOf: URL(fileURLWithPath: statePath)),
              let decoded = try? JSONDecoder().decode(RestartLockState.self, from: data) else {
            state = nil
            return
        }
        state = decoded
    }

    func recordRestart() {
        guard var current = state, current.isActive else { return }

        // Detect if a reboot happened since the last recorded boot time
        var info = timeval()
        var size = MemoryLayout<timeval>.stride
        let mib: [Int32] = [CTL_KERN, KERN_BOOTTIME]
        guard sysctl(UnsafeMutablePointer(mutating: mib), 2, &info, &size, nil, 0) == 0 else { return }
        let currentBootTime = TimeInterval(info.tv_sec)

        // Only decrement if boot time changed (i.e. actual reboot)
        guard currentBootTime != current.lastBootTime else { return }

        current.remainingRestarts = max(0, current.remainingRestarts - 1)
        current.lastBootTime = currentBootTime

        if current.remainingRestarts <= 0 {
            current.isActive = false
        }

        state = current
        saveState()
    }

    private func saveState() {
        guard let state = state,
              let data = try? JSONEncoder().encode(state) else { return }
        try? data.write(to: URL(fileURLWithPath: statePath))
    }
}
