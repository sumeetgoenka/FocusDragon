import SwiftUI

struct RestartLockView: View {
    @StateObject private var manager = RestartLockManager.shared
    @State private var selectedCount: Int = 3

    var body: some View {
        VStack(spacing: 20) {
            if manager.isActive {
                activeLockView
            } else {
                setupView
            }
        }
        .padding()
    }

    private var setupView: some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.clockwise.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(AppTheme.flame)

            Text("Restart Lock")
                .font(AppTheme.headerFont(18))

            Text("Require system restarts before unlocking")
                .font(AppTheme.bodyFont(12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 10) {
                Label("Ultimate commitment mechanism", systemImage: "checkmark.circle")
                Label("Survives app termination", systemImage: "checkmark.circle")
                Label("Enforced by daemon", systemImage: "checkmark.circle")
            }
            .font(AppTheme.bodyFont(12))
            .foregroundColor(.secondary)

            Divider()

            VStack(spacing: 15) {
                Text("Number of Restarts Required")
                    .font(AppTheme.bodyFont(12))
                    .foregroundColor(.secondary)

                Picker("Restarts", selection: $selectedCount) {
                    ForEach(1...10, id: \.self) { count in
                        Text("\(count)").tag(count)
                    }
                }
                .pickerStyle(.segmented)

                Text(warningText)
                    .font(AppTheme.bodyFont(11))
                    .foregroundColor(AppTheme.flame)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(AppTheme.flame.opacity(0.1))
                    .cornerRadius(8)
            }

            Button("Activate Restart Lock") {
                manager.activate(requiredRestarts: selectedCount)
            }
            .buttonStyle(PrimaryGlowButtonStyle(accent: AppTheme.flame))
        }
    }

    private var activeLockView: some View {
        VStack(spacing: 25) {
            ZStack {
                Circle()
                    .fill(AppTheme.flame.opacity(0.1))
                    .frame(width: 120, height: 120)

                VStack {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 40))
                        .foregroundColor(AppTheme.flame)

                    Text("\(manager.remainingRestarts)")
                        .font(AppTheme.titleFont(28))
                        .foregroundColor(AppTheme.flame)
                }
            }

            Text("Restart Lock Active")
                .font(AppTheme.headerFont(16))

            VStack(spacing: 10) {
                Text("Restarts Remaining:")
                    .font(AppTheme.bodyFont(12))
                    .foregroundColor(.secondary)

                HStack(spacing: 10) {
                    ForEach(0..<manager.requiredRestarts, id: \.self) { index in
                        Circle()
                            .fill(index < (manager.requiredRestarts - manager.remainingRestarts) ?
                                  Color.green : Color.gray.opacity(0.3))
                            .frame(width: 20, height: 20)
                            .overlay(
                                Image(systemName: index < (manager.requiredRestarts - manager.remainingRestarts) ?
                                      "checkmark" : "arrow.clockwise")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white)
                            )
                    }
                }
            }

            VStack(spacing: 5) {
                Text("Instructions:")
                    .font(AppTheme.headerFont(14))

                Text("Restart your system \(manager.remainingRestarts) more time(s) to unlock")
                    .font(AppTheme.bodyFont(12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)

            if let uptime = BootDetector.shared.getUptime() {
                Text("System uptime: \(formatUptime(uptime))")
                    .font(AppTheme.bodyFont(11))
                    .foregroundColor(.secondary)
            }

            restartInstructions
        }
    }

    private var restartInstructions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How to Restart:")
                .font(AppTheme.headerFont(14))

            VStack(alignment: .leading, spacing: 5) {
                Label("Apple menu → Restart", systemImage: "1.circle.fill")
                Label("Click 'Restart' to confirm", systemImage: "2.circle.fill")
                Label("Wait for system to boot", systemImage: "3.circle.fill")
                Label("Counter will decrement", systemImage: "4.circle.fill")
            }
            .font(AppTheme.bodyFont(11))
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }

    private var warningText: String {
        if selectedCount == 1 {
            return "Requires 1 system restart to unlock"
        } else {
            return "Requires \(selectedCount) system restarts to unlock. This is a strong commitment!"
        }
    }

    private func formatUptime(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60

        if hours > 24 {
            let days = hours / 24
            return "\(days) day(s), \(hours % 24) hour(s)"
        } else {
            return "\(hours) hour(s), \(minutes) minute(s)"
        }
    }
}
