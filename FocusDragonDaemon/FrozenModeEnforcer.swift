//
//  FrozenModeEnforcer.swift
//  FocusDragonDaemon
//
//  Enforces Frozen Turkey mode actions while a lock is active.
//

import Foundation
import SystemConfiguration

final class FrozenModeEnforcer {
    private let checkInterval: TimeInterval = 5.0
    private var timer: Timer?
    private var state: FrozenState?
    private var isBlocking = false
    private var lastActionAt: Date?

    func update(state: FrozenState?, isBlocking: Bool) {
        self.state = state
        self.isBlocking = isBlocking

        if let s = state, s.isActive, isBlocking {
            start()
        } else {
            stop()
        }
    }

    private func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer!, forMode: .common)
        tick()
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
        lastActionAt = nil
    }

    private func tick() {
        guard let state = state, state.isActive, isBlocking else { return }
        if state.isExpired { return }

        switch state.mode {
        case .limitedAccess:
            return
        case .lockScreen:
            if shouldTriggerAction(interval: 15) {
                triggerLockScreen()
            }
        case .logout:
            if shouldTriggerAction(interval: 60) {
                triggerLogout()
            }
        case .shutdown:
            if shouldTriggerAction(interval: 60) {
                triggerShutdown()
            }
        }
    }

    private func shouldTriggerAction(interval: TimeInterval) -> Bool {
        if let last = lastActionAt, Date().timeIntervalSince(last) < interval {
            return false
        }
        lastActionAt = Date()
        return true
    }

    private func triggerLockScreen() {
        runAsConsoleUser(executable: "/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession", arguments: ["-suspend"])
    }

    private func triggerLogout() {
        runAsConsoleUser(executable: "/usr/bin/osascript", arguments: ["-e", "tell application \"System Events\" to log out"])
    }

    private func triggerShutdown() {
        _ = runTask("/sbin/shutdown", ["-h", "now"])
    }

    private func runAsConsoleUser(executable: String, arguments: [String]) {
        guard let uid = consoleUserUID() else { return }
        let args = ["asuser", "\(uid)", executable] + arguments
        _ = runTask("/bin/launchctl", args)
    }

    private func consoleUserUID() -> uid_t? {
        var uid: uid_t = 0
        var gid: gid_t = 0
        guard let username = SCDynamicStoreCopyConsoleUser(nil, &uid, &gid) as String?,
              !username.isEmpty,
              username != "loginwindow" else {
            return nil
        }
        return uid
    }

    private func runTask(_ path: String, _ args: [String]) -> Int32 {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: path)
        task.arguments = args
        task.standardOutput = Pipe()
        task.standardError = Pipe()

        do {
            try task.run()
        } catch {
            return -1
        }

        task.waitUntilExit()
        return task.terminationStatus
    }
}
