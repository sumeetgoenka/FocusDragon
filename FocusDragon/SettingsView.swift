//
//  SettingsView.swift
//  FocusDragon
//
//  Created by Anay Goenka on 17/02/2026.
//

import SwiftUI

struct SettingsView: View {
    @State private var showUninstallAlert = false
    @State private var isUninstalling = false

    var body: some View {
        Form {
            Section("System Daemon") {
                DaemonStatusView()

                if DaemonInstaller.shared.isDaemonInstalled() {
                    Button("Uninstall Daemon", role: .destructive) {
                        showUninstallAlert = true
                    }
                    .disabled(isUninstalling)
                }
            }

            Section("About") {
                LabeledContent("Version", value: "1.0.0")
                LabeledContent("Daemon Status", value: DaemonInstaller.shared.isDaemonRunning() ? "Running" : "Not Running")
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 400, minHeight: 300)
        .alert("Uninstall Daemon", isPresented: $showUninstallAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Uninstall", role: .destructive) {
                uninstallDaemon()
            }
        } message: {
            Text("This will stop and remove the system daemon. Blocking will only work when the app is running.")
        }
    }

    private func uninstallDaemon() {
        isUninstalling = true

        DaemonInstaller.shared.uninstall { result in
            isUninstalling = false
            // Could show success/error alert here
        }
    }
}

#Preview {
    SettingsView()
}
