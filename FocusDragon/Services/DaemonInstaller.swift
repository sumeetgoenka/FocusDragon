//
//  DaemonInstaller.swift
//  FocusDragon
//
//  Created by Claude Code on 18/02/2026.
//

import Foundation
import AppKit
import ServiceManagement

/// Manages daemon lifecycle using SMAppService (no admin password required).
///
/// **Xcode Setup Required:**
/// 1. Place the daemon plist at `Contents/Library/LaunchDaemons/com.focusdragon.daemon.plist`
///    in the main app bundle (add a "Copy Files" build phase → Absolute Path: `Contents/Library/LaunchDaemons`).
/// 2. Place the daemon executable in `Contents/MacOS/` of the main app bundle
///    (add FocusDragonDaemon as a dependency of the FocusDragon target and add a "Copy Files"
///    build phase → Destination: Executables).
/// 3. Both the app and daemon must be signed with the same Team ID.
@Observable
final class DaemonInstaller {
    static let shared = DaemonInstaller()

    private let daemonService = SMAppService.daemon(plistName: "com.focusdragon.daemon.plist")

    // MARK: - Published State

    private(set) var status: ServiceStatus = .notRegistered

    enum ServiceStatus: Equatable {
        case notRegistered
        case enabled
        case requiresApproval
        case notFound
        case unknown(String)

        var displayName: String {
            switch self {
            case .notRegistered: return "Not Installed"
            case .enabled: return "Running"
            case .requiresApproval: return "Needs Approval"
            case .notFound: return "Not Found"
            case .unknown(let s): return s
            }
        }

        var isRunning: Bool { self == .enabled }
    }

    private init() {
        refreshStatus()
    }

    // MARK: - Status

    func refreshStatus() {
        status = mapStatus(daemonService.status)
    }

    var isDaemonInstalled: Bool {
        let s = daemonService.status
        return s == .enabled || s == .requiresApproval
    }

    var isDaemonRunning: Bool {
        return daemonService.status == .enabled
    }

    // MARK: - Registration (no admin password)

    /// Register the daemon. The system will prompt the user via
    /// System Settings → General → Login Items to approve it.
    func register() throws {
        try daemonService.register()
        refreshStatus()
    }

    /// Unregister the daemon.
    func unregister() throws {
        try daemonService.unregister()
        refreshStatus()
    }

    // MARK: - Open System Settings

    /// Opens System Settings → Login Items so the user can approve the daemon.
    func openLoginItemsSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Opens System Settings → Privacy & Security → Full Disk Access.
    func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Opens System Settings → Privacy & Security → Accessibility.
    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Helpers

    private func mapStatus(_ s: SMAppService.Status) -> ServiceStatus {
        switch s {
        case .notRegistered:
            return .notRegistered
        case .enabled:
            return .enabled
        case .requiresApproval:
            return .requiresApproval
        case .notFound:
            return .notFound
        @unknown default:
            return .unknown("\(s)")
        }
    }
}
