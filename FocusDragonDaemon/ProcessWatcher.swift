//
//  ProcessWatcher.swift
//  FocusDragonDaemon
//
//  Created by Claude on 18/02/2026.
//

import Foundation
import AppKit

/// Monitors running processes and terminates blocked applications
class ProcessWatcher {
    // MARK: - Configuration

    private let checkInterval: TimeInterval = 1.5
    private let terminationGracePeriod: TimeInterval = 2.0

    // System apps that should never be terminated
    private let protectedApps: Set<String> = [
        "com.apple.finder",
        "com.apple.systemuiserver",
        "com.apple.dock",
        "com.apple.loginwindow",
        "com.apple.WindowManager",
        "com.apple.systempreferences",
        "com.apple.ActivityMonitor"
    ]

    // MARK: - State

    private var timer: Timer?
    private var blockedBundleIDs: Set<String> = []
    private var isBlocking = false

    // MARK: - Public Methods

    func start() {
        guard timer == nil else { return }

        timer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            self?.scanProcesses()
        }
        RunLoop.main.add(timer!, forMode: .common)

        log("ProcessWatcher started (interval: \(checkInterval)s)", level: .info)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        log("ProcessWatcher stopped", level: .info)
    }

    func updateApps(_ bundleIDs: [String], isBlocking: Bool) {
        // Filter out protected system apps
        let safeIDs = Set(bundleIDs).subtracting(protectedApps)

        self.blockedBundleIDs = safeIDs
        self.isBlocking = isBlocking

        let filteredCount = bundleIDs.count - safeIDs.count
        if filteredCount > 0 {
            log("Filtered \(filteredCount) protected system apps from block list", level: .warning)
        }

        log("Updated apps: \(safeIDs.count) blocked, blocking=\(isBlocking)", level: .info)
    }

    // MARK: - Private Methods

    private func scanProcesses() {
        guard isBlocking && !blockedBundleIDs.isEmpty else { return }

        let runningApps = NSWorkspace.shared.runningApplications

        for app in runningApps {
            guard let bundleID = app.bundleIdentifier else { continue }

            // Check if this app should be blocked
            if blockedBundleIDs.contains(bundleID) {
                terminateApp(app, bundleID: bundleID)
            }
        }
    }

    private func terminateApp(_ app: NSRunningApplication, bundleID: String) {
        let appName = app.localizedName ?? bundleID
        log("Terminating blocked app: \(appName) (\(bundleID))", level: .info)

        // Try graceful termination first
        let terminated = app.terminate()

        if !terminated {
            // If graceful termination fails, force kill after grace period
            DispatchQueue.main.asyncAfter(deadline: .now() + terminationGracePeriod) { [weak self] in
                if !app.isTerminated {
                    let pid = app.processIdentifier
                    self?.forceKillProcess(pid: pid, bundleID: bundleID)
                }
            }
        }
    }

    private func forceKillProcess(pid: pid_t, bundleID: String) {
        log("Force killing process (PID: \(pid), Bundle: \(bundleID))", level: .warning)

        let result = kill(pid, SIGKILL)
        if result == 0 {
            log("Successfully force-killed PID \(pid)", level: .info)
        } else {
            log("Failed to force-kill PID \(pid): error \(result)", level: .error)
        }
    }

    private func log(_ message: String, level: LogLevel = .info) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        print("[\(timestamp)] [\(level.rawValue)] [PROCESS] \(message)")
    }

    private enum LogLevel: String {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARN"
        case error = "ERROR"
    }
}
