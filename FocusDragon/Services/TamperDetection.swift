import Foundation
import Combine

class TamperDetection: ObservableObject {
    static let shared = TamperDetection()

    @Published var isMonitoring = false
    @Published var protectionLevel: ProtectionLevel = .none
    @Published var tamperAttempts: Int = 0
    @Published var lastTamperDate: Date?

    private var cancellables = Set<AnyCancellable>()

    private init() {
        protectionLevel = ProtectionLevel.current
    }

    /// Start monitoring gated by the current protection level.
    func startMonitoring() {
        startMonitoring(level: ProtectionLevel.current)
    }

    func startMonitoring(level: ProtectionLevel) {
        // Stop any existing monitors first
        if isMonitoring {
            stopAllMonitors()
        }

        protectionLevel = level
        ProtectionLevel.current = level
        isMonitoring = true

        // Level 1+: daemon process protection
        if level.hasProcessProtection {
            ProcessProtection.shared.startMonitoring()
        }

        // Level 2+: block System Settings, Terminal, Activity Monitor + file monitoring
        if level.hasSystemSettingsBlocking {
            SystemSettingsBlocker.shared.startMonitoring()
        }
        if level.hasTerminalBlocking {
            TerminalBlocker.shared.startMonitoring()
        }
        if level.hasActivityMonitorBlocking {
            ActivityMonitorBlocker.shared.startMonitoring()
        }
        if level.hasFileSystemMonitoring {
            FileSystemMonitor.shared.startMonitoring()
        }

        print("TamperDetection: Monitors started at level \(level.displayName)")
    }

    func stopMonitoring() {
        stopAllMonitors()
        isMonitoring = false
        print("TamperDetection: All monitors stopped")
    }

    private func stopAllMonitors() {
        SystemSettingsBlocker.shared.stopMonitoring()
        TerminalBlocker.shared.stopMonitoring()
        ActivityMonitorBlocker.shared.stopMonitoring()
        FileSystemMonitor.shared.stopMonitoring()
        ProcessProtection.shared.stopMonitoring()
    }

    func recordTamperAttempt() {
        tamperAttempts += 1
        lastTamperDate = Date()

        saveStats()
    }

    private let statsKey = "tamperDetectionStats"

    private func saveStats() {
        let stats: [String: Any] = [
            "attempts": tamperAttempts,
            "lastDate": lastTamperDate?.timeIntervalSince1970 ?? 0
        ]

        UserDefaults.standard.set(stats, forKey: statsKey)
    }

    func loadStats() {
        guard let stats = UserDefaults.standard.dictionary(forKey: statsKey) else {
            return
        }

        tamperAttempts = stats["attempts"] as? Int ?? 0

        if let timestamp = stats["lastDate"] as? TimeInterval {
            lastTamperDate = Date(timeIntervalSince1970: timestamp)
        }
    }
}
