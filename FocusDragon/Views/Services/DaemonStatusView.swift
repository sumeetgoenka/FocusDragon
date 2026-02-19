//
//  DaemonStatusView.swift
//  FocusDragon
//
//  Created by Claude Code on 18/02/2026.
//

import SwiftUI

struct DaemonStatusView: View {
    @State private var showSetup = false

    private let installer = DaemonInstaller.shared

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            Text(installer.status.displayName)
                .font(.caption)
                .foregroundColor(.secondary)

            if !installer.status.isRunning {
                Button(installer.status == .requiresApproval ? "Approve" : "Set Up") {
                    if installer.status == .requiresApproval {
                        installer.openLoginItemsSettings()
                    } else {
                        showSetup = true
                    }
                }
                .buttonStyle(.link)
                .font(.caption)
            }
        }
        .onAppear {
            installer.refreshStatus()
        }
        .sheet(isPresented: $showSetup) {
            DaemonSetupView()
        }
    }

    private var statusColor: Color {
        switch installer.status {
        case .enabled: return .green
        case .requiresApproval: return .orange
        default: return .red
        }
    }
}

#Preview {
    DaemonStatusView()
}
