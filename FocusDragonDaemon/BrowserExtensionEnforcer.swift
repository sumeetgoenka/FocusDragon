//
//  BrowserExtensionEnforcer.swift
//  FocusDragonDaemon
//
//  Monitors browser extension heartbeats. If blocking is active and
//  an extension hasn't sent a heartbeat within the staleness
//  threshold (or lacks incognito/profile coverage), force-quit
//  the browser to prevent bypass.
//

import Foundation
import AppKit
import CoreGraphics
import SystemConfiguration

class BrowserExtensionEnforcer {
    // MARK: - Configuration

    /// How often we check for stale heartbeats (seconds)
    private let checkInterval: TimeInterval = 2.0

    /// If the heartbeat file is older than this, the extension is considered dead
    private let stalenessThreshold: TimeInterval = 10.0

    /// Path where the native messaging host writes heartbeats
    private let heartbeatDir = "/Library/Application Support/FocusDragon/heartbeats"

    /// Chrome bundle IDs to force-quit
    private let chromeBundleIDs: Set<String> = [
        "com.google.Chrome",
        "com.google.Chrome.canary",
        "com.google.Chrome.beta",
    ]

    /// Brave bundle IDs to force-quit
    private let braveBundleIDs: Set<String> = [
        "com.brave.Browser",
        "com.brave.Browser.beta",
        "com.brave.Browser.dev",
        "com.brave.Browser.nightly",
    ]

    /// Vivaldi bundle IDs to force-quit
    private let vivaldiBundleIDs: Set<String> = [
        "com.vivaldi.Vivaldi",
        "com.vivaldi.VivaldiSnapshot",
    ]

    /// Opera bundle IDs to force-quit
    private let operaBundleIDs: Set<String> = [
        "com.operasoftware.Opera",
        "com.operasoftware.OperaGX",
        "com.operasoftware.OperaDeveloper",
    ]

    /// Comet bundle IDs to force-quit
    private let cometBundleIDs: Set<String> = [
        "ai.perplexity.comet",
    ]

    /// Firefox bundle IDs to force-quit
    private let firefoxBundleIDs: Set<String> = [
        "org.mozilla.firefox",
        "org.mozilla.firefoxdeveloperedition",
        "org.mozilla.nightly",
        "org.mozilla.firefoxbeta",
    ]

    /// Edge bundle IDs to force-quit
    private let edgeBundleIDs: Set<String> = [
        "com.microsoft.edgemac",
        "com.microsoft.edgemac.Beta",
        "com.microsoft.edgemac.Dev",
        "com.microsoft.edgemac.Canary",
    ]

    /// Safari bundle IDs to force-quit
    private let safariBundleIDs: Set<String> = [
        "com.apple.Safari",
        "com.apple.SafariTechnologyPreview"
    ]

    /// How often we rescan installed apps for browser detection
    private let browserScanInterval: TimeInterval = 600.0

    /// Keywords used to identify browser apps (secondary signal only)
    private let browserKeywords: [String] = [
        "browser",
        "chrome",
        "chromium",
        "firefox",
        "safari",
        "edge",
        "edgemac",
        "brave",
        "vivaldi",
        "opera",
        "comet",
        "orion",
        "arc",
        "tor",
        "waterfox",
        "librewolf",
        "palemoon",
        "seamonkey",
        "yandex",
        "thorium",
        "ungoogled",
        "zen",
        "duckduckgo",
        "maxthon"
    ]

    /// Frameworks that indicate a bundled browser engine
    private let browserEngineFrameworks: [String] = [
        "Chromium Embedded Framework.framework",
        "Electron Framework.framework",
        "QtWebEngineCore.framework",
        "QtWebKit.framework",
        "WebKit.framework"
    ]

    private let safariAppGroupID = "group.com.focusdragon.shared"
    private let safariHeartbeatKey = "safariExtensionHeartbeat"

    // MARK: - State

    private var timer: Timer?
    private var isBlocking = false
    private var requireExtension = false

    private let browserScanQueue = DispatchQueue(label: "com.focusdragon.browser-scan", qos: .utility)
    private let browserCatalogQueue = DispatchQueue(label: "com.focusdragon.browser-catalog")
    private var lastBrowserScan = Date.distantPast
    private var isScanningBrowsers = false
    private var unsupportedBrowserBundleIDs: Set<String> = []

    // MARK: - Public Methods

    func start() {
        guard timer == nil else { return }

        // Ensure heartbeat directory exists
        try? FileManager.default.createDirectory(
            atPath: heartbeatDir,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: NSNumber(value: 0o777)]
        )

        timer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            self?.checkHeartbeats()
        }
        RunLoop.main.add(timer!, forMode: .common)

        log("BrowserExtensionEnforcer started", level: .info)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        log("BrowserExtensionEnforcer stopped", level: .info)
    }

    func update(isBlocking: Bool, requireExtension: Bool) {
        self.isBlocking = isBlocking
        self.requireExtension = requireExtension
        log("BrowserExtensionEnforcer updated: blocking=\(isBlocking), requireExtension=\(requireExtension)", level: .info)
    }

    // MARK: - Private

    private func checkHeartbeats() {
        guard isBlocking && requireExtension else { return }

        refreshBrowserCatalogIfNeeded()
        enforceUnsupportedBrowsers()

        checkBrowser(
            name: "chrome",
            bundleIDs: chromeBundleIDs,
            enforceWindowCoverage: true
        )

        checkBrowser(
            name: "edge",
            bundleIDs: edgeBundleIDs,
            enforceWindowCoverage: true
        )

        checkBrowser(
            name: "brave",
            bundleIDs: braveBundleIDs,
            enforceWindowCoverage: true
        )

        checkBrowser(
            name: "vivaldi",
            bundleIDs: vivaldiBundleIDs,
            enforceWindowCoverage: true
        )

        checkBrowser(
            name: "opera",
            bundleIDs: operaBundleIDs,
            enforceWindowCoverage: true
        )

        checkBrowser(
            name: "comet",
            bundleIDs: cometBundleIDs,
            enforceWindowCoverage: true
        )

        checkBrowser(
            name: "firefox",
            bundleIDs: firefoxBundleIDs,
            enforceWindowCoverage: true
        )

        checkSafari()
    }

    private func checkBrowser(name: String, bundleIDs: Set<String>, enforceWindowCoverage: Bool) {
        let runningApps = NSWorkspace.shared.runningApplications.filter { app in
            guard let bid = app.bundleIdentifier else { return false }
            return bundleIDs.contains(bid)
        }

        guard !runningApps.isEmpty else { return }

        if !extensionInstalled(for: runningApps, browserName: name) {
            forceQuitApps(runningApps, reason: "FocusDragon extension not installed for \(name)")
            return
        }

        let fm = FileManager.default
        var allProfilesFresh = true
        var anyIncognitoMissing = false
        var foundAnyHeartbeat = false
        var totalHeartbeatWindows = 0
        var hasStructuredHeartbeat = false

        if let files = try? fm.contentsOfDirectory(atPath: heartbeatDir) {
            let heartbeatFiles = files.filter { $0.hasPrefix("\(name)_") && $0.hasSuffix(".heartbeat") }

            for file in heartbeatFiles {
                let path = (heartbeatDir as NSString).appendingPathComponent(file)
                guard let data = fm.contents(atPath: path),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    allProfilesFresh = false
                    continue
                }

                foundAnyHeartbeat = true
                hasStructuredHeartbeat = true

                if let attrs = try? fm.attributesOfItem(atPath: path),
                   let modDate = attrs[.modificationDate] as? Date {
                    let age = Date().timeIntervalSince(modDate)
                    if age > stalenessThreshold {
                        let profileId = json["profileId"] as? String ?? "unknown"
                        log("Heartbeat stale for \(name) profile \(profileId) (\(String(format: "%.1f", age))s old)", level: .warning)
                        allProfilesFresh = false
                    }
                }

                let incognitoAllowed = (json["incognitoAllowed"] as? Bool) ?? false
                if !incognitoAllowed {
                    anyIncognitoMissing = true
                }

                let windowCount = json["windowCount"] as? Int ?? 0
                if windowCount > 0 {
                    totalHeartbeatWindows += windowCount
                }
            }
        }

        if !foundAnyHeartbeat {
            let legacyPath = (heartbeatDir as NSString).appendingPathComponent("\(name).heartbeat")
            if fm.fileExists(atPath: legacyPath),
               let attrs = try? fm.attributesOfItem(atPath: legacyPath),
               let modDate = attrs[.modificationDate] as? Date {
                let age = Date().timeIntervalSince(modDate)
                if age <= stalenessThreshold {
                    foundAnyHeartbeat = true
                    allProfilesFresh = true
                }
            }
        }

        var shouldKill = false
        var reason = ""

        if !foundAnyHeartbeat {
            shouldKill = true
            reason = "no extension heartbeat found"
        } else if !allProfilesFresh {
            shouldKill = true
            reason = "extension heartbeat stale in one or more profiles"
        } else if anyIncognitoMissing {
            shouldKill = true
            reason = "extension not allowed in incognito — sites can be bypassed"
        } else if enforceWindowCoverage && hasStructuredHeartbeat {
            let actualWindowCount = countVisibleWindows(for: runningApps)
            if actualWindowCount > totalHeartbeatWindows {
                shouldKill = true
                reason = "extension missing in one or more profiles (windows \(actualWindowCount) > heartbeats \(totalHeartbeatWindows))"
            }
        }

        if shouldKill {
            forceQuitApps(runningApps, reason: reason)
        }
    }

    private func countVisibleWindows(for apps: [NSRunningApplication]) -> Int {
        let pids = Set(apps.map { $0.processIdentifier })
        guard let infoList = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return 0
        }

        var count = 0
        for info in infoList {
            guard let pid = info[kCGWindowOwnerPID as String] as? pid_t else { continue }
            if !pids.contains(pid) { continue }

            let layer = info[kCGWindowLayer as String] as? Int ?? 0
            if layer != 0 { continue }

            let isOnscreen = info[kCGWindowIsOnscreen as String] as? Bool ?? true
            if !isOnscreen { continue }

            count += 1
        }

        return count
    }

    private func forceQuitApps(_ apps: [NSRunningApplication], reason: String) {
        for app in apps {
            let name = app.localizedName ?? "Browser"
            log("Force-quitting \(name) (PID \(app.processIdentifier)) — \(reason)", level: .warning)

            app.forceTerminate()

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if !app.isTerminated {
                    kill(app.processIdentifier, SIGKILL)
                }
            }
        }
    }

    // MARK: - Unsupported Browser Detection

    private func refreshBrowserCatalogIfNeeded() {
        let now = Date()
        let shouldScan = browserCatalogQueue.sync { () -> Bool in
            if isScanningBrowsers { return false }
            if now.timeIntervalSince(lastBrowserScan) < browserScanInterval { return false }
            isScanningBrowsers = true
            lastBrowserScan = now
            return true
        }

        guard shouldScan else { return }

        browserScanQueue.async { [weak self] in
            self?.scanInstalledApplicationsForBrowsers()
        }
    }

    private func scanInstalledApplicationsForBrowsers() {
        guard let home = consoleUserHomeDirectory() else {
            browserCatalogQueue.sync { isScanningBrowsers = false }
            return
        }

        let searchDirs: [URL] = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/Applications/Utilities"),
            URL(fileURLWithPath: "/System/Applications"),
            URL(fileURLWithPath: "/System/Applications/Utilities"),
            URL(fileURLWithPath: "\(home)/Applications"),
        ]

        var detected: Set<String> = []
        let supported = supportedBundleIDs()

        for dir in searchDirs {
            detected.formUnion(scanBrowserBundles(in: dir, supported: supported))
        }

        browserCatalogQueue.sync {
            unsupportedBrowserBundleIDs = detected
            isScanningBrowsers = false
        }

        if !detected.isEmpty {
            log("Detected unsupported browsers: \(detected.sorted())", level: .info)
        }
    }

    private func scanBrowserBundles(in directory: URL, supported: Set<String>) -> Set<String> {
        var detected: Set<String> = []
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .isPackageKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return detected
        }

        for case let url as URL in enumerator {
            if url.pathExtension.lowercased() != "app" { continue }
            enumerator.skipDescendants()

            guard let info = appBundleInfo(at: url),
                  let bundleID = (info["CFBundleIdentifier"] as? String) else {
                continue
            }

            if supported.contains(bundleID) { continue }
            if isBrowserBundle(info: info, bundleURL: url) {
                detected.insert(bundleID)
            }
        }

        return detected
    }

    private func enforceUnsupportedBrowsers() {
        let runningApps = NSWorkspace.shared.runningApplications
        let supported = supportedBundleIDs()
        var offenders: [NSRunningApplication] = []

        for app in runningApps {
            guard let bundleID = app.bundleIdentifier else { continue }
            if supported.contains(bundleID) { continue }

            if isKnownUnsupportedBrowser(bundleID) {
                offenders.append(app)
                continue
            }

            guard let bundleURL = app.bundleURL,
                  let info = appBundleInfo(at: bundleURL) else {
                continue
            }

            if isBrowserBundle(info: info, bundleURL: bundleURL) {
                rememberUnsupportedBrowser(bundleID)
                offenders.append(app)
            }
        }

        if !offenders.isEmpty {
            forceQuitApps(offenders, reason: "unsupported browser detected")
        }
    }

    private func isKnownUnsupportedBrowser(_ bundleID: String) -> Bool {
        browserCatalogQueue.sync {
            unsupportedBrowserBundleIDs.contains(bundleID)
        }
    }

    private func rememberUnsupportedBrowser(_ bundleID: String) {
        browserCatalogQueue.sync {
            unsupportedBrowserBundleIDs.insert(bundleID)
        }
    }

    private func supportedBundleIDs() -> Set<String> {
        var set = Set<String>()
        set.formUnion(chromeBundleIDs)
        set.formUnion(edgeBundleIDs)
        set.formUnion(braveBundleIDs)
        set.formUnion(vivaldiBundleIDs)
        set.formUnion(operaBundleIDs)
        set.formUnion(cometBundleIDs)
        set.formUnion(firefoxBundleIDs)
        set.formUnion(safariBundleIDs)
        return set
    }

    private func appBundleInfo(at bundleURL: URL) -> [String: Any]? {
        let infoURL = bundleURL.appendingPathComponent("Contents/Info.plist")
        return NSDictionary(contentsOf: infoURL) as? [String: Any]
    }

    private func isBrowserBundle(info: [String: Any], bundleURL: URL) -> Bool {
        let identifier = (info["CFBundleIdentifier"] as? String)?.lowercased() ?? ""
        if identifier.hasPrefix("com.focusdragon.") {
            return false
        }

        let displayName = (info["CFBundleDisplayName"] as? String)
        let name = (info["CFBundleName"] as? String) ?? displayName ?? bundleURL.deletingPathExtension().lastPathComponent
        let exec = (info["CFBundleExecutable"] as? String) ?? ""
        let text = "\(identifier) \(name) \(exec)".lowercased()

        var score = 0
        if hasHttpScheme(info) {
            score += 2
        }
        if hasWebContentTypes(info) {
            score += 1
        }
        if hasBrowserEngineFrameworks(bundleURL) {
            score += 2
        }
        if containsBrowserKeyword(in: text) {
            score += 1
        }

        // Require a strong signal: either http/https handling or a bundled browser engine,
        // plus at least one additional signal.
        let strongSignal = hasHttpScheme(info) || hasBrowserEngineFrameworks(bundleURL)
        return strongSignal && score >= 3
    }

    private func containsBrowserKeyword(in text: String) -> Bool {
        let tokens = Set(text.split { !$0.isLetter && !$0.isNumber }.map { String($0) })

        for keyword in browserKeywords {
            if keyword.count <= 3 {
                if tokens.contains(keyword) {
                    return true
                }
            } else if text.contains(keyword) {
                return true
            }
        }

        return false
    }

    private func hasBrowserEngineFrameworks(_ bundleURL: URL) -> Bool {
        let frameworksDir = bundleURL
            .appendingPathComponent("Contents")
            .appendingPathComponent("Frameworks")

        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: frameworksDir,
            includingPropertiesForKeys: nil
        ) else {
            return false
        }

        for url in contents {
            if browserEngineFrameworks.contains(url.lastPathComponent) {
                return true
            }
        }

        return false
    }

    private func hasHttpScheme(_ info: [String: Any]) -> Bool {
        guard let urlTypes = info["CFBundleURLTypes"] as? [[String: Any]] else { return false }
        for type in urlTypes {
            guard let schemes = type["CFBundleURLSchemes"] as? [String] else { continue }
            for scheme in schemes {
                let lower = scheme.lowercased()
                if lower == "http" || lower == "https" {
                    return true
                }
            }
        }
        return false
    }

    private func hasWebContentTypes(_ info: [String: Any]) -> Bool {
        guard let docTypes = info["CFBundleDocumentTypes"] as? [[String: Any]] else { return false }

        let webContentTypes: Set<String> = [
            "public.html",
            "public.xhtml",
            "public.url",
            "public.webloc",
            "public.internet-shortcut",
            "public.url-name",
            "com.apple.web-internet-location",
        ]

        for docType in docTypes {
            if let contentTypes = docType["LSItemContentTypes"] as? [String] {
                for type in contentTypes {
                    if webContentTypes.contains(type.lowercased()) {
                        return true
                    }
                }
            }

            if let extensions = docType["CFBundleTypeExtensions"] as? [String] {
                for ext in extensions {
                    let lower = ext.lowercased()
                    if lower == "html" || lower == "htm" || lower == "xhtml" || lower == "webloc" || lower == "url" {
                        return true
                    }
                }
            }
        }

        return false
    }

    // MARK: - Safari Enforcement

    private func checkSafari() {
        let runningApps = NSWorkspace.shared.runningApplications.filter { app in
            guard let bid = app.bundleIdentifier else { return false }
            return safariBundleIDs.contains(bid)
        }

        guard !runningApps.isEmpty else { return }

        var shouldKill = false
        var reason = ""

        if let heartbeatAge = safariHeartbeatAge() {
            if heartbeatAge > stalenessThreshold {
                shouldKill = true
                reason = "Safari extension heartbeat stale"
            }
        } else {
            shouldKill = true
            reason = "no Safari extension heartbeat found"
        }

        let privateStatus = safariHasPrivateWindows()
        if privateStatus == true {
            shouldKill = true
            reason = "Safari private browsing detected — can bypass extension"
        } else if privateStatus == nil {
            shouldKill = true
            reason = "unable to verify Safari private browsing state"
        }

        if shouldKill {
            forceQuitApps(runningApps, reason: reason)
        }
    }

    private func safariHeartbeatAge() -> TimeInterval? {
        guard let prefsPath = safariPreferencesPath(),
              let dict = NSDictionary(contentsOfFile: prefsPath) as? [String: Any] else {
            return nil
        }

        if let timestamp = dict[safariHeartbeatKey] as? TimeInterval {
            return Date().timeIntervalSince1970 - timestamp
        }

        if let number = dict[safariHeartbeatKey] as? NSNumber {
            return Date().timeIntervalSince1970 - number.doubleValue
        }

        return nil
    }

    private func safariPreferencesPath() -> String? {
        guard let home = consoleUserHomeDirectory() else { return nil }
        return "\(home)/Library/Group Containers/\(safariAppGroupID)/Library/Preferences/\(safariAppGroupID).plist"
    }

    private func consoleUserHomeDirectory() -> String? {
        var uid: uid_t = 0
        var gid: gid_t = 0

        guard let username = SCDynamicStoreCopyConsoleUser(nil, &uid, &gid) as String?,
              !username.isEmpty,
              username != "loginwindow" else {
            return nil
        }

        return FileManager.default.homeDirectory(forUser: username)?.path
    }

    private func safariHasPrivateWindows() -> Bool? {
        let script = """
        tell application \"Safari\"
            try
                set privateCount to count (windows whose private is true)
                return privateCount as string
            on error
                return \"error\"
            end try
        end tell
        """

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", script]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
        } catch {
            return nil
        }

        task.waitUntilExit()

        guard task.terminationStatus == 0 else { return nil }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              output != "error" else {
            return nil
        }

        if let count = Int(output) {
            return count > 0
        }

        return nil
    }

    // MARK: - Extension Installation Detection

    private func extensionInstalled(for runningApps: [NSRunningApplication], browserName: String) -> Bool {
        guard let home = consoleUserHomeDirectory() else {
            return true
        }

        let fm = FileManager.default

        for app in runningApps {
            guard let bundleID = app.bundleIdentifier else { continue }
            let manifestPaths = nativeHostManifestPaths(for: bundleID, homeDirectory: home, browserName: browserName)

            if manifestPaths.isEmpty {
                return false
            }

            let hasManifest = manifestPaths.contains { fm.fileExists(atPath: $0) }
            if !hasManifest {
                return false
            }
        }

        return true
    }

    private func nativeHostManifestPaths(for bundleID: String, homeDirectory: String, browserName: String) -> [String] {
        let manifest = "com.focusdragon.nativehost.json"

        switch bundleID {
        case "com.google.Chrome":
            return ["\(homeDirectory)/Library/Application Support/Google/Chrome/NativeMessagingHosts/\(manifest)"]
        case "com.google.Chrome.beta":
            return ["\(homeDirectory)/Library/Application Support/Google/Chrome Beta/NativeMessagingHosts/\(manifest)"]
        case "com.google.Chrome.canary":
            return ["\(homeDirectory)/Library/Application Support/Google/Chrome Canary/NativeMessagingHosts/\(manifest)"]

        case "com.microsoft.edgemac":
            return ["\(homeDirectory)/Library/Application Support/Microsoft Edge/NativeMessagingHosts/\(manifest)"]
        case "com.microsoft.edgemac.Beta":
            return ["\(homeDirectory)/Library/Application Support/Microsoft Edge Beta/NativeMessagingHosts/\(manifest)"]
        case "com.microsoft.edgemac.Dev":
            return ["\(homeDirectory)/Library/Application Support/Microsoft Edge Dev/NativeMessagingHosts/\(manifest)"]
        case "com.microsoft.edgemac.Canary":
            return ["\(homeDirectory)/Library/Application Support/Microsoft Edge Canary/NativeMessagingHosts/\(manifest)"]

        case "com.brave.Browser":
            return ["\(homeDirectory)/Library/Application Support/BraveSoftware/Brave-Browser/NativeMessagingHosts/\(manifest)"]
        case "com.brave.Browser.beta":
            return ["\(homeDirectory)/Library/Application Support/BraveSoftware/Brave-Browser-Beta/NativeMessagingHosts/\(manifest)"]
        case "com.brave.Browser.dev":
            return ["\(homeDirectory)/Library/Application Support/BraveSoftware/Brave-Browser-Dev/NativeMessagingHosts/\(manifest)"]
        case "com.brave.Browser.nightly":
            return ["\(homeDirectory)/Library/Application Support/BraveSoftware/Brave-Browser-Nightly/NativeMessagingHosts/\(manifest)"]

        case "com.vivaldi.Vivaldi":
            return ["\(homeDirectory)/Library/Application Support/Vivaldi/NativeMessagingHosts/\(manifest)"]
        case "com.vivaldi.VivaldiSnapshot":
            return ["\(homeDirectory)/Library/Application Support/Vivaldi Snapshot/NativeMessagingHosts/\(manifest)"]

        case "com.operasoftware.Opera":
            return ["\(homeDirectory)/Library/Application Support/com.operasoftware.Opera/NativeMessagingHosts/\(manifest)"]
        case "com.operasoftware.OperaGX":
            return ["\(homeDirectory)/Library/Application Support/com.operasoftware.OperaGX/NativeMessagingHosts/\(manifest)"]
        case "com.operasoftware.OperaDeveloper":
            return ["\(homeDirectory)/Library/Application Support/com.operasoftware.OperaDeveloper/NativeMessagingHosts/\(manifest)"]

        case "ai.perplexity.comet":
            return [
                "\(homeDirectory)/Library/Application Support/Comet/NativeMessagingHosts/\(manifest)",
                "\(homeDirectory)/Library/Application Support/Perplexity/Comet/NativeMessagingHosts/\(manifest)",
                "\(homeDirectory)/Library/Application Support/ai.perplexity.comet/NativeMessagingHosts/\(manifest)"
            ]

        case "org.mozilla.firefox",
             "org.mozilla.firefoxdeveloperedition",
             "org.mozilla.firefoxbeta",
             "org.mozilla.nightly":
            return ["\(homeDirectory)/Library/Application Support/Mozilla/NativeMessagingHosts/\(manifest)"]

        default:
            if browserName == "firefox" {
                return ["\(homeDirectory)/Library/Application Support/Mozilla/NativeMessagingHosts/\(manifest)"]
            }
            return []
        }
    }

    // MARK: - Heartbeat File Management

    /// Called by the native messaging host to record a heartbeat
    static func recordHeartbeat(browser: String) {
        let dir = "/Library/Application Support/FocusDragon/heartbeats"
        let path = (dir as NSString).appendingPathComponent("\(browser).heartbeat")

        // Create/update heartbeat file (touch it)
        try? FileManager.default.createDirectory(
            atPath: dir,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: NSNumber(value: 0o777)]
        )

        if FileManager.default.fileExists(atPath: path) {
            // Update modification date
            try? FileManager.default.setAttributes(
                [.modificationDate: Date()],
                ofItemAtPath: path
            )
        } else {
            // Create the file
            let timestamp = ISO8601DateFormatter().string(from: Date())
            try? timestamp.write(toFile: path, atomically: true, encoding: .utf8)
        }
    }

    /// Remove heartbeat file (e.g. when blocking stops)
    static func clearHeartbeats() {
        let dir = "/Library/Application Support/FocusDragon/heartbeats"
        try? FileManager.default.removeItem(atPath: dir)
    }

    private func log(_ message: String, level: LogLevel) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        print("[\(timestamp)] [\(level.rawValue)] [BROWSER-ENFORCER] \(message)")
    }

    private enum LogLevel: String {
        case info = "INFO"
        case warning = "WARN"
        case error = "ERROR"
    }
}
