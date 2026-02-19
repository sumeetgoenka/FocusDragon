import Foundation
import AppKit

class ActivityMonitorBlocker {
    static let shared = ActivityMonitorBlocker()

    private let activityMonitorBundleId = "com.apple.ActivityMonitor"
    private var isMonitoring = false
    private var timer: Timer?

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkForActivityMonitor()
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        isMonitoring = false
    }

    private func checkForActivityMonitor() {
        let runningApps = NSWorkspace.shared.runningApplications

        for app in runningApps {
            guard let bundleId = app.bundleIdentifier else { continue }

            if bundleId == activityMonitorBundleId {
                terminateActivityMonitor(app)
            }
        }
    }

    private func terminateActivityMonitor(_ app: NSRunningApplication) {
        print("ActivityMonitorBlocker: Terminating Activity Monitor")

        _ = app.forceTerminate()

        let pid = app.processIdentifier
        kill(pid, SIGKILL)

        NotificationHelper.shared.showActivityMonitorBlocked()
    }
}
