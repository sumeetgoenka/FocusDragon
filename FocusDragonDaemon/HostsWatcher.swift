//
//  HostsWatcher.swift
//  FocusDragonDaemon
//
//  Created by Claude on 18/02/2026.
//

import Foundation

/// Monitors and protects the /etc/hosts file from tampering
class HostsWatcher {
    // MARK: - Configuration

    private let hostsPath = "/etc/hosts"
    private let backupPath = "/Library/Application Support/FocusDragon/hosts.backup"
    private let startMarker = "#### FocusDragon Block Start ####"
    private let endMarker = "#### FocusDragon Block End ####"
    private let checkInterval: TimeInterval = 5.0

    // MARK: - State

    private var blockedDomains: [String] = []
    private var isBlocking = false
    private var timer: Timer?
    private var lastModificationDate: Date?

    // MARK: - Public Methods

    func start() {
        log("HostsWatcher started", level: .info)

        // Store initial modification date
        updateLastModificationDate()

        // Start monitoring timer
        timer = Timer.scheduledTimer(
            withTimeInterval: checkInterval,
            repeats: true
        ) { [weak self] _ in
            self?.checkHostsFile()
        }

        // Add to run loop
        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
        }

        log("Monitoring /etc/hosts every \(checkInterval) seconds", level: .info)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        log("HostsWatcher stopped", level: .info)
    }

    func updateDomains(_ domains: [String], isBlocking: Bool) {
        self.blockedDomains = domains
        self.isBlocking = isBlocking
        log("Updated domains: \(domains.count) total, blocking=\(isBlocking)", level: .info)

        // Apply immediately
        if isBlocking && !domains.isEmpty {
            applyBlock()
        } else if !isBlocking {
            removeBlock()
        }
    }

    func createBackup() {
        guard !FileManager.default.fileExists(atPath: backupPath) else {
            log("Backup already exists", level: .info)
            return
        }

        do {
            try FileManager.default.copyItem(atPath: hostsPath, toPath: backupPath)
            log("Hosts file backed up to \(backupPath)", level: .info)
        } catch {
            log("Backup failed: \(error.localizedDescription)", level: .error)
        }
    }

    func restoreBackup() {
        guard FileManager.default.fileExists(atPath: backupPath) else {
            log("No backup to restore", level: .warning)
            return
        }

        do {
            let backupContent = try String(contentsOfFile: backupPath, encoding: .utf8)
            try backupContent.write(toFile: hostsPath, atomically: true, encoding: .utf8)
            flushDNSCache()
            updateLastModificationDate()
            log("Hosts file restored from backup", level: .info)
        } catch {
            log("Restore failed: \(error.localizedDescription)", level: .error)
        }
    }

    // MARK: - Monitoring

    private func checkHostsFile() {
        guard isBlocking else { return }

        let currentDate = getModificationDate()

        // Check if file was modified externally
        if let last = lastModificationDate,
           let current = currentDate,
           current > last {
            log("Hosts file was modified externally!", level: .warning)
            handleTampering()
        }
    }

    private func handleTampering() {
        // Check if our block section is still present
        guard let content = readHostsFile(),
              content.contains(startMarker) else {
            log("Block section removed! Re-applying...", level: .warning)
            applyBlock()
            return
        }

        // Check if our entries are intact
        if !verifyBlockIntegrity() {
            log("Block section corrupted! Fixing...", level: .warning)
            applyBlock()
        } else {
            // File was modified but our section is intact (other entries changed)
            log("External modification detected but FocusDragon section intact", level: .info)
            updateLastModificationDate()
        }
    }

    private func verifyBlockIntegrity() -> Bool {
        guard let content = readHostsFile() else { return false }

        // Extract our block section
        guard let blockSection = extractBlockSection(from: content) else {
            log("Could not extract block section", level: .warning)
            return false
        }

        // Verify all domains are present
        for domain in blockedDomains {
            let entry = "0.0.0.0 \(domain)"
            if !blockSection.contains(entry) {
                log("Missing entry: \(entry)", level: .warning)
                return false
            }
        }

        return true
    }

    // MARK: - Block Management

    private func applyBlock() {
        guard isBlocking, !blockedDomains.isEmpty else {
            log("Skipping block application (isBlocking=\(isBlocking), domains=\(blockedDomains.count))", level: .debug)
            return
        }

        log("Applying hosts file block for \(blockedDomains.count) domains", level: .info)

        // Read current hosts file
        guard var hostsContent = readHostsFile() else {
            log("ERROR: Could not read hosts file", level: .error)
            return
        }

        // Remove existing block section
        hostsContent = removeBlockSection(from: hostsContent)

        // Generate new block section
        let blockSection = generateBlockSection()

        // Append block section
        hostsContent += "\n" + blockSection

        // Write to hosts file
        if writeHostsFile(content: hostsContent) {
            log("Hosts file updated successfully", level: .info)
            flushDNSCache()
            updateLastModificationDate()
        } else {
            log("ERROR: Failed to write hosts file", level: .error)
        }
    }

    private func removeBlock() {
        log("Removing hosts file block", level: .info)

        guard var hostsContent = readHostsFile() else {
            log("ERROR: Could not read hosts file", level: .error)
            return
        }

        hostsContent = removeBlockSection(from: hostsContent)

        if writeHostsFile(content: hostsContent) {
            log("Block removed successfully", level: .info)
            flushDNSCache()
            updateLastModificationDate()
        } else {
            log("ERROR: Failed to write hosts file", level: .error)
        }
    }

    private func generateBlockSection() -> String {
        var lines = [startMarker]

        for domain in blockedDomains {
            lines.append("0.0.0.0 \(domain)")

            // Also block www variant (but not if domain already starts with www)
            if !domain.hasPrefix("www.") {
                lines.append("0.0.0.0 www.\(domain)")
            }
        }

        lines.append(endMarker)
        return lines.joined(separator: "\n")
    }

    private func removeBlockSection(from content: String) -> String {
        guard let startRange = content.range(of: startMarker),
              let endRange = content.range(of: endMarker) else {
            return content
        }

        var cleaned = content
        let blockRange = startRange.lowerBound..<content.index(after: endRange.upperBound)
        cleaned.removeSubrange(blockRange)

        // Clean up extra newlines
        while cleaned.hasSuffix("\n\n\n") {
            cleaned = String(cleaned.dropLast())
        }

        return cleaned
    }

    private func extractBlockSection(from content: String) -> String? {
        guard let startRange = content.range(of: startMarker),
              let endRange = content.range(of: endMarker) else {
            return nil
        }

        let blockRange = startRange.upperBound..<endRange.lowerBound
        return String(content[blockRange])
    }

    // MARK: - File Operations

    private func readHostsFile() -> String? {
        do {
            return try String(contentsOfFile: hostsPath, encoding: .utf8)
        } catch {
            log("Read error: \(error.localizedDescription)", level: .error)
            return nil
        }
    }

    private func writeHostsFile(content: String) -> Bool {
        do {
            try content.write(toFile: hostsPath, atomically: true, encoding: .utf8)

            // Verify and fix permissions after writing
            fixPermissions()

            return true
        } catch {
            log("Write error: \(error.localizedDescription)", level: .error)
            return false
        }
    }

    private func getModificationDate() -> Date? {
        let attrs = try? FileManager.default.attributesOfItem(atPath: hostsPath)
        return attrs?[.modificationDate] as? Date
    }

    private func updateLastModificationDate() {
        lastModificationDate = getModificationDate()
        if let date = lastModificationDate {
            log("Updated last modification date: \(date)", level: .debug)
        }
    }

    // MARK: - File Permissions

    private func verifyPermissions() -> Bool {
        let attrs = try? FileManager.default.attributesOfItem(atPath: hostsPath)

        guard let permissions = attrs?[.posixPermissions] as? NSNumber else {
            return false
        }

        // /etc/hosts should be 644 (rw-r--r--)
        let expected: UInt16 = 0o644
        return permissions.uint16Value == expected
    }

    private func fixPermissions() {
        guard !verifyPermissions() else { return }

        let attrs: [FileAttributeKey: Any] = [
            .posixPermissions: NSNumber(value: 0o644)
        ]

        do {
            try FileManager.default.setAttributes(attrs, ofItemAtPath: hostsPath)
            log("Permissions fixed to 644", level: .info)
        } catch {
            log("Failed to fix permissions: \(error.localizedDescription)", level: .warning)
        }
    }

    // MARK: - DNS Cache

    private func flushDNSCache() {
        // macOS DNS cache flush
        let task = Process()
        task.launchPath = "/usr/bin/dscacheutil"
        task.arguments = ["-flushcache"]

        do {
            try task.run()
            task.waitUntilExit()

            // Also kill mDNSResponder for good measure
            let killTask = Process()
            killTask.launchPath = "/usr/bin/killall"
            killTask.arguments = ["-HUP", "mDNSResponder"]
            try killTask.run()
            killTask.waitUntilExit()

            log("DNS cache flushed", level: .debug)
        } catch {
            log("Failed to flush DNS cache: \(error.localizedDescription)", level: .warning)
        }
    }

    // MARK: - Logging

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
