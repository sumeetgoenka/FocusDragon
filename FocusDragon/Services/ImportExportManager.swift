//
//  ImportExportManager.swift
//  FocusDragon
//

import Foundation
import AppKit
import UniformTypeIdentifiers

struct BlockListExport: Codable {
    let version: String
    let exportDate: Date
    let blockedDomains: [String]
    let blockedApps: [ExportedApp]
    let presetName: String?

    struct ExportedApp: Codable {
        let name: String
        let bundleIdentifier: String
    }
}

enum ImportError: LocalizedError {
    case invalidFormat
    case unsupportedVersion

    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "The file is not a valid FocusDragon export."
        case .unsupportedVersion:
            return "This export file version is not supported."
        }
    }
}

@MainActor
class ImportExportManager {
    static let shared = ImportExportManager()
    private init() {}

    func exportCurrentList(from manager: BlockListManager, name: String?) -> URL? {
        let domains = manager.getWebsites().compactMap { $0.domain }

        let apps = manager.getApplications().compactMap { item -> BlockListExport.ExportedApp? in
            guard let appName = item.appName, let bundleId = item.bundleIdentifier else { return nil }
            return BlockListExport.ExportedApp(name: appName, bundleIdentifier: bundleId)
        }

        let export = BlockListExport(
            version: "1.0",
            exportDate: Date(),
            blockedDomains: domains,
            blockedApps: apps,
            presetName: name
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(export) else { return nil }

        let safeName = (name ?? "export")
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
        let filename = "focusdragon-\(safeName)-\(Int(Date().timeIntervalSince1970)).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

        try? data.write(to: url)
        return url
    }

    func exportCurrentListCSV(from manager: BlockListManager, name: String?) -> URL? {
        let domains = manager.getWebsites().compactMap { $0.domain }
        let apps = manager.getApplications().compactMap { $0.bundleIdentifier }

        var lines: [String] = ["type,value"]
        lines.append(contentsOf: domains.map { "domain,\($0)" })
        lines.append(contentsOf: apps.map { "app,\($0)" })

        let content = lines.joined(separator: "\n")
        let safeName = (name ?? "export")
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
        let filename = "focusdragon-\(safeName)-\(Int(Date().timeIntervalSince1970)).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func exportDomainsPlainText(from manager: BlockListManager, name: String?) -> URL? {
        let domains = manager.getWebsites().compactMap { $0.domain }
        let content = domains.joined(separator: "\n")
        let safeName = (name ?? "export")
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
        let filename = "focusdragon-\(safeName)-\(Int(Date().timeIntervalSince1970)).txt"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func importList(from url: URL, into manager: BlockListManager) throws {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let export = try? decoder.decode(BlockListExport.self, from: data) else {
            // Attempt CSV or plain text formats
            if let text = String(data: data, encoding: .utf8) {
                let parsed = parseTextImport(text)
                if parsed.domains.isEmpty && parsed.apps.isEmpty {
                    throw ImportError.invalidFormat
                }
                for domain in parsed.domains {
                    manager.addDomain(domain)
                }
                for bundleId in parsed.apps {
                    let item = BlockItem(appName: bundleId, bundleIdentifier: bundleId)
                    manager.addApplication(item)
                }
                return
            }
            throw ImportError.invalidFormat
        }

        guard export.version == "1.0" else {
            throw ImportError.unsupportedVersion
        }

        for domain in export.blockedDomains {
            manager.addDomain(domain)
        }

        for app in export.blockedApps {
            let item = BlockItem(appName: app.name, bundleIdentifier: app.bundleIdentifier)
            manager.addApplication(item)
        }
    }

    func showSavePanel(for url: URL, contentType: UTType = .json) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = url.lastPathComponent
        panel.allowedContentTypes = [contentType]
        panel.begin { response in
            guard response == .OK, let destination = panel.url else { return }
            try? FileManager.default.copyItem(at: url, to: destination)
        }
    }

    func showOpenPanel(completion: @escaping (URL?) -> Void) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json, .commaSeparatedText, .plainText]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.begin { response in
            completion(response == .OK ? panel.url : nil)
        }
    }

    private func parseTextImport(_ text: String) -> (domains: [String], apps: [String]) {
        var domains: Set<String> = []
        var apps: Set<String> = []

        let lines = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty { continue }
            if line.hasPrefix("#") || line.hasPrefix("//") { continue }

            let cleaned = line
                .replacingOccurrences(of: "0.0.0.0", with: "")
                .replacingOccurrences(of: "127.0.0.1", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let tokens = cleaned
                .split { $0 == "," || $0 == ";" || $0 == "\t" || $0 == " " }
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }

            for token in tokens where !token.isEmpty {
                if let domain = extractDomain(from: token) {
                    domains.insert(domain)
                } else if token.contains(".") && !token.contains("/") {
                    apps.insert(token)
                }
            }
        }

        return (Array(domains).sorted(), Array(apps).sorted())
    }

    private func extractDomain(from token: String) -> String? {
        var value = token.lowercased()

        if value.hasPrefix("http://") || value.hasPrefix("https://") {
            if let url = URL(string: value), let host = url.host {
                return host.replacingOccurrences(of: "^www\\.", with: "", options: .regularExpression)
            }
        }

        value = value.replacingOccurrences(of: "www.", with: "")
        if value.contains("/") {
            value = value.components(separatedBy: "/")[0]
        }

        if value.contains(".") && value.range(of: "^[a-z0-9.-]+$", options: .regularExpression) != nil {
            return value
        }

        return nil
    }
}
