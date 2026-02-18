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
}
