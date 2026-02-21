//
//  BrowserCatalog.swift
//  FocusDragon
//
//  Created by Codex on 21/02/2026.
//

import AppKit
import Foundation

struct BrowserDefinition: Identifiable {
    let id: String
    let displayName: String
    let icon: String
    let bundleIDs: [String]
    let scheme: String?
    let isSafari: Bool
    let isFirefox: Bool
}

struct InstalledBrowser: Identifiable {
    let id: String
    let definition: BrowserDefinition
    let bundleID: String?
    let appName: String?
}

enum BrowserCatalog {
    static let all: [BrowserDefinition] = [
        BrowserDefinition(
            id: "safari",
            displayName: "Safari",
            icon: "safari",
            bundleIDs: ["com.apple.Safari", "com.apple.SafariTechnologyPreview"],
            scheme: nil,
            isSafari: true,
            isFirefox: false
        ),
        BrowserDefinition(
            id: "chrome",
            displayName: "Chrome",
            icon: "globe",
            bundleIDs: ["com.google.Chrome", "com.google.Chrome.canary", "com.google.Chrome.beta"],
            scheme: "chrome",
            isSafari: false,
            isFirefox: false
        ),
        BrowserDefinition(
            id: "edge",
            displayName: "Edge",
            icon: "globe",
            bundleIDs: ["com.microsoft.edgemac", "com.microsoft.edgemac.Beta", "com.microsoft.edgemac.Dev", "com.microsoft.edgemac.Canary"],
            scheme: "edge",
            isSafari: false,
            isFirefox: false
        ),
        BrowserDefinition(
            id: "brave",
            displayName: "Brave",
            icon: "globe",
            bundleIDs: ["com.brave.Browser", "com.brave.Browser.beta", "com.brave.Browser.dev", "com.brave.Browser.nightly"],
            scheme: "chrome",
            isSafari: false,
            isFirefox: false
        ),
        BrowserDefinition(
            id: "vivaldi",
            displayName: "Vivaldi",
            icon: "globe",
            bundleIDs: ["com.vivaldi.Vivaldi", "com.vivaldi.VivaldiSnapshot"],
            scheme: "chrome",
            isSafari: false,
            isFirefox: false
        ),
        BrowserDefinition(
            id: "opera",
            displayName: "Opera",
            icon: "globe",
            bundleIDs: ["com.operasoftware.Opera", "com.operasoftware.OperaGX", "com.operasoftware.OperaDeveloper"],
            scheme: "chrome",
            isSafari: false,
            isFirefox: false
        ),
        BrowserDefinition(
            id: "comet",
            displayName: "Comet",
            icon: "globe",
            bundleIDs: ["ai.perplexity.comet"],
            scheme: "chrome",
            isSafari: false,
            isFirefox: false
        ),
        BrowserDefinition(
            id: "firefox",
            displayName: "Firefox",
            icon: "flame",
            bundleIDs: ["org.mozilla.firefox", "org.mozilla.firefoxdeveloperedition", "org.mozilla.nightly", "org.mozilla.firefoxbeta"],
            scheme: nil,
            isSafari: false,
            isFirefox: true
        )
    ]

    static func installedBrowsers() -> [InstalledBrowser] {
        all.compactMap { definition in
            if definition.isSafari {
                return InstalledBrowser(
                    id: definition.id,
                    definition: definition,
                    bundleID: definition.bundleIDs.first,
                    appName: "Safari"
                )
            }

            guard let bundleID = definition.bundleIDs.first(where: { isAppInstalled(bundleID: $0) }) else {
                return nil
            }

            let appName = appNameFor(bundleID: bundleID)
            return InstalledBrowser(
                id: "\(definition.id)-\(bundleID)",
                definition: definition,
                bundleID: bundleID,
                appName: appName
            )
        }
    }

    static func isAppInstalled(bundleID: String) -> Bool {
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil
    }

    static func appNameFor(bundleID: String) -> String? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return nil
        }
        return url.deletingPathExtension().lastPathComponent
    }
}
