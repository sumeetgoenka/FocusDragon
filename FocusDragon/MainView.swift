//
//  MainView.swift
//  FocusDragon
//
//  Created by Anay Goenka on 17/02/2026.
//

import SwiftUI

// MARK: - Sidebar Navigation

enum SidebarItem: String, CaseIterable, Identifiable {
    case blocker = "Blocker"
    case statistics = "Statistics"
    case pomodoro = "Pomodoro"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .blocker: return "shield.lefthalf.filled"
        case .statistics: return "chart.bar.fill"
        case .pomodoro: return "timer"
        case .settings: return "gearshape.fill"
        }
    }
}

// MARK: - Main View

struct MainView: View {
    @ObservedObject var manager: BlockListManager
    @ObservedObject private var lockManager = LockManager.shared
    @Environment(\.colorScheme) private var scheme
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isProcessing = false

    @State private var showLockSettings = false
    @State private var showUnlockPrompt = false
    @State private var unlockText = ""
    @State private var showStartupPermissions = false
    @State private var showStartupExtensions = false
    @State private var didCheckStartupPrompts = false
    @State private var selectedItem: SidebarItem = .blocker

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailContent
        }
        .frame(minWidth: 920, minHeight: 640)
        .alert("Error", isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            verifyBlockingState()
            queueStartupPromptsIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .scheduleLockActivated)) { notification in
            // Schedule just became active — start blocking if not already
            if !manager.isBlocking, !manager.blockedItems.isEmpty {
                Task {
                    try? await startBlocking(userInitiated: false)
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
        .onReceive(NotificationCenter.default.publisher(for: .extensionSetupRequested)) { _ in
            showStartupExtensions = true
        }
        .sheet(isPresented: $showLockSettings) {
            LockSettingsView()
                .frame(minWidth: 500, minHeight: 400)
        }
        .sheet(isPresented: $showStartupPermissions, onDismiss: {
            queueExtensionsPromptAfterPermissions()
        }) {
            DaemonSetupView()
        }
        .sheet(isPresented: $showStartupExtensions) {
            ExtensionSetupPromptView()
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

    // MARK: - Sidebar

    private var sidebar: some View {
        List(SidebarItem.allCases, selection: $selectedItem) { item in
            Label(item.rawValue, systemImage: item.icon)
                .font(AppTheme.bodyFont(13))
                .padding(.vertical, 4)
        }
        .navigationSplitViewColumnWidth(min: 160, ideal: 190, max: 220)
        .listStyle(.sidebar)
    }

    // MARK: - Detail Content

    @ViewBuilder
    private var detailContent: some View {
        switch selectedItem {
        case .blocker:
            blockerContent
        case .statistics:
            StatisticsView()
        case .pomodoro:
            PomodoroView(manager: manager)
        case .settings:
            SettingsView(manager: manager)
        }
    }

    // MARK: - Blocker Content

    private var blockerContent: some View {
        GeometryReader { geo in
            let isWide = geo.size.width > 700

            VStack(spacing: 20) {
                headerSection

                if isWide {
                    HStack(alignment: .top, spacing: 20) {
                        blockListSection
                        sidePanel
                    }
                } else {
                    VStack(spacing: 20) {
                        blockListSection
                        sidePanel
                    }
                }

                actionBar
            }
            .padding(.horizontal, 26)
            .padding(.top, 20)
            .padding(.bottom, 24)
        }
    }

    private var headerSection: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("FocusDragon")
                    .font(.title.bold())

                Text("Block distracting websites and apps across your system.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                showLockSettings = true
            } label: {
                Label(lockButtonTitle, systemImage: lockButtonIcon)
            }
            .disabled(!manager.isBlocking)
        }
    }

    private var blockListSection: some View {
        GroupBox {
            BlockListView(manager: manager)
                .frame(minHeight: 380)
        }
    }

    private var sidePanel: some View {
        VStack(spacing: 14) {
            statusCard
            GroupBox {
                BrowserExtensionStatusView()
            }
        }
    }

    private var statusCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(manager.isBlocking ? Color.green : Color.gray)
                        .frame(width: 10, height: 10)
                    Text(manager.isBlocking ? "Blocking Active" : "Not Blocking")
                        .font(.headline)
                }

                Text(manager.isBlocking ? "Distractions are locked down across your system." : "Start a session to block websites and apps.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    if manager.isBlocking {
                        statusPill("Session Live", color: .green)
                    } else {
                        statusPill("Idle", color: .gray)
                    }

                    if lockManager.currentLock.isLocked {
                        statusPill(lockManager.currentLock.type.displayName, color: .orange)
                    } else {
                        statusPill("No Lock", color: .blue)
                    }
                }
            }
        }
    }

    private func statusPill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .clipShape(Capsule())
    }

    private var actionBar: some View {
        HStack(spacing: 14) {
            Button(manager.isBlocking ? "Stop Block" : "Start Block") {
                toggleBlocking()
            }
            .buttonStyle(.borderedProminent)
            .tint(manager.isBlocking ? .red : .green)
            .controlSize(.large)
            .disabled(isProcessing || manager.blockedItems.isEmpty)

            if isProcessing {
                ProgressView()
                    .scaleEffect(0.8)
            }

        }
        .padding(.horizontal, 6)
    }

    private var lockButtonTitle: String {
        if !manager.isBlocking { return "Lock" }
        if lockManager.currentLock.isLocked {
            return "Locked: \(lockManager.currentLock.type.displayName)"
        }
        return "Add Lock"
    }

    private var lockButtonIcon: String {
        lockManager.currentLock.isLocked ? "lock.fill" : "lock.open"
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
                    try await startBlocking(userInitiated: true)
                }
            } catch {
                await MainActor.run {
                    if let blockError = error as? BlockError, blockError == .extensionsRequired {
                        return
                    }
                    showError(error)
                }
            }

            await MainActor.run {
                isProcessing = false
            }
        }
    }

    private func startBlocking(userInitiated: Bool = true) async throws {
        if userInitiated {
            let ready = await promptExtensionsIfNeeded()
            if !ready {
                throw BlockError.extensionsRequired
            }
        } else {
            let ready = await extensionsReadyForBlocking()
            if !ready {
                throw BlockError.extensionsRequired
            }
        }

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
        let whitelistApps = manager.effectiveWhitelistAppsForEnforcement()
        if !enabledApps.isEmpty || !whitelistApps.isEmpty {
            await MainActor.run {
                ProcessMonitor.shared.startMonitoring(
                    blockedApps: enabledApps,
                    appExceptions: manager.appExceptions,
                    whitelistOnlyApps: whitelistApps
                )
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
            manager.endBlockingSession()
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
            let whitelistApps = manager.effectiveWhitelistAppsForEnforcement()
            if !enabledApps.isEmpty || !whitelistApps.isEmpty {
                ProcessMonitor.shared.startMonitoring(
                    blockedApps: enabledApps,
                    appExceptions: manager.appExceptions,
                    whitelistOnlyApps: whitelistApps
                )
            }
        }
    }

    private func queueStartupPromptsIfNeeded() {
        guard !didCheckStartupPrompts else { return }
        didCheckStartupPrompts = true

        guard hasCompletedOnboarding else { return }

        Task {
            let ready = await extensionsReadyForBlocking()
            if !ready {
                await MainActor.run {
                    showStartupPermissions = true
                }
            }
        }
    }

    private func queueExtensionsPromptAfterPermissions() {
        guard hasCompletedOnboarding else { return }

        Task {
            let ready = await extensionsReadyForBlocking()
            if !ready {
                await MainActor.run {
                    showStartupExtensions = true
                }
            }
        }
    }

    private func promptExtensionsIfNeeded() async -> Bool {
        let ready = await ExtensionRequirementChecker.extensionsReadyForBlocking()
        if !ready {
            await MainActor.run {
                showStartupExtensions = true
            }
        }
        return ready
    }

    private func extensionsReadyForBlocking() async -> Bool {
        await ExtensionRequirementChecker.extensionsReadyForBlocking()
    }

    private func showError(_ error: Error) {
        alertMessage = error.localizedDescription
        showingAlert = true
    }
}

enum BlockError: LocalizedError {
    case noDomains
    case daemonNotRunning
    case extensionsRequired

    var errorDescription: String? {
        switch self {
        case .noDomains:
            return "No websites or apps enabled for blocking"
        case .daemonNotRunning:
            return "The background service is not running. Go to Settings → Set Up Permissions to enable it."
        case .extensionsRequired:
            return "Browser extensions are required before starting a block."
        }
    }
}

#Preview {
    MainView(manager: BlockListManager())
}
