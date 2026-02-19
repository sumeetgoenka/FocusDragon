import Foundation
import Combine

class RandomTextLockController: ObservableObject {
    @Published var isActive: Bool = false
    @Published var randomText: String = ""
    @Published var displayText: String = ""
    @Published var attempts: Int = 0
    @Published var lastError: String?

    private let maxAttempts: Int = 5
    private let textLength: Int = 8
    private var cancellables = Set<AnyCancellable>()

    func activate() {
        let generated = RandomTextGenerator.shared.generateWithPattern()
        randomText = generated.text
        displayText = generated.pattern
        attempts = 0
        lastError = nil
        isActive = true

        saveState()
        NotificationHelper.shared.showRandomTextLockActivated(text: displayText)
    }

    func verify(_ input: String) -> Bool {
        attempts += 1
        saveState()

        let cleanInput = input.uppercased().replacingOccurrences(of: "-", with: "")
        let cleanTarget = randomText.uppercased()

        if cleanInput == cleanTarget {
            // Success
            deactivate()
            NotificationHelper.shared.showRandomTextLockUnlocked()
            return true
        } else {
            // Failure
            let remaining = maxAttempts - attempts

            if attempts >= maxAttempts {
                lastError = "Maximum attempts reached. Lock cannot be removed."
                NotificationHelper.shared.showMaxAttemptsReached()
            } else {
                lastError = "Incorrect. \(remaining) attempt(s) remaining."
            }

            return false
        }
    }

    func deactivate() {
        isActive = false
        randomText = ""
        displayText = ""
        attempts = 0
        lastError = nil
        clearState()
    }

    var canAttempt: Bool {
        return attempts < maxAttempts
    }

    var attemptsRemaining: Int {
        return max(0, maxAttempts - attempts)
    }

    // MARK: - Persistence

    private let stateKey = "randomTextLockState"

    struct State: Codable {
        let isActive: Bool
        let randomText: String
        let displayText: String
        let attempts: Int
        let createdAt: Date
    }

    private func saveState() {
        let state = State(
            isActive: isActive,
            randomText: randomText,
            displayText: displayText,
            attempts: attempts,
            createdAt: Date()
        )

        if let encoded = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(encoded, forKey: stateKey)
        }
    }

    func loadState() {
        guard let data = UserDefaults.standard.data(forKey: stateKey),
              let state = try? JSONDecoder().decode(State.self, from: data) else {
            return
        }

        isActive = state.isActive
        randomText = state.randomText
        displayText = state.displayText
        attempts = state.attempts
    }

    private func clearState() {
        UserDefaults.standard.removeObject(forKey: stateKey)
    }
}
