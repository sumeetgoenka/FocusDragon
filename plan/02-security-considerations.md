# FocusDragon — Security & Privacy Considerations

## Security Philosophy

FocusDragon is a **self-imposed restriction tool**, not a security product. The goal is to make bypassing **annoying enough** to keep users focused, not to make it impossible.

**Key Principle:** With physical access to a Mac, determined users can always bypass FocusDragon (Recovery Mode, reinstall macOS, etc.). This is **by design** — users should always maintain sovereignty over their computers.

## Threat Model

### What We Protect Against

✅ **Impulsive bypass attempts**
- Opening blocked site in browser
- Launching blocked app
- Quick toggle to disable blocking
- Disabling browser extension

✅ **Basic technical bypass attempts**
- Editing hosts file manually
- Killing daemon process
- Changing system time
- Using VPN to bypass DNS

✅ **Circumvention during locked blocks**
- Uninstalling app while locked
- Accessing System Settings to change time
- Force-quitting processes

### What We DON'T Protect Against

❌ **Physical access attacks**
- Booting into Recovery Mode
- Reinstalling macOS
- Removing hard drive
- Using another computer

❌ **Sophisticated technical attacks**
- Kernel-level hooks
- Rootkit installation
- Network-level proxies
- VM/containerization

❌ **Social engineering**
- Getting someone else's password
- Tricking another user to disable

**Why?** These attacks require significant effort, time, and technical knowledge. If a user is that motivated to bypass, they will. FocusDragon adds friction, not bulletproof security.

## Privacy Guarantees

### Data Collection: ZERO

FocusDragon collects **no data** whatsoever:

- ❌ No telemetry
- ❌ No analytics
- ❌ No crash reports (unless user manually submits)
- ❌ No network requests (except browser extensions syncing locally)
- ❌ No account creation
- ❌ No cloud storage

### Data Storage: Local Only

All data stays on user's Mac:

```
~/Library/Application Support/FocusDragon/
├── blocklist.json              # Block list
├── statistics.json             # Usage stats
└── preferences.plist           # Settings

/Library/Application Support/FocusDragon/
└── config.json                 # Daemon config (shared)
```

**No external servers involved.**

### Open Source Transparency

- All code is publicly auditable
- No binary blobs
- No obfuscation
- MIT License (permissive)

Users can:
- Read every line of code
- Verify no data collection
- Build from source
- Fork and modify

## Permission Requirements

FocusDragon requires specific macOS permissions. Here's what they're used for:

### Administrator Privileges (Required)

**Why:** Modify `/etc/hosts`, install LaunchDaemon

**When:** Installation and first block

**How:** `osascript` prompt for password

**Scope:** Only for specific operations, not persistent

```swift
let script = """
do shell script "echo 'Installing daemon'" with administrator privileges
"""
```

**User control:** Password dialog clearly states what's happening

### Full Disk Access (Recommended)

**Why:** Safari extension enforcement, certain file monitoring

**When:** Setup, if user enables Safari extension

**How:** User manually enables in System Settings → Privacy

**Scope:** Read-only access to browser data

**User control:** Optional, can decline

### Accessibility (Optional)

**Why:** Detect System Settings access (strict mode)

**When:** User enables "Strict Protection" mode

**How:** User manually enables in System Settings → Privacy

**Scope:** Monitor window titles to detect certain apps

**User control:** Optional, only for strict mode

### Notifications (Optional)

**Why:** Alert when apps are blocked

**When:** Setup

**How:** Standard macOS permission prompt

**Scope:** Send local notifications only

**User control:** Can decline, app still works

## Security Best Practices in Code

### 1. Input Validation

**Always validate user input:**

```swift
func addDomain(_ domain: String) {
    // Validate format
    guard domain.isValidDomain else {
        throw ValidationError.invalidDomain
    }

    // Sanitize
    let clean = domain
        .lowercased()
        .trimmingCharacters(in: .whitespaces)

    // Check length
    guard clean.count < 256 else {
        throw ValidationError.tooLong
    }

    blockedItems.append(BlockItem(domain: clean))
}

extension String {
    var isValidDomain: Bool {
        let pattern = "^([a-zA-Z0-9]([a-zA-Z0-9\\-]{0,61}[a-zA-Z0-9])?\\.)+[a-zA-Z]{2,}$"
        return self.range(of: pattern, options: .regularExpression) != nil
    }
}
```

### 2. Avoid Shell Injection

**NEVER do this:**
```swift
// BAD - Shell injection vulnerability
let command = "echo '\(userInput)' >> /etc/hosts"
shell(command)
```

**Instead, use Process with argument array:**
```swift
// GOOD - No injection possible
let process = Process()
process.launchPath = "/bin/echo"
process.arguments = [userInput]  // Safely escaped
```

### 3. Path Traversal Prevention

**Always use hardcoded paths:**
```swift
// GOOD
let hostsPath = "/etc/hosts"

// BAD - Don't construct from user input
let hostsPath = "/etc/\(userInput)"  // Could be "../../../etc/passwd"
```

### 4. Least Privilege Principle

**Main app runs as user:**
```swift
// App runs with user privileges
// Only requests admin when necessary
if needsAdminPrivileges {
    requestAdminOnce()
}
```

**Daemon runs as root (necessary):**
```xml
<!-- Only daemon runs as root -->
<key>UserName</key>
<string>root</string>
```

**Minimize root operations:**
- Read config files
- Modify /etc/hosts
- Terminate processes
- Nothing else

### 5. Secure File Permissions

```bash
# Config file readable by all, writable by root
chmod 644 /Library/Application Support/FocusDragon/config.json
chown root:wheel /Library/Application Support/FocusDragon/config.json

# Plist only readable/writable by root
chmod 644 /Library/LaunchDaemons/com.focusdragon.daemon.plist
chown root:wheel /Library/LaunchDaemons/com.focusdragon.daemon.plist

# Daemon executable only executable by root
chmod 755 /Library/Application Support/FocusDragon/FocusDragonDaemon
chown root:wheel /Library/Application Support/FocusDragon/FocusDragonDaemon
```

### 6. Safe Data Serialization

```swift
// Use Codable for type safety
struct DaemonConfig: Codable {
    var blockedDomains: [String]
    var lockState: LockState?
}

// Validate after decoding
func loadConfig() -> DaemonConfig? {
    guard let data = try? Data(contentsOf: configURL),
          var config = try? JSONDecoder().decode(DaemonConfig.self, from: data) else {
        return nil
    }

    // Validate all domains
    config.blockedDomains = config.blockedDomains.filter { $0.isValidDomain }

    return config
}
```

### 7. Error Handling Without Information Leaks

```swift
// BAD - Leaks system information
catch {
    showError("Failed: \(error)")  // Might contain paths, etc.
}

// GOOD - Generic user-facing message
catch {
    logger.error("Hosts file error: \(error)")  // Log details
    showError("Failed to apply block. Check permissions.")  // Generic to user
}
```

## Code Signing & Notarization

### Without Apple Developer Account (Free)

**Self-signing:**
```bash
codesign --force --deep --sign - FocusDragon.app
```

**User experience:**
- Gatekeeper warning: "Unidentified Developer"
- Must right-click → Open
- LaunchDaemon might have issues

**Security implications:**
- No identity verification
- Users must trust the source (GitHub)
- Can't use auto-update safely

### With Apple Developer Account ($99/year)

**Proper signing:**
```bash
codesign --force --deep \
    --sign "Developer ID Application: Your Name (TEAM_ID)" \
    --options runtime \
    FocusDragon.app
```

**Notarization:**
```bash
xcrun notarytool submit FocusDragon.app.zip \
    --apple-id your@email.com \
    --team-id TEAM_ID \
    --password app-specific-password \
    --wait
```

**Benefits:**
- No Gatekeeper warnings
- Better user trust
- LaunchDaemon works reliably
- Can use auto-update

**Recommendation:** If project gains traction, consider paying for Developer account.

## Daemon Security

### Why Run as Root?

The daemon **must** run as root to:
1. Modify `/etc/hosts` (requires root)
2. Terminate any process (requires root for non-owned processes)
3. Resist user tampering (users can't kill root processes)

**Minimizing risk:**
- Daemon code is minimal (~500 lines)
- No network access
- No user input processing
- Auditable (open source)
- Logs all actions

### LaunchDaemon Configuration

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
          "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Identity -->
    <key>Label</key>
    <string>com.focusdragon.daemon</string>

    <!-- Run as root -->
    <key>UserName</key>
    <string>root</string>

    <!-- Auto-start -->
    <key>RunAtLoad</key>
    <true/>

    <!-- Auto-restart if killed -->
    <key>KeepAlive</key>
    <true/>

    <!-- Restart throttle (prevent rapid restarts) -->
    <key>ThrottleInterval</key>
    <integer>5</integer>

    <!-- Resource limits (prevent abuse) -->
    <key>HardResourceLimits</key>
    <dict>
        <key>NumberOfFiles</key>
        <integer>256</integer>
        <key>NumberOfProcesses</key>
        <integer>10</integer>
    </dict>

    <!-- Low priority (don't interfere with system) -->
    <key>Nice</key>
    <integer>10</integer>
</dict>
</plist>
```

### Daemon Self-Protection

**Against termination:**
```swift
// KeepAlive in plist ensures auto-restart
// Additionally, log termination attempts
signal(SIGTERM) { signal in
    logger.warning("Received SIGTERM - will restart via KeepAlive")
    cleanupAndExit()
}
```

**Against tampering:**
```swift
// Check own executable hasn't been replaced
func verifyIntegrity() {
    let expectedHash = "..."  // Embedded at build time
    let actualHash = sha256(executablePath)

    if expectedHash != actualHash {
        logger.critical("Daemon binary has been tampered with!")
        // Continue running, but log
    }
}
```

## Browser Extension Security

### Extension Permissions

**Chrome manifest.json:**
```json
{
  "permissions": [
    "declarativeNetRequest",  // Block requests
    "storage",                // Store config
    "nativeMessaging"         // Communicate with app
  ],
  "host_permissions": [
    "<all_urls>"              // Necessary to block any site
  ]
}
```

**Privacy implications:**
- Extension CAN see all web requests
- Extension DOES NOT log or transmit data
- All blocking is local
- Open source for verification

### Native Messaging Security

**Host manifest restricts which extensions can connect:**
```json
{
  "name": "com.focusdragon.extension",
  "allowed_origins": [
    "chrome-extension://YOUR_EXTENSION_ID/"
  ]
}
```

**Only FocusDragon extension can connect, not arbitrary extensions.**

## Tamper Resistance Levels

### Level 0: No Protection (Default)

- Basic blocking only
- Can disable anytime
- No tamper detection

**Use case:** Casual focus aid

### Level 1: Standard Protection

- Lock mechanisms work
- Daemon protects hosts file
- Uninstall blocked during locks

**Use case:** Most users

### Level 2: Strict Protection

- + System Settings blocked during locks
- + Terminal blocked during locks
- + Activity Monitor blocked

**Use case:** Users who need stronger commitment

### Level 3: Paranoid Mode

- + All text editors blocked
- + Network tools blocked
- + Password required for app settings
- + Full tamper logging

**Use case:** Extreme procrastinators

**Recommendation:** Default to Level 1, let users opt-in to higher levels.

## Known Vulnerabilities & Mitigations

### 1. Recovery Mode Bypass

**Attack:** Boot into Recovery Mode, disable daemon, reboot
**Mitigation:** None (by design)
**Detection:** Log warning on next boot
**Philosophy:** Users should always have ultimate control

### 2. Time Change Attack

**Attack:** Change system time to expire timer lock
**Mitigation:**
- Block System Settings during locks
- Use monotonic clock (`mach_absolute_time()`) instead of `Date()`
- Detect time jumps

```swift
import Darwin

func getMonotonicTime() -> UInt64 {
    var info = mach_timebase_info()
    mach_timebase_info(&info)
    return mach_absolute_time() * UInt64(info.numer) / UInt64(info.denom)
}
```

### 3. VPN/DNS Bypass

**Attack:** Use VPN with custom DNS to bypass hosts file
**Mitigation:** Browser extensions catch this
**Status:** Partially mitigated

### 4. IP Address Access

**Attack:** Access site by IP (e.g., `142.250.185.46`)
**Mitigation:** Browser extensions block IP access
**Status:** Mitigated with extensions

### 5. Container/VM Bypass

**Attack:** Run browser in Docker/VM with own hosts file
**Mitigation:** None
**Philosophy:** That much effort = user wins

### 6. Daemon Kill via launchctl

**Attack:** `sudo launchctl unload` to disable daemon
**Mitigation:** Daemon prevents this if locked
**Status:** Mitigated during locks

```swift
// Check if being unloaded during lock
if isLocked {
    // Log attempt
    logger.warning("Attempted to unload daemon while locked")
    // Exit with error code
    exit(1)  // launchctl will keep it running
}
```

## Audit & Compliance

### Security Audit Checklist

- [ ] No hardcoded credentials
- [ ] No network requests (except extensions to own daemon)
- [ ] All user input validated
- [ ] No shell injection vulnerabilities
- [ ] File permissions set correctly
- [ ] Daemon runs with least privilege
- [ ] Error messages don't leak information
- [ ] Logs don't contain sensitive data
- [ ] No data collection/telemetry
- [ ] Open source (auditable)

### Privacy Audit Checklist

- [ ] No data sent to external servers
- [ ] No analytics/tracking
- [ ] No user accounts
- [ ] All data stored locally
- [ ] No access to user files (except hosts)
- [ ] Permissions clearly explained
- [ ] User can export/delete data
- [ ] GDPR compliant (no data = compliant)

## Responsible Disclosure

If security vulnerabilities are found:

1. **Report privately** - Don't publish publicly first
2. **Email:** security@focusdragon.dev (create this)
3. **Give time to fix** - 90 days before public disclosure
4. **Acknowledge reporters** - Credit in CHANGELOG

**Not considered vulnerabilities:**
- Recovery Mode bypass
- VM/container bypass
- Physical access attacks
- Social engineering

## Security Best Practices for Users

**DO:**
- ✅ Download from official GitHub releases only
- ✅ Verify DMG checksum (if provided)
- ✅ Review permissions requested
- ✅ Keep macOS updated
- ✅ Use strong admin password

**DON'T:**
- ❌ Download from third-party sites
- ❌ Share admin password
- ❌ Disable SIP (System Integrity Protection)
- ❌ Run modified versions from unknown sources

## Conclusion

FocusDragon balances **effectiveness** with **user sovereignty**:

- Strong enough to prevent impulsive bypass
- Transparent about what it does
- Respects user's ultimate control
- No privacy violations
- Open to security audits

Security is not about making bypass impossible — it's about making it annoying enough that users stay focused instead.

---

**Next:** Move to [phase-1/](./phase-1/) to start building!
