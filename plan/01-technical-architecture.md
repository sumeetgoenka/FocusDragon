# FocusDragon — Technical Architecture

## System Architecture Overview

FocusDragon consists of four main components:

```
┌─────────────────────────────────────────────────────────────┐
│                     User Space                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │         FocusDragon.app (SwiftUI)                   │   │
│  │  ┌──────────┬──────────┬──────────┬──────────────┐ │   │
│  │  │   UI     │  Models  │ Services │  Utilities   │ │   │
│  │  └──────────┴──────────┴──────────┴──────────────┘ │   │
│  │  - Block list management                            │   │
│  │  - Lock configuration                               │   │
│  │  - Statistics display                               │   │
│  │  - Settings & preferences                           │   │
│  └────────────────────┬────────────────────────────────┘   │
│                       │ IPC (XPC / File-based)             │
└───────────────────────┼────────────────────────────────────┘
                        │
┌───────────────────────┼────────────────────────────────────┐
│                 System Space (root)                        │
│  ┌────────────────────▼───────────────────────────────┐   │
│  │    FocusDragonDaemon (LaunchDaemon)                │   │
│  │  ┌──────────┬──────────┬──────────┬──────────────┐ │   │
│  │  │  Hosts   │ Process  │   Lock   │    Tamper    │ │   │
│  │  │ Watcher  │ Monitor  │ Enforcer │   Detector   │ │   │
│  │  └──────────┴──────────┴──────────┴──────────────┘ │   │
│  │  - Runs as root                                     │   │
│  │  - Auto-starts on boot                              │   │
│  │  - Enforces blocking                                │   │
│  │  - Self-protection                                  │   │
│  └──────┬──────────────────┬─────────────────────────┘   │
│         │                  │                              │
│    ┌────▼─────┐      ┌─────▼────────┐                   │
│    │/etc/hosts│      │  Running     │                   │
│    │          │      │  Processes   │                   │
│    └──────────┘      └──────────────┘                   │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│              Browser Extensions (User Space)                │
│  ┌──────────────┬──────────────┬──────────────┐            │
│  │   Chrome     │   Firefox    │    Safari    │            │
│  │  Extension   │  Extension   │  Extension   │            │
│  └──────┬───────┴──────┬───────┴──────┬───────┘            │
│         │              │              │                     │
│         └──────────────┴──────────────┘                     │
│              Native Messaging Bridge                        │
│                        │                                    │
│              ┌─────────▼─────────┐                          │
│              │  Shared Config    │                          │
│              └───────────────────┘                          │
└─────────────────────────────────────────────────────────────┘
```

## Component Details

### 1. Main Application (FocusDragon.app)

**Technology:** Swift + SwiftUI
**Runs as:** Current user
**Purpose:** User interface and configuration

**Key Responsibilities:**
- Display and manage block lists
- Configure lock mechanisms
- Show statistics and history
- Communicate with daemon
- Handle user preferences

**Architecture Pattern:** MVVM (Model-View-ViewModel)

```
FocusDragon/
├── App/
│   └── FocusDragonApp.swift        # App entry point, @main
├── Views/                          # SwiftUI views
│   ├── MainView.swift
│   ├── BlockListView.swift
│   ├── StatsView.swift
│   ├── SettingsView.swift
│   └── LockSelectionView.swift
├── Models/                         # Data models
│   ├── BlockItem.swift
│   ├── LockState.swift
│   ├── BlockingStatistics.swift
│   └── Schedule.swift
├── Services/                       # Business logic
│   ├── BlockListManager.swift
│   ├── HostsFileManager.swift
│   ├── ProcessMonitor.swift
│   ├── DaemonCommunicator.swift
│   └── StatisticsTracker.swift
└── Utilities/
    ├── NotificationHelper.swift
    └── Helpers.swift
```

**Data Flow:**
```
User Action → View → ViewModel → Service → Daemon → System
```

### 2. Background Daemon (FocusDragonDaemon)

**Technology:** Swift (command-line executable)
**Runs as:** root (via LaunchDaemon)
**Purpose:** Enforce blocks with elevated privileges

**Key Responsibilities:**
- Monitor and protect `/etc/hosts`
- Terminate blocked processes
- Enforce lock mechanisms
- Detect tamper attempts
- Persist across reboots

**Process Model:**
```
LaunchDaemon Plist → launchd → FocusDragonDaemon (PID)
                                      ↓
                               Continuous Loop
                                      ↓
                        ┌─────────────┴─────────────┐
                        │                           │
                   Check Hosts File          Check Processes
                        ↓                           ↓
                  Re-apply if changed     Terminate if blocked
```

**File Structure:**
```
FocusDragonDaemon/
├── main.swift                      # Entry point
├── DaemonService.swift             # Main service loop
├── HostsWatcher.swift              # Monitors /etc/hosts
├── ProcessWatcher.swift            # Monitors running apps
├── LockEnforcer.swift              # Enforces lock state
├── TamperDetector.swift            # Detects bypass attempts
└── IPCHandler.swift                # Handles communication
```

### 3. Shared Framework

**Technology:** Swift framework/package
**Purpose:** Share code between app and daemon

**Contents:**
```swift
// Shared data models
struct BlockItem: Codable { }
struct LockState: Codable { }
enum LockType: Codable { }

// Shared configuration format
struct DaemonConfig: Codable {
    var blockedDomains: [String]
    var blockedApps: [BlockedApp]
    var lockState: LockState?
    var isBlocking: Bool
}

// Shared utilities
extension String {
    var isValidDomain: Bool { }
}
```

### 4. Browser Extensions

**Technology:** JavaScript (Chrome/Firefox), Swift (Safari)
**Runs as:** Browser extension
**Purpose:** Redundant blocking layer

**Architecture:**
```
Extension
├── manifest.json / Info.plist
├── background.js                   # Service worker
├── content.js                      # Injected script
├── blocked.html                    # Block page
└── native-bridge                   # Native messaging
        ↓
   Main App / Daemon
        ↓
   Shared Config
```

## Data Flow & Communication

### IPC: App ↔ Daemon

**Option 1: XPC (Preferred)**
```swift
// App side
let connection = NSXPCConnection(serviceName: "com.focusdragon.daemon")
connection.remoteObjectInterface = NSXPCInterface(with: DaemonProtocol.self)
connection.resume()

let daemon = connection.remoteObjectProxy as? DaemonProtocol
daemon?.updateBlockList(domains, apps) { success in }
```

**Option 2: File-based (Simpler)**
```
/Library/Application Support/FocusDragon/
├── config.json                     # Written by app
├── status.json                     # Written by daemon
└── lock.lock                       # Lock file
```

**Configuration Format:**
```json
{
  "version": "1.0.0",
  "blockedDomains": ["youtube.com", "facebook.com"],
  "blockedApps": [
    {
      "bundleIdentifier": "com.valvesoftware.steam",
      "name": "Steam"
    }
  ],
  "isBlocking": true,
  "lockState": {
    "isLocked": true,
    "lockType": "timer",
    "expiresAt": "2024-12-31T23:59:59Z"
  }
}
```

**Daemon reads config every 2 seconds:**
```swift
Timer.scheduledTimer(withTimeInterval: 2.0) {
    let config = readConfig()
    updateBlockingRules(config)
}
```

### Extension ↔ App Communication

**Native Messaging:**
```
Browser Extension
      ↓ (Native Messaging)
Native Bridge Executable
      ↓ (Read File)
Shared Config File
      ↑ (Write File)
   Daemon
```

**Native Bridge:**
```swift
#!/usr/bin/env swift
// Reads from stdin (browser)
// Reads config file
// Writes to stdout (browser)
while true {
    let message = readMessage()
    let config = readConfig()
    sendMessage(config)
}
```

## Blocking Mechanisms

### DNS-Level Blocking (Hosts File)

**How it works:**
1. App sends block list to daemon
2. Daemon modifies `/etc/hosts`
3. DNS queries for blocked domains return `0.0.0.0`
4. Network requests fail before leaving the machine

**Format:**
```
#### FocusDragon Block Start ####
0.0.0.0 youtube.com
0.0.0.0 www.youtube.com
0.0.0.0 facebook.com
0.0.0.0 www.facebook.com
#### FocusDragon Block End ####
```

**Protection:**
- Daemon checks modification time every 5 seconds
- Re-applies block section if changed
- Works even if app is closed

**Advantages:**
- Works in ALL browsers
- Works in all apps (blocks API calls too)
- VPN-proof
- Fast (no network overhead)

**Limitations:**
- Doesn't block IP access (142.250.185.46)
- Requires DNS flush to take effect
- Can be bypassed with custom DNS (extensions catch this)

### Process-Level Blocking

**How it works:**
1. Daemon polls running processes every 1.5 seconds
2. Compares bundle IDs against block list
3. Terminates matches immediately

**Implementation:**
```swift
func checkProcesses() {
    let apps = NSWorkspace.shared.runningApplications
    for app in apps {
        if blockedBundleIDs.contains(app.bundleIdentifier) {
            app.terminate()  // Graceful
            if app.isRunning {
                kill(app.processIdentifier, SIGKILL)  // Force
            }
        }
    }
}
```

**Protection:**
- Runs as root (users can't kill daemon)
- Matches by bundle ID (can't bypass by renaming)
- Force kill after graceful attempt fails

**Advantages:**
- Works on all applications
- Can't be bypassed by renaming
- Survives app restarts

**Limitations:**
- Brief flash when app launches
- Some apps resist termination
- Background processes might respawn

### Browser Extension Blocking

**How it works:**
1. Extension loads block list from native messaging
2. Uses `declarativeNetRequest` (Chrome) or `webRequest` (Firefox)
3. Redirects blocked URLs to block page
4. Monitors for IP access

**Protection:**
- Works even if hosts file bypassed
- Blocks direct IP access
- Works in incognito mode
- Detects if extension disabled

**Advantages:**
- Catches IP-based access
- Works with DNS-over-HTTPS
- Can show custom block page

**Limitations:**
- Can be disabled by user (daemon detects)
- Browser-specific implementations
- Not as robust as system-level blocking

## State Management

### Block State
```swift
@Published var blockedItems: [BlockItem] = []
@Published var isBlocking: Bool = false
```

**Persistence:**
- UserDefaults for app state
- `/Library/Application Support/FocusDragon/config.json` for daemon state
- Both must stay in sync

### Lock State
```swift
struct LockState: Codable {
    var isLocked: Bool
    var lockType: LockType
    var expiresAt: Date?
    var randomText: String?
    var requireRestart: Bool
}
```

**Persistence:**
- Stored in config.json
- Daemon enforces lock rules
- Survives reboot

**Lock Enforcement:**
```swift
func canUnlock() -> Bool {
    switch lockState.lockType {
    case .timer:
        return Date() > lockState.expiresAt
    case .randomText:
        return userInput == lockState.randomText
    case .restartRequired:
        return hasRebootedSincelock()
    // ...
    }
}
```

## Security Model

### Privilege Separation

**User Space (Limited Privileges):**
- Main app runs as current user
- Can only modify user files
- Requests admin for daemon install

**System Space (Root Privileges):**
- Daemon runs as root
- Can modify `/etc/hosts`
- Can kill any process
- Can't be killed by user

**Trust Boundary:**
```
User → App → IPC → Daemon (trusted boundary) → System
```

### Tamper Detection

**What daemon watches for:**
1. Hosts file modification
2. Daemon process termination
3. Config file tampering
4. System time changes
5. Extension disable attempts

**Response Actions:**
- Re-apply hosts file
- Restart daemon (via KeepAlive)
- Log attempt
- Notify user (if unlocked)
- If locked: prevent action if possible

### Attack Surfaces & Mitigations

**Attack:** Edit hosts file manually
**Mitigation:** Daemon re-applies block within 5 seconds

**Attack:** Kill daemon process
**Mitigation:** LaunchDaemon `KeepAlive` auto-restarts

**Attack:** Unload LaunchDaemon
**Mitigation:** Requires `sudo`, daemon prevents if locked

**Attack:** Change system time
**Mitigation:** Daemon blocks System Settings, uses monotonic clock

**Attack:** Boot into Recovery Mode
**Mitigation:** Cannot prevent, but daemon detects on next boot

**Attack:** Use VPN to bypass hosts
**Mitigation:** Hosts file checked before VPN, extensions catch it

**Attack:** Access site by IP
**Mitigation:** Browser extensions block IP access

**Attack:** Disable browser extension
**Mitigation:** Daemon detects, alerts user, re-enables if possible

**Attack:** Use different browser
**Mitigation:** Hosts file blocks all browsers

### Secure Coding Practices

1. **Input Validation:**
   ```swift
   func addDomain(_ domain: String) {
       guard domain.isValidDomain else { return }
       // ...
   }
   ```

2. **SQL Injection Prevention:** N/A (no database)

3. **Command Injection Prevention:**
   ```swift
   // Never use shell commands with user input
   // Use Process() with arguments array instead
   ```

4. **Path Traversal Prevention:**
   ```swift
   // Never construct paths from user input
   let hostsPath = "/etc/hosts"  // Hardcoded
   ```

5. **Least Privilege:**
   - App runs as user
   - Only daemon runs as root
   - Daemon only does what requires root

## Performance Considerations

### CPU Usage

**Target:** <5% average

**Optimizations:**
- Process monitoring: 1.5s interval (not continuous)
- Hosts file check: 5s interval
- Config check: 2s interval
- Use efficient Swift collections (Set for lookups)

### Memory Usage

**Target:** <100MB total (app + daemon)

**Optimizations:**
- No large data structures
- Lazy loading for statistics
- Release resources when not needed

### Battery Impact

**Target:** Minimal (<1% battery per hour)

**Optimizations:**
- No continuous polling
- Sleep timers when inactive
- Efficient Swift code (not Electron)

### Startup Time

**Target:** <1 second to launch

**Optimizations:**
- Lazy initialization
- Async configuration loading
- Pre-compiled Swift

## Error Handling

### Graceful Degradation

**If daemon fails to start:**
- App shows warning
- Still allows configuration
- Manual hosts file blocking possible

**If hosts file locked:**
- Fall back to extension-only blocking
- Notify user of limitation

**If extension not installed:**
- App still works
- Suggest installing extensions

### Error Recovery

```swift
do {
    try applyHostsBlock()
} catch {
    // Log error
    logger.error("Failed to apply block: \(error)")

    // Notify user
    showAlert("Blocking failed: \(error.localizedDescription)")

    // Attempt recovery
    if canRetry {
        retryAfterDelay()
    }
}
```

## Logging & Debugging

**Daemon Logs:**
```
/var/log/focusdragon/
├── daemon.log              # stdout
└── daemon-error.log        # stderr
```

**App Logs:**
```swift
import os.log

let logger = Logger(subsystem: "com.focusdragon", category: "blocking")
logger.info("Starting block with \(domains.count) domains")
logger.error("Failed to communicate with daemon: \(error)")
```

**Log Levels:**
- **Debug:** Verbose, development only
- **Info:** Normal operations
- **Warning:** Recoverable issues
- **Error:** Failures

## Testing Strategy

### Unit Tests
- Model validation
- Domain validation
- Lock logic
- Date/time calculations

### Integration Tests
- App ↔ Daemon communication
- Hosts file manipulation
- Process monitoring

### UI Tests
- SwiftUI views render correctly
- User flows work end-to-end

### Manual Tests
- Install on clean Mac
- Test all lock types
- Verify tamper resistance
- Check performance

## Deployment Architecture

```
GitHub Release
     ↓
   DMG File
     ↓
User Downloads
     ↓
Mounts DMG → Copies FocusDragon.app to /Applications
     ↓
Launches App
     ↓
Onboarding → Installs Daemon
     ↓
FocusDragon Ready
```

---

**Next:** [02-security-considerations.md](./02-security-considerations.md)
