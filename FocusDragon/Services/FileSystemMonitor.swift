import Foundation

class FileSystemMonitor {
    static let shared = FileSystemMonitor()

    private let protectedPaths: [String] = [
        "/Library/LaunchDaemons/com.focusdragon.daemon.plist",
        "/Library/Application Support/FocusDragon/",
        "/etc/hosts"
    ]

    private var fileDescriptors: [Int32] = []
    private var dispatchSources: [DispatchSourceFileSystemObject] = []

    func startMonitoring() {
        for path in protectedPaths {
            monitorPath(path)
        }
    }

    func stopMonitoring() {
        for source in dispatchSources {
            source.cancel()
        }

        for fd in fileDescriptors {
            close(fd)
        }

        dispatchSources.removeAll()
        fileDescriptors.removeAll()
    }

    private func monitorPath(_ path: String) {
        let fd = open(path, O_EVTONLY)
        guard fd >= 0 else {
            print("FileSystemMonitor: Failed to open \(path)")
            return
        }

        fileDescriptors.append(fd)

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename],
            queue: DispatchQueue.global()
        )

        source.setEventHandler { [weak self] in
            self?.handleFileSystemEvent(path: path)
        }

        source.resume()
        dispatchSources.append(source)
    }

    private func handleFileSystemEvent(path: String) {
        print("FileSystemMonitor: Detected modification to \(path)")

        // Take corrective action
        if path.contains("daemon.plist") {
            restoreDaemonPlist()
        } else if path.contains("FocusDragon") {
            restoreConfigFiles()
        } else if path.contains("hosts") {
            restoreHostsFile()
        }

        NotificationHelper.shared.showTamperDetected(path: path)
    }

    private let daemonPlistPath = "/Library/LaunchDaemons/com.focusdragon.daemon.plist"
    private let daemonPlistBackupPath = "/Library/Application Support/FocusDragon/daemon_plist_backup.plist"
    private let configDirPath = "/Library/Application Support/FocusDragon/"

    private func restoreDaemonPlist() {
        print("FileSystemMonitor: Daemon plist modified, attempting restore")

        // If the plist was deleted, restore from backup
        if !FileManager.default.fileExists(atPath: daemonPlistPath) {
            if FileManager.default.fileExists(atPath: daemonPlistBackupPath) {
                do {
                    try FileManager.default.copyItem(atPath: daemonPlistBackupPath, toPath: daemonPlistPath)
                    print("FileSystemMonitor: Daemon plist restored from backup")

                    // Re-load the daemon
                    let task = Process()
                    task.launchPath = "/bin/launchctl"
                    task.arguments = ["load", daemonPlistPath]
                    try? task.run()
                } catch {
                    print("FileSystemMonitor: Failed to restore daemon plist: \(error)")
                }
            }
        } else {
            // Plist was modified — back it up in case it was corrupted, then re-load
            backupDaemonPlist()
        }
    }

    private func restoreConfigFiles() {
        print("FileSystemMonitor: Config files modified, checking integrity")

        // Ensure the config directory still exists
        if !FileManager.default.fileExists(atPath: configDirPath) {
            do {
                try FileManager.default.createDirectory(
                    atPath: configDirPath,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
                print("FileSystemMonitor: Recreated config directory")
            } catch {
                print("FileSystemMonitor: Failed to recreate config dir: \(error)")
            }
        }

        // If lock_state.json was deleted while a lock is active, re-write it
        let lockStatePath = configDirPath + "lock_state.json"
        if !FileManager.default.fileExists(atPath: lockStatePath) {
            LockManager.shared.syncLockStateToDisk()
            print("FileSystemMonitor: Re-synced lock state to disk")
        }
    }

    private func restoreHostsFile() {
        print("FileSystemMonitor: Hosts file modified externally")
        // The daemon's HostsWatcher will detect this and re-apply blocks.
        // Force a daemon config reload to ensure it picks up the change quickly.
        let task = Process()
        task.launchPath = "/bin/launchctl"
        task.arguments = ["kickstart", "-k", "system/com.focusdragon.daemon"]
        try? task.run()
    }

    /// Create a backup of the daemon plist for future restoration.
    func backupDaemonPlist() {
        guard FileManager.default.fileExists(atPath: daemonPlistPath) else { return }
        do {
            if FileManager.default.fileExists(atPath: daemonPlistBackupPath) {
                try FileManager.default.removeItem(atPath: daemonPlistBackupPath)
            }
            try FileManager.default.copyItem(atPath: daemonPlistPath, toPath: daemonPlistBackupPath)
            print("FileSystemMonitor: Daemon plist backed up")
        } catch {
            print("FileSystemMonitor: Failed to backup daemon plist: \(error)")
        }
    }
}
