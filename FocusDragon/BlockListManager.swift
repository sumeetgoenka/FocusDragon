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
    @Published var requireBrowserExtension: Bool = true {
        didSet {
            UserDefaults.standard.set(requireBrowserExtension, forKey: requireExtensionKey)
            saveState()
        }
    }
    @Published var urlExceptions: [URLException] = [] {
        didSet { saveState() }
    }
    @Published var appExceptions: [AppException] = [] {
        didSet { saveState() }
    }
    @Published var internetBlockConfig: InternetBlockConfig = InternetBlockConfig() {
        didSet { saveState() }
    }
    @Published var frozenState: FrozenState? {
        didSet { saveState() }
    }
    @Published var stats = BlockStats()

    private let userDefaults = UserDefaults.standard
    private let blockedItemsKey = "blockedItems"
    private let isBlockingKey = "isBlocking"
    private let statsKey = "blockStats"
    private let requireExtensionKey = "requireBrowserExtension"
    private let urlExceptionsKey = "urlExceptions"
    private let appExceptionsKey = "appExceptions"
    private let internetBlockKey = "internetBlockConfig"
    private let frozenStateKey = "frozenState"
    private let sharedBlockedDomainsKey = "blockedDomains"
    private let sharedIsBlockingKey = "isBlocking"
    private let sharedUrlExceptionsKey = "urlExceptions"

    init() {
        loadState()

        NotificationCenter.default.addObserver(
            forName: Notification.Name("FocusDragonLockStateChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.writeDaemonConfig()
        }
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
        let domains = blockedItems
            .filter { $0.type == .website && $0.isEnabled }
            .compactMap { $0.domain }
        let apps = blockedItems
            .filter { $0.type == .application && $0.isEnabled }
            .compactMap { $0.appName ?? $0.bundleIdentifier }
        StatisticsManager.shared.startSession(
            domains: domains,
            apps: apps,
            lockType: LockManager.shared.currentLock.type
        )
        saveState()
    }

    func endBlockingSession() {
        StatisticsManager.shared.endSession()
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

        if let encoded = try? JSONEncoder().encode(urlExceptions) {
            userDefaults.set(encoded, forKey: urlExceptionsKey)
        }

        if let encoded = try? JSONEncoder().encode(appExceptions) {
            userDefaults.set(encoded, forKey: appExceptionsKey)
        }

        if let encoded = try? JSONEncoder().encode(internetBlockConfig) {
            userDefaults.set(encoded, forKey: internetBlockKey)
        }

        if let encoded = try? JSONEncoder().encode(frozenState) {
            userDefaults.set(encoded, forKey: frozenStateKey)
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
        var frozenStateToSend: FrozenState? = frozenState

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
            if lock.type == .frozen {
                timerExpiry = lock.unlockAt
                if let mode = lock.frozenMode {
                    frozenStateToSend = FrozenState(
                        isActive: true,
                        mode: mode,
                        startedAt: lock.createdAt,
                        expiresAt: lock.unlockAt,
                        allowedAppBundleIDs: lock.frozenAllowedApps ?? []
                    )
                }
            }
        }

        let config = DaemonConfig(
            isBlocking: isBlocking,
            lastModified: Date(),
            blockedDomains: enabledDomains,
            blockedApps: enabledApps,
            urlExceptions: urlExceptions,
            appExceptions: appExceptions,
            internetBlockConfig: internetBlockConfig,
            frozenState: frozenStateToSend,
            lockState: sharedLockState,
            timerLockExpiry: timerExpiry,
            requireBrowserExtension: requireBrowserExtension
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

        writeSharedExtensionState(domains: enabledDomains, isBlocking: isBlocking, urlExceptions: urlExceptions)
    }

    private func writeSharedExtensionState(domains: [String], isBlocking: Bool, urlExceptions: [URLException]) {
        guard let sharedDefaults = UserDefaults(suiteName: SharedConstants.appGroupIdentifier) else {
            return
        }

        sharedDefaults.set(domains, forKey: sharedBlockedDomainsKey)
        sharedDefaults.set(isBlocking, forKey: sharedIsBlockingKey)
        if let encoded = try? JSONEncoder().encode(urlExceptions) {
            sharedDefaults.set(encoded, forKey: sharedUrlExceptionsKey)
        }
    }

    private func loadState() {
        if let data = userDefaults.data(forKey: blockedItemsKey),
           let decoded = try? JSONDecoder().decode([BlockItem].self, from: data) {
            blockedItems = decoded
        }
        isBlocking = userDefaults.bool(forKey: isBlockingKey)
        let storedRequireExtension = userDefaults.object(forKey: requireExtensionKey) as? Bool
        requireBrowserExtension = storedRequireExtension ?? true
        if requireBrowserExtension == false {
            requireBrowserExtension = true
        }

        if let data = userDefaults.data(forKey: statsKey),
           let decoded = try? JSONDecoder().decode(BlockStats.self, from: data) {
            stats = decoded
        }

        if let data = userDefaults.data(forKey: urlExceptionsKey),
           let decoded = try? JSONDecoder().decode([URLException].self, from: data) {
            urlExceptions = decoded
        }

        if let data = userDefaults.data(forKey: appExceptionsKey),
           let decoded = try? JSONDecoder().decode([AppException].self, from: data) {
            appExceptions = decoded
        }

        if let data = userDefaults.data(forKey: internetBlockKey),
           let decoded = try? JSONDecoder().decode(InternetBlockConfig.self, from: data) {
            internetBlockConfig = decoded
        }

        if let data = userDefaults.data(forKey: frozenStateKey),
           let decoded = try? JSONDecoder().decode(FrozenState.self, from: data) {
            frozenState = decoded
        }
    }

    func effectiveWhitelistAppsForEnforcement() -> [String] {
        var whitelist = Set<String>()

        if let frozen = frozenState,
           frozen.isActive,
           frozen.mode == .limitedAccess {
            whitelist.formUnion(frozen.allowedAppBundleIDs)
        }

        if internetBlockConfig.isEnabled {
            whitelist.formUnion(internetBlockConfig.whitelistApps)
        }

        return Array(whitelist)
    }
}
