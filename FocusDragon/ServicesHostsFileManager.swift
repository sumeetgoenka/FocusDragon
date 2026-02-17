//
//  HostsFileManager.swift
//  FocusDragon
//
//  Created by Anay Goenka on 17/02/2026.
//

import Foundation
import Combine
import AppKit

/// Manages reading and writing to the system hosts file (/etc/hosts)
@MainActor
class HostsFileManager: ObservableObject {
    static let shared = HostsFileManager()

    private let hostsPath = "/etc/hosts"
    private let startMarker = "#### FocusDragon Block Start ####"
    private let endMarker = "#### FocusDragon Block End ####"

    private init() {}

    // MARK: - Public Methods

    /// Applies blocking to the specified domains
    func applyBlock(domains: [String]) throws {
        guard !domains.isEmpty else {
            try removeBlock()
            return
        }

        let hostsContent = try readHostsFile()
        let cleanedContent = removeExistingBlock(from: hostsContent)
        let blockSection = generateBlockSection(for: domains)
        let updatedContent = cleanedContent + "\n" + blockSection

        try writeHostsFile(content: updatedContent)
        try flushDNSCache()
    }

    /// Removes all FocusDragon blocking entries
    func removeBlock() throws {
        let hostsContent = try readHostsFile()
        let cleanedContent = removeExistingBlock(from: hostsContent)
        try writeHostsFile(content: cleanedContent)
        try flushDNSCache()
    }

    /// Requests administrator privileges
    func requestAdminPrivileges() -> Bool {
        // Use osascript to prompt for sudo
        let script = """
        do shell script "echo 'FocusDragon requesting admin access'" with administrator privileges
        """

        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", script]

        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            return false
        }
    }

    // MARK: - Private Methods

    private func readHostsFile() throws -> String {
        return try String(contentsOfFile: hostsPath, encoding: .utf8)
    }

    private func writeHostsFile(content: String) throws {
        // This requires root privileges
        // For Phase 1, we'll use a shell script with sudo
        let tempFile = "/tmp/focusdragon_hosts_temp"
        try content.write(toFile: tempFile, atomically: true, encoding: .utf8)

        let script = """
        #!/bin/bash
        sudo cp "\(tempFile)" "\(hostsPath)"
        rm "\(tempFile)"
        """

        try runShellScript(script)
    }

    private func removeExistingBlock(from content: String) -> String {
        guard let startRange = content.range(of: startMarker),
              let endRange = content.range(of: endMarker) else {
            return content
        }

        var cleaned = content
        let blockRange = startRange.lowerBound..<endRange.upperBound
        cleaned.removeSubrange(blockRange)

        // Remove extra newlines
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned
    }

    private func generateBlockSection(for domains: [String]) -> String {
        var entries: [String] = [startMarker]

        for domain in domains {
            let cleaned = domain.lowercased().trimmingCharacters(in: .whitespaces)
            entries.append("0.0.0.0 \(cleaned)")

            // Also block www variant
            if !cleaned.hasPrefix("www.") {
                entries.append("0.0.0.0 www.\(cleaned)")
            }
        }

        entries.append(endMarker)
        return entries.joined(separator: "\n")
    }

    private func flushDNSCache() throws {
        let task = Process()
        task.launchPath = "/usr/bin/sudo"
        task.arguments = ["dscacheutil", "-flushcache"]

        try task.run()
        task.waitUntilExit()

        // Also flush mDNSResponder
        let task2 = Process()
        task2.launchPath = "/usr/bin/sudo"
        task2.arguments = ["killall", "-HUP", "mDNSResponder"]

        try task2.run()
        task2.waitUntilExit()
    }

    private func runShellScript(_ script: String) throws {
        let tempScript = "/tmp/focusdragon_script.sh"
        try script.write(toFile: tempScript, atomically: true, encoding: .utf8)

        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = [tempScript]

        let pipe = Pipe()
        task.standardError = pipe

        try task.run()
        task.waitUntilExit()

        if task.terminationStatus != 0 {
            let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw NSError(
                domain: "HostsFileManager",
                code: Int(task.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: errorString]
            )
        }

        try FileManager.default.removeItem(atPath: tempScript)
    }
}
