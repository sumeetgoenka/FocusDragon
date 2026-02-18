//
//  HostsWatcher.swift
//  FocusDragonDaemon
//
//  Created by Claude on 18/02/2026.
//

import Foundation

/// Monitors and protects the /etc/hosts file
/// Full implementation will be completed in Phase 3.2
class HostsWatcher {
    // MARK: - Configuration

    private let hostsPath = "/etc/hosts"
    private let startMarker = "#### FocusDragon Block Start ####"
    private let endMarker = "#### FocusDragon Block End ####"

    // MARK: - State

    private var currentDomains: [String] = []
    private var isBlocking = false
    private var fileSource: DispatchSourceFileSystemObject?

    // MARK: - Public Methods

    func start() {
        log("HostsWatcher started (stub implementation)", level: .info)
        // Full implementation in Phase 3.2
    }

    func stop() {
        fileSource?.cancel()
        fileSource = nil
        log("HostsWatcher stopped", level: .info)
    }

    func updateDomains(_ domains: [String], isBlocking: Bool) {
        self.currentDomains = domains
        self.isBlocking = isBlocking
        log("Updated domains: \(domains.count) total, blocking=\(isBlocking)", level: .info)

        // Apply blocks if needed
        if isBlocking && !domains.isEmpty {
            applyBlocks()
        } else {
            removeBlocks()
        }
    }

    // MARK: - Private Methods

    private func applyBlocks() {
        do {
            // Read current hosts file
            let hostsContent = try String(contentsOfFile: hostsPath, encoding: .utf8)

            // Remove existing FocusDragon blocks
            let cleanedContent = removeExistingBlock(from: hostsContent)

            // Generate new block section
            let blockSection = generateBlockSection()

            // Combine
            let updatedContent = cleanedContent + "\n" + blockSection

            // Write back (daemon runs as root, no privilege escalation needed)
            try updatedContent.write(toFile: hostsPath, atomically: true, encoding: .utf8)

            // Flush DNS cache
            flushDNSCache()

            log("Applied blocks for \(currentDomains.count) domains", level: .info)
        } catch {
            log("Failed to apply blocks: \(error.localizedDescription)", level: .error)
        }
    }

    private func removeBlocks() {
        do {
            let hostsContent = try String(contentsOfFile: hostsPath, encoding: .utf8)
            let cleanedContent = removeExistingBlock(from: hostsContent)
            try cleanedContent.write(toFile: hostsPath, atomically: true, encoding: .utf8)
            flushDNSCache()
            log("Removed all blocks", level: .info)
        } catch {
            log("Failed to remove blocks: \(error.localizedDescription)", level: .error)
        }
    }

    private func removeExistingBlock(from content: String) -> String {
        var lines = content.components(separatedBy: .newlines)
        var result: [String] = []
        var inBlock = false

        for line in lines {
            if line.contains(startMarker) {
                inBlock = true
                continue
            }
            if line.contains(endMarker) {
                inBlock = false
                continue
            }
            if !inBlock {
                result.append(line)
            }
        }

        // Remove trailing empty lines
        while result.last?.isEmpty == true {
            result.removeLast()
        }

        return result.joined(separator: "\n")
    }

    private func generateBlockSection() -> String {
        var section = [startMarker]

        for domain in currentDomains {
            // Block both with and without www
            section.append("0.0.0.0 \(domain)")
            section.append("0.0.0.0 www.\(domain)")
        }

        section.append(endMarker)
        return section.joined(separator: "\n")
    }

    private func flushDNSCache() {
        let task = Process()
        task.launchPath = "/usr/bin/dscacheutil"
        task.arguments = ["-flushcache"]

        do {
            try task.run()
            task.waitUntilExit()

            // Also kill mDNSResponder
            let killTask = Process()
            killTask.launchPath = "/usr/bin/killall"
            killTask.arguments = ["-HUP", "mDNSResponder"]
            try killTask.run()

            log("DNS cache flushed", level: .debug)
        } catch {
            log("Failed to flush DNS cache: \(error.localizedDescription)", level: .warning)
        }
    }

    private func log(_ message: String, level: LogLevel = .info) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        print("[\(timestamp)] [\(level.rawValue)] [HOSTS] \(message)")
    }

    private enum LogLevel: String {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARN"
        case error = "ERROR"
    }
}
