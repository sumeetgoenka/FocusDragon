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
    private var appExceptions: [AppException] = []
    private var whitelistOnlyApps: Set<String> = []
    private var terminationCount: [String: Int] = [:]
    private var respawnDetection: [String: Date] = [:]

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

    func updateApps(_ bundleIDs: [String],
                    isBlocking: Bool,
                    appExceptions: [AppException] = [],
                    whitelistOnlyApps: [String] = []) {
        // Filter out protected system apps
        let safeIDs = Set(bundleIDs).subtracting(protectedApps)

        self.blockedBundleIDs = safeIDs
        self.isBlocking = isBlocking
        self.appExceptions = appExceptions
        self.whitelistOnlyApps = Set(whitelistOnlyApps)

        let filteredCount = bundleIDs.count - safeIDs.count
        if filteredCount > 0 {
            log("Filtered \(filteredCount) protected system apps from block list", level: .warning)
        }

        log("Updated apps: \(safeIDs.count) blocked, blocking=\(isBlocking)", level: .info)
    }

    func getStatistics() -> [String: Int] {
        return terminationCount
    }

    func resetStatistics() {
        terminationCount.removeAll()
        log("Statistics reset", level: .info)
    }

    // MARK: - Private Methods

    private func scanProcesses() {
        guard isBlocking else { return }

        let runningApps = NSWorkspace.shared.runningApplications

        if !whitelistOnlyApps.isEmpty {
            enforceWhitelistOnly(runningApps: runningApps)
            return
        }

        guard !blockedBundleIDs.isEmpty else { return }

        let now = Date()
        let allowedExceptions = Set(appExceptions.filter { $0.isActive(on: now) }.map { $0.bundleIdentifier })

        for app in runningApps {
            guard let bundleID = app.bundleIdentifier else { continue }

            // Check if this app should be blocked
            if blockedBundleIDs.contains(bundleID), !allowedExceptions.contains(bundleID) {
                terminateApp(app, bundleID: bundleID)
            }
        }
    }

    private func enforceWhitelistOnly(runningApps: [NSRunningApplication]) {
        let allowed = whitelistOnlyApps.union(protectedApps).union([SharedConstants.appBundleIdentifier])

        for app in runningApps {
            guard let bundleID = app.bundleIdentifier else { continue }
            if allowed.contains(bundleID) { continue }
            if !isUserFacingApp(app) { continue }
            terminateApp(app, bundleID: bundleID)
        }
    }

    private func isUserFacingApp(_ app: NSRunningApplication) -> Bool {
        guard let bundleURL = app.bundleURL else { return false }
        let path = bundleURL.path
        if path.hasPrefix("/Applications/") || path.hasPrefix("/Users/") {
            return true
        }
        return false
    }

    private func terminateApp(_ app: NSRunningApplication, bundleID: String) {
        // Check for rapid respawning
        if let lastTermination = respawnDetection[bundleID],
           Date().timeIntervalSince(lastTermination) < 10 {
            let interval = Date().timeIntervalSince(lastTermination)
            log("WARNING: \(bundleID) is respawning rapidly (interval: \(String(format: "%.1f", interval))s)", level: .warning)
            handleRespawning(bundleID)
        }

        // Record this termination timestamp
        respawnDetection[bundleID] = Date()

        let appName = app.localizedName ?? bundleID
        log("Terminating blocked app: \(appName) (\(bundleID))", level: .info)

        // Increment termination count
        terminationCount[bundleID, default: 0] += 1

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

    private func handleRespawning(_ bundleID: String) {
        log("Checking for launch agents/daemons for \(bundleID)", level: .info)

        let possiblePaths = [
            "/Library/LaunchAgents/\(bundleID).plist",
            "/Library/LaunchDaemons/\(bundleID).plist",
            NSHomeDirectory() + "/Library/LaunchAgents/\(bundleID).plist"
        ]

        var foundAgent = false
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                log("Found launch agent/daemon at: \(path)", level: .warning)
                foundAgent = true
            }
        }

        if !foundAgent {
            log("No launch agents found for \(bundleID) - app may have built-in auto-restart", level: .info)
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
