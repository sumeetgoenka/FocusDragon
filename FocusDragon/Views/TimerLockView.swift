import SwiftUI

struct TimerLockView: View {
    @StateObject private var controller = TimerLockController()
    @State private var hours: Int = 1
    @State private var minutes: Int = 0
    @State private var showingPresets: Bool = false

    private let presets: [(String, TimeInterval)] = [
        ("15 minutes", 900),
        ("30 minutes", 1800),
        ("1 hour", 3600),
        ("2 hours", 7200),
        ("4 hours", 14400),
        ("8 hours", 28800),
        ("12 hours", 43200),
        ("24 hours", 86400)
    ]

    var body: some View {
        VStack(spacing: 20) {
            if controller.isActive {
                activeTimerView
            } else {
                timerConfigurationView
            }
        }
        .padding()
        .onAppear {
            controller.loadState()
        }
    }

    private var activeTimerView: some View {
        VStack(spacing: 20) {
            Text("Timer Lock Active")
                .font(.headline)

            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                    .frame(width: 200, height: 200)

                // Progress circle
                Circle()
                    .trim(from: 0, to: CGFloat(controller.progress))
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [.blue, .purple]),
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360)
                        ),
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.1), value: controller.progress)

                VStack(spacing: 5) {
                    Text(controller.formattedTime)
                        .font(.system(size: 40, weight: .bold, design: .monospaced))

                    Text("remaining")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Text("Block cannot be stopped until timer expires")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            progressBar
        }
    }

    private var timerConfigurationView: some View {
        VStack(spacing: 20) {
            Text("Set Timer Lock Duration")
                .font(.headline)

            // Preset buttons
            VStack(spacing: 10) {
                Text("Quick Presets")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(presets, id: \.0) { preset in
                        Button(action: {
                            applyPreset(preset.1)
                        }) {
                            Text(preset.0)
                                .font(.subheadline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }

            Divider()

            // Custom duration
            VStack(spacing: 10) {
                Text("Custom Duration")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack(spacing: 20) {
                    VStack {
                        Text("Hours")
                            .font(.caption)
                        Picker("Hours", selection: $hours) {
                            ForEach(0..<25) { hour in
                                Text("\(hour)").tag(hour)
                            }
                        }
                        .frame(width: 80)
                    }

                    Text(":")
                        .font(.title)
                        .foregroundColor(.secondary)

                    VStack {
                        Text("Minutes")
                            .font(.caption)
                        Picker("Minutes", selection: $minutes) {
                            ForEach(0..<60) { minute in
                                Text(String(format: "%02d", minute)).tag(minute)
                            }
                        }
                        .frame(width: 80)
                    }
                }

                Button("Start Timer Lock") {
                    startTimer()
                }
                .buttonStyle(.borderedProminent)
                .disabled(totalSeconds == 0)
            }
        }
    }

    private var progressBar: some View {
        VStack(spacing: 5) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                        .cornerRadius(4)

                    Rectangle()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [.blue, .purple]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(width: geometry.size.width * CGFloat(controller.progress), height: 8)
                        .cornerRadius(4)
                        .animation(.linear(duration: 0.1), value: controller.progress)
                }
            }
            .frame(height: 8)

            HStack {
                Text("Started: \(formattedStartTime)")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Spacer()

                Text(String(format: "%.1f%%", controller.progress * 100))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Actions

    private func startTimer() {
        let duration = TimeInterval(totalSeconds)
        controller.start(duration: duration)
    }

    private func applyPreset(_ duration: TimeInterval) {
        controller.start(duration: duration)
    }

    // MARK: - Helpers

    private var totalSeconds: Int {
        return hours * 3600 + minutes * 60
    }

    private var formattedStartTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: Date())
    }
}
