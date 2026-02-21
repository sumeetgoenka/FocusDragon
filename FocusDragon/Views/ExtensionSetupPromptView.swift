//
//  ExtensionSetupPromptView.swift
//  FocusDragon
//
//  Created by Codex on 21/02/2026.
//

import SwiftUI
import SafariServices
import AppKit

struct ExtensionSetupPromptView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let installedBrowsers = BrowserCatalog.installedBrowsers()

        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                AppCard {
                    VStack(spacing: 20) {
                        HStack {
                            Spacer()
                            Button(action: { dismiss() }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                                    .font(.title2)
                            }
                            .buttonStyle(.plain)
                        }

                        Image(systemName: "puzzlepiece.extension.fill")
                            .font(.system(size: 72))
                            .foregroundStyle(AppTheme.accent.gradient)
                            .symbolRenderingMode(.hierarchical)

                        VStack(spacing: 6) {
                            Text("Install Browser Extensions")
                                .font(AppTheme.titleFont(22))

                            Text("Browser extensions are required for FocusDragon to enforce blocks in browsers. Install the extension for any browsers you use.")
                                .multilineTextAlignment(.center)
                                .font(AppTheme.bodyFont(12))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 30)
                        }

                        if installedBrowsers.isEmpty {
                            Text("No supported browsers detected. Install a browser, then return here to add the FocusDragon extension.")
                                .font(AppTheme.bodyFont(11))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 30)
                        } else {
                            VStack(spacing: 10) {
                                ForEach(installedBrowsers) { browser in
                                    extensionRow(
                                        browser: browser.definition.displayName,
                                        icon: browser.definition.icon,
                                        action: { openExtensions(for: browser) }
                                    )
                                }
                            }
                            .padding(.horizontal, 30)
                        }

                        Text("You can also install extensions later from Settings → Advanced → Install Browser Extensions.")
                            .font(AppTheme.bodyFont(11))
                            .foregroundColor(.secondary)

                        Button("Done") { dismiss() }
                            .buttonStyle(PrimaryGlowButtonStyle())
                            .controlSize(.large)
                    }
                    .padding(.vertical, 20)
                }
            }
            .padding(30)
        }
        .frame(width: 640, height: 620)
    }

    private func extensionRow(browser: String, icon: String, action: @escaping () -> Void) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(AppTheme.accent)
                .frame(width: 22)
            Text(browser)
                .font(AppTheme.bodyFont(12))
            Spacer()
            Button("Open Extensions") { action() }
                .buttonStyle(SecondaryButtonStyle())
                .controlSize(.small)
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    private func openExtensions(for browser: InstalledBrowser) {
        if browser.definition.isSafari {
            openSafari()
            return
        }

        if browser.definition.isFirefox {
            openFirefox(bundleID: browser.bundleID, appName: browser.appName)
            return
        }

        guard let scheme = browser.definition.scheme else { return }
        let urlString = "\(scheme)://extensions/"
        guard let url = URL(string: urlString) else { return }

        if let bundleID = browser.bundleID {
            NSWorkspace.shared.open(
                [url],
                withAppBundleIdentifier: bundleID,
                options: [.default],
                additionalEventParamDescriptor: nil,
                launchIdentifiers: nil
            )
            return
        }

        if let appName = browser.appName {
            openChromium(app: appName, url: url)
        }
    }

    private func openSafari() {
        SFSafariApplication.showPreferencesForExtension(
            withIdentifier: SharedConstants.safariExtensionIdentifier
        ) { _ in }
    }

    private func openChromium(app: String, url: URL) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-a", app, url.absoluteString]
        try? task.run()
    }

    private func openFirefox(bundleID: String?, appName: String?) {
        let url = URL(string: "about:addons")!

        if let bundleID {
            NSWorkspace.shared.open(
                [url],
                withAppBundleIdentifier: bundleID,
                options: [.default],
                additionalEventParamDescriptor: nil,
                launchIdentifiers: nil
            )
            return
        }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-a", appName ?? "Firefox", url.absoluteString]
        try? task.run()
    }
}

#Preview {
    ExtensionSetupPromptView()
}
