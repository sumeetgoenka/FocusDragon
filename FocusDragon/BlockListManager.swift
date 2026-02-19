//
//  BlockListManager.swift
//  FocusDragon
//
//  Created by Anay Goenka on 17/02/2026.
//

import Foundation
import Combine
import SwiftUI

@MainActor
class BlockListManager: ObservableObject {
    @Published var blockedItems: [BlockItem] = [] {
        didSet {
            saveState()
        }
    }
    @Published var isBlocking: Bool = false {
        didSet {
            saveState()
        }
    }
    @Published var stats = BlockStats()

    private let userDefaults = UserDefaults.standard
    private let blockedItemsKey = "blockedItems"
    private let isBlockingKey = "isBlocking"
    private let statsKey = "blockStats"

    init() {
        loadState()
    }

    func addDomain(_ domain: String) {
        print("📝 BlockListManager.addDomain called with: '\(domain)'")
        // Clean the domain using the cleanDomain extension
        let cleaned = domain.cleanDomain

        // Validate domain format
        guard cleaned.isValidDomain else {
            print("📝 Invalid domain format: \(domain)")
            return
        }

        // Check if already exists
        guard !blockedItems.contains(where: { $0.domain == cleaned }) else {
            print("📝 Domain already exists: \(cleaned)")
            return
        }

        let item = BlockItem(domain: cleaned)
        blockedItems.append(item)
        print("📝 Domain added to blockedItems. New count: \(blockedItems.count)")
    }

    func removeDomain(at offsets: IndexSet) {
        blockedItems.remove(atOffsets: offsets)
    }

    func toggleDomain(id: UUID) {
        if let index = blockedItems.firstIndex(where: { $0.id == id }) {
            blockedItems[index].isEnabled.toggle()
            // Manually trigger save since we're modifying array element
            saveState()
        }
    }

    func addApplication(_ app: BlockItem) {
        guard app.type == .application else { return }

        // Check for duplicates
        if blockedItems.contains(where: {
            $0.type == .application && $0.bundleIdentifier == app.bundleIdentifier
        }) {
            return
        }

        blockedItems.append(app)
    }

    func getWebsites() -> [BlockItem] {
        blockedItems.filter { $0.type == .website }
    }

    func getApplications() -> [BlockItem] {
        blockedItems.filter { $0.type == .application }
    }

    func startBlockingSession() {
        stats.startSession()
        saveState()
    }

    private func saveState() {
        if let encoded = try? JSONEncoder().encode(blockedItems) {
            userDefaults.set(encoded, forKey: blockedItemsKey)
        }
        userDefaults.set(isBlocking, forKey: isBlockingKey)

        if let encoded = try? JSONEncoder().encode(stats) {
            userDefaults.set(encoded, forKey: statsKey)
        }

        writeDaemonConfig()
    }

    /// Public entry point to re-sync config.json without changing any state.
    /// Call this on app launch so the daemon immediately reflects the saved state.
    func syncWithDaemon() {
        writeDaemonConfig()
    }

    /// Writes the current block state to the shared config file that the daemon reads.
    private func writeDaemonConfig() {
        let configPath = "/Library/Application Support/FocusDragon/config.json"

        let enabledDomains = blockedItems
            .filter { $0.type == .website && $0.isEnabled }
            .compactMap { $0.domain }

        let enabledApps = blockedItems
            .filter { $0.type == .application && $0.isEnabled }
            .compactMap { item -> DaemonConfig.BlockedApp? in
                guard let bundleId = item.bundleIdentifier, let name = item.appName else { return nil }
                return DaemonConfig.BlockedApp(bundleIdentifier: bundleId, appName: name)
            }

        // Populate lock state for daemon enforcement
        let lockManager = LockManager.shared
        let lock = lockManager.currentLock
        var sharedLockState: SharedLockState?
        var timerExpiry: Date?

        if lock.isLocked {
            sharedLockState = SharedLockState(
                isLocked: true,
                lockType: lock.type.rawValue,
                expiresAt: lock.unlockAt,
                randomText: lock.randomText,
                requireRestart: lock.type == .restart
            )
            if lock.type == .timer {
                timerExpiry = lock.unlockAt
            }
        }

        let config = DaemonConfig(
            isBlocking: isBlocking,
            lastModified: Date(),
            blockedDomains: enabledDomains,
            blockedApps: enabledApps,
            lockState: sharedLockState,
            timerLockExpiry: timerExpiry
        )

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(config)
            try data.write(to: URL(fileURLWithPath: configPath), options: .atomic)
        } catch {
            // Silently fail if directory isn't writable yet (before daemon setup completes).
            print("⚠️ writeDaemonConfig failed (run daemon setup to fix): \(error.localizedDescription)")
        }
    }

    private func loadState() {
        if let data = userDefaults.data(forKey: blockedItemsKey),
           let decoded = try? JSONDecoder().decode([BlockItem].self, from: data) {
            blockedItems = decoded
        }
        isBlocking = userDefaults.bool(forKey: isBlockingKey)

        if let data = userDefaults.data(forKey: statsKey),
           let decoded = try? JSONDecoder().decode(BlockStats.self, from: data) {
            stats = decoded
        }
    }
}
