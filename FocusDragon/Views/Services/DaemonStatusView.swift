//
//  DaemonStatusView.swift
//  FocusDragon
//
//  Created by Claude Code on 18/02/2026.
//

import SwiftUI

struct DaemonStatusView: View {
    @State private var isRunning = false
    @State private var isChecking = true
    @State private var showSetup = false

    var body: some View {
        HStack(spacing: 8) {
            if isChecking {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.7)
            } else {
                Circle()
                    .fill(isRunning ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
            }

            Text(statusText)
                .font(.caption)
                .foregroundColor(.secondary)

            if !isRunning && !isChecking {
                Button("Install") {
                    showSetup = true
                }
                .buttonStyle(.link)
                .font(.caption)
            }
        }
        .onAppear {
            checkStatus()
        }
        .sheet(isPresented: $showSetup) {
            DaemonSetupView()
        }
    }

    private var statusText: String {
        if isChecking {
            return "Checking daemon..."
        }
        return isRunning ? "System Daemon Running" : "System Daemon Not Running"
    }

    private func checkStatus() {
        isChecking = true

        DispatchQueue.global(qos: .background).async {
            let running = DaemonInstaller.shared.isDaemonRunning()

            DispatchQueue.main.async {
                isRunning = running
                isChecking = false
            }
        }
    }
}

#Preview {
    DaemonStatusView()
}
