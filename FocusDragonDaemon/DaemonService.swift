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
    private var configTimer: Timer?

    // MARK: - State

    private var currentConfig: DaemonConfig?
    private var isRunning = false
    private var lastConfigModTime: Date?

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
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: configPath),
              let modTime = attrs[.modificationDate] as? Date else {
            return
        }

        // Check if file has been modified since last load
        if let lastMod = lastConfigModTime, modTime > lastMod {
            log("Configuration file changed, reloading...", level: .info)
            loadConfiguration()
        } else if lastConfigModTime == nil {
            // First poll after startup
            loadConfiguration()
        }
    }

    private func updateWatchers() {
        guard let config = currentConfig else { return }

        // Update hosts watcher
        hostsWatcher?.updateDomains(config.blockedDomains, isBlocking: config.isBlocking)

        // Update process watcher
        let bundleIDs = config.blockedApps.map { $0.bundleIdentifier }
        processWatcher?.updateApps(bundleIDs, isBlocking: config.isBlocking)

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
            processWatcher?.updateApps(bundleIDs, isBlocking: config.isBlocking)
        }
        processWatcher?.start()

        log("Watchers started", level: .info)
    }

    private func stopWatchers() {
        hostsWatcher?.stop()
        processWatcher?.stop()
        hostsWatcher = nil
        processWatcher = nil
        log("Watchers stopped", level: .info)
    }

    // MARK: - Utilities

    private func createDirectories() {
        let dirs = [
            "/Library/Application Support/FocusDragon",
            "/var/log/focusdragon"
        ]

        for dir in dirs {
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
