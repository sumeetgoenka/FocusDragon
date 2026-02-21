//
//  DaemonService.swift
//  FocusDragonDaemon
//
//  Created by Claude on 18/02/2026.
//

import Foundation

/// Core daemon service that orchestrates all blocking and monitoring
class DaemonService {
    // MARK: - Configuration

    private let configPath = "/Library/Application Support/FocusDragon/config.json"
    private let logPath = "/var/log/focusdragon/daemon.log"
    private let configPollInterval: TimeInterval = 2.0

    // MARK: - Components

    private var hostsWatcher: HostsWatcher?
    private var processWatcher: ProcessWatcher?
    private var browserEnforcer: BrowserExtensionEnforcer?
    private var internetBlocker: InternetBlocker?
    private var frozenEnforcer: FrozenModeEnforcer?
    private var configTimer: Timer?
    private var restartLockManager: RestartLockManager?

    // MARK: - State

    private var currentConfig: DaemonConfig?
    private var isRunning = false
    private var lastConfigModTime: Date?
    private var lastLockStateModTime: Date?

    // MARK: - Initialization

    init() {
        setupLogging()
    }

    // MARK: - Public Methods

    func start() {
        guard !isRunning else {
            log("Daemon already running", level: .warning)
            return
        }
        isRunning = true

        log("Daemon started", level: .info)

        // Create necessary directories
        createDirectories()

        // Load initial configuration
        loadConfiguration()

        // Initialize restart lock manager
        restartLockManager = RestartLockManager.shared

        // Record this boot for restart lock tracking
        restartLockManager?.recordRestart()

        // Check if restart lock is active
        if restartLockManager?.isActive == true,
           restartLockManager?.canUnlock == false {
            log("Restart lock active: \(restartLockManager?.remainingRestarts ?? 0) restarts remaining", level: .info)
            enforceRestartLock()
        }

        // Start watchers
        startWatchers()

        // Poll for configuration changes
        startConfigurationPolling()

        log("All services started successfully", level: .info)
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false

        log("Stopping daemon...", level: .info)

        // Stop watchers
        stopWatchers()

        // Stop configuration polling
        configTimer?.invalidate()
        configTimer = nil

        log("Daemon stopped", level: .info)
    }

    func reloadConfiguration() {
        log("Reloading configuration on SIGHUP", level: .info)
        loadConfiguration()
    }

    // MARK: - Configuration Management

    private func loadConfiguration() {
        let configURL = URL(fileURLWithPath: configPath)

        // Check if config file exists
        guard FileManager.default.fileExists(atPath: configPath) else {
            log("No configuration file found at \(configPath), using defaults", level: .warning)
            currentConfig = DaemonConfig()
            updateWatchers()
            return
        }

        // Load and parse configuration
        do {
            let data = try Data(contentsOf: configURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let config = try decoder.decode(DaemonConfig.self, from: data)

            // Update modification time
            if let attrs = try? FileManager.default.attributesOfItem(atPath: configPath),
               let modTime = attrs[.modificationDate] as? Date {
                lastConfigModTime = modTime
            }

            currentConfig = config
            log("Configuration loaded: \(config.blockedDomains.count) domains, \(config.blockedApps.count) apps, blocking=\(config.isBlocking)", level: .info)

            // Update watchers with new config
            updateWatchers()
        } catch {
            log("Failed to load configuration: \(error.localizedDescription)", level: .error)
            // Keep using previous config if available
            if currentConfig == nil {
                currentConfig = DaemonConfig()
                updateWatchers()
            }
        }
    }

    private func startConfigurationPolling() {
        configTimer = Timer.scheduledTimer(withTimeInterval: configPollInterval, repeats: true) { [weak self] _ in
            self?.checkForConfigChanges()
        }
        RunLoop.main.add(configTimer!, forMode: .common)
        log("Configuration polling started (interval: \(configPollInterval)s)", level: .info)
    }

    private func checkForConfigChanges() {
        // Check config.json
        if let attrs = try? FileManager.default.attributesOfItem(atPath: configPath),
           let modTime = attrs[.modificationDate] as? Date {

            if let lastMod = lastConfigModTime, modTime > lastMod {
                log("Configuration file changed, reloading...", level: .info)
                loadConfiguration()
            } else if lastConfigModTime == nil {
                loadConfiguration()
            }
        }

        // Also check lock_state.json for lock enforcement
        let lockStatePath = "/Library/Application Support/FocusDragon/lock_state.json"
        if let attrs = try? FileManager.default.attributesOfItem(atPath: lockStatePath),
           let modTime = attrs[.modificationDate] as? Date {
            if lastLockStateModTime == nil || modTime > lastLockStateModTime! {
                lastLockStateModTime = modTime
                enforceLockState()
            }
        }
    }

    private func updateWatchers() {
        guard let config = currentConfig else { return }

        // Before applying, enforce lock state: if a lock is active, prevent
        // the app from setting isBlocking = false.
        if !config.isBlocking {
            if isLockedByLockState() {
                log("Lock active — overriding isBlocking to true", level: .warning)
                currentConfig?.isBlocking = true
            }
        }

        let effectiveConfig = currentConfig ?? config

        // Update hosts watcher (exclude domains with path exceptions)
        let exceptionDomains = Set(effectiveConfig.urlExceptions.map { $0.domain.lowercased() })
        let hostsDomains = effectiveConfig.blockedDomains.filter { !exceptionDomains.contains($0.lowercased()) }
        hostsWatcher?.updateDomains(hostsDomains, isBlocking: effectiveConfig.isBlocking)

        // Update process watcher
        let bundleIDs = effectiveConfig.blockedApps.map { $0.bundleIdentifier }
        var whitelistApps: [String] = []
        if effectiveConfig.frozenState?.mode == .limitedAccess {
            whitelistApps.append(contentsOf: effectiveConfig.frozenState?.allowedAppBundleIDs ?? [])
        }
        if effectiveConfig.internetBlockConfig?.isEnabled == true {
            whitelistApps.append(contentsOf: effectiveConfig.internetBlockConfig?.whitelistApps ?? [])
        }
        let uniqueWhitelist = Array(Set(whitelistApps))
        processWatcher?.updateApps(
            bundleIDs,
            isBlocking: effectiveConfig.isBlocking,
            appExceptions: effectiveConfig.appExceptions,
            whitelistOnlyApps: uniqueWhitelist
        )

        // Update browser extension enforcer
        browserEnforcer?.update(
            isBlocking: effectiveConfig.isBlocking,
            requireExtension: effectiveConfig.requireBrowserExtension
        )

        // Update internet blocker
        internetBlocker?.update(config: effectiveConfig.internetBlockConfig, isBlocking: effectiveConfig.isBlocking)

        // Update frozen enforcer
        frozenEnforcer?.update(state: effectiveConfig.frozenState, isBlocking: effectiveConfig.isBlocking)

        // Clear heartbeats when blocking stops
        if !effectiveConfig.isBlocking {
            BrowserExtensionEnforcer.clearHeartbeats()
        }

        log("Watchers updated with new configuration", level: .info)
    }

    // MARK: - Watcher Management

    private func startWatchers() {
        // Start hosts file watcher
        hostsWatcher = HostsWatcher()

        // Create backup before first use
        hostsWatcher?.createBackup()

        // Apply current configuration
        if let config = currentConfig {
            hostsWatcher?.updateDomains(config.blockedDomains, isBlocking: config.isBlocking)
        }
        hostsWatcher?.start()

        // Start process watcher
        processWatcher = ProcessWatcher()
        if let config = currentConfig {
            let bundleIDs = config.blockedApps.map { $0.bundleIdentifier }
            var whitelistApps: [String] = []
            if config.frozenState?.mode == .limitedAccess {
                whitelistApps.append(contentsOf: config.frozenState?.allowedAppBundleIDs ?? [])
            }
            if config.internetBlockConfig?.isEnabled == true {
                whitelistApps.append(contentsOf: config.internetBlockConfig?.whitelistApps ?? [])
            }
            let uniqueWhitelist = Array(Set(whitelistApps))
            processWatcher?.updateApps(
                bundleIDs,
                isBlocking: config.isBlocking,
                appExceptions: config.appExceptions,
                whitelistOnlyApps: uniqueWhitelist
            )
        }
        processWatcher?.start()

        // Start browser extension enforcer
        browserEnforcer = BrowserExtensionEnforcer()
        if let config = currentConfig {
            browserEnforcer?.update(
                isBlocking: config.isBlocking,
                requireExtension: config.requireBrowserExtension
            )
        }
        browserEnforcer?.start()

        // Start internet blocker
        internetBlocker = InternetBlocker()
        if let config = currentConfig {
            internetBlocker?.update(config: config.internetBlockConfig, isBlocking: config.isBlocking)
        }

        // Start frozen mode enforcer
        frozenEnforcer = FrozenModeEnforcer()
        if let config = currentConfig {
            frozenEnforcer?.update(state: config.frozenState, isBlocking: config.isBlocking)
        }

        log("Watchers started", level: .info)
    }

    private func stopWatchers() {
        hostsWatcher?.stop()
        processWatcher?.stop()
        browserEnforcer?.stop()
        hostsWatcher = nil
        processWatcher = nil
        browserEnforcer = nil
        internetBlocker = nil
        frozenEnforcer = nil
        log("Watchers stopped", level: .info)
    }

    // MARK: - Lock Enforcement

    /// Read lock_state.json and enforce blocking if a lock is active.
    private func enforceLockState() {
        if isLockedByLockState() {
            if currentConfig?.isBlocking == false {
                currentConfig?.isBlocking = true
                updateWatchers()
                log("Lock state enforced: blocking re-enabled", level: .info)
            }
        }
    }

    /// Returns true if lock_state.json indicates an active lock.
    private func isLockedByLockState() -> Bool {
        // Check restart lock first
        if restartLockManager?.isActive == true,
           restartLockManager?.canUnlock == false {
            return true
        }

        // Check lock_state.json
        let lockStatePath = "/Library/Application Support/FocusDragon/lock_state.json"
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: lockStatePath)) else {
            return false
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let lockState = try? decoder.decode(DaemonLockState.self, from: data) else {
            return false
        }

        // Not locked
        if !lockState.isLocked { return false }

        // Timer lock: check expiry
        if lockState.lockType == "timer" {
            if let expiry = lockState.expiresAt {
                return Date() < expiry
            }
            return false
        }

        // All other lock types: if isLocked, enforce
        return true
    }

    private func enforceRestartLock() {
        // Ensure blocking remains active
        if currentConfig?.isBlocking == false {
            currentConfig?.isBlocking = true
            log("Restart lock: forced blocking on", level: .info)
        }
    }

    // MARK: - Utilities

    private func createDirectories() {
        let configDir = "/Library/Application Support/FocusDragon"
        let logDir = "/var/log/focusdragon"

        for dir in [configDir, logDir] {
            do {
                try FileManager.default.createDirectory(
                    atPath: dir,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
                log("Created directory: \(dir)", level: .debug)
            } catch {
                log("Failed to create directory \(dir): \(error.localizedDescription)", level: .error)
            }
        }

        // Make config dir world-writable so the main app (running as user) can write
        // config.json without any privilege escalation or password prompts.
        let attrs: [FileAttributeKey: Any] = [.posixPermissions: NSNumber(value: 0o777)]
        try? FileManager.default.setAttributes(attrs, ofItemAtPath: configDir)
    }

    private func setupLogging() {
        // Create log directory if needed
        let logDir = "/var/log/focusdragon"
        try? FileManager.default.createDirectory(
            atPath: logDir,
            withIntermediateDirectories: true,
            attributes: nil
        )

        // Redirect stdout and stderr to log file
        if freopen(logPath, "a", stdout) == nil {
            print("Warning: Failed to redirect stdout to \(logPath)")
        }
        if freopen(logPath, "a", stderr) == nil {
            print("Warning: Failed to redirect stderr to \(logPath)")
        }

        // Ensure unbuffered output
        setvbuf(stdout, nil, _IONBF, 0)
        setvbuf(stderr, nil, _IONBF, 0)
    }

    private func log(_ message: String, level: LogLevel = .info) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        print("[\(timestamp)] [\(level.rawValue)] [SERVICE] \(message)")
    }

    // MARK: - Log Level

    private enum LogLevel: String {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARN"
        case error = "ERROR"
    }
}

// MARK: - Daemon Lock State (lightweight struct for reading app-side lock state)

private struct DaemonLockState: Codable {
    var lockType: String
    var isLocked: Bool
    var expiresAt: Date?
    var breakDelay: TimeInterval?
}
