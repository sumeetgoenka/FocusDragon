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
            PulsingDot(color: statusColor)
                .frame(width: 10, height: 10)

            Text(installer.status.displayName)
                .font(AppTheme.bodyFont(11))
                .foregroundColor(.secondary)

            if !installer.status.isRunning {
                Button(installer.status == .requiresApproval ? "Approve" : "Set Up") {
                    if installer.status == .requiresApproval {
                        installer.openLoginItemsSettings()
                    } else {
                        showSetup = true
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
                .controlSize(.small)
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
