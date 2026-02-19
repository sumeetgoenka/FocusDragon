import Foundation

class ProcessProtection {
    static let shared = ProcessProtection()

    private let protectedProcesses: Set<String> = [
        "FocusDragonDaemon",
        "focusdragon_daemon"
    ]

    private var timer: Timer?

    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkProtectedProcesses()
        }

        // Check immediately
        checkProtectedProcesses()
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func checkProtectedProcesses() {
        // Check if daemon is running
        let isDaemonRunning = checkProcess("FocusDragonDaemon")

        if !isDaemonRunning {
            print("ProcessProtection: Daemon not running, attempting restart")
            restartDaemon()
        }
    }

    private func checkProcess(_ name: String) -> Bool {
        let task = Process()
        task.launchPath = "/bin/ps"
        task.arguments = ["-ax"]

        let pipe = Pipe()
        task.standardOutput = pipe

        try? task.run()
        task.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        return output.contains(name)
    }

    private func restartDaemon() {
        let task = Process()
        task.launchPath = "/bin/launchctl"
        task.arguments = ["start", "com.focusdragon.daemon"]

        try? task.run()

        NotificationHelper.shared.showDaemonRestarted()
    }
}
