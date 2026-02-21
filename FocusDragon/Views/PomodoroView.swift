import SwiftUI

struct PomodoroView: View {
    @ObservedObject var manager: BlockListManager
    @StateObject private var timer = PomodoroTimer()

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 28) {
                Text(timer.isWorkSession ? "Work" : "Break")
                    .font(.title2.bold())
                    .foregroundColor(timer.isWorkSession ? .orange : .accentColor)

                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.15), lineWidth: 16)
                        .frame(width: 200, height: 200)

                    Circle()
                        .trim(from: 0, to: CGFloat(timer.remainingTime / (timer.isWorkSession ? timer.workDuration : timer.shortBreakDuration)))
                        .stroke(
                            timer.isWorkSession ? Color.orange : Color.accentColor,
                            style: StrokeStyle(lineWidth: 16, lineCap: .round)
                        )
                        .frame(width: 200, height: 200)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.3), value: timer.remainingTime)

                    Text(formatTime(timer.remainingTime))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }

                HStack(spacing: 16) {
                    Button(timer.isRunning ? "Pause" : "Start") {
                        if timer.isRunning {
                            timer.pause()
                        } else {
                            timer.start()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(timer.isWorkSession ? .orange : .accentColor)
                    .controlSize(.large)

                    Button("Reset") {
                        timer.reset()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }

                Text("Sessions completed: \(timer.sessionsCompleted)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            timer.onBlockingStateChange = { [weak manager] shouldBlock in
                manager?.isBlocking = shouldBlock
            }
        }
    }

    func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}
