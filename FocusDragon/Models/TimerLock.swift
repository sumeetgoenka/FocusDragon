import Foundation
import Combine

class TimerLockController: ObservableObject {
    @Published var isActive: Bool = false
    @Published var remainingTime: TimeInterval = 0
    @Published var progress: Double = 0.0

    private var startTime: Date?
    private var duration: TimeInterval = 0
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()

    func start(duration: TimeInterval) {
        self.duration = duration
        self.startTime = Date()
        self.remainingTime = duration
        self.isActive = true
        self.progress = 1.0

        saveState()
        startTimer()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        isActive = false
        remainingTime = 0
        progress = 0
        clearState()
    }

    func resume() {
        guard let startTime = startTime else { return }

        let elapsed = Date().timeIntervalSince(startTime)
        remainingTime = max(0, duration - elapsed)

        if remainingTime > 0 {
            isActive = true
            startTimer()
        } else {
            // Timer already expired
            stop()
        }
    }

    private func startTimer() {
        timer?.invalidate()

        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateTimer()
        }

        RunLoop.main.add(timer!, forMode: .common)
    }

    private func updateTimer() {
        guard let startTime = startTime else {
            stop()
            return
        }

        let elapsed = Date().timeIntervalSince(startTime)
        remainingTime = max(0, duration - elapsed)
        progress = remainingTime / duration

        if remainingTime <= 0 {
            timerExpired()
        }

        saveState()
    }

    private func timerExpired() {
        stop()
        NotificationHelper.shared.showTimerExpired()
    }

    // MARK: - Persistence

    private let stateKey = "timerLockState"

    private func saveState() {
        let state: [String: Any] = [
            "isActive": isActive,
            "startTime": startTime?.timeIntervalSince1970 ?? 0,
            "duration": duration,
            "remainingTime": remainingTime
        ]

        UserDefaults.standard.set(state, forKey: stateKey)
    }

    func loadState() {
        guard let state = UserDefaults.standard.dictionary(forKey: stateKey) else {
            return
        }

        if let active = state["isActive"] as? Bool, active,
           let start = state["startTime"] as? TimeInterval,
           let dur = state["duration"] as? TimeInterval {
            startTime = Date(timeIntervalSince1970: start)
            duration = dur
            resume()
        }
    }

    private func clearState() {
        UserDefaults.standard.removeObject(forKey: stateKey)
    }

    var formattedTime: String {
        let hours = Int(remainingTime) / 3600
        let minutes = (Int(remainingTime) % 3600) / 60
        let seconds = Int(remainingTime) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    var isExpired: Bool {
        return remainingTime <= 0 && isActive == false
    }
}
