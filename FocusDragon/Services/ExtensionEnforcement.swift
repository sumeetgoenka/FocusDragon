//
//  ExtensionEnforcement.swift
//  FocusDragon
//
//  Takes corrective action when a browser extension is disabled or
//  becomes unresponsive during an active blocking session. Falls back
//  to hosts-file blocking and warns the user.
//

import Foundation
import AppKit

class ExtensionEnforcement {
    static let shared = ExtensionEnforcement()

    private let configPath = "/Library/Application Support/FocusDragon/config.json"

    private init() {}

    // MARK: - Public

    /// Called by ExtensionMonitor when an extension transitions to inactive.
    func handleExtensionDisabled(browser: String) {
        // Notify user
        NotificationHelper.shared.showExtensionDisabled(browser: browser)

        // Record tamper attempt
        TamperDetection.shared.recordTamperAttempt()

        // If a lock is active, escalate with a modal warning
        if LockManager.shared.currentLock.isLocked {
            showCriticalWarning(browser: browser)
        }

        // Ensure hosts-file blocking is in place as a fallback
        activateHostsFileBackup()
    }

    // MARK: - Private

    private func showCriticalWarning(browser: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Extension Disabled"
            alert.informativeText = """
            The FocusDragon \(browser) extension was disabled.

            Block is still active via other methods.

            Please re-enable the extension for the best experience.
            """
            alert.alertStyle = .critical
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    private func activateHostsFileBackup() {
        // Read blocked domains from the shared daemon config file rather
        // than going through the @MainActor BlockListManager directly.
        let domains = readBlockedDomainsFromConfig()
        guard !domains.isEmpty else { return }

        DispatchQueue.main.async {
            do {
                try HostsFileManager.shared.applyBlock(domains: domains)
                print("ExtensionEnforcement: hosts-file backup activated for \(domains.count) domains")
            } catch {
                print("ExtensionEnforcement: failed to activate hosts-file backup – \(error)")
            }
        }
    }

    /// Reads blocked domains straight from the daemon config JSON on disk.
    private func readBlockedDomainsFromConfig() -> [String] {
        guard let data = FileManager.default.contents(atPath: configPath) else {
            return []
        }

        let decoder = JSONDecoder()
        guard let config = try? decoder.decode(DaemonConfig.self, from: data) else {
            return []
        }

        guard config.isBlocking else { return [] }
        let exceptionDomains = Set(config.urlExceptions.map { $0.domain.lowercased() })
        return config.blockedDomains.filter { !exceptionDomains.contains($0.lowercased()) }
    }
}
