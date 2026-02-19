import Foundation

class RandomTextGenerator {
    static let shared = RandomTextGenerator()

    private init() {}

    enum CharacterSet {
        case alphanumeric
        case letters
        case numbers
        case custom(String)

        var characters: String {
            switch self {
            case .alphanumeric:
                // Exclude confusing characters: 0, O, I, 1, l
                return "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
            case .letters:
                return "ABCDEFGHJKLMNPQRSTUVWXYZ"
            case .numbers:
                return "23456789"
            case .custom(let chars):
                return chars
            }
        }
    }

    func generate(length: Int = 8, using charset: CharacterSet = .alphanumeric) -> String {
        let characters = charset.characters
        return String((0..<length).map { _ in
            characters.randomElement()!
        })
    }

    func generateWithPattern() -> (text: String, pattern: String) {
        // Generate text with visual pattern for easier reading
        // e.g., "AB3-CD5-EF7" instead of "AB3CD5EF7"
        let part1 = generate(length: 3)
        let part2 = generate(length: 3)
        let part3 = generate(length: 3)

        let text = "\(part1)\(part2)\(part3)"
        let pattern = "\(part1)-\(part2)-\(part3)"

        return (text, pattern)
    }

    func generatePronounceableText(length: Int = 8) -> String {
        // Generate pronounceable text using consonant-vowel patterns
        let consonants = "BCDFGHJKLMNPRSTVWXYZ"
        let vowels = "AEIOU"

        var result = ""
        for i in 0..<length {
            if i % 2 == 0 {
                result.append(consonants.randomElement()!)
            } else {
                result.append(vowels.randomElement()!)
            }
        }

        return result
    }

    func generateWithChecksum(length: Int = 6) -> (text: String, full: String) {
        let text = generate(length: length)
        let checksum = calculateChecksum(text)
        let full = "\(text)\(checksum)"

        return (text, full)
    }

    private func calculateChecksum(_ text: String) -> String {
        let sum = text.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        let checksum = sum % 100
        return String(format: "%02d", checksum)
    }
}
