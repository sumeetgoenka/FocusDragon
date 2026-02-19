import Foundation

struct ScheduleRule: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var startTime: DateComponents // Hour and minute
    var endTime: DateComponents
    var days: Set<Weekday>
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        name: String = "New Schedule",
        startTime: DateComponents,
        endTime: DateComponents,
        days: Set<Weekday>,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.startTime = startTime
        self.endTime = endTime
        self.days = days
        self.isEnabled = isEnabled
    }

    func isActiveNow() -> Bool {
        guard isEnabled else { return false }

        let now = Date()
        let calendar = Calendar.current
        let weekday = Weekday(from: calendar.component(.weekday, from: now))

        // Check if today is included
        guard days.contains(weekday) else { return false }

        // Get current time components
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)

        let currentMinutes = currentHour * 60 + currentMinute
        let startMinutes = (startTime.hour ?? 0) * 60 + (startTime.minute ?? 0)
        let endMinutes = (endTime.hour ?? 0) * 60 + (endTime.minute ?? 0)

        // Handle overnight schedules
        if endMinutes < startMinutes {
            // Schedule crosses midnight
            return currentMinutes >= startMinutes || currentMinutes < endMinutes
        } else {
            return currentMinutes >= startMinutes && currentMinutes < endMinutes
        }
    }

    var formattedTimeRange: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short

        let startDate = Calendar.current.date(from: startTime) ?? Date()
        let endDate = Calendar.current.date(from: endTime) ?? Date()

        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
    }

    var formattedDays: String {
        if days.count == 7 {
            return "Every day"
        } else if days == Weekday.weekdays {
            return "Weekdays"
        } else if days == Weekday.weekends {
            return "Weekends"
        } else {
            return days.sorted().map { $0.shortName }.joined(separator: ", ")
        }
    }
}

enum Weekday: Int, Codable, CaseIterable, Comparable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7

    init(from calendarWeekday: Int) {
        self = Weekday(rawValue: calendarWeekday) ?? .sunday
    }

    var name: String {
        switch self {
        case .sunday: return "Sunday"
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        }
    }

    var shortName: String {
        return String(name.prefix(3))
    }

    /// The Calendar weekday value (1=Sunday, 7=Saturday) — same as rawValue.
    var calendarValue: Int {
        return rawValue
    }

    static func < (lhs: Weekday, rhs: Weekday) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    static let weekdays: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]
    static let weekends: Set<Weekday> = [.saturday, .sunday]
    static let allDays: Set<Weekday> = Set(Weekday.allCases)
}
