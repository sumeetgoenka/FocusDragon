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

    func startMonitoring(blockedApps: [BlockItem]) {
        stopMonitoring()

        // Extract bundle IDs
        blockedBundleIDs = Set(blockedApps
            .filter { $0.type == .application && $0.isEnabled }
            .compactMap { $0.bundleIdentifier })

        // Remove any system protected apps
        blockedBundleIDs.subtract(systemProtectedApps)

        guard !blockedBundleIDs.isEmpty else { return }

        isMonitoring = true

        // Start timer
        timer = Timer.scheduledTimer(
            withTimeInterval: 1.5,
            repeats: true
        ) { [weak self] _ in
            self?.checkRunningProcesses()
        }

        // Add to run loop to ensure it fires
        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
        }

        print("ProcessMonitor: Started monitoring \(blockedBundleIDs.count) apps")
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        isMonitoring = false
        blockedBundleIDs.removeAll()
        print("ProcessMonitor: Stopped monitoring")
    }

    private func checkRunningProcesses() {
        let runningApps = NSWorkspace.shared.runningApplications

        for app in runningApps {
            guard let bundleId = app.bundleIdentifier else { continue }

            if blockedBundleIDs.contains(bundleId) {
                terminateApplication(app)
            }
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

    func updateBlockedApps(_ apps: [BlockItem]) {
        if isMonitoring {
            // Restart with new list
            startMonitoring(blockedApps: apps)
        }
    }
}
