//
//  ProcessMonitor.swift
//  FocusDragon
//
//  Created by Claude Code on 18/02/2026.
//

import Foundation
import AppKit
import Combine

class ProcessMonitor: ObservableObject {
    static let shared = ProcessMonitor()

    private var timer: Timer?
    private var blockedBundleIDs: Set<String> = []
    private var appExceptions: [AppException] = []
    private var whitelistOnlyApps: Set<String> = []
    @Published var isMonitoring = false
    @Published var terminationCount = 0

    // Apps that should NEVER be terminated (safety)
    private let systemProtectedApps: Set<String> = [
        "com.apple.finder",
        "com.apple.systemuiserver",
        "com.apple.dock",
        "com.apple.loginwindow",
        "com.apple.WindowManager"
    ]

    private init() {}

    func startMonitoring(blockedApps: [BlockItem],
                         appExceptions: [AppException] = [],
                         whitelistOnlyApps: [String] = []) {
        stopMonitoring()

        // Extract bundle IDs
        blockedBundleIDs = Set(blockedApps
            .filter { $0.type == .application && $0.isEnabled }
            .compactMap { $0.bundleIdentifier })

        // Remove any system protected apps
        blockedBundleIDs.subtract(systemProtectedApps)
        self.appExceptions = appExceptions
        self.whitelistOnlyApps = Set(whitelistOnlyApps)

        if !whitelistOnlyApps.isEmpty {
            isMonitoring = true
            startTimer()
            print("ProcessMonitor: Started monitoring whitelist-only mode (\(whitelistOnlyApps.count) apps)")
            return
        }

        guard !blockedBundleIDs.isEmpty else { return }

        isMonitoring = true
        startTimer()

        print("ProcessMonitor: Started monitoring \(blockedBundleIDs.count) apps")
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        isMonitoring = false
        blockedBundleIDs.removeAll()
        appExceptions = []
        whitelistOnlyApps = []
        print("ProcessMonitor: Stopped monitoring")
    }

    private func checkRunningProcesses() {
        let runningApps = NSWorkspace.shared.runningApplications

        if !whitelistOnlyApps.isEmpty {
            enforceWhitelistOnly(runningApps: runningApps)
            return
        }

        let now = Date()
        let allowedExceptions = Set(appExceptions.filter { $0.isActive(on: now) }.map { $0.bundleIdentifier })

        for app in runningApps {
            guard let bundleId = app.bundleIdentifier else { continue }

            if blockedBundleIDs.contains(bundleId), !allowedExceptions.contains(bundleId) {
                terminateApplication(app)
            }
        }
    }

    private func enforceWhitelistOnly(runningApps: [NSRunningApplication]) {
        let allowed = whitelistOnlyApps.union(systemProtectedApps).union([SharedConstants.appBundleIdentifier])

        for app in runningApps {
            guard let bundleId = app.bundleIdentifier else { continue }
            if allowed.contains(bundleId) { continue }
            if !isUserFacingApp(app) { continue }
            terminateApplication(app)
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

    private func startTimer() {
        timer = Timer.scheduledTimer(
            withTimeInterval: 1.5,
            repeats: true
        ) { [weak self] _ in
            self?.checkRunningProcesses()
        }

        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func terminateApplication(_ app: NSRunningApplication) {
        let appName = app.localizedName ?? "Unknown"
        print("ProcessMonitor: Terminating \(appName) (\(app.bundleIdentifier ?? ""))")

        // Try graceful termination first
        let terminated = app.terminate()

        // If graceful fails, force kill after 2 seconds
        if !terminated {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                if !app.isTerminated {
                    let pid = app.processIdentifier
                    kill(pid, SIGKILL)
                    print("ProcessMonitor: Force killed PID \(pid)")
                }
            }
        }

        terminationCount += 1

        // Send notification
        NotificationHelper.shared.showBlockedAppNotification(appName: appName)
    }

    func updateBlockedApps(_ apps: [BlockItem],
                           appExceptions: [AppException] = [],
                           whitelistOnlyApps: [String] = []) {
        if isMonitoring {
            // Restart with new list
            startMonitoring(blockedApps: apps,
                            appExceptions: appExceptions,
                            whitelistOnlyApps: whitelistOnlyApps)
        }
    }
}
