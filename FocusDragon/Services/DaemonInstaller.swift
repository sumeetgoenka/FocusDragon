//
//  DaemonInstaller.swift
//  FocusDragon
//
//  Created by Claude Code on 18/02/2026.
//

import Foundation

class DaemonInstaller {
    static let shared = DaemonInstaller()

    private let daemonPlistPath = "/Library/LaunchDaemons/com.focusdragon.daemon.plist"

    private init() {}

    // MARK: - Status Checking

    func isDaemonInstalled() -> Bool {
        return FileManager.default.fileExists(atPath: daemonPlistPath)
    }

    func isDaemonRunning() -> Bool {
        let task = Process()
        task.launchPath = "/bin/launchctl"
        task.arguments = ["list", "com.focusdragon.daemon"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            return false
        }
    }

    // MARK: - Installation

    func install(completion: @escaping (Result<Void, Error>) -> Void) {
        // Get script path from bundle
        guard let scriptPath = Bundle.main.path(forResource: "install-daemon", ofType: "sh") else {
            completion(.failure(InstallError.scriptNotFound))
            return
        }

        // Get daemon binary and plist paths (built into app bundle)
        guard let daemonPath = getDaemonPath(),
              let plistPath = getPlistPath() else {
            completion(.failure(InstallError.resourcesNotFound))
            return
        }

        // Execute script with admin privileges via osascript
        let command = """
        do shell script "bash '\(scriptPath)' '\(daemonPath)' '\(plistPath)'" with administrator privileges
        """

        executeAppleScript(command, completion: completion)
    }

    func uninstall(completion: @escaping (Result<Void, Error>) -> Void) {
        guard let scriptPath = Bundle.main.path(forResource: "uninstall-daemon", ofType: "sh") else {
            completion(.failure(InstallError.scriptNotFound))
            return
        }

        let command = """
        do shell script "bash '\(scriptPath)'" with administrator privileges
        """

        executeAppleScript(command, completion: completion)
    }

    // MARK: - Private Helpers

    private func getDaemonPath() -> String? {
        // Daemon binary should be in app bundle Resources
        return Bundle.main.path(forResource: "FocusDragonDaemon", ofType: nil)
    }

    private func getPlistPath() -> String? {
        // Plist should be in app bundle Resources
        return Bundle.main.path(forResource: "com.focusdragon.daemon", ofType: "plist")
    }

    private func executeAppleScript(_ script: String, completion: @escaping (Result<Void, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            task.launchPath = "/usr/bin/osascript"
            task.arguments = ["-e", script]

            let pipe = Pipe()
            task.standardError = pipe

            do {
                try task.run()
                task.waitUntilExit()

                if task.terminationStatus == 0 {
                    DispatchQueue.main.async {
                        completion(.success(()))
                    }
                } else {
                    let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
                    let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"

                    DispatchQueue.main.async {
                        completion(.failure(InstallError.executionFailed(errorString)))
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    enum InstallError: LocalizedError {
        case scriptNotFound
        case resourcesNotFound
        case executionFailed(String)

        var errorDescription: String? {
            switch self {
            case .scriptNotFound:
                return "Installation script not found in app bundle"
            case .resourcesNotFound:
                return "Daemon resources not found. Please rebuild the app."
            case .executionFailed(let details):
                return "Installation failed: \(details)"
            }
        }
    }
}
