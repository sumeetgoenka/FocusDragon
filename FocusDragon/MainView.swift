//
//  MainView.swift
//  FocusDragon
//
//  Created by Anay Goenka on 17/02/2026.
//

import SwiftUI

struct MainView: View {
    @StateObject private var manager = BlockListManager()
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isProcessing = false

    var body: some View {
        VStack(spacing: 20) {
            Text("FocusDragon")
                .font(.largeTitle)
                .fontWeight(.bold)

            // Block list (now supports both websites and apps)
            BlockListView(manager: manager)
                .frame(minHeight: 300)

            // Status and controls
            HStack {
                Circle()
                    .fill(manager.isBlocking ? Color.green : Color.gray)
                    .frame(width: 12, height: 12)
                Text(manager.isBlocking ? "Blocking Active" : "Not Blocking")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 20) {
                Button(manager.isBlocking ? "Stop Block" : "Start Block") {
                    toggleBlocking()
                }
                .buttonStyle(.borderedProminent)
                .tint(manager.isBlocking ? .red : .green)
                .disabled(isProcessing || manager.blockedItems.isEmpty)

                if isProcessing {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding()
        }
        .frame(minWidth: 600, minHeight: 500)
        .padding()
        .alert("Error", isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            verifyBlockingState()
        }
    }

    private func toggleBlocking() {
        print("🚀 Toggle blocking clicked")
        isProcessing = true

        Task {
            do {
                if manager.isBlocking {
                    print("🚀 Stopping blocking...")
                    try await stopBlocking()
                } else {
                    print("🚀 Starting blocking...")
                    try await startBlocking()
                }
            } catch {
                print("🚀 Error occurred: \(error)")
                await MainActor.run {
                    showError(error)
                }
            }

            await MainActor.run {
                isProcessing = false
            }
        }
    }

    private func startBlocking() async throws {
        print("🚀 In startBlocking()")
        let enabledDomains = manager.blockedItems
            .filter { $0.isEnabled && $0.type == .website }
            .compactMap { $0.domain }

        let enabledApps = manager.blockedItems
            .filter { $0.isEnabled && $0.type == .application }

        print("🚀 Enabled domains: \(enabledDomains)")
        print("🚀 Enabled apps: \(enabledApps.count)")

        guard !enabledDomains.isEmpty || !enabledApps.isEmpty else {
            print("🚀 No enabled items!")
            throw BlockError.noDomains
        }

        // Apply website blocks if needed
        if !enabledDomains.isEmpty {
            print("🚀 Applying website blocks...")
            try await MainActor.run {
                try HostsFileManager.shared.applyBlock(domains: enabledDomains)
            }
        }

        // Start process monitoring for apps
        if !enabledApps.isEmpty {
            print("🚀 Starting app monitoring...")
            await MainActor.run {
                ProcessMonitor.shared.startMonitoring(blockedApps: enabledApps)
            }
        }

        await MainActor.run {
            manager.isBlocking = true
            manager.startBlockingSession()
            NotificationHelper.shared.showBlockingStarted()
        }
    }

    private func stopBlocking() async throws {
        print("🚀 Stopping blocking...")

        // Stop process monitoring
        ProcessMonitor.shared.stopMonitoring()

        // Remove hosts file blocks
        try await MainActor.run {
            try HostsFileManager.shared.removeBlock()
        }

        await MainActor.run {
            manager.isBlocking = false
            NotificationHelper.shared.showBlockingStopped()
        }
    }

    private func verifyBlockingState() {
        // Check if hosts file has our markers
        let hostsContent = try? String(contentsOfFile: "/etc/hosts", encoding: .utf8)
        let hasMarkers = hostsContent?.contains("#### FocusDragon Block Start ####") ?? false

        if manager.isBlocking && !hasMarkers {
            // Block should be active but isn't - reapply
            Task {
                try? await startBlocking()
            }
        } else if !manager.isBlocking && hasMarkers {
            // Block shouldn't be active but is - remove
            Task {
                try? await stopBlocking()
            }
        }
    }

    private func showError(_ error: Error) {
        alertMessage = error.localizedDescription
        showingAlert = true
    }
}

enum BlockError: LocalizedError {
    case noDomains
    case privilegesDenied

    var errorDescription: String? {
        switch self {
        case .noDomains:
            return "No websites or apps enabled for blocking"
        case .privilegesDenied:
            return "Administrator privileges are required to modify the hosts file"
        }
    }
}

#Preview {
    MainView()
}
