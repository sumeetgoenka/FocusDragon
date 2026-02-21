import Foundation

struct FocusSession: Codable, Identifiable {
    let id: UUID
    let startTime: Date
    var endTime: Date?
    var duration: TimeInterval { (endTime ?? Date()).timeIntervalSince(startTime) }
    var blockedDomains: [String]
    var blockedApps: [String]
    var interruptionAttempts: Int = 0
    var lockType: LockType?

    var isActive: Bool { endTime == nil }
}

struct DailyStats: Codable, Identifiable {
    var id: String { dayKey }
    let date: Date
    var totalFocusTime: TimeInterval = 0
    var sessionsCount: Int = 0
    var domainsBlocked: Set<String> = []
    var appsBlocked: Set<String> = []
    var interruptionAttempts: Int = 0

    private var dayKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

struct ProductivityStreak: Codable {
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var lastSessionDate: Date?

    mutating func recordSession() {
        let today = Calendar.current.startOfDay(for: Date())

        if let last = lastSessionDate {
            let lastDay = Calendar.current.startOfDay(for: last)
            let daysBetween = Calendar.current.dateComponents([.day], from: lastDay, to: today).day ?? 0

            if daysBetween == 0 {
                // Same day, keep streak
            } else if daysBetween == 1 {
                // Next day, increment
                currentStreak += 1
                longestStreak = max(longestStreak, currentStreak)
            } else {
                // Streak broken
                currentStreak = 1
            }
        } else {
            currentStreak = 1
        }

        lastSessionDate = Date()
    }

    mutating func reset() {
        currentStreak = 0
    }
}

struct FocusStatistics: Codable {
    var sessions: [FocusSession] = []
    var dailyStats: [String: DailyStats] = [:]
    var streak: ProductivityStreak = ProductivityStreak()
    var totalFocusTime: TimeInterval = 0
    var totalSessions: Int = 0
    var totalInterruptions: Int = 0

    var averageSessionDuration: TimeInterval {
        guard totalSessions > 0 else { return 0 }
        return totalFocusTime / TimeInterval(totalSessions)
    }

    var websitesBlockedCount: Int {
        var unique = Set<String>()
        for session in sessions {
            unique.formUnion(session.blockedDomains)
        }
        return unique.count
    }

    var appsBlockedCount: Int {
        var unique = Set<String>()
        for session in sessions {
            unique.formUnion(session.blockedApps)
        }
        return unique.count
    }

    var timeSavedEstimate: TimeInterval {
        // Simple estimate: time spent in focus sessions
        return totalFocusTime
    }

    var mostBlockedDomains: [(String, Int)] {
        var counts: [String: Int] = [:]
        for session in sessions {
            for domain in session.blockedDomains {
                counts[domain, default: 0] += 1
            }
        }
        return counts.sorted { $0.value > $1.value }.prefix(10).map { ($0.key, $0.value) }
    }

    var mostBlockedApps: [(String, Int)] {
        var counts: [String: Int] = [:]
        for session in sessions {
            for app in session.blockedApps {
                counts[app, default: 0] += 1
            }
        }
        return counts.sorted { $0.value > $1.value }.prefix(10).map { ($0.key, $0.value) }
    }
}
