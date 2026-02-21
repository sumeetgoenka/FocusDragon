//
//  NotificationHelper.swift
//  FocusDragon
//
//  Created by Claude Code on 18/02/2026.
//

import Foundation
import UserNotifications

class NotificationHelper {
    static let shared = NotificationHelper()

    private init() {
        requestAuthorization()
    }

    private var notificationsEnabled: Bool {
        UserDefaults.standard.object(forKey: "enableNotifications") as? Bool ?? true
    }

    private var soundsEnabled: Bool {
        UserDefaults.standard.object(forKey: "enableSounds") as? Bool ?? true
    }

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification authorization error: \(error)")
            }
        }
    }

    private func enqueue(_ content: UNMutableNotificationContent, identifier: String? = nil) {
        guard notificationsEnabled else { return }

        if !soundsEnabled {
            content.sound = nil
        } else if content.sound == nil {
            content.sound = .default
        }

        let request = UNNotificationRequest(
            identifier: identifier ?? UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Notification error: \(error)")
            }
        }
    }

    func showBlockedAppNotification(appName: String) {
        let content = UNMutableNotificationContent()
        content.title = "Application Blocked"
        content.body = "\(appName) was blocked by FocusDragon"
        content.sound = .default
        enqueue(content)
    }

    func showBlockingStarted() {
        let content = UNMutableNotificationContent()
        content.title = "FocusDragon Active"
        content.body = "Blocking is now active"
        content.sound = .default
        enqueue(content)
    }

    func showBlockingStopped() {
        let content = UNMutableNotificationContent()
        content.title = "FocusDragon Inactive"
        content.body = "Blocking has been stopped"
        content.sound = .default
        enqueue(content)
    }

    func showTimerExpired() {
        let content = UNMutableNotificationContent()
        content.title = "Timer Lock Expired"
        content.body = "You can now stop blocking if needed"
        content.sound = .default
        content.categoryIdentifier = "TIMER_EXPIRED"
        enqueue(content, identifier: "timer-expired")
    }

    func showTimerMilestone(remaining: TimeInterval) {
        let hours = Int(remaining / 3600)
        let minutes = Int((remaining.truncatingRemainder(dividingBy: 3600)) / 60)

        let content = UNMutableNotificationContent()
        content.title = "Timer Lock Update"

        if hours > 0 {
            content.body = "\(hours) hour(s) and \(minutes) minute(s) remaining"
        } else {
            content.body = "\(minutes) minute(s) remaining"
        }

        content.sound = .default
        enqueue(content, identifier: "timer-milestone-\(UUID().uuidString)")
    }

    func showRandomTextLockActivated(text: String) {
        let content = UNMutableNotificationContent()
        content.title = "Random Text Lock Active"
        content.body = "You must type the code to unlock: \(text)"
        content.sound = .default
        enqueue(content, identifier: "random-text-lock-activated")
    }

    func showRandomTextLockUnlocked() {
        let content = UNMutableNotificationContent()
        content.title = "Random Text Lock Removed"
        content.body = "You can now stop blocking if needed"
        content.sound = .default
        enqueue(content, identifier: "random-text-lock-unlocked")
    }

    func showMaxAttemptsReached() {
        let content = UNMutableNotificationContent()
        content.title = "Lock Attempts Exhausted"
        content.body = "Maximum attempts reached. Lock cannot be removed."
        content.sound = .default
        enqueue(content, identifier: "max-attempts-reached")
    }

    func showClipboardCleared() {
        let content = UNMutableNotificationContent()
        content.title = "Clipboard Cleared"
        content.body = "Protected text was removed from clipboard"
        content.sound = .default
        enqueue(content, identifier: "clipboard-cleared")
    }

    func showRestartLockActivated(count: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Restart Lock Active"
        content.body = "\(count) system restart(s) required to unlock"
        content.sound = .default
        enqueue(content, identifier: "restart-lock-activated")
    }

    func showRestartLockDeactivated() {
        let content = UNMutableNotificationContent()
        content.title = "Restart Lock Removed"
        content.body = "You can now stop blocking if needed"
        content.sound = .default
        enqueue(content, identifier: "restart-lock-deactivated")
    }

    func showRestartLockCompleted() {
        let content = UNMutableNotificationContent()
        content.title = "Restart Lock Complete"
        content.body = "All required restarts completed. Lock removed."
        content.sound = .default
        enqueue(content, identifier: "restart-lock-completed")
    }

    func showRestartDetected(remaining: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Restart Detected"
        content.body = "\(remaining) restart(s) remaining before unlock"
        content.sound = .default
        enqueue(content, identifier: "restart-detected-\(UUID().uuidString)")
    }

    func showSystemSettingsBlocked(appName: String) {
        let content = UNMutableNotificationContent()
        content.title = "System Settings Blocked"
        content.body = "\(appName) was blocked to prevent tampering"
        content.sound = .default

        enqueue(content)
    }

    func showTerminalBlocked() {
        let content = UNMutableNotificationContent()
        content.title = "Terminal Blocked"
        content.body = "Terminal access blocked during focus session"
        content.sound = .default
        enqueue(content, identifier: UUID().uuidString)
    }

    func showActivityMonitorBlocked() {
        let content = UNMutableNotificationContent()
        content.title = "Activity Monitor Blocked"
        content.body = "Cannot view processes during focus session"
        content.sound = .default
        enqueue(content, identifier: UUID().uuidString)
    }

    func showTamperDetected(path: String) {
        let content = UNMutableNotificationContent()
        content.title = "Tamper Detected"
        content.body = "Detected modification to \(path)"
        content.sound = .default
        enqueue(content, identifier: UUID().uuidString)

        TamperDetection.shared.recordTamperAttempt()
    }

    func showDaemonRestarted() {
        let content = UNMutableNotificationContent()
        content.title = "FocusDragon Protected"
        content.body = "Daemon was restarted automatically"
        content.sound = .default
        enqueue(content, identifier: UUID().uuidString)
    }

    // MARK: - Schedule Lock Notifications

    func showScheduleActivated(schedule: ScheduleRule) {
        let content = UNMutableNotificationContent()
        content.title = "Schedule Lock Active"
        content.body = "\(schedule.name): \(schedule.formattedTimeRange) (\(schedule.formattedDays))"
        content.sound = .default
        enqueue(content, identifier: "schedule-activated")
    }

    func showScheduleDeactivated() {
        let content = UNMutableNotificationContent()
        content.title = "Schedule Lock Ended"
        content.body = "Scheduled blocking period has ended"
        content.sound = .default
        enqueue(content, identifier: "schedule-deactivated")
    }

    // MARK: - Breakable Lock Notifications

    func showBreakableLockActivated(delay: TimeInterval) {
        let seconds = Int(delay)
        let content = UNMutableNotificationContent()
        content.title = "Breakable Lock Active"
        content.body = "A \(seconds)-second delay is required before unlocking"
        content.sound = .default
        enqueue(content, identifier: "breakable-lock-activated")
    }

    func showBreakableLockReady() {
        let content = UNMutableNotificationContent()
        content.title = "Breakable Lock Ready"
        content.body = "Countdown complete — you may now unlock"
        content.sound = .default
        enqueue(content, identifier: "breakable-lock-ready")
    }

    func showExtensionDisabled(browser: String) {
        let content = UNMutableNotificationContent()
        content.title = "Extension Disabled"
        content.body = "The FocusDragon \(browser) extension is no longer responding. Please re-enable it."
        content.sound = .default

        // Use a fixed identifier per browser so we don't spam notifications
        enqueue(content, identifier: "extension-disabled-\(browser.lowercased())")
    }

    func showPomodoroBreak() {
        let content = UNMutableNotificationContent()
        content.title = "Pomodoro Break"
        content.body = "Great work! Time for a break."
        content.sound = .default
        enqueue(content, identifier: "pomodoro-break-\(UUID().uuidString)")
    }

    func showPomodoroWork() {
        let content = UNMutableNotificationContent()
        content.title = "Pomodoro Work"
        content.body = "Break over — time to focus!"
        content.sound = .default
        enqueue(content, identifier: "pomodoro-work-\(UUID().uuidString)")
    }
}
