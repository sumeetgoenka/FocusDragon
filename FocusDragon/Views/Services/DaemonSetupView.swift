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
        VStack(spacing: 0) {
            // Header
            stepHeader
                .padding(.bottom, 20)

            // Step content
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

            Spacer()

            // Navigation
            stepNavigation
        }
        .frame(width: 520, height: 500)
        .padding(30)
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
                .foregroundStyle(.blue.gradient)

            Text("Set Up Permissions")
                .font(.title2)
                .fontWeight(.bold)

            Text("FocusDragon needs a couple of system permissions to enforce blocks reliably. No admin password required — just toggle a few switches.")
                .multilineTextAlignment(.center)
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
                .foregroundStyle(.orange.gradient)

            Text("Enable Background Service")
                .font(.title2)
                .fontWeight(.bold)

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
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)

                Button("Register Background Service") {
                    registerDaemon()
                }
                .buttonStyle(.borderedProminent)
            }

            Button("Refresh Status") {
                installer.refreshStatus()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private var fullDiskAccessStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.doc.fill")
                .font(.system(size: 48))
                .foregroundStyle(.purple.gradient)

            Text("Grant Full Disk Access")
                .font(.title2)
                .fontWeight(.bold)

            Text("FocusDragon needs Full Disk Access to modify /etc/hosts and block websites.\n\nIn the settings window, find **FocusDragon** (or **Xcode** if running in debug) and toggle it on.")
                .multilineTextAlignment(.center)
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
            .buttonStyle(.borderedProminent)
        }
    }

    private var doneStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green.gradient)

            Text("All Set!")
                .font(.title2)
                .fontWeight(.bold)

            Text("FocusDragon is ready to protect your focus. Blocks will stay active even when the app is closed.")
                .multilineTextAlignment(.center)
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
                .foregroundColor(.blue)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(description).font(.caption).foregroundColor(.secondary)
            }
        }
    }

    private func statusBadge(title: String, active: Bool) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(active ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
            Text(title)
                .font(.caption)
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
                    .buttonStyle(.bordered)
            }

            Spacer()

            if currentStep < 3 {
                Button("Next") { currentStep += 1 }
                    .buttonStyle(.borderedProminent)
            } else {
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
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
