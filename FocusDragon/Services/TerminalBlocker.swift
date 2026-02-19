import Foundation
import AppKit

class TerminalBlocker {
    static let shared = TerminalBlocker()

    private let blockedTerminals: Set<String> = [
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "com.microsoft.VSCode", // VSCode integrated terminal
        "com.sublimetext.4",
        "com.jetbrains.intellij"
    ]

    private let blockedCommands: Set<String> = [
        "launchctl", // Control daemons
        "sudo",      // Root access
        "pkill",     // Kill processes
        "killall",   // Kill by name
        "defaults"   // Modify preferences
    ]

    private var isMonitoring = false
    private var timer: Timer?

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkForTerminals()
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        isMonitoring = false
    }

    private func checkForTerminals() {
        let runningApps = NSWorkspace.shared.runningApplications

        for app in runningApps {
            guard let bundleId = app.bundleIdentifier else { continue }

            if blockedTerminals.contains(bundleId) {
                terminateTerminal(app)
            }
        }
    }

    private func terminateTerminal(_ app: NSRunningApplication) {
        let name = app.localizedName ?? "Terminal"
        print("TerminalBlocker: Terminating \(name)")

        _ = app.forceTerminate()

        let pid = app.processIdentifier
        kill(pid, SIGKILL)

        NotificationHelper.shared.showTerminalBlocked()
    }

    func isCommandAllowed(_ command: String) -> Bool {
        let commandName = (command as NSString).lastPathComponent

        for blocked in blockedCommands {
            if commandName.contains(blocked) {
                return false
            }
        }

        return true
    }
}
