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

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification authorization error: \(error)")
            }
        }
    }

    func showBlockedAppNotification(appName: String) {
        let content = UNMutableNotificationContent()
        content.title = "Application Blocked"
        content.body = "\(appName) was blocked by FocusDragon"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Notification error: \(error)")
            }
        }
    }

    func showBlockingStarted() {
        let content = UNMutableNotificationContent()
        content.title = "FocusDragon Active"
        content.body = "Blocking is now active"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    func showBlockingStopped() {
        let content = UNMutableNotificationContent()
        content.title = "FocusDragon Inactive"
        content.body = "Blocking has been stopped"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    func showTimerExpired() {
        let content = UNMutableNotificationContent()
        content.title = "Timer Lock Expired"
        content.body = "You can now stop blocking if needed"
        content.sound = .default
        content.categoryIdentifier = "TIMER_EXPIRED"

        let request = UNNotificationRequest(
            identifier: "timer-expired",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
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

        let request = UNNotificationRequest(
            identifier: "timer-milestone-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    func showRandomTextLockActivated(text: String) {
        let content = UNMutableNotificationContent()
        content.title = "Random Text Lock Active"
        content.body = "You must type the code to unlock: \(text)"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "random-text-lock-activated",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    func showRandomTextLockUnlocked() {
        let content = UNMutableNotificationContent()
        content.title = "Random Text Lock Removed"
        content.body = "You can now stop blocking if needed"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "random-text-lock-unlocked",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    func showMaxAttemptsReached() {
        let content = UNMutableNotificationContent()
        content.title = "Lock Attempts Exhausted"
        content.body = "Maximum attempts reached. Lock cannot be removed."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "max-attempts-reached",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    func showClipboardCleared() {
        let content = UNMutableNotificationContent()
        content.title = "Clipboard Cleared"
        content.body = "Protected text was removed from clipboard"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "clipboard-cleared",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    func showRestartLockActivated(count: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Restart Lock Active"
        content.body = "\(count) system restart(s) required to unlock"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "restart-lock-activated",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    func showRestartLockDeactivated() {
        let content = UNMutableNotificationContent()
        content.title = "Restart Lock Removed"
        content.body = "You can now stop blocking if needed"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "restart-lock-deactivated",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    func showRestartLockCompleted() {
        let content = UNMutableNotificationContent()
        content.title = "Restart Lock Complete"
        content.body = "All required restarts completed. Lock removed."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "restart-lock-completed",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    func showRestartDetected(remaining: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Restart Detected"
        content.body = "\(remaining) restart(s) remaining before unlock"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "restart-detected-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    func showSystemSettingsBlocked(appName: String) {
        let content = UNMutableNotificationContent()
        content.title = "System Settings Blocked"
        content.body = "\(appName) was blocked to prevent tampering"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    func showTerminalBlocked() {
        let content = UNMutableNotificationContent()
        content.title = "Terminal Blocked"
        content.body = "Terminal access blocked during focus session"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    func showActivityMonitorBlocked() {
        let content = UNMutableNotificationContent()
        content.title = "Activity Monitor Blocked"
        content.body = "Cannot view processes during focus session"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    func showTamperDetected(path: String) {
        let content = UNMutableNotificationContent()
        content.title = "Tamper Detected"
        content.body = "Detected modification to \(path)"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)

        TamperDetection.shared.recordTamperAttempt()
    }

    func showDaemonRestarted() {
        let content = UNMutableNotificationContent()
        content.title = "FocusDragon Protected"
        content.body = "Daemon was restarted automatically"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Schedule Lock Notifications

    func showScheduleActivated(schedule: ScheduleRule) {
        let content = UNMutableNotificationContent()
        content.title = "Schedule Lock Active"
        content.body = "\(schedule.name): \(schedule.formattedTimeRange) (\(schedule.formattedDays))"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "schedule-activated",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    func showScheduleDeactivated() {
        let content = UNMutableNotificationContent()
        content.title = "Schedule Lock Ended"
        content.body = "Scheduled blocking period has ended"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "schedule-deactivated",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Breakable Lock Notifications

    func showBreakableLockActivated(delay: TimeInterval) {
        let seconds = Int(delay)
        let content = UNMutableNotificationContent()
        content.title = "Breakable Lock Active"
        content.body = "A \(seconds)-second delay is required before unlocking"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "breakable-lock-activated",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    func showBreakableLockReady() {
        let content = UNMutableNotificationContent()
        content.title = "Breakable Lock Ready"
        content.body = "Countdown complete — you may now unlock"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "breakable-lock-ready",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }
}
