import Foundation
import Combine

class ScheduleLockController: ObservableObject {
    static let shared = ScheduleLockController()

    @Published var schedules: [ScheduleRule] = []
    @Published var isActive: Bool = false
    @Published var activeSchedule: ScheduleRule?
    @Published var nextActivation: Date?

    private var timer: Timer?
    private let userDefaults = UserDefaults.standard
    private let schedulesKey = "focusDragon.schedules"

    private init() {
        loadSchedules()
        startMonitoring()
    }

    // MARK: - Schedule Management

    func addSchedule(_ schedule: ScheduleRule) {
        schedules.append(schedule)
        saveSchedules()
        checkSchedules()
    }

    func updateSchedule(_ schedule: ScheduleRule) {
        if let index = schedules.firstIndex(where: { $0.id == schedule.id }) {
            schedules[index] = schedule
            saveSchedules()
            checkSchedules()
        }
    }

    func removeSchedule(_ schedule: ScheduleRule) {
        schedules.removeAll { $0.id == schedule.id }
        saveSchedules()
        checkSchedules()
    }

    func toggleSchedule(_ schedule: ScheduleRule) {
        if let index = schedules.firstIndex(where: { $0.id == schedule.id }) {
            schedules[index].isEnabled.toggle()
            saveSchedules()
            checkSchedules()
        }
    }

    // MARK: - Monitoring

    private func startMonitoring() {
        // Check every minute
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.checkSchedules()
        }

        // Also check immediately
        checkSchedules()
    }

    private func checkSchedules() {
        let activeSchedules = schedules.filter { $0.isActiveNow() }

        if let active = activeSchedules.first {
            // Schedule is active
            if !isActive || activeSchedule?.id != active.id {
                activateSchedule(active)
            }
        } else {
            // No active schedule
            if isActive {
                deactivateSchedule()
            }
        }

        calculateNextActivation()
    }

    private func activateSchedule(_ schedule: ScheduleRule) {
        isActive = true
        activeSchedule = schedule

        // Notify to start blocking
        NotificationCenter.default.post(
            name: .scheduleLockActivated,
            object: schedule
        )

        NotificationHelper.shared.showScheduleActivated(schedule: schedule)
    }

    private func deactivateSchedule() {
        isActive = false
        activeSchedule = nil

        // Notify to stop blocking
        NotificationCenter.default.post(
            name: .scheduleLockDeactivated,
            object: nil
        )

        NotificationHelper.shared.showScheduleDeactivated()
    }

    private func calculateNextActivation() {
        guard !schedules.isEmpty else {
            nextActivation = nil
            return
        }

        let now = Date()
        let calendar = Calendar.current
        var nearestDate: Date?

        for schedule in schedules.filter({ $0.isEnabled }) {
            // Check next 7 days
            for dayOffset in 0..<7 {
                guard let targetDate = calendar.date(byAdding: .day, value: dayOffset, to: now) else {
                    continue
                }

                let weekday = Weekday(from: calendar.component(.weekday, from: targetDate))

                if schedule.days.contains(weekday) {
                    var components = calendar.dateComponents([.year, .month, .day], from: targetDate)
                    components.hour = schedule.startTime.hour
                    components.minute = schedule.startTime.minute

                    if let activationDate = calendar.date(from: components),
                       activationDate > now {
                        if nearestDate == nil || activationDate < nearestDate! {
                            nearestDate = activationDate
                        }
                    }
                }
            }
        }

        nextActivation = nearestDate
    }

    // MARK: - Preset Schedules

    func createWorkHoursSchedule() -> ScheduleRule {
        var startTime = DateComponents()
        startTime.hour = 9
        startTime.minute = 0

        var endTime = DateComponents()
        endTime.hour = 17
        endTime.minute = 0

        return ScheduleRule(
            name: "Work Hours",
            startTime: startTime,
            endTime: endTime,
            days: Weekday.weekdays
        )
    }

    func createEveningSchedule() -> ScheduleRule {
        var startTime = DateComponents()
        startTime.hour = 18
        startTime.minute = 0

        var endTime = DateComponents()
        endTime.hour = 22
        endTime.minute = 0

        return ScheduleRule(
            name: "Evening Focus",
            startTime: startTime,
            endTime: endTime,
            days: Weekday.allDays
        )
    }

    func createStudySchedule() -> ScheduleRule {
        var startTime = DateComponents()
        startTime.hour = 14
        startTime.minute = 0

        var endTime = DateComponents()
        endTime.hour = 18
        endTime.minute = 0

        return ScheduleRule(
            name: "Study Time",
            startTime: startTime,
            endTime: endTime,
            days: Weekday.weekdays
        )
    }

    // MARK: - Persistence

    private func saveSchedules() {
        if let encoded = try? JSONEncoder().encode(schedules) {
            userDefaults.set(encoded, forKey: schedulesKey)
        }
    }

    private func loadSchedules() {
        if let data = userDefaults.data(forKey: schedulesKey),
           let decoded = try? JSONDecoder().decode([ScheduleRule].self, from: data) {
            schedules = decoded
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let scheduleLockActivated = Notification.Name("scheduleLockActivated")
    static let scheduleLockDeactivated = Notification.Name("scheduleLockDeactivated")
}
