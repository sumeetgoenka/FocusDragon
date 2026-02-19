import Foundation
import AppKit

class SystemSettingsBlocker {
    static let shared = SystemSettingsBlocker()

    private let blockedSettings: Set<String> = [
        "com.apple.systempreferences", // System Settings
        "com.apple.preference.network", // Network settings
        "com.apple.preference.datetime", // Date & Time
        "com.apple.preference.security" // Security & Privacy
    ]

    private var isMonitoring = false
    private var timer: Timer?

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkForBlockedApps()
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        isMonitoring = false
    }

    private func checkForBlockedApps() {
        let runningApps = NSWorkspace.shared.runningApplications

        for app in runningApps {
            guard let bundleId = app.bundleIdentifier else { continue }

            if blockedSettings.contains(bundleId) {
                terminateApp(app, name: app.localizedName ?? bundleId)
            }
        }
    }

    private func terminateApp(_ app: NSRunningApplication, name: String) {
        print("SystemSettingsBlocker: Terminating \(name)")

        // Force terminate
        _ = app.forceTerminate()

        // Also kill via PID for good measure
        let pid = app.processIdentifier
        kill(pid, SIGKILL)

        NotificationHelper.shared.showSystemSettingsBlocked(appName: name)
    }
}
