import Foundation
import Combine

class RestartLockManager: ObservableObject {
    static let shared = RestartLockManager()

    @Published var isActive: Bool = false
    @Published var requiredRestarts: Int = 0
    @Published var remainingRestarts: Int = 0
    @Published var lastBootTime: Date?

    private let persistenceFile = "/Library/Application Support/FocusDragon/restart_lock.json"
    private var timer: Timer?

    struct State: Codable {
        let isActive: Bool
        let requiredRestarts: Int
        let remainingRestarts: Int
        let lastBootTime: TimeInterval
        let createdAt: TimeInterval
    }

    private init() {
        loadState()
        startMonitoring()
    }

    // MARK: - Activation

    func activate(requiredRestarts: Int) {
        guard requiredRestarts > 0, requiredRestarts <= 10 else {
            return
        }

        self.requiredRestarts = requiredRestarts
        self.remainingRestarts = requiredRestarts
        self.isActive = true
        self.lastBootTime = BootDetector.shared.getBootTime()

        saveState()
        NotificationHelper.shared.showRestartLockActivated(count: requiredRestarts)
    }

    func deactivate() {
        isActive = false
        requiredRestarts = 0
        remainingRestarts = 0
        lastBootTime = nil

        clearState()
        NotificationHelper.shared.showRestartLockDeactivated()
    }

    // MARK: - Monitoring

    private func startMonitoring() {
        // Check every 30 seconds for system restarts
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.checkForRestart()
        }

        // Check immediately
        checkForRestart()
    }

    private func checkForRestart() {
        guard isActive, let lastBoot = lastBootTime else {
            return
        }

        if BootDetector.shared.didRebootSince(lastBoot) {
            // System was restarted!
            handleRestart()
        }
    }

    private func handleRestart() {
        remainingRestarts = max(0, remainingRestarts - 1)
        lastBootTime = BootDetector.shared.getBootTime()

        saveState()

        if remainingRestarts == 0 {
            // All restarts completed - unlock
            NotificationHelper.shared.showRestartLockCompleted()
            deactivate()
        } else {
            NotificationHelper.shared.showRestartDetected(remaining: remainingRestarts)
        }
    }

    var canUnlock: Bool {
        return !isActive || remainingRestarts <= 0
    }

    // MARK: - Persistence

    private func saveState() {
        let state = State(
            isActive: isActive,
            requiredRestarts: requiredRestarts,
            remainingRestarts: remainingRestarts,
            lastBootTime: lastBootTime?.timeIntervalSince1970 ?? Date().timeIntervalSince1970,
            createdAt: Date().timeIntervalSince1970
        )

        do {
            let data = try JSONEncoder().encode(state)

            // Create directory if needed
            let dir = (persistenceFile as NSString).deletingLastPathComponent
            try FileManager.default.createDirectory(
                atPath: dir,
                withIntermediateDirectories: true
            )

            try data.write(to: URL(fileURLWithPath: persistenceFile))
        } catch {
            print("RestartLockManager: Failed to save state: \(error)")
        }
    }

    private func loadState() {
        guard FileManager.default.fileExists(atPath: persistenceFile) else {
            return
        }

        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: persistenceFile))
            let state = try JSONDecoder().decode(State.self, from: data)

            isActive = state.isActive
            requiredRestarts = state.requiredRestarts
            remainingRestarts = state.remainingRestarts
            lastBootTime = Date(timeIntervalSince1970: state.lastBootTime)
        } catch {
            print("RestartLockManager: Failed to load state: \(error)")
        }
    }

    private func clearState() {
        try? FileManager.default.removeItem(atPath: persistenceFile)
    }
}
