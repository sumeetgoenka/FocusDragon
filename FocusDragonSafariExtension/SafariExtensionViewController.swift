import AppKit
import Combine
import SafariServices
import SwiftUI

final class SafariExtensionViewController: SFSafariExtensionViewController {
    static let shared: SafariExtensionViewController = {
        SafariExtensionViewController()
    }()

    override func loadView() {
        let rootView = SafariExtensionPopoverView()
        view = NSHostingView(rootView: rootView)
        preferredContentSize = NSSize(width: 320, height: 420)
    }
}

private struct SafariExtensionPopoverView: View {
    private let appGroupID = "group.com.focusdragon.shared"
    private let blockedDomainsKey = "blockedDomains"
    private let isBlockingKey = "isBlocking"
    private let refreshTimer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    @State private var blockedDomains: [String] = []
    @State private var isBlocking: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("FocusDragon")
                .font(.headline) 

            Text(statusText)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Divider()

            if blockedDomains.isEmpty {
                Text("No sites blocked")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(blockedDomains, id: \.self) { domain in
                            Text(domain)
                                .font(.caption)
                                .padding(.vertical, 2)
                        }
                    }
                }
            }

            Spacer(minLength: 8)

            Button("Open App") {
                NSWorkspace.shared.launchApplication("FocusDragon")
            }
        }
        .padding(16)
        .onAppear {
            refresh()
        }
        .onReceive(refreshTimer) { _ in
            refresh()
        }
    }

    private var statusText: String {
        if isBlocking && !blockedDomains.isEmpty {
            return "Blocking \(blockedDomains.count) site(s)"
        }
        return "No blocking active"
    }

    private func refresh() {
        guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else {
            blockedDomains = []
            isBlocking = false
            return
        }

        let domains = sharedDefaults.array(forKey: blockedDomainsKey) as? [String] ?? []
        blockedDomains = domains
        isBlocking = sharedDefaults.bool(forKey: isBlockingKey)
    }
}
