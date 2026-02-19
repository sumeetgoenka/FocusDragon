//
//  FocusDragonApp.swift
//  FocusDragon
//
//  Created by Anay Goenka on 16/02/2026.
//

import SwiftUI
import UserNotifications
import AppKit

@main
struct FocusDragonApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        // Request notification permissions on launch
        NotificationHelper.shared.requestAuthorization()

        // Auto-start tamper detection at the persisted protection level
        let level = ProtectionLevel.current
        if level != .none {
            TamperDetection.shared.startMonitoring(level: level)
        }
        TamperDetection.shared.loadStats()

        // Backup daemon plist proactively on launch
        FileSystemMonitor.shared.backupDaemonPlist()

        // Sync lock state to disk so daemon has latest
        LockManager.shared.syncLockStateToDisk()

        // Initialize schedule lock controller so schedules fire even
        // if the user never opens the lock settings UI
        _ = ScheduleLockController.shared
    }

    var body: some Scene {
        WindowGroup {
            MainView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }

        Settings {
            SettingsView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "shield", accessibilityDescription: "FocusDragon")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Open FocusDragon", action: #selector(openMain), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    @objc func openMain() {
        NSApp.activate(ignoringOtherApps: true)
    }
}
