//
//  AppSelector.swift
//  FocusDragon
//
//  Created by Claude Code on 18/02/2026.
//

import Foundation
import AppKit
import UniformTypeIdentifiers

class AppSelector {
    static let shared = AppSelector()

    private init() {}

    func selectApplication(completion: @escaping (BlockItem?) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.message = "Select an application to block"

        panel.begin { response in
            guard response == .OK, let url = panel.url else {
                completion(nil)
                return
            }

            let item = self.createBlockItem(from: url)
            completion(item)
        }
    }

    private func createBlockItem(from url: URL) -> BlockItem? {
        guard let bundle = Bundle(url: url),
              let bundleIdentifier = bundle.bundleIdentifier else {
            return nil
        }

        let appName = url.deletingPathExtension().lastPathComponent
        let iconPath = extractIconPath(from: bundle)

        return BlockItem(
            appName: appName,
            bundleIdentifier: bundleIdentifier,
            iconPath: iconPath
        )
    }

    private func extractIconPath(from bundle: Bundle) -> String? {
        // Try to get app icon
        if let iconFile = bundle.object(forInfoDictionaryKey: "CFBundleIconFile") as? String {
            var iconPath = bundle.bundlePath + "/Contents/Resources/" + iconFile
            if !iconFile.hasSuffix(".icns") {
                iconPath += ".icns"
            }
            if FileManager.default.fileExists(atPath: iconPath) {
                return iconPath
            }
        }
        return nil
    }

    func getInstalledApplications() -> [BlockItem] {
        var apps: [BlockItem] = []

        let appDirs = [
            "/Applications",
            "/System/Applications",
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path
        ]

        for dir in appDirs {
            guard let contents = try? FileManager.default.contentsOfDirectory(atPath: dir) else {
                continue
            }

            for file in contents where file.hasSuffix(".app") {
                let appURL = URL(fileURLWithPath: dir).appendingPathComponent(file)
                if let item = createBlockItem(from: appURL) {
                    apps.append(item)
                }
            }
        }

        return apps.sorted { $0.displayName < $1.displayName }
    }
}
