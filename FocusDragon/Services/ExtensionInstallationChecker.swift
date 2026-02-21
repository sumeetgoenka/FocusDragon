//
//  ExtensionInstallationChecker.swift
//  FocusDragon
//
//  Checks whether browser extensions and their native-messaging
//  manifests are installed, and whether each extension is currently
//  reporting as active.
//

import Foundation

class ExtensionInstallationChecker {
    static let shared = ExtensionInstallationChecker()

    struct ExtensionStatus: Identifiable {
        let id = UUID()
        let browser: String
        let isInstalled: Bool
        let isEnabled: Bool
    }

    private init() {}

    // MARK: - Public

    func checkAllExtensions() -> [ExtensionStatus] {
        return [
            checkChromeExtension(),
            checkBraveExtension(),
            checkVivaldiExtension(),
            checkOperaExtension(),
            checkCometExtension(),
            checkFirefoxExtension(),
            checkEdgeExtension(),
            checkSafariExtension()
        ]
    }

    // MARK: - Per-browser checks

    private func checkChromeExtension() -> ExtensionStatus {
        // Native messaging manifest presence is the best proxy for
        // "the extension & native host are installed"
        let manifestPath = "\(NSHomeDirectory())/Library/Application Support/Google/Chrome/NativeMessagingHosts/com.focusdragon.nativehost.json"

        let isInstalled = FileManager.default.fileExists(atPath: manifestPath)

        return ExtensionStatus(
            browser: "Chrome",
            isInstalled: isInstalled,
            isEnabled: ExtensionMonitor.shared.chromeExtensionActive
        )
    }

    private func checkBraveExtension() -> ExtensionStatus {
        let manifestPath = "\(NSHomeDirectory())/Library/Application Support/BraveSoftware/Brave-Browser/NativeMessagingHosts/com.focusdragon.nativehost.json"
        let isInstalled = FileManager.default.fileExists(atPath: manifestPath)

        return ExtensionStatus(
            browser: "Brave",
            isInstalled: isInstalled,
            isEnabled: ExtensionMonitor.shared.braveExtensionActive
        )
    }

    private func checkVivaldiExtension() -> ExtensionStatus {
        let manifestPath = "\(NSHomeDirectory())/Library/Application Support/Vivaldi/NativeMessagingHosts/com.focusdragon.nativehost.json"
        let isInstalled = FileManager.default.fileExists(atPath: manifestPath)

        return ExtensionStatus(
            browser: "Vivaldi",
            isInstalled: isInstalled,
            isEnabled: ExtensionMonitor.shared.vivaldiExtensionActive
        )
    }

    private func checkOperaExtension() -> ExtensionStatus {
        let manifestPaths = [
            "\(NSHomeDirectory())/Library/Application Support/com.operasoftware.Opera/NativeMessagingHosts/com.focusdragon.nativehost.json",
            "\(NSHomeDirectory())/Library/Application Support/com.operasoftware.OperaGX/NativeMessagingHosts/com.focusdragon.nativehost.json",
            "\(NSHomeDirectory())/Library/Application Support/com.operasoftware.OperaDeveloper/NativeMessagingHosts/com.focusdragon.nativehost.json"
        ]

        let isInstalled = manifestPaths.contains { FileManager.default.fileExists(atPath: $0) }

        return ExtensionStatus(
            browser: "Opera",
            isInstalled: isInstalled,
            isEnabled: ExtensionMonitor.shared.operaExtensionActive
        )
    }

    private func checkCometExtension() -> ExtensionStatus {
        let manifestPaths = [
            "\(NSHomeDirectory())/Library/Application Support/Comet/NativeMessagingHosts/com.focusdragon.nativehost.json",
            "\(NSHomeDirectory())/Library/Application Support/Perplexity/Comet/NativeMessagingHosts/com.focusdragon.nativehost.json",
            "\(NSHomeDirectory())/Library/Application Support/ai.perplexity.comet/NativeMessagingHosts/com.focusdragon.nativehost.json"
        ]

        let isInstalled = manifestPaths.contains { FileManager.default.fileExists(atPath: $0) }

        return ExtensionStatus(
            browser: "Comet",
            isInstalled: isInstalled,
            isEnabled: ExtensionMonitor.shared.cometExtensionActive
        )
    }

    private func checkFirefoxExtension() -> ExtensionStatus {
        let manifestPath = "\(NSHomeDirectory())/Library/Application Support/Mozilla/NativeMessagingHosts/com.focusdragon.nativehost.json"

        let isInstalled = FileManager.default.fileExists(atPath: manifestPath)

        return ExtensionStatus(
            browser: "Firefox",
            isInstalled: isInstalled,
            isEnabled: ExtensionMonitor.shared.firefoxExtensionActive
        )
    }

    private func checkEdgeExtension() -> ExtensionStatus {
        let manifestPath = "\(NSHomeDirectory())/Library/Application Support/Microsoft Edge/NativeMessagingHosts/com.focusdragon.nativehost.json"

        let isInstalled = FileManager.default.fileExists(atPath: manifestPath)

        return ExtensionStatus(
            browser: "Edge",
            isInstalled: isInstalled,
            isEnabled: ExtensionMonitor.shared.edgeExtensionActive
        )
    }

    private func checkSafariExtension() -> ExtensionStatus {
        // Safari extension is bundled with the app, so it's always installed
        return ExtensionStatus(
            browser: "Safari",
            isInstalled: true,
            isEnabled: ExtensionMonitor.shared.safariExtensionActive
        )
    }
}
