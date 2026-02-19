//
//  SettingsView.swift
//  FocusDragon
//
//  Created by Anay Goenka on 17/02/2026.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showUninstallAlert = false
    @State private var showSetup = false
    @State private var uninstallError: String?
    @State private var showUninstallError = false
    @State private var showPasswordRequired = false

    private let installer = DaemonInstaller.shared

    var body: some View {
        Form {
            // MARK: - Background Service
            Section("Background Service") {
                DaemonStatusView()

                if installer.isDaemonInstalled {
                    Button("Unregister Service", role: .destructive) {
                        if SettingsProtection.shared.shouldPreventUninstall() {
                            showPasswordRequired = true
                        } else {
                            showUninstallAlert = true
                        }
                    }
                } else {
                    Button("Set Up Permissions") {
                        showSetup = true
                    }
                }
            }

            // MARK: - Lock & Protection
            Section("Lock & Protection") {
                SettingsProtectionView()
            }

            // MARK: - Permissions
            Section("System Permissions") {
                Button(action: { installer.openFullDiskAccessSettings() }) {
                    HStack {
                        Label("Full Disk Access", systemImage: "lock.doc")
                        Spacer()
                        Image(systemName: "arrow.up.forward.square")
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)

                Button(action: { installer.openLoginItemsSettings() }) {
                    HStack {
                        Label("Login Items", systemImage: "gearshape.arrow.triangle.2.circlepath")
                        Spacer()
                        Image(systemName: "arrow.up.forward.square")
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }

            // MARK: - About
            Section("About") {
                LabeledContent("Version", value: "1.0.0")
                LabeledContent("Service Status", value: installer.status.displayName)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 420, minHeight: 350)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
        .sheet(isPresented: $showSetup) {
            DaemonSetupView()
        }
        .alert("Unregister Service", isPresented: $showUninstallAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Unregister", role: .destructive) {
                unregisterDaemon()
            }
        } message: {
            Text("This will stop the background service. Blocking will only work while the app is open.")
        }
        .alert("Error", isPresented: $showUninstallError) {
            Button("OK") { }
        } message: {
            Text(uninstallError ?? "Unknown error")
        }
        .alert("Uninstall Prevented", isPresented: $showPasswordRequired) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("A lock is active or settings protection is enabled. You must authenticate in Lock & Protection settings before unregistering the service.")
        }
    }

    private func unregisterDaemon() {
        do {
            try installer.unregister()
        } catch {
            uninstallError = error.localizedDescription
            showUninstallError = true
        }
    }
}

#Preview {
    SettingsView()
}
