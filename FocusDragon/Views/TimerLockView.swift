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
                .font(AppTheme.headerFont(16))

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
                            gradient: Gradient(colors: [AppTheme.accent, AppTheme.electricBlue]),
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
                        .font(AppTheme.titleFont(36))

                    Text("remaining")
                        .font(AppTheme.bodyFont(11))
                        .foregroundColor(.secondary)
                }
            }

            Text("Block cannot be stopped until timer expires")
                .font(AppTheme.bodyFont(12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            progressBar
        }
    }

    private var timerConfigurationView: some View {
        VStack(spacing: 20) {
            Text("Set Timer Lock Duration")
                .font(AppTheme.headerFont(16))

            // Preset buttons
            VStack(spacing: 10) {
                Text("Quick Presets")
                    .font(AppTheme.bodyFont(12))
                    .foregroundColor(.secondary)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(presets, id: \.0) { preset in
                        Button(action: {
                            applyPreset(preset.1)
                        }) {
                            Text(preset.0)
                                .font(AppTheme.bodyFont(12))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }
                }
            }

            Divider()

            // Custom duration
            VStack(spacing: 10) {
                Text("Custom Duration")
                    .font(AppTheme.bodyFont(12))
                    .foregroundColor(.secondary)

                HStack(spacing: 20) {
                    VStack {
                        Text("Hours")
                            .font(AppTheme.bodyFont(11))
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
                            .font(AppTheme.bodyFont(11))
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
                .buttonStyle(PrimaryGlowButtonStyle())
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
                            gradient: Gradient(colors: [AppTheme.accent, AppTheme.electricBlue]),
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
                    .font(AppTheme.bodyFont(10))
                    .foregroundColor(.secondary)

                Spacer()

                Text(String(format: "%.1f%%", controller.progress * 100))
                    .font(AppTheme.bodyFont(10))
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
