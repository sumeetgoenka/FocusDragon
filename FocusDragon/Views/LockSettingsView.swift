import SwiftUI

struct LockSettingsView: View {
    @ObservedObject var lockManager = LockManager.shared
    @State private var selectedLockType: LockType = .none
    @State private var timerHours: Int = 1
    @State private var timerMinutes: Int = 0
    @State private var restartCount: Int = 1
    @State private var breakDelay: TimeInterval = 60
    @State private var frozenHours: Int = 1
    @State private var frozenMinutes: Int = 0
    @State private var frozenMode: FrozenMode = .lockScreen
    @State private var frozenAllowedApps: [BlockItem] = []
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var protectionLevel: ProtectionLevel = ProtectionLevel.current

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(spacing: 20) {
                    headerSection
                    protectionLevelPicker

                    if lockManager.currentLock.isLocked {
                        currentLockView
                    } else {
                        lockSelectionView
                    }
                }
                .padding()
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private var headerSection: some View {
        VStack(spacing: 6) {
            Text("Lock Protection")
                .font(AppTheme.titleFont(22))
            Text("Choose a lock to prevent stopping early.")
                .font(AppTheme.bodyFont(12))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Protection Level

    private var protectionLevelPicker: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Protection Level")
                    .font(AppTheme.headerFont(15))

                Picker("Protection Level", selection: $protectionLevel) {
                    ForEach(ProtectionLevel.allCases, id: \.self) { level in
                        HStack {
                            Image(systemName: level.icon)
                            Text(level.displayName)
                        }.tag(level)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: protectionLevel) { newLevel in
                    ProtectionLevel.current = newLevel
                    TamperDetection.shared.startMonitoring(level: newLevel)
                }

                Text(protectionLevel.description)
                    .font(AppTheme.bodyFont(11))
                    .foregroundColor(.secondary)
            }
        }
    }

    private var currentLockView: some View {
        AppCard {
            VStack(spacing: 15) {
                HStack {
                    Image(systemName: "lock.fill")
                        .foregroundColor(AppTheme.flame)
                    Text("Block is Locked")
                        .font(AppTheme.headerFont(18))
                }

                Text(lockManager.currentLock.type.displayName)
                    .font(AppTheme.bodyFont(12))
                    .foregroundColor(.secondary)

                switch lockManager.currentLock.type {
                case .timer:
                    timerLockStatus
                case .randomText:
                    randomTextLockStatus
                case .schedule:
                    scheduleLockStatus
                case .restart:
                    restartLockStatus
                case .breakable:
                    breakableLockStatus
                case .frozen:
                    frozenLockStatus
                default:
                    EmptyView()
                }

                Divider()

                unlockButton
            }
        }
    }

    private var lockSelectionView: some View {
        AppCard {
            VStack(spacing: 15) {
                Picker("Lock Type", selection: $selectedLockType) {
                    Text("No Lock").tag(LockType.none)
                    Text("Timer Lock").tag(LockType.timer)
                    Text("Random Text Lock").tag(LockType.randomText)
                    Text("Schedule Lock").tag(LockType.schedule)
                    Text("Restart Lock").tag(LockType.restart)
                    Text("Breakable Lock").tag(LockType.breakable)
                    Text("Frozen Turkey").tag(LockType.frozen)
                }
                .pickerStyle(.segmented)

                switch selectedLockType {
                case .timer:
                    timerLockConfiguration
                case .randomText:
                    randomTextLockConfiguration
                case .schedule:
                    scheduleLockConfiguration
                case .restart:
                    restartLockConfiguration
                case .breakable:
                    breakableLockConfiguration
                case .frozen:
                    frozenLockConfiguration
                default:
                    Text("No lock protection")
                        .font(AppTheme.bodyFont(12))
                        .foregroundColor(.secondary)
                }

                if selectedLockType != .none && selectedLockType != .schedule {
                    Button("Apply Lock") {
                        applyLock()
                    }
                    .buttonStyle(PrimaryGlowButtonStyle())
                }
            }
        }
    }

    // MARK: - Lock Configuration Views

    private var timerLockConfiguration: some View {
        VStack(spacing: 10) {
            Text("Block will unlock after:")
                .font(AppTheme.bodyFont(12))

            HStack {
                Stepper("Hours: \(timerHours)", value: $timerHours, in: 0...24)
                Stepper("Minutes: \(timerMinutes)", value: $timerMinutes, in: 0...59)
            }

            Text("Total: \(formatDuration())")
                .font(AppTheme.bodyFont(11))
                .foregroundColor(.secondary)
        }
    }

    private var randomTextLockConfiguration: some View {
        VStack(spacing: 10) {
            Text("You will need to type a random text to unlock")
                .font(AppTheme.bodyFont(12))
                .multilineTextAlignment(.center)

            Text("Maximum \(lockManager.configuration.maxTextAttempts) attempts")
                .font(AppTheme.bodyFont(11))
                .foregroundColor(.secondary)
        }
    }

    private var scheduleLockConfiguration: some View {
        ScheduleLockView()
    }

    private var restartLockConfiguration: some View {
        VStack(spacing: 10) {
            Text("Number of restarts required to unlock:")
                .font(AppTheme.bodyFont(12))

            Stepper("Restarts: \(restartCount)", value: $restartCount, in: 1...10)

            Text("You must restart your Mac \(restartCount) time(s) to unlock")
                .font(AppTheme.bodyFont(11))
                .foregroundColor(.secondary)
        }
    }

    private var breakableLockConfiguration: some View {
        VStack(spacing: 10) {
            Text("Delay before unlock becomes available:")
                .font(AppTheme.bodyFont(12))

            Picker("Delay", selection: $breakDelay) {
                ForEach(BreakableLockController.delayPresets, id: \.seconds) { preset in
                    Text(preset.label).tag(preset.seconds)
                }
            }

            Text("When you request unlock, you must wait this long")
                .font(AppTheme.bodyFont(11))
                .foregroundColor(.secondary)
        }
    }

    private var frozenLockConfiguration: some View {
        VStack(spacing: 12) {
            Text("Frozen Turkey Mode")
                .font(AppTheme.headerFont(14))

            HStack {
                Stepper("Hours: \(frozenHours)", value: $frozenHours, in: 0...24)
                Stepper("Minutes: \(frozenMinutes)", value: $frozenMinutes, in: 0...59)
            }

            Picker("Mode", selection: $frozenMode) {
                Text("Lock Screen").tag(FrozenMode.lockScreen)
                Text("Logout").tag(FrozenMode.logout)
                Text("Shutdown").tag(FrozenMode.shutdown)
                Text("Limited Access").tag(FrozenMode.limitedAccess)
            }
            .pickerStyle(.segmented)

            if frozenMode == .limitedAccess {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Allowed Apps")
                        .font(AppTheme.bodyFont(11))
                        .foregroundColor(.secondary)
                    Button("Add Allowed App") {
                        AppSelector.shared.selectApplication { item in
                            guard let item else { return }
                            if !frozenAllowedApps.contains(where: { $0.bundleIdentifier == item.bundleIdentifier }) {
                                frozenAllowedApps.append(item)
                            }
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    ForEach(frozenAllowedApps, id: \.id) { app in
                        HStack {
                            Text(app.appName ?? app.displayName)
                            Spacer()
                            Button(role: .destructive) {
                                frozenAllowedApps.removeAll { $0.id == app.id }
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(SecondaryButtonStyle())
                            .controlSize(.small)
                        }
                    }
                }
            }

            Text("Duration: \(formatFrozenDuration())")
                .font(AppTheme.bodyFont(11))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Lock Status Views

    private var timerLockStatus: some View {
        VStack(spacing: 5) {
            if let remaining = lockManager.currentLock.remainingTime {
                Text("Time Remaining:")
                    .font(AppTheme.bodyFont(11))
                Text(formatTimeInterval(remaining))
                    .font(AppTheme.titleFont(22))
                    .monospacedDigit()
            }
        }
    }

    private var randomTextLockStatus: some View {
        VStack(spacing: 5) {
            Text("Random Text Lock Active")
                .font(AppTheme.bodyFont(11))
            Text("Attempts: \(lockManager.currentLock.textAttempts)/\(lockManager.currentLock.maxAttempts)")
                .font(AppTheme.bodyFont(12))
        }
    }

    private var scheduleLockStatus: some View {
        VStack(spacing: 5) {
            Text("Schedule Lock Active")
                .font(AppTheme.bodyFont(11))
            if let active = ScheduleLockController.shared.activeSchedule {
                Text(active.name)
                    .font(AppTheme.bodyFont(12))
                Text(active.formattedTimeRange)
                    .font(AppTheme.bodyFont(11))
                    .foregroundColor(.secondary)
            }
        }
    }

    private var restartLockStatus: some View {
        VStack(spacing: 5) {
            Text("Restarts Required:")
                .font(AppTheme.bodyFont(11))
            Text("\(lockManager.currentLock.remainingRestarts ?? 0)")
                .font(AppTheme.titleFont(22))
        }
    }

    private var breakableLockStatus: some View {
        VStack(spacing: 5) {
            Text("Breakable Lock Active")
                .font(AppTheme.bodyFont(11))
            BreakableLockView()
        }
    }

    private var frozenLockStatus: some View {
        VStack(spacing: 5) {
            if let remaining = lockManager.currentLock.remainingTime {
                Text("Frozen Mode Active")
                    .font(AppTheme.bodyFont(11))
                Text(formatTimeInterval(remaining))
                    .font(AppTheme.titleFont(22))
                    .monospacedDigit()
                if let mode = lockManager.currentLock.frozenMode {
                    Text(mode.displayName)
                        .font(AppTheme.bodyFont(10))
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var unlockButton: some View {
        Button("Attempt Unlock") {
            attemptUnlock()
        }
        .buttonStyle(PrimaryGlowButtonStyle(accent: AppTheme.flame))
    }

    // MARK: - Actions

    private func applyLock() {
        do {
            switch selectedLockType {
            case .timer:
                let duration = TimeInterval(timerHours * 3600 + timerMinutes * 60)
                try lockManager.createTimerLock(duration: duration)
            case .randomText:
                lockManager.createRandomTextLock()
            case .schedule:
                // Schedule locks are auto-managed by ScheduleLockController
                // They activate when a schedule rule matches the current time
                if ScheduleLockController.shared.schedules.isEmpty {
                    showError = true
                    errorMessage = "Add at least one schedule rule first."
                }
                return
            case .restart:
                try lockManager.createRestartLock(numberOfRestarts: restartCount)
            case .breakable:
                try lockManager.createBreakableLock(delay: breakDelay)
            case .frozen:
                let duration = TimeInterval(frozenHours * 3600 + frozenMinutes * 60)
                let allowed = frozenAllowedApps.compactMap { $0.bundleIdentifier }
                try lockManager.createFrozenLock(duration: duration, mode: frozenMode, allowedApps: allowed)
            default:
                break
            }
        } catch {
            showError = true
            errorMessage = error.localizedDescription
        }
    }

    private func attemptUnlock() {
        let result = lockManager.attemptUnlock()
        if case .failure(let failure) = result {
            showError = true
            errorMessage = failure.message
        }
    }

    // MARK: - Helpers

    private func formatDuration() -> String {
        let total = timerHours * 3600 + timerMinutes * 60
        return formatTimeInterval(TimeInterval(total))
    }

    private func formatFrozenDuration() -> String {
        let total = frozenHours * 3600 + frozenMinutes * 60
        return formatTimeInterval(TimeInterval(total))
    }

    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: interval) ?? ""
    }
}
