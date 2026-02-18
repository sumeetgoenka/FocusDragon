//
//  DaemonSetupView.swift
//  FocusDragon
//
//  Created by Claude Code on 18/02/2026.
//

import SwiftUI

struct DaemonSetupView: View {
    @State private var isInstalling = false
    @State private var installError: String?
    @State private var showError = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "gearshape.2.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            Text("Install System Daemon")
                .font(.title)
                .fontWeight(.bold)

            Text("FocusDragon needs to install a background service to enforce blocks when the app is closed.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 40)

            VStack(alignment: .leading, spacing: 10) {
                Label("Runs automatically on startup", systemImage: "checkmark.circle.fill")
                Label("Enforces blocks 24/7", systemImage: "checkmark.circle.fill")
                Label("Protects against tampering", systemImage: "checkmark.circle.fill")
                Label("Requires administrator password", systemImage: "key.fill")
            }
            .foregroundColor(.secondary)
            .padding(.vertical)

            Spacer()

            HStack(spacing: 15) {
                Button("Skip for Now") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .disabled(isInstalling)

                Button(action: installDaemon) {
                    if isInstalling {
                        HStack {
                            ProgressView()
                                .controlSize(.small)
                            Text("Installing...")
                        }
                    } else {
                        Text("Install Daemon")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isInstalling)
            }
        }
        .frame(width: 500, height: 450)
        .padding(30)
        .alert("Installation Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(installError ?? "Unknown error")
        }
    }

    private func installDaemon() {
        isInstalling = true

        DaemonInstaller.shared.install { result in
            isInstalling = false

            switch result {
            case .success:
                dismiss()
            case .failure(let error):
                installError = error.localizedDescription
                showError = true
            }
        }
    }
}

#Preview {
    DaemonSetupView()
}
