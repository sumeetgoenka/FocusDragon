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
    nonisolated(unsafe) static let shared = HostsFileManager()

    private let hostsPath = "/etc/hosts"
    private let startMarker = "#### FocusDragon Block Start ####"
    private let endMarker = "#### FocusDragon Block End ####"

    nonisolated private init() {}

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

    // MARK: - Private Methods

    private func readHostsFile() throws -> String {
        return try String(contentsOfFile: hostsPath, encoding: .utf8)
    }

    private func writeHostsFile(content: String) throws {
        // Write to temp file in app's temp directory
        let tempDir = NSTemporaryDirectory()
        let tempFile = (tempDir as NSString).appendingPathComponent("focusdragon_hosts_temp")
        try content.write(toFile: tempFile, atomically: true, encoding: .utf8)

        // Use osascript to copy with admin privileges
        let script = """
        do shell script "cp '\(tempFile)' '\(hostsPath)' && rm '\(tempFile)'" with administrator privileges
        """

        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", script]

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
        // Use osascript to flush DNS with admin privileges
        let script = """
        do shell script "dscacheutil -flushcache && killall -HUP mDNSResponder" with administrator privileges
        """

        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", script]

        try task.run()
        task.waitUntilExit()

        if task.terminationStatus != 0 {
            // DNS flush failure is not critical, just log it
            print("⚠️ DNS cache flush failed with status: \(task.terminationStatus)")
        }
    }
}
