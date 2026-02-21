import SwiftUI

struct BreakableLockView: View {
    @StateObject private var controller = BreakableLockController.shared
    @State private var selectedDelay: TimeInterval = 60

    var body: some View {
        VStack(spacing: 20) {
            headerSection

            if controller.isCountingDown {
                countdownView
            } else if controller.isReadyToUnlock {
                readyToUnlockView
            } else {
                configurationView
            }
        }
        .padding()
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 5) {
            Image(systemName: "hourglass")
                .font(.system(size: 40))
                .foregroundColor(AppTheme.flame)

            Text("Breakable Lock")
                .font(AppTheme.headerFont(18))

            Text("Adds a non-skippable delay before unlocking")
                .font(AppTheme.bodyFont(12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Configuration (Setup)

    private var configurationView: some View {
        VStack(spacing: 15) {
            Text("Choose delay duration:")
                .font(AppTheme.bodyFont(12))
                .foregroundColor(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(BreakableLockController.delayPresets, id: \.seconds) { preset in
                    Button(action: {
                        selectedDelay = preset.seconds
                    }) {
                        Text(preset.label)
                            .font(AppTheme.bodyFont(12))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(selectedDelay == preset.seconds ? AppTheme.flame : Color(.controlBackgroundColor))
                            .foregroundColor(selectedDelay == preset.seconds ? .white : .primary)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }

            Text("When you request an unlock, you'll wait \(formatDelay(selectedDelay)) before it takes effect.")
                .font(AppTheme.bodyFont(11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 5)
        }
    }

    // MARK: - Countdown View

    private var countdownView: some View {
        VStack(spacing: 20) {
            ZStack {
                // Background circle
                Circle()
                    .stroke(AppTheme.flame.opacity(0.2), lineWidth: 8)
                    .frame(width: 150, height: 150)

                // Progress circle
                Circle()
                    .trim(from: 0, to: controller.progress)
                    .stroke(AppTheme.flame, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 150, height: 150)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.1), value: controller.progress)

                VStack(spacing: 5) {
                    Text(controller.formattedRemaining)
                        .font(AppTheme.titleFont(32))
                        .foregroundColor(AppTheme.flame)

                    Text("remaining")
                        .font(AppTheme.bodyFont(11))
                        .foregroundColor(.secondary)
                }
            }

            Text("Please wait — this countdown cannot be skipped.")
                .font(AppTheme.bodyFont(12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            ProgressView(value: controller.progress)
                .tint(AppTheme.flame)
                .padding(.horizontal, 20)
        }
    }

    // MARK: - Ready to Unlock

    private var readyToUnlockView: some View {
        VStack(spacing: 15) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(.green)

            Text("Countdown Complete")
                .font(AppTheme.headerFont(15))
                .foregroundColor(.green)

            Text("You may now unlock blocking.")
                .font(AppTheme.bodyFont(12))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Helpers

    private func formatDelay(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let minutes = total / 60
        let secs = total % 60

        if minutes > 0 && secs > 0 {
            return "\(minutes) min \(secs) sec"
        } else if minutes > 0 {
            return "\(minutes) minute\(minutes == 1 ? "" : "s")"
        } else {
            return "\(secs) second\(secs == 1 ? "" : "s")"
        }
    }
}
