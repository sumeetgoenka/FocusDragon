import Foundation
import Combine

class PomodoroTimer: ObservableObject {
    @Published var isRunning = false
    @Published var isWorkSession = true
    @Published var remainingTime: TimeInterval = 1500 // 25 minutes

    private var timer: Timer?

    let workDuration: TimeInterval = 1500 // 25 min
    let shortBreakDuration: TimeInterval = 300 // 5 min
    let longBreakDuration: TimeInterval = 900 // 15 min

    @Published var sessionsCompleted = 0

    /// Callback invoked when blocking state should change (true = start, false = stop)
    var onBlockingStateChange: ((Bool) -> Void)?

    func start() {
        isRunning = true

        if isWorkSession {
            onBlockingStateChange?(true)
        }

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func pause() {
        isRunning = false
        timer?.invalidate()
    }

    func reset() {
        pause()
        remainingTime = workDuration
        isWorkSession = true
    }

    private func tick() {
        remainingTime -= 1

        if remainingTime <= 0 {
            completeSession()
        }
    }

    private func completeSession() {
        timer?.invalidate()
        isRunning = false

        if isWorkSession {
            sessionsCompleted += 1

            // Stop blocking
            onBlockingStateChange?(false)

            // Start break
            isWorkSession = false
            remainingTime = (sessionsCompleted % 4 == 0) ? longBreakDuration : shortBreakDuration

            NotificationHelper.shared.showPomodoroBreak()
        } else {
            // Start work session
            isWorkSession = true
            remainingTime = workDuration

            NotificationHelper.shared.showPomodoroWork()
        }
    }
}
