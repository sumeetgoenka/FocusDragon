import SwiftUI
import Charts

struct StatisticsView: View {
    @StateObject private var manager = StatisticsManager.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header
                summaryCards
                streakCard
                sessionsChart
                heatmapView
                topBlockedList
                topBlockedAppsList
                exportButton
            }
            .padding(24)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Statistics")
                    .font(.title.bold())
                Text("Your focus sessions, streaks, and blocked items.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }

    private var summaryCards: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
            StatCard(
                title: "Total Focus Time",
                value: formatDuration(manager.statistics.totalFocusTime),
                icon: "clock.fill",
                color: .blue
            )

            StatCard(
                title: "Sessions",
                value: "\(manager.statistics.totalSessions)",
                icon: "calendar",
                color: .green
            )

            StatCard(
                title: "Websites Blocked",
                value: "\(manager.statistics.websitesBlockedCount)",
                icon: "globe",
                color: .purple
            )

            StatCard(
                title: "Apps Blocked",
                value: "\(manager.statistics.appsBlockedCount)",
                icon: "app.badge.fill",
                color: .orange
            )

            StatCard(
                title: "Time Saved",
                value: formatDuration(manager.statistics.timeSavedEstimate),
                icon: "timer",
                color: .teal
            )

            StatCard(
                title: "Interruptions",
                value: "\(manager.statistics.totalInterruptions)",
                icon: "exclamationmark.triangle.fill",
                color: .red
            )
        }
    }

    private var streakCard: some View {
        GroupBox {
            VStack(spacing: 10) {
                HStack {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.orange)
                    Text("Productivity Streak")
                        .font(.headline)
                }

                HStack(spacing: 40) {
                    VStack {
                        Text("\(manager.statistics.streak.currentStreak)")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                        Text("Current")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    VStack {
                        Text("\(manager.statistics.streak.longestStreak)")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                        Text("Best")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var sessionsChart: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Text("Last 7 Days")
                    .font(.headline)

                Chart(manager.getStatsForLast(7)) { stat in
                    BarMark(
                        x: .value("Date", stat.date, unit: .day),
                        y: .value("Hours", stat.totalFocusTime / 3600)
                    )
                    .foregroundStyle(Color.accentColor.gradient)
                }
                .frame(height: 200)
            }
        }
    }

    private var topBlockedList: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 4) {
                Text("Most Blocked Sites")
                    .font(.headline)

                ForEach(manager.statistics.mostBlockedDomains.prefix(5), id: \.0) { domain, count in
                    HStack {
                        Text(domain)
                            .font(.body)
                        Spacer()
                        Text("\(count)x")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var topBlockedAppsList: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 4) {
                Text("Most Blocked Apps")
                    .font(.headline)

                ForEach(manager.statistics.mostBlockedApps.prefix(5), id: \.0) { app, count in
                    HStack {
                        Text(app)
                            .font(.body)
                        Spacer()
                        Text("\(count)x")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var heatmapView: some View {
        let days = manager.heatmapData(lastDays: 84)
        let columns = Array(repeating: GridItem(.fixed(12), spacing: 4), count: 7)

        return GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Text("Activity Heatmap (Last 12 Weeks)")
                    .font(.headline)

                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(days) { day in
                        Rectangle()
                            .fill(heatmapColor(for: day.intensity))
                            .frame(width: 12, height: 12)
                            .cornerRadius(2)
                            .help("\(day.minutes) min")
                    }
                }
            }
        }
    }

    private var exportButton: some View {
        GroupBox {
            HStack(spacing: 12) {
                Button("Export JSON") {
                    if let url = manager.exportStatistics() {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    }
                }

                Button("Export CSV") {
                    if let url = manager.exportStatisticsCSV() {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    }
                }

                Button("Export PDF") {
                    if let url = manager.exportStatisticsPDF() {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    }
                }
            }
        }
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    private func heatmapColor(for intensity: Int) -> Color {
        switch intensity {
        case 0: return Color.gray.opacity(0.2)
        case 1: return Color.accentColor.opacity(0.3)
        case 2: return Color.accentColor.opacity(0.55)
        case 3: return Color.accentColor.opacity(0.8)
        default: return Color.accentColor
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .foregroundColor(color)
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
