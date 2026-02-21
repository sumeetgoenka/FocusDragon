import Foundation
import Combine
import AppKit

class StatisticsManager: ObservableObject {
    static let shared = StatisticsManager()

    @Published var statistics = FocusStatistics()
    @Published var currentSession: FocusSession?

    private let storageKey = "focusStatistics"
    private var timer: Timer?

    private init() {
        loadStatistics()
        startPeriodicSave()
    }

    // MARK: - Session Management

    func startSession(domains: [String], apps: [String], lockType: LockType?) {
        let session = FocusSession(
            id: UUID(),
            startTime: Date(),
            blockedDomains: domains,
            blockedApps: apps,
            lockType: lockType
        )

        currentSession = session
        statistics.sessions.append(session)
        statistics.streak.recordSession()
        saveStatistics()

        NotificationCenter.default.post(name: .sessionStarted, object: session)
    }

    func endSession() {
        guard var session = currentSession else { return }

        session.endTime = Date()

        // Update session in array
        if let index = statistics.sessions.firstIndex(where: { $0.id == session.id }) {
            statistics.sessions[index] = session
        }

        // Update totals
        statistics.totalFocusTime += session.duration
        statistics.totalSessions += 1

        // Update daily stats
        updateDailyStats(for: session)

        currentSession = nil
        saveStatistics()

        NotificationCenter.default.post(name: .sessionEnded, object: session)
    }

    func recordInterruption() {
        currentSession?.interruptionAttempts += 1
        statistics.totalInterruptions += 1
        saveStatistics()
    }

    // MARK: - Daily Stats

    private func updateDailyStats(for session: FocusSession) {
        let dateKey = dayKey(for: session.startTime)

        var dayStats = statistics.dailyStats[dateKey] ?? DailyStats(date: session.startTime)
        dayStats.totalFocusTime += session.duration
        dayStats.sessionsCount += 1
        dayStats.domainsBlocked.formUnion(session.blockedDomains)
        dayStats.appsBlocked.formUnion(session.blockedApps)
        dayStats.interruptionAttempts += session.interruptionAttempts

        statistics.dailyStats[dateKey] = dayStats
    }

    private func dayKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    func getStatsForLast(_ days: Int) -> [DailyStats] {
        let calendar = Calendar.current
        var stats: [DailyStats] = []

        for i in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: -i, to: Date()) else { continue }
            let key = dayKey(for: date)

            if let dayStats = statistics.dailyStats[key] {
                stats.append(dayStats)
            } else {
                stats.append(DailyStats(date: date))
            }
        }

        return stats.reversed()
    }

    // MARK: - Persistence

    private func saveStatistics() {
        if let encoded = try? JSONEncoder().encode(statistics) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }

    private func loadStatistics() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(FocusStatistics.self, from: data) {
            statistics = decoded
        }
    }

    private func startPeriodicSave() {
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.saveStatistics()
        }
    }

    func exportStatistics() -> URL? {
        guard let encoded = try? JSONEncoder().encode(statistics) else { return nil }

        let filename = "focusdragon-stats-\(Date().timeIntervalSince1970).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

        try? encoded.write(to: url)
        return url
    }

    func exportStatisticsCSV() -> URL? {
        var lines: [String] = []
        lines.append("date,total_focus_minutes,sessions,domains_blocked,apps_blocked,interruptions")

        for stat in statistics.dailyStats.values.sorted(by: { $0.date < $1.date }) {
            let minutes = Int(stat.totalFocusTime / 60)
            let domains = stat.domainsBlocked.count
            let apps = stat.appsBlocked.count
            let line = "\(dayKey(for: stat.date)),\(minutes),\(stat.sessionsCount),\(domains),\(apps),\(stat.interruptionAttempts)"
            lines.append(line)
        }

        let content = lines.joined(separator: "\n")
        let filename = "focusdragon-stats-\(Date().timeIntervalSince1970).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func exportStatisticsPDF() -> URL? {
        let filename = "focusdragon-stats-\(Date().timeIntervalSince1970).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

        let summary = statisticsSummaryText()
        let data = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            return nil
        }

        context.beginPDFPage(nil)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.textColor
        ]

        let attributed = NSAttributedString(string: summary, attributes: attrs)
        let textRect = CGRect(x: 36, y: 36, width: 540, height: 720)
        attributed.draw(in: textRect)
        context.endPDFPage()
        context.closePDF()

        data.write(to: url, atomically: true)
        return url
    }

    func heatmapData(lastDays: Int) -> [HeatmapDay] {
        let calendar = Calendar.current
        var days: [HeatmapDay] = []

        for i in 0..<lastDays {
            guard let date = calendar.date(byAdding: .day, value: -i, to: Date()) else { continue }
            let key = dayKey(for: date)
            let stat = statistics.dailyStats[key]
            let minutes = stat.map { Int($0.totalFocusTime / 60) } ?? 0
            days.append(HeatmapDay(date: date, minutes: minutes))
        }

        return days.reversed()
    }

    private func statisticsSummaryText() -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .full
        let total = formatter.string(from: statistics.totalFocusTime) ?? "0 minutes"

        var lines: [String] = []
        lines.append("FocusDragon Statistics")
        lines.append("----------------------")
        lines.append("Total focus time: \(total)")
        lines.append("Sessions: \(statistics.totalSessions)")
        lines.append("Current streak: \(statistics.streak.currentStreak) days")
        lines.append("Longest streak: \(statistics.streak.longestStreak) days")
        lines.append("Websites blocked: \(statistics.websitesBlockedCount)")
        lines.append("Apps blocked: \(statistics.appsBlockedCount)")
        lines.append("")
        lines.append("Top blocked sites:")
        for (domain, count) in statistics.mostBlockedDomains.prefix(5) {
            lines.append("- \(domain) (\(count)x)")
        }
        lines.append("")
        lines.append("Top blocked apps:")
        for (app, count) in statistics.mostBlockedApps.prefix(5) {
            lines.append("- \(app) (\(count)x)")
        }
        return lines.joined(separator: "\n")
    }
}

struct HeatmapDay: Identifiable {
    let id = UUID()
    let date: Date
    let minutes: Int

    var intensity: Int {
        switch minutes {
        case 0: return 0
        case 1..<30: return 1
        case 30..<120: return 2
        case 120..<240: return 3
        default: return 4
        }
    }
}

extension Notification.Name {
    static let sessionStarted = Notification.Name("sessionStarted")
    static let sessionEnded = Notification.Name("sessionEnded")
}
