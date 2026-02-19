//
//  MainView.swift
//  FocusDragon
//
//  Created by Anay Goenka on 17/02/2026.
//

import SwiftUI

struct MainView: View {
    @StateObject private var manager = BlockListManager()
    @ObservedObject private var lockManager = LockManager.shared
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isProcessing = false

    @State private var showSettings = false
    @State private var showLockSettings = false
    @State private var showUnlockPrompt = false
    @State private var unlockText = ""

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Spacer()
                Text("FocusDragon")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
                Button(action: { showSettings = true }) {
                    Image(systemName: "gearshape")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .help("Settings")
            }

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

            // Lock settings button
            if manager.isBlocking {
                Button {
                    showLockSettings = true
                } label: {
                    Label(lockManager.currentLock.isLocked ? "Locked (\(lockManager.currentLock.type.displayName))" : "Add Lock",
                          systemImage: lockManager.currentLock.isLocked ? "lock.fill" : "lock.open")
                }
                .buttonStyle(.bordered)
                .tint(lockManager.currentLock.isLocked ? .orange : .secondary)
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
        .onReceive(NotificationCenter.default.publisher(for: .scheduleLockActivated)) { notification in
            // Schedule just became active — start blocking if not already
            if !manager.isBlocking, !manager.blockedItems.isEmpty {
                Task {
                    try? await startBlocking()
                    await MainActor.run {
                        // Create schedule lock in LockManager
                        if let rule = notification.object as? ScheduleRule {
                            try? lockManager.createScheduleLock(
                                start: Calendar.current.date(from: rule.startTime) ?? Date(),
                                end: Calendar.current.date(from: rule.endTime) ?? Date(),
                                days: Set(rule.days.map { $0.calendarValue })
                            )
                        }
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .scheduleLockDeactivated)) { _ in
            // Schedule ended — unlock and stop blocking
            if manager.isBlocking && lockManager.currentLock.type == .schedule {
                lockManager.reset()
                Task { try? await stopBlocking() }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .frame(minWidth: 450, minHeight: 350)
        }
        .sheet(isPresented: $showLockSettings) {
            LockSettingsView()
                .frame(minWidth: 500, minHeight: 400)
        }
        .alert("Unlock Required", isPresented: $showUnlockPrompt) {
            if lockManager.currentLock.type == .randomText {
                TextField("Enter code", text: $unlockText)
                Button("Unlock") {
                    let result = lockManager.attemptUnlock(with: unlockText)
                    if result.isSuccess {
                        unlockText = ""
                        // Now stop blocking
                        Task { try? await stopBlocking() ; await MainActor.run { isProcessing = false } }
                    } else if case .failure(let f) = result {
                        alertMessage = f.message
                        showingAlert = true
                    }
                }
            }
            Button("Cancel", role: .cancel) { unlockText = "" }
        } message: {
            Text(lockManager.currentLock.type == .randomText
                 ? "Type the random code to unlock and stop blocking."
                 : "A \(lockManager.currentLock.type.displayName) is active — you cannot stop blocking yet.")
        }
    }

    private func toggleBlocking() {
        isProcessing = true

        Task {
            do {
                if manager.isBlocking {
                    // Check lock state before allowing stop
                    if lockManager.currentLock.isLocked {
                        await MainActor.run {
                            isProcessing = false
                            // For types that need user input, show prompt
                            if lockManager.currentLock.type == .randomText {
                                showUnlockPrompt = true
                            } else {
                                let result = lockManager.attemptUnlock()
                                if result.isSuccess {
                                    Task { try? await stopBlocking() ; await MainActor.run { isProcessing = false } }
                                } else if case .failure(let f) = result {
                                    alertMessage = f.message
                                    showingAlert = true
                                }
                            }
                        }
                        return
                    }
                    try await stopBlocking()
                } else {
                    try await startBlocking()
                }
            } catch {
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
        let enabledDomains = manager.blockedItems
            .filter { $0.isEnabled && $0.type == .website }
            .compactMap { $0.domain }

        let enabledApps = manager.blockedItems
            .filter { $0.isEnabled && $0.type == .application }

        guard !enabledDomains.isEmpty || !enabledApps.isEmpty else {
            throw BlockError.noDomains
        }

        // Website blocking is handled entirely by the daemon (runs as root, writes /etc/hosts).
        // No osascript, no password prompts — ever.
        if !enabledDomains.isEmpty && !DaemonInstaller.shared.isDaemonRunning {
            throw BlockError.daemonNotRunning
        }

        // Start in-app process monitoring (no root required).
        if !enabledApps.isEmpty {
            await MainActor.run {
                ProcessMonitor.shared.startMonitoring(blockedApps: enabledApps)
            }
        }

        await MainActor.run {
            // isBlocking = true triggers saveState() → writeDaemonConfig().
            // Daemon picks up the new config.json within ~2 seconds and applies
            // the /etc/hosts block with no password prompt.
            manager.isBlocking = true
            manager.startBlockingSession()
            NotificationHelper.shared.showBlockingStarted()
        }
    }

    private func stopBlocking() async throws {
        ProcessMonitor.shared.stopMonitoring()

        await MainActor.run {
            // isBlocking = false → writeDaemonConfig() → daemon removes /etc/hosts block.
            manager.isBlocking = false
            NotificationHelper.shared.showBlockingStopped()
        }
    }

    private func verifyBlockingState() {
        // Push current state to config.json on launch so the daemon is in sync.
        manager.syncWithDaemon()

        // Restart in-app process monitoring if a session is already active.
        if manager.isBlocking {
            let enabledApps = manager.blockedItems.filter { $0.isEnabled && $0.type == .application }
            if !enabledApps.isEmpty {
                ProcessMonitor.shared.startMonitoring(blockedApps: enabledApps)
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
    case daemonNotRunning

    var errorDescription: String? {
        switch self {
        case .noDomains:
            return "No websites or apps enabled for blocking"
        case .daemonNotRunning:
            return "The background service is not running. Go to Settings → Set Up Permissions to enable it."
        }
    }
}

#Preview {
    MainView()
}
