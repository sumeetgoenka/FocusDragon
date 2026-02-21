//
//  ExtensionRequirementChecker.swift
//  FocusDragon
//
//  Created by Codex on 21/02/2026.
//

import Foundation
import SafariServices

enum ExtensionRequirementChecker {
    static func extensionsReadyForBlocking() async -> Bool {
        let installedBrowsers = BrowserCatalog.installedBrowsers()
        let statuses = ExtensionInstallationChecker.shared.checkAllExtensions()
        let statusByName = Dictionary(uniqueKeysWithValues: statuses.map { ($0.browser, $0) })

        for browser in installedBrowsers where !browser.definition.isSafari {
            let status = statusByName[browser.definition.displayName]
            if status?.isInstalled != true {
                return false
            }
        }

        if installedBrowsers.contains(where: { $0.definition.isSafari }) {
            let safariEnabled = await safariExtensionEnabled()
            if !safariEnabled {
                return false
            }
        }

        return true
    }

    private static func safariExtensionEnabled() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSafariExtensionManager.getStateOfSafariExtension(
                withIdentifier: SharedConstants.safariExtensionIdentifier
            ) { state, _ in
                continuation.resume(returning: state?.isEnabled ?? false)
            }
        }
    }
}
