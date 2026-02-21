//
//  DaemonSetupView.swift
//  FocusDragon
//
//  Created by Claude Code on 18/02/2026.
//

import SwiftUI

struct DaemonSetupView: View {
    @State private var currentStep = 0
    @State private var errorMessage: String?
    @State private var showError = false

    @Environment(\.dismiss) private var dismiss

    private let installer = DaemonInstaller.shared

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                stepHeader
                    .padding(.bottom, 20)

                AppCard {
                    Group {
                        switch currentStep {
                        case 0: welcomeStep
                        case 1: backgroundServiceStep
                        case 2: fullDiskAccessStep
                        case 3: doneStep
                        default: EmptyView()
                        }
                    }
                    .frame(maxWidth: .infinity)
                }

                Spacer()

                stepNavigation
            }
            .padding(30)
        }
        .frame(width: 560, height: 540)
        .alert("Setup Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "An unknown error occurred.")
        }
    }

    // MARK: - Steps

    private var welcomeStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "shield.checkerboard")
                .font(.system(size: 56))
                .foregroundStyle(AppTheme.accent.gradient)

            Text("Set Up Permissions")
                .font(AppTheme.titleFont(22))

            Text("FocusDragon needs a couple of system permissions to enforce blocks reliably. No admin password required — just toggle a few switches.")
                .multilineTextAlignment(.center)
                .font(AppTheme.bodyFont(12))
                .foregroundColor(.secondary)
                .padding(.horizontal, 20)

            VStack(alignment: .leading, spacing: 12) {
                permissionRow(icon: "arrow.triangle.2.circlepath",
                              title: "Background Service",
                              description: "Keeps blocks active when the app is closed")
                permissionRow(icon: "lock.doc",
                              title: "Full Disk Access",
                              description: "Allows modifying /etc/hosts to block websites")
            }
            .padding(.top, 8)
        }
    }

    private var backgroundServiceStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "gearshape.arrow.triangle.2.circlepath")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.flame.gradient)

            Text("Enable Background Service")
                .font(AppTheme.titleFont(22))

            if installer.status == .enabled {
                Label("Background service is active!", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.headline)
            } else if installer.status == .requiresApproval {
                Text("FocusDragon has been registered but needs your approval.\nOpen **System Settings → General → Login Items** and enable FocusDragon under \"Allow in the Background\".")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)

                Button("Open Login Items Settings") {
                    installer.openLoginItemsSettings()
                }
                .buttonStyle(.borderedProminent)
            } else {
                Text("Click the button below to register the background service. The system will ask you to approve it in **System Settings → Login Items**.")
                    .multilineTextAlignment(.center)
                    .font(AppTheme.bodyFont(12))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)

                Button("Register Background Service") {
                    registerDaemon()
                }
                .buttonStyle(PrimaryGlowButtonStyle())
            }

            Button("Refresh Status") {
                installer.refreshStatus()
            }
            .buttonStyle(SecondaryButtonStyle())
            .controlSize(.small)
        }
    }

    private var fullDiskAccessStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.doc.fill")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.electricBlue.gradient)

            Text("Grant Full Disk Access")
                .font(AppTheme.titleFont(22))

            Text("FocusDragon needs Full Disk Access to modify /etc/hosts and block websites.\n\nIn the settings window, find **FocusDragon** (or **Xcode** if running in debug) and toggle it on.")
                .multilineTextAlignment(.center)
                .font(AppTheme.bodyFont(12))
                .foregroundColor(.secondary)
                .padding(.horizontal, 10)

            #if DEBUG
            Text("**Dev note:** When running from Xcode, grant Full Disk Access to **Xcode** instead. The standalone .app will appear by name once exported.")
                .font(.caption)
                .foregroundColor(.orange)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 10)
            #endif

            Button("Open Full Disk Access Settings") {
                installer.openFullDiskAccessSettings()
            }
            .buttonStyle(PrimaryGlowButtonStyle())
        }
    }

    private var doneStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundStyle(AppTheme.accent.gradient)

            Text("All Set!")
                .font(AppTheme.titleFont(22))

            Text("FocusDragon is ready to protect your focus. Blocks will stay active even when the app is closed.")
                .multilineTextAlignment(.center)
                .font(AppTheme.bodyFont(12))
                .foregroundColor(.secondary)
                .padding(.horizontal, 20)

            HStack(spacing: 12) {
                statusBadge(
                    title: "Background Service",
                    active: installer.status.isRunning
                )
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Components

    private func permissionRow(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(AppTheme.accent)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(AppTheme.headerFont(14))
                Text(description).font(AppTheme.bodyFont(11)).foregroundColor(.secondary)
            }
        }
    }

    private func statusBadge(title: String, active: Bool) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(active ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
            Text(title)
                .font(AppTheme.bodyFont(11))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }

    private var stepHeader: some View {
        HStack(spacing: 8) {
            ForEach(0..<4) { i in
                Capsule()
                    .fill(i <= currentStep ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(height: 4)
            }
        }
    }

    private var stepNavigation: some View {
        HStack {
            if currentStep > 0 {
                Button("Back") { currentStep -= 1 }
                    .buttonStyle(SecondaryButtonStyle())
            }

            Spacer()

            if currentStep < 3 {
                Button("Next") { currentStep += 1 }
                    .buttonStyle(PrimaryGlowButtonStyle())
            } else {
                Button("Done") { dismiss() }
                    .buttonStyle(PrimaryGlowButtonStyle())
            }
        }
    }

    // MARK: - Actions

    private func registerDaemon() {
        do {
            try installer.register()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

#Preview {
    DaemonSetupView()
}
