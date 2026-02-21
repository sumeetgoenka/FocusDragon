//
//  ExtensionInstallView.swift
//  FocusDragon
//
//  Shows the installation and health status of each browser extension
//  and provides a one-tap refresh.
//

import SwiftUI

struct ExtensionInstallView: View {
    @State private var extensionStatuses: [ExtensionInstallationChecker.ExtensionStatus] = []

    var body: some View {
        VStack(spacing: 20) {
            Text("Browser Extensions")
                .font(AppTheme.headerFont(16))

            ForEach(extensionStatuses) { status in
                ExtensionRow(status: status)
            }

            Button("Refresh Status") {
                refreshStatuses()
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .padding()
        .onAppear {
            refreshStatuses()
        }
    }

    private func refreshStatuses() {
        extensionStatuses = ExtensionInstallationChecker.shared.checkAllExtensions()
    }
}

struct ExtensionRow: View {
    let status: ExtensionInstallationChecker.ExtensionStatus
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack {
            Image(systemName: browserIcon)
                .foregroundColor(AppTheme.electricBlue)
            Text(status.browser)

            Spacer()

            if status.isInstalled && status.isEnabled {
                Label("Active", systemImage: "checkmark.circle.fill")
                    .foregroundColor(AppTheme.accent)
            } else if status.isInstalled {
                Label("Disabled", systemImage: "exclamationmark.circle.fill")
                    .foregroundColor(.orange)
            } else {
                Label("Not Installed", systemImage: "xmark.circle.fill")
                    .foregroundColor(.red)
            }
        }
        .font(AppTheme.bodyFont(12))
        .padding(10)
        .background(AppTheme.cardFill(scheme))
        .cornerRadius(10)
    }

    private var browserIcon: String {
        switch status.browser {
        case "Chrome": return "globe"
        case "Brave": return "globe"
        case "Vivaldi": return "globe"
        case "Opera": return "globe"
        case "Comet": return "globe"
        case "Firefox": return "globe"
        case "Edge": return "globe"
        case "Safari": return "safari"
        default: return "globe"
        }
    }
}

#Preview {
    ExtensionInstallView()
        .frame(width: 360)
}
