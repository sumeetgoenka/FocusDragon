import SwiftUI

struct RandomTextLockView: View {
    @StateObject private var controller = RandomTextLockController()
    @State private var userInput: String = ""
    @State private var shakeCount: Int = 0
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 20) {
            if controller.isActive {
                activeLockView
            } else {
                setupView
            }
        }
        .padding()
        .onAppear {
            controller.loadState()
        }
    }

    private var setupView: some View {
        VStack(spacing: 15) {
            Image(systemName: "keyboard.badge.ellipsis")
                .font(.system(size: 60))
                .foregroundColor(.purple)

            Text("Random Text Lock")
                .font(.title2)
                .fontWeight(.semibold)

            Text("You'll need to type a random code to unlock")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 10) {
                Label("Creates deliberate friction", systemImage: "checkmark.circle")
                Label("Prevents impulsive unblocking", systemImage: "checkmark.circle")
                Label("Maximum 5 attempts", systemImage: "checkmark.circle")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)

            Button("Activate Random Text Lock") {
                controller.activate()
                isInputFocused = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var activeLockView: some View {
        VStack(spacing: 25) {
            // Lock icon
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: "lock.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.purple)
            }

            Text("Random Text Lock Active")
                .font(.title3)
                .fontWeight(.semibold)

            // Display random text
            randomTextDisplay

            // Input field
            if controller.canAttempt {
                inputSection
            } else {
                maxAttemptsView
            }

            // Attempts counter
            attemptsCounter
        }
    }

    private var randomTextDisplay: some View {
        VStack(spacing: 10) {
            Text("Type this code to unlock:")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text(controller.displayText)
                .font(.system(size: 36, weight: .bold, design: .monospaced))
                .tracking(5)
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(8)
                .textSelection(.enabled)

            HStack(spacing: 5) {
                Image(systemName: "info.circle")
                    .font(.caption)
                Text("Copy-paste disabled. Must type manually.")
                    .font(.caption)
            }
            .foregroundColor(.orange)
        }
    }

    private var inputSection: some View {
        VStack(spacing: 15) {
            TextField("Enter code here", text: $userInput)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 24, design: .monospaced))
                .disableAutocorrection(true)
                .focused($isInputFocused)
                .onSubmit {
                    verifyInput()
                }
                .shake(times: shakeCount)

            if let error = controller.lastError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(error)
                }
                .font(.subheadline)
                .foregroundColor(.red)
            }

            Button("Verify Code") {
                verifyInput()
            }
            .buttonStyle(.borderedProminent)
            .disabled(userInput.isEmpty)
        }
    }

    private var maxAttemptsView: some View {
        VStack(spacing: 15) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(.red)

            Text("Maximum Attempts Reached")
                .font(.headline)
                .foregroundColor(.red)

            Text("Lock cannot be removed. Block will remain active.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Text("You can only stop blocking by:")
                .font(.caption)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 5) {
                Text("• Waiting for timer to expire (if set)")
                Text("• Waiting for schedule window (if set)")
                Text("• Restarting required times (if set)")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
    }

    private var attemptsCounter: some View {
        HStack {
            ForEach(0..<5) { index in
                Circle()
                    .fill(index < controller.attempts ? Color.red : Color.gray.opacity(0.3))
                    .frame(width: 12, height: 12)
            }
        }
        .padding(.top, 10)
    }

    // MARK: - Actions

    private func verifyInput() {
        let success = controller.verify(userInput)

        if !success {
            // Shake animation on failure
            withAnimation(.default) {
                shakeCount += 1
                userInput = ""
            }

            // Refocus for retry
            isInputFocused = true
        }
    }
}

// MARK: - Shake Animation

struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 10
    var shakesPerUnit = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(
            translationX: amount * sin(animatableData * .pi * CGFloat(shakesPerUnit)),
            y: 0
        ))
    }
}

extension View {
    func shake(times: Int) -> some View {
        modifier(ShakeModifier(shakes: times))
    }
}

struct ShakeModifier: ViewModifier {
    let shakes: Int
    @State private var isShaking = false

    func body(content: Content) -> some View {
        content
            .modifier(ShakeEffect(animatableData: isShaking ? CGFloat(shakes) : 0))
            .onChange(of: shakes) { _ in
                isShaking.toggle()
            }
    }
}
