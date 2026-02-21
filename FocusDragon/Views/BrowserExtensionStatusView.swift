import SwiftUI
import SafariServices
import AppKit
import Combine

struct BrowserExtensionStatusView: View {
    private enum Health {
        case healthy
        case warning
        case error
    }

    private struct StatusInfo: Identifiable {
        let id = UUID()
        let name: String
        let state: Health
        let detail: String
    }

    private let refreshTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    private let heartbeatDir = "/Library/Application Support/FocusDragon/heartbeats"
    private let stalenessThreshold: TimeInterval = 10.0

    @State private var statuses: [StatusInfo] = []
    @State private var safariEnabled: Bool?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Browser Extensions")
                    .font(AppTheme.headerFont(15))
                Spacer()
                AppBadge(text: "Live", color: AppTheme.accent)
            }

            ForEach(statuses) { status in
                HStack(spacing: 10) {
                    PulsingDot(color: color(for: status.state))
                    Text(status.name)
                        .font(AppTheme.bodyFont(12))
                        .frame(width: 70, alignment: .leading)
                    Spacer()
                    Text(status.detail)
                        .font(AppTheme.bodyFont(11))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .padding(.vertical, 6)
        .onAppear {
            refreshSafariEnabled()
            refreshStatuses()
        }
        .onReceive(refreshTimer) { _ in
            refreshSafariEnabled()
            refreshStatuses()
        }
    }

    private func refreshStatuses() {
        let chrome = heartbeatStatus(for: "chrome", displayName: "Chrome")
        let edge = heartbeatStatus(for: "edge", displayName: "Edge")
        let brave = heartbeatStatus(for: "brave", displayName: "Brave")
        let vivaldi = heartbeatStatus(for: "vivaldi", displayName: "Vivaldi")
        let opera = heartbeatStatus(for: "opera", displayName: "Opera")
        let comet = heartbeatStatus(for: "comet", displayName: "Comet")
        let firefox = heartbeatStatus(for: "firefox", displayName: "Firefox")
        let safari = safariStatus(displayName: "Safari", isEnabled: safariEnabled)

        statuses = [chrome, edge, brave, vivaldi, opera, comet, firefox, safari]
    }

    private func heartbeatStatus(for prefix: String, displayName: String) -> StatusInfo {
        let fm = FileManager.default
        var foundAnyHeartbeat = false
        var allFresh = true
        var anyIncognitoMissing = false

        if let files = try? fm.contentsOfDirectory(atPath: heartbeatDir) {
            let heartbeatFiles = files.filter { $0.hasPrefix("\(prefix)_") && $0.hasSuffix(".heartbeat") }

            for file in heartbeatFiles {
                let path = (heartbeatDir as NSString).appendingPathComponent(file)
                guard let data = fm.contents(atPath: path),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    allFresh = false
                    continue
                }

                foundAnyHeartbeat = true

                if let attrs = try? fm.attributesOfItem(atPath: path),
                   let modDate = attrs[.modificationDate] as? Date {
                    let age = Date().timeIntervalSince(modDate)
                    if age > stalenessThreshold {
                        allFresh = false
                    }
                }

                let incognitoAllowed = (json["incognitoAllowed"] as? Bool) ?? false
                if !incognitoAllowed {
                    anyIncognitoMissing = true
                }
            }
        }

        if !foundAnyHeartbeat {
            return StatusInfo(name: displayName, state: .warning, detail: "Not detected")
        }

        if !allFresh {
            return StatusInfo(name: displayName, state: .error, detail: "Not responding")
        }

        if anyIncognitoMissing {
            return StatusInfo(name: displayName, state: .warning, detail: "Private mode off")
        }

        return StatusInfo(name: displayName, state: .healthy, detail: "Active")
    }

    private func safariStatus(displayName: String, isEnabled: Bool?) -> StatusInfo {
        let safariRunning = isSafariRunning()
        let heartbeatAge = safariHeartbeatAge()

        if safariRunning {
            if heartbeatAge == nil {
                return StatusInfo(name: displayName, state: .error, detail: "Not responding")
            }
            if let age = heartbeatAge, age > stalenessThreshold {
                return StatusInfo(name: displayName, state: .error, detail: "Heartbeat stale")
            }
        }

        if let enabled = isEnabled {
            return StatusInfo(
                name: displayName,
                state: enabled ? .healthy : .error,
                detail: enabled ? "Enabled" : "Disabled"
            )
        }

        return StatusInfo(name: displayName, state: .warning, detail: "Status unknown")
    }

    private func refreshSafariEnabled() {
        SFSafariExtensionManager.getStateOfSafariExtension(withIdentifier: SharedConstants.safariExtensionIdentifier) { state, _ in
            DispatchQueue.main.async {
                safariEnabled = state?.isEnabled
            }
        }
    }

    private func safariHeartbeatAge() -> TimeInterval? {
        guard let sharedDefaults = UserDefaults(suiteName: SharedConstants.appGroupIdentifier) else {
            return nil
        }

        guard let timestamp = sharedDefaults.value(forKey: SharedConstants.safariHeartbeatKey) as? TimeInterval else {
            return nil
        }

        return Date().timeIntervalSince1970 - timestamp
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

    private func color(for state: Health) -> Color {
        switch state {
        case .healthy:
            return .green
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }
}

#Preview {
    BrowserExtensionStatusView()
        .padding()
        .frame(width: 360)
}
