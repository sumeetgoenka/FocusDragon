# Phase 3: Background Service (LaunchDaemon)

**Objective:** Create a privileged background service that runs as root, enforces blocks persistently, and resists tampering.

## Overview

Phase 3 transforms FocusDragon from a user-space app into a system-level blocker by adding a LaunchDaemon that:
- Runs with root privileges
- Starts automatically on boot
- Monitors and protects `/etc/hosts`
- Enforces blocks even when main app is closed
- Automatically restarts if killed
- Provides tamper resistance

## Sections

### 3.1 LaunchDaemon Creation
- Create separate Swift executable for daemon
- Configure plist file with KeepAlive and root privileges
- Installation and loading process

### 3.2 IPC (Inter-Process Communication)
- Set up XPC service or file-based communication
- Sync block lists between app and daemon
- Command protocol (start, stop, update, status)

### 3.3 Hosts File Protection
- Continuous monitoring of `/etc/hosts` modification time
- Automatic re-application if tampered
- Lock file permissions during active blocks

### 3.4 Process Monitoring in Daemon
- Move process monitoring to daemon for persistence
- Ensure monitoring continues when app is closed
- Handle daemon lifecycle events

### 3.5 Self-Protection
- Daemon monitors its own running state
- KeepAlive ensures automatic restart
- Detect and log termination attempts

### 3.6 Installation & Uninstallation
- Installation script with sudo
- Proper cleanup on uninstall
- Handle updates and reinstalls

## Key Files

```
FocusDragonDaemon/
├── main.swift                          # Entry point
├── DaemonService.swift                 # Core service logic
├── HostsWatcher.swift                  # Monitors hosts file
├── ProcessWatcher.swift                # Monitors blocked apps
├── IPCHandler.swift                    # Handles communication
├── com.focusdragon.daemon.plist        # LaunchDaemon configuration
└── Info.plist

Scripts/
├── install-daemon.sh                   # Installation script
└── uninstall-daemon.sh                 # Cleanup script
```

## LaunchDaemon Plist Template

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.focusdragon.daemon</string>

    <key>ProgramArguments</key>
    <array>
        <string>/Library/Application Support/FocusDragon/FocusDragonDaemon</string>
    </array>

    <key>RunAtLoad</key>
    <true/>

    <key>KeepAlive</key>
    <true/>

    <key>UserName</key>
    <string>root</string>

    <key>StandardOutPath</key>
    <string>/var/log/focusdragon/daemon.log</string>

    <key>StandardErrorPath</key>
    <string>/var/log/focusdragon/daemon-error.log</string>

    <key>ThrottleInterval</key>
    <integer>5</integer>
</dict>
</plist>
```

## Installation Commands

```bash
# Copy daemon executable
sudo cp FocusDragonDaemon "/Library/Application Support/FocusDragon/"

# Copy plist
sudo cp com.focusdragon.daemon.plist /Library/LaunchDaemons/

# Set permissions
sudo chmod 644 /Library/LaunchDaemons/com.focusdragon.daemon.plist
sudo chown root:wheel /Library/LaunchDaemons/com.focusdragon.daemon.plist

# Load daemon
sudo launchctl load -w /Library/LaunchDaemons/com.focusdragon.daemon.plist

# Check status
sudo launchctl list | grep focusdragon
```

## Uninstallation Commands

```bash
# Unload daemon
sudo launchctl unload /Library/LaunchDaemons/com.focusdragon.daemon.plist

# Remove files
sudo rm /Library/LaunchDaemons/com.focusdragon.daemon.plist
sudo rm -rf "/Library/Application Support/FocusDragon/"
sudo rm -rf /var/log/focusdragon/
```

## IPC Architecture

### Option 1: XPC (Preferred)
- Structured, Apple-recommended
- Type-safe communication
- Better security

### Option 2: File-Based (Simpler)
- JSON config file: `/Library/Application Support/FocusDragon/config.json`
- Daemon watches file for changes
- Simple but less robust

### Data to Sync
```swift
struct DaemonConfig: Codable {
    var blockedDomains: [String]
    var blockedApps: [BlockedApp]
    var isBlocking: Bool
    var lockState: LockState?
}

struct BlockedApp: Codable {
    var bundleIdentifier: String
    var name: String
}

struct LockState: Codable {
    var lockType: LockType
    var expiresAt: Date?
    var randomText: String?
}
```

## Testing Criteria

### Test 1: Daemon Installation
- [ ] Daemon installs successfully
- [ ] Appears in `launchctl list`
- [ ] Runs as root (check with `ps aux | grep focusdragon`)

### Test 2: Auto-Start on Boot
- [ ] Restart Mac
- [ ] Daemon automatically running
- [ ] Blocks are still enforced

### Test 3: Hosts File Protection
- [ ] Start blocking
- [ ] Manually edit `/etc/hosts` to remove block
- [ ] Block is re-applied within seconds

### Test 4: Process Monitoring Persistence
- [ ] Block app and start blocking
- [ ] Quit main FocusDragon app
- [ ] Launch blocked app
- [ ] App still gets terminated (daemon continues monitoring)

### Test 5: Daemon Self-Protection
- [ ] Kill daemon: `sudo kill -9 <PID>`
- [ ] Daemon automatically restarts
- [ ] Blocking continues

### Test 6: IPC Communication
- [ ] Update block list in main app
- [ ] Daemon receives update within seconds
- [ ] New blocks take effect immediately

### Test 7: Uninstallation
- [ ] Run uninstall script
- [ ] Daemon stops
- [ ] All files removed
- [ ] No orphaned processes

## Security Considerations

🔒 **Running as root:** Daemon has full system access - keep code minimal and auditable
🔒 **IPC security:** Validate all incoming commands from main app
🔒 **File permissions:** Ensure config files are only writable by root
🔒 **Logging:** Log all actions for debugging and accountability

## Performance Notes

- Hosts file check interval: 5 seconds
- Config file check interval: 2 seconds
- Process monitoring interval: 1.5 seconds
- Expected CPU usage: <3% average
- Expected memory: <50MB

## Deliverables

✅ Working LaunchDaemon running as root
✅ Automatic start on boot
✅ Hosts file protection implemented
✅ Process monitoring moved to daemon
✅ IPC between app and daemon working
✅ Installation/uninstallation scripts
✅ Blocks persist after Mac restart
✅ Tamper resistance functional

## Estimated Time

**Total: 6-8 hours**
- Daemon creation: 2 hours
- IPC setup: 2 hours
- Hosts/process monitoring: 2 hours
- Installation scripts: 1 hour
- Testing: 1-2 hours

## Next Phase

After Phase 3 → **Phase 4: Lock Mechanisms & Tamper Resistance**
