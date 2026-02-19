import SwiftUI

struct LockSettingsView: View {
    @ObservedObject var lockManager = LockManager.shared
    @State private var selectedLockType: LockType = .none
    @State private var timerHours: Int = 1
    @State private var timerMinutes: Int = 0
    @State private var restartCount: Int = 1
    @State private var breakDelay: TimeInterval = 60
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var protectionLevel: ProtectionLevel = ProtectionLevel.current

    var body: some View {
        VStack(spacing: 20) {
            Text("Add Lock Protection")
                .font(.headline)

            protectionLevelPicker

            if lockManager.currentLock.isLocked {
                currentLockView
            } else {
                lockSelectionView
            }
        }
        .padding()
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Protection Level

    private var protectionLevelPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Protection Level")
                .font(.subheadline)
                .fontWeight(.medium)

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
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }

    private var currentLockView: some View {
        VStack(spacing: 15) {
            HStack {
                Image(systemName: "lock.fill")
                    .foregroundColor(.red)
                Text("Block is Locked")
                    .font(.title3)
                    .fontWeight(.semibold)
            }

            Text(lockManager.currentLock.type.displayName)
                .font(.subheadline)
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
            default:
                EmptyView()
            }

            Divider()

            unlockButton
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }

    private var lockSelectionView: some View {
        VStack(spacing: 15) {
            Picker("Lock Type", selection: $selectedLockType) {
                Text("No Lock").tag(LockType.none)
                Text("Timer Lock").tag(LockType.timer)
                Text("Random Text Lock").tag(LockType.randomText)
                Text("Schedule Lock").tag(LockType.schedule)
                Text("Restart Lock").tag(LockType.restart)
                Text("Breakable Lock").tag(LockType.breakable)
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
            default:
                Text("No lock protection")
                    .foregroundColor(.secondary)
            }

            if selectedLockType != .none && selectedLockType != .schedule {
                Button("Apply Lock") {
                    applyLock()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    // MARK: - Lock Configuration Views

    private var timerLockConfiguration: some View {
        VStack(spacing: 10) {
            Text("Block will unlock after:")
                .font(.subheadline)

            HStack {
                Stepper("Hours: \(timerHours)", value: $timerHours, in: 0...24)
                Stepper("Minutes: \(timerMinutes)", value: $timerMinutes, in: 0...59)
            }

            Text("Total: \(formatDuration())")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var randomTextLockConfiguration: some View {
        VStack(spacing: 10) {
            Text("You will need to type a random text to unlock")
                .font(.subheadline)
                .multilineTextAlignment(.center)

            Text("Maximum \(lockManager.configuration.maxTextAttempts) attempts")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var scheduleLockConfiguration: some View {
        ScheduleLockView()
    }

    private var restartLockConfiguration: some View {
        VStack(spacing: 10) {
            Text("Number of restarts required to unlock:")
                .font(.subheadline)

            Stepper("Restarts: \(restartCount)", value: $restartCount, in: 1...10)

            Text("You must restart your Mac \(restartCount) time(s) to unlock")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var breakableLockConfiguration: some View {
        VStack(spacing: 10) {
            Text("Delay before unlock becomes available:")
                .font(.subheadline)

            Picker("Delay", selection: $breakDelay) {
                ForEach(BreakableLockController.delayPresets, id: \.seconds) { preset in
                    Text(preset.label).tag(preset.seconds)
                }
            }

            Text("When you request unlock, you must wait this long")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Lock Status Views

    private var timerLockStatus: some View {
        VStack(spacing: 5) {
            if let remaining = lockManager.currentLock.remainingTime {
                Text("Time Remaining:")
                    .font(.caption)
                Text(formatTimeInterval(remaining))
                    .font(.title2)
                    .fontWeight(.bold)
                    .monospacedDigit()
            }
        }
    }

    private var randomTextLockStatus: some View {
        VStack(spacing: 5) {
            Text("Random Text Lock Active")
                .font(.caption)
            Text("Attempts: \(lockManager.currentLock.textAttempts)/\(lockManager.currentLock.maxAttempts)")
                .font(.subheadline)
        }
    }

    private var scheduleLockStatus: some View {
        VStack(spacing: 5) {
            Text("Schedule Lock Active")
                .font(.caption)
            if let active = ScheduleLockController.shared.activeSchedule {
                Text(active.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(active.formattedTimeRange)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var restartLockStatus: some View {
        VStack(spacing: 5) {
            Text("Restarts Required:")
                .font(.caption)
            Text("\(lockManager.currentLock.remainingRestarts ?? 0)")
                .font(.title2)
                .fontWeight(.bold)
        }
    }

    private var breakableLockStatus: some View {
        VStack(spacing: 5) {
            Text("Breakable Lock Active")
                .font(.caption)
            BreakableLockView()
        }
    }

    private var unlockButton: some View {
        Button("Attempt Unlock") {
            attemptUnlock()
        }
        .buttonStyle(.borderedProminent)
        .tint(.orange)
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

    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: interval) ?? ""
    }
}
