//
//  OnboardingView.swift
//  FocusDragon
//

import SwiftUI
import ServiceManagement
import SafariServices

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var currentPage = 0
    @ObservedObject var manager: BlockListManager

    private let totalPages = 6

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                stepIndicator
                    .padding(.top, 28)
                    .padding(.horizontal, 40)

                Group {
                    switch currentPage {
                    case 0: WelcomePage()
                    case 1: PermissionsPage()
                    case 2: ExtensionsPage()
                    case 3: FirstBlockPage(manager: manager)
                    case 4: TestBlockPage(manager: manager)
                    case 5: CompletePage(onFinish: { hasCompletedOnboarding = true })
                    default: EmptyView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                navigationButtons
                    .padding(.bottom, 28)
                    .padding(.horizontal, 40)
            }
        }
        .frame(width: 660, height: 560)
        .interactiveDismissDisabled(true)
    }

    // MARK: - Step indicator

    private var stepIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalPages, id: \.self) { i in
                Capsule()
                    .fill(i <= currentPage ? Color.accentColor : Color.secondary.opacity(0.25))
                    .frame(height: 4)
            }
        }
    }

    // MARK: - Navigation

    private var navigationButtons: some View {
        HStack {
            if currentPage > 0 {
                Button("Back") { withAnimation { currentPage -= 1 } }
                    .buttonStyle(.bordered)
            } else {
                Spacer().frame(width: 70)
            }

            Spacer()

            if currentPage < totalPages - 1 {
                Button("Next") { withAnimation { currentPage += 1 } }
                    .buttonStyle(.borderedProminent)
            }
            // CompletePage handles its own finish button
        }
    }
}

// MARK: - Page 1: Welcome

private struct WelcomePage: View {
    var body: some View {
        AppCard {
            VStack(spacing: 24) {
                Image(systemName: "shield.lefthalf.filled.slash")
                    .font(.system(size: 96))
                    .foregroundStyle(AppTheme.accent.gradient)
                    .symbolRenderingMode(.hierarchical)

                VStack(spacing: 10) {
                    Text("Welcome to FocusDragon")
                        .font(AppTheme.titleFont(26))

                    Text("Block distracting websites and apps so you can do your best work. Blocks are enforced at the system level — no browser tricks, no workarounds.")
                        .multilineTextAlignment(.center)
                        .font(AppTheme.bodyFont(12))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 40)
                }

                VStack(alignment: .leading, spacing: 12) {
                    featureRow(icon: "lock.fill",          color: AppTheme.electricBlue, text: "System-level website blocking via /etc/hosts")
                    featureRow(icon: "app.badge.fill",     color: AppTheme.flame, text: "App blocking with live process monitoring")
                    featureRow(icon: "timer",              color: AppTheme.accent, text: "Lock mechanisms to prevent cheating")
                    featureRow(icon: "puzzlepiece.fill",   color: .green,  text: "Browser extensions for airtight enforcement")
                }
                .padding(.horizontal, 40)
            }
            .padding(.vertical, 20)
        }
        .padding(.horizontal, 40)
    }

    private func featureRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(color)
                .frame(width: 22)
            Text(text)
                .font(.callout)
        }
    }
}

// MARK: - Page 2: Permissions

private struct PermissionsPage: View {
    @State private var installer = DaemonInstaller.shared

    var body: some View {
        AppCard {
            VStack(spacing: 20) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(AppTheme.flame.gradient)
                    .symbolRenderingMode(.hierarchical)

                VStack(spacing: 6) {
                    Text("System Permissions")
                        .font(AppTheme.titleFont(22))

                    Text("FocusDragon needs two permissions to enforce blocks reliably. You can also set these up later from Settings.")
                        .multilineTextAlignment(.center)
                        .font(AppTheme.bodyFont(12))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 30)
                }

                VStack(spacing: 12) {
                    permissionCard(
                        icon: "gearshape.arrow.triangle.2.circlepath",
                        title: "Background Service",
                        description: "Keeps blocks active when the app is closed",
                        status: daemonStatus,
                        statusColor: installer.status.isRunning ? .green : .orange
                    ) {
                        if installer.status == .notRegistered {
                            Button("Register") { registerDaemon() }
                                .buttonStyle(SecondaryButtonStyle())
                                .controlSize(.small)
                        } else if installer.status == .requiresApproval {
                            Button("Open Login Items") { installer.openLoginItemsSettings() }
                                .buttonStyle(SecondaryButtonStyle())
                                .controlSize(.small)
                        } else {
                            Button("Refresh") { installer.refreshStatus() }
                                .buttonStyle(SecondaryButtonStyle())
                                .controlSize(.small)
                        }
                    }

                    permissionCard(
                        icon: "lock.doc.fill",
                        title: "Full Disk Access",
                        description: "Required to edit /etc/hosts for website blocking",
                        status: "Open System Settings to grant",
                        statusColor: .secondary
                    ) {
                        Button("Open Settings") { installer.openFullDiskAccessSettings() }
                            .buttonStyle(SecondaryButtonStyle())
                            .controlSize(.small)
                    }
                }
                .padding(.horizontal, 30)
            }
            .padding(.vertical, 20)
        }
        .padding(.horizontal, 40)
    }

    private var daemonStatus: String {
        switch installer.status {
        case .enabled:          return "Active"
        case .requiresApproval: return "Needs approval in Login Items"
        case .notRegistered:    return "Not registered"
        case .notFound:         return "Not found"
        case .unknown(let s):   return s
        }
    }

    private func registerDaemon() {
        try? installer.register()
        installer.refreshStatus()
    }

    private func permissionCard(
        icon: String,
        title: String,
        description: String,
        status: String,
        statusColor: Color,
        @ViewBuilder action: () -> some View
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(status)
                    .font(.caption2)
                    .foregroundColor(statusColor)
            }

            Spacer()

            action()
        }
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
    }
}

// MARK: - Page 3: Extensions

private struct ExtensionsPage: View {
    var body: some View {
        AppCard {
            VStack(spacing: 20) {
                Image(systemName: "puzzlepiece.extension.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(AppTheme.accent.gradient)
                    .symbolRenderingMode(.hierarchical)

                VStack(spacing: 6) {
                    Text("Browser Extensions")
                        .font(AppTheme.titleFont(22))

                    Text("Install the FocusDragon extension in your browsers for complete blocking. Required for browser enforcement.")
                        .multilineTextAlignment(.center)
                        .font(AppTheme.bodyFont(12))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 30)
                }

                VStack(spacing: 10) {
                    extensionRow(browser: "Safari",         icon: "safari",               action: openSafari)
                    extensionRow(browser: "Chrome",         icon: "globe",                action: { openChromium(app: "Google Chrome", scheme: "chrome") })
                    extensionRow(browser: "Edge",           icon: "globe",                action: { openChromium(app: "Microsoft Edge", scheme: "edge") })
                    extensionRow(browser: "Brave",          icon: "globe",                action: { openChromium(app: "Brave Browser", scheme: "chrome") })
                    extensionRow(browser: "Firefox",        icon: "flame",                action: openFirefox)
                }
                .padding(.horizontal, 30)

                Text("You can also install extensions later from Settings → Advanced → Install Browser Extensions.")
                    .font(AppTheme.bodyFont(11))
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 20)
        }
        .padding(.horizontal, 40)
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

    private func openSafari() {
        SFSafariApplication.showPreferencesForExtension(
            withIdentifier: SharedConstants.safariExtensionIdentifier
        ) { _ in }
    }

    private func openChromium(app: String, scheme: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-a", app, "\(scheme)://extensions/"]
        try? task.run()
    }

    private func openFirefox() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-a", "Firefox", "about:addons"]
        try? task.run()
    }
}

// MARK: - Page 4: First Block

private struct FirstBlockPage: View {
    @ObservedObject var manager: BlockListManager
    @State private var domain: String = ""

    var body: some View {
        AppCard {
            VStack(spacing: 20) {
                Image(systemName: "globe.badge.checkmark")
                    .font(.system(size: 72))
                    .foregroundStyle(AppTheme.electricBlue.gradient)
                    .symbolRenderingMode(.hierarchical)

                VStack(spacing: 6) {
                    Text("Add Your First Block")
                        .font(AppTheme.titleFont(22))

                    Text("Enter a website you want to block. You can edit it later from the main screen.")
                        .multilineTextAlignment(.center)
                        .font(AppTheme.bodyFont(12))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 30)
                }

                HStack {
                    TextField("e.g. youtube.com", text: $domain)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 300)
                    Button("Add") {
                        manager.addDomain(domain)
                        domain = ""
                    }
                    .buttonStyle(PrimaryGlowButtonStyle())
                    .disabled(domain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                Text("\(manager.getWebsites().count) websites in block list")
                    .font(AppTheme.bodyFont(11))
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 20)
        }
        .padding(.horizontal, 40)
    }
}

// MARK: - Page 5: Test Block

private struct TestBlockPage: View {
    @ObservedObject var manager: BlockListManager
    @State private var errorMessage: String?
    @State private var showExtensionsPrompt = false

    var body: some View {
        AppCard {
            VStack(spacing: 20) {
                Image(systemName: "shield.checkered")
                    .font(.system(size: 72))
                    .foregroundStyle(AppTheme.accent.gradient)
                    .symbolRenderingMode(.hierarchical)

                VStack(spacing: 6) {
                    Text("Test Your Block")
                        .font(AppTheme.titleFont(22))

                    Text("Start a short block to make sure everything works. You can stop it anytime.")
                        .multilineTextAlignment(.center)
                        .font(AppTheme.bodyFont(12))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 30)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(AppTheme.bodyFont(11))
                        .foregroundColor(.red)
                }

                Button(manager.isBlocking ? "Stop Block" : "Start Block") {
                    toggleBlocking()
                }
                .buttonStyle(PrimaryGlowButtonStyle(accent: manager.isBlocking ? AppTheme.flame : AppTheme.accent))
                .disabled(manager.blockedItems.isEmpty)

                Text(manager.isBlocking ? "Blocking is active" : "Blocking is off")
                    .font(AppTheme.bodyFont(11))
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 20)
        }
        .padding(.horizontal, 40)
        .sheet(isPresented: $showExtensionsPrompt) {
            ExtensionSetupPromptView()
        }
    }

    private func toggleBlocking() {
        if manager.isBlocking {
            manager.endBlockingSession()
            manager.isBlocking = false
            return
        }

        Task {
            let extensionsReady = await ExtensionRequirementChecker.extensionsReadyForBlocking()
            if !extensionsReady {
                await MainActor.run {
                    errorMessage = "Browser extensions are required before starting a block."
                    showExtensionsPrompt = true
                }
                return
            }

            let hasWebsite = manager.blockedItems.contains { $0.type == .website && $0.isEnabled }
            if hasWebsite && !DaemonInstaller.shared.isDaemonRunning {
                await MainActor.run {
                    errorMessage = "Background service is not running. Go back to Permissions to set it up."
                }
                return
            }

            await MainActor.run {
                manager.isBlocking = true
                manager.startBlockingSession()
                errorMessage = nil
            }
        }
    }
}

// MARK: - Page 4: Complete

private struct CompletePage: View {
    let onFinish: () -> Void

    var body: some View {
        AppCard {
            VStack(spacing: 28) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 96))
                    .foregroundStyle(AppTheme.accent.gradient)
                    .symbolRenderingMode(.hierarchical)

                VStack(spacing: 10) {
                    Text("All Set!")
                        .font(AppTheme.titleFont(26))

                    Text("FocusDragon is ready. Add websites and apps to your block list, then tap \"Start Block\" to begin a focus session.")
                        .multilineTextAlignment(.center)
                        .font(AppTheme.bodyFont(12))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 40)
                }

                VStack(alignment: .leading, spacing: 12) {
                    tipRow(icon: "plus.circle", text: "Add domains manually or use the Presets for quick setup")
                    tipRow(icon: "lock.fill",   text: "Enable a Lock to prevent disabling blocks mid-session")
                    tipRow(icon: "bell",        text: "You'll get a notification when blocking starts and stops")
                }
                .padding(.horizontal, 50)

                Button("Get Started") {
                    onFinish()
                }
                .buttonStyle(PrimaryGlowButtonStyle())
                .controlSize(.large)
            }
            .padding(.vertical, 20)
        }
        .padding(.horizontal, 40)
    }

    private func tipRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(AppTheme.accent)
                .frame(width: 22)
            Text(text)
                .font(AppTheme.bodyFont(12))
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    OnboardingView(manager: BlockListManager())
}
