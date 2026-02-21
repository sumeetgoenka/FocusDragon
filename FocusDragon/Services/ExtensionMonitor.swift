//
//  ExtensionMonitor.swift
//  FocusDragon
//
//  Monitors browser extension health by reading heartbeat files written
//  by the native messaging host and checking Safari extension state via
//  SFSafariExtensionManager. Triggers enforcement actions when extensions
//  go offline during an active block session.
//

import Foundation
import SafariServices

class ExtensionMonitor {
    static let shared = ExtensionMonitor()

    private(set) var chromeExtensionActive = false
    private(set) var braveExtensionActive = false
    private(set) var vivaldiExtensionActive = false
    private(set) var operaExtensionActive = false
    private(set) var cometExtensionActive = false
    private(set) var firefoxExtensionActive = false
    private(set) var edgeExtensionActive = false
    private(set) var safariExtensionActive = false

    private var timer: Timer?

    private let heartbeatDir = "/Library/Application Support/FocusDragon/heartbeats"
    private let stalenessThreshold: TimeInterval = 10.0
    private let checkInterval: TimeInterval = 10.0

    /// Tracks per-browser last-known state so we only fire enforcement
    /// actions on the transition from healthy → unhealthy.
    private var previousStates: [String: Bool] = [
        "chrome": false,
        "brave": false,
        "vivaldi": false,
        "opera": false,
        "comet": false,
        "firefox": false,
        "edge": false,
        "safari": false
    ]

    private init() {}

    // MARK: - Public

    func startMonitoring() {
        guard timer == nil else { return }

        timer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            self?.checkExtensions()
        }
        RunLoop.main.add(timer!, forMode: .common)

        checkExtensions()
        print("ExtensionMonitor: started")
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        print("ExtensionMonitor: stopped")
    }

    var allExtensionsActive: Bool {
        return chromeExtensionActive
            || braveExtensionActive
            || vivaldiExtensionActive
            || operaExtensionActive
            || cometExtensionActive
            || firefoxExtensionActive
            || edgeExtensionActive
            || safariExtensionActive
    }

    var activeExtensionCount: Int {
        var count = 0
        if chromeExtensionActive { count += 1 }
        if braveExtensionActive { count += 1 }
        if vivaldiExtensionActive { count += 1 }
        if operaExtensionActive { count += 1 }
        if cometExtensionActive { count += 1 }
        if firefoxExtensionActive { count += 1 }
        if edgeExtensionActive { count += 1 }
        if safariExtensionActive { count += 1 }
        return count
    }

    // MARK: - Private

    private func checkExtensions() {
        checkHeartbeatExtension(prefix: "chrome", setter: { [weak self] active in
            self?.chromeExtensionActive = active
            self?.handleStateChange(browser: "Chrome", key: "chrome", isActive: active)
        })

        checkHeartbeatExtension(prefix: "brave", setter: { [weak self] active in
            self?.braveExtensionActive = active
            self?.handleStateChange(browser: "Brave", key: "brave", isActive: active)
        })

        checkHeartbeatExtension(prefix: "vivaldi", setter: { [weak self] active in
            self?.vivaldiExtensionActive = active
            self?.handleStateChange(browser: "Vivaldi", key: "vivaldi", isActive: active)
        })

        checkHeartbeatExtension(prefix: "opera", setter: { [weak self] active in
            self?.operaExtensionActive = active
            self?.handleStateChange(browser: "Opera", key: "opera", isActive: active)
        })

        checkHeartbeatExtension(prefix: "comet", setter: { [weak self] active in
            self?.cometExtensionActive = active
            self?.handleStateChange(browser: "Comet", key: "comet", isActive: active)
        })

        checkHeartbeatExtension(prefix: "firefox", setter: { [weak self] active in
            self?.firefoxExtensionActive = active
            self?.handleStateChange(browser: "Firefox", key: "firefox", isActive: active)
        })

        checkHeartbeatExtension(prefix: "edge", setter: { [weak self] active in
            self?.edgeExtensionActive = active
            self?.handleStateChange(browser: "Edge", key: "edge", isActive: active)
        })

        checkSafariExtension()
    }

    /// Reads heartbeat files for Chrome/Firefox to determine if the extension is alive.
    private func checkHeartbeatExtension(prefix: String, setter: @escaping (Bool) -> Void) {
        let fm = FileManager.default

        guard let files = try? fm.contentsOfDirectory(atPath: heartbeatDir) else {
            setter(false)
            return
        }

        let heartbeatFiles = files.filter {
            $0.hasPrefix("\(prefix)_") && $0.hasSuffix(".heartbeat")
        }

        guard !heartbeatFiles.isEmpty else {
            // No heartbeat files: browser not detected (not necessarily disabled)
            setter(false)
            return
        }

        // Check if any heartbeat file is fresh
        var anyFresh = false
        for file in heartbeatFiles {
            let path = (heartbeatDir as NSString).appendingPathComponent(file)
            if let attrs = try? fm.attributesOfItem(atPath: path),
               let modDate = attrs[.modificationDate] as? Date {
                let age = Date().timeIntervalSince(modDate)
                if age <= stalenessThreshold {
                    anyFresh = true
                    break
                }
            }
        }

        setter(anyFresh)
    }

    /// Checks Safari extension state via the SafariServices framework.
    private func checkSafariExtension() {
        // First check heartbeat from App Group UserDefaults
        var heartbeatFresh = false
        if let sharedDefaults = UserDefaults(suiteName: SharedConstants.appGroupIdentifier),
           let timestamp = sharedDefaults.value(forKey: SharedConstants.safariHeartbeatKey) as? TimeInterval {
            let age = Date().timeIntervalSince1970 - timestamp
            heartbeatFresh = age <= stalenessThreshold
        }

        // Also check SFSafariExtensionManager for enabled state
        SFSafariExtensionManager.getStateOfSafariExtension(
            withIdentifier: SharedConstants.safariExtensionIdentifier
        ) { [weak self] state, _ in
            DispatchQueue.main.async {
                let enabled = state?.isEnabled ?? false
                let active = enabled && (heartbeatFresh || !self!.isSafariRunning())

                self?.safariExtensionActive = active
                self?.handleStateChange(browser: "Safari", key: "safari", isActive: active)

                // If disabled, prompt re-enable
                if let state = state, !state.isEnabled, self?.isSafariRunning() == true {
                    self?.promptEnableSafariExtension()
                }
            }
        }
    }

    /// Only fires enforcement actions on the healthy → unhealthy transition.
    private func handleStateChange(browser: String, key: String, isActive: Bool) {
        let wasActive = previousStates[key] ?? false
        previousStates[key] = isActive

        // Extension just went offline
        if wasActive && !isActive {
            ExtensionEnforcement.shared.handleExtensionDisabled(browser: browser)
        }
    }

    private func promptEnableSafariExtension() {
        SFSafariApplication.showPreferencesForExtension(
            withIdentifier: SharedConstants.safariExtensionIdentifier
        )
    }

    private func isSafariRunning() -> Bool {
        let safariBundleIDs: Set<String> = [
            "com.apple.Safari",
            "com.apple.SafariTechnologyPreview"
        ]
        return NSWorkspace.shared.runningApplications.contains { app in
            guard let bid = app.bundleIdentifier else { return false }
            return safariBundleIDs.contains(bid)
        }
    }
}
