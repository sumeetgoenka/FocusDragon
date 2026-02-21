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
    @StateObject private var manager = BlockListManager()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("menuBarMode") private var menuBarMode = false

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

        // Start monitoring browser extension health
        ExtensionMonitor.shared.startMonitoring()
    }

    var body: some Scene {
        WindowGroup {
            MainView(manager: manager)
                .accentColor(AppTheme.accent)
                .onAppear {
                    appDelegate.blockListManager = manager
                    if menuBarMode {
                        appDelegate.menuBarController.install(manager: manager)
                    }
                }
                .onChange(of: menuBarMode) { _, newValue in
                    if newValue {
                        appDelegate.menuBarController.install(manager: manager)
                    } else {
                        appDelegate.menuBarController.uninstall()
                    }
                }
                .sheet(isPresented: Binding(
                    get: { !hasCompletedOnboarding },
                    set: { _ in }
                )) {
                    OnboardingView(manager: manager)
                        .accentColor(AppTheme.accent)
                }
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }

        Settings {
            SettingsView(manager: manager)
                .accentColor(AppTheme.accent)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    let menuBarController = MenuBarController()
    var blockListManager: BlockListManager?
}
