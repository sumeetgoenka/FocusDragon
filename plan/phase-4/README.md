# Phase 4: Lock Mechanisms & Tamper Resistance

**Objective:** Implement lock modes that prevent users from easily disabling blocks, making FocusDragon the toughest blocker available.

## Overview

Phase 4 adds the critical "lock" features that make FocusDragon tamper-resistant:
- Timer-based locks (block for X hours/days)
- Random text unlock (type random string to disable)
- Schedule locks (active during specific times)
- Restart-required locks
- Breakable locks (with friction)
- Anti-tamper mechanisms

## Lock Types

### 1. Timer Lock
**Usage:** "Block for 2 hours"
- Countdown timer
- Cannot disable until timer expires
- Persists across reboots
- Display remaining time

### 2. Random Text Lock
**Usage:** "Type this random string to unlock"
- Generate random 30-character string
- Must type exactly to unlock
- Case-sensitive
- Prevents impulsive disabling

### 3. Schedule Lock
**Usage:** "Block during work hours (9 AM - 5 PM weekdays)"
- Time range based
- Day-of-week support
- Automatically enables/disables
- Multiple schedules possible

### 4. Restart Required Lock
**Usage:** "Must restart Mac to unlock"
- Ultimate commitment device
- Flag survives reboot
- Manual unlock after restart
- Highest friction

### 5. Breakable Lock
**Usage:** "Can disable but with 60-second delay"
- Delay before unlock
- Countdown that can't be skipped
- Adds friction to impulsive decisions
- Customizable delay

## Lock State Model

```swift
enum LockType: String, Codable {
    case none
    case timer
    case randomText
    case schedule
    case restartRequired
    case breakable
}

struct LockState: Codable {
    var isLocked: Bool
    var lockType: LockType
    var expiresAt: Date?              // For timer lock
    var randomText: String?            // For random text lock
    var schedules: [Schedule]?         // For schedule lock
    var requireRestart: Bool           // For restart lock
    var breakDelay: TimeInterval?      // For breakable lock
    var lockedAt: Date
}

struct Schedule: Codable {
    var weekdays: Set<Int>  // 1 = Sunday, 7 = Saturday
    var startTime: TimeComponents
    var endTime: TimeComponents
}

struct TimeComponents: Codable {
    var hour: Int
    var minute: Int
}
```

## Anti-Tamper Mechanisms

### Level 1: Basic Protection
- Daemon prevents hosts file modification
- Process monitoring can't be stopped while locked
- Uninstaller disabled during locks

### Level 2: Moderate Protection
- Block System Settings during locks (prevents time change)
- Block Terminal during locks (optional strict mode)
- Block Activity Monitor during locks
- Detect daemon kill attempts and log

### Level 3: Aggressive Protection (Optional)
- Block all text editors
- Block Recovery Mode detection
- Block network reconfiguration apps
- Require password for settings changes

### Level 4: Nuclear Option
- "Frozen Turkey" mode: locks entire computer
- Logout/shutdown only options
- No app access during block

## Implementation Sections

### 4.1 Lock State Management
- Create lock models
- Persistence across reboots
- Lock validation logic
- UI for lock selection

### 4.2 Timer Lock Implementation
- Countdown timer
- Expiration checking
- Time remaining display
- Daemon enforcement

### 4.3 Random Text Lock
- Random string generation
- Input validation UI
- Unlock attempt logging

### 4.4 Schedule Lock
- Schedule parser and validator
- Current time checking
- Automatic enable/disable
- UI for schedule configuration

### 4.5 Restart Lock
- Reboot detection
- Persistent flag management
- Clear lock UI flow

### 4.6 Breakable Lock
- Countdown UI
- Non-skippable delay
- Configurable delay length

### 4.7 Anti-Tamper Implementation
- System Settings blocking
- Terminal/Activity Monitor blocking
- Time change detection
- Tamper attempt logging

### 4.8 Settings Protection
- Password protect settings
- Prevent uninstall during locks
- Secure storage of lock state

## Key Files

```
FocusDragon/Models/
├── LockType.swift
├── LockState.swift
└── Schedule.swift

FocusDragon/Services/
├── LockManager.swift
├── AntiTamperService.swift
└── ScheduleEvaluator.swift

FocusDragon/Views/
├── LockSelectionView.swift
├── TimerLockView.swift
├── RandomTextLockView.swift
├── ScheduleLockView.swift
└── UnlockView.swift

FocusDragonDaemon/
├── LockEnforcer.swift
└── TamperDetector.swift
```

## Lock UI Flow

```
Main View
    └─> Start Block
        └─> Lock Options Modal
            ├─> No Lock (default)
            ├─> Timer Lock → Enter duration → Start
            ├─> Random Text → Generate & show text → Start
            ├─> Schedule → Configure times → Start
            ├─> Restart Required → Confirm → Start
            └─> Breakable → Set delay → Start

Active Blocking (Locked)
    └─> Stop Block (if locked)
        └─> Unlock Modal
            ├─> Timer: Show remaining time, can't unlock
            ├─> Random Text: Input field, verify
            ├─> Schedule: Show next unlock time
            ├─> Restart: Must restart Mac
            └─> Breakable: 60-second countdown
```

## Testing Criteria

### Test 1: Timer Lock
- [ ] Set 5-minute timer lock
- [ ] Start blocking
- [ ] Try to stop before timer expires → denied
- [ ] Wait 5 minutes
- [ ] Can now stop blocking

### Test 2: Timer Survives Restart
- [ ] Set 30-minute timer lock
- [ ] Restart Mac
- [ ] Timer continues counting down
- [ ] Still can't unlock early

### Test 3: Random Text Lock
- [ ] Start with random text lock
- [ ] Random string displayed
- [ ] Try incorrect text → denied
- [ ] Type exact text → unlocks

### Test 4: Schedule Lock
- [ ] Set schedule: 9 AM - 5 PM weekdays
- [ ] During time window → blocking active
- [ ] Try to disable → denied
- [ ] After 5 PM → automatically unlocks

### Test 5: Restart Required
- [ ] Start with restart lock
- [ ] Try to unlock → denied
- [ ] Restart Mac
- [ ] Can now unlock

### Test 6: Breakable Lock
- [ ] Set 60-second delay
- [ ] Try to unlock → 60-second countdown starts
- [ ] Can't skip countdown
- [ ] After 60 seconds → unlocks

### Test 7: System Settings Block
- [ ] Enable strict mode
- [ ] Start locked block
- [ ] Try to open System Settings → blocked
- [ ] Stop blocking → System Settings accessible

### Test 8: Uninstall Prevention
- [ ] Start locked block
- [ ] Try to uninstall → denied with error
- [ ] Unlock and stop
- [ ] Can now uninstall

## Tamper Resistance Levels

Users can choose protection level:

**Level 0 - No Protection (Default)**
- Basic blocking only
- Can stop anytime
- No tamper resistance

**Level 1 - Standard Protection**
- Lock mechanisms active
- Daemon protects hosts file
- Uninstall blocked during locks

**Level 2 - Strict Protection**
- + System Settings blocked during locks
- + Terminal blocked during locks
- + Activity Monitor blocked during locks

**Level 3 - Paranoid Mode**
- + All text editors blocked
- + Network tools blocked
- + Password required for settings
- + Tamper logging

## Security Considerations

⚠️ **Balance:** Too aggressive = users will abandon the app
⚠️ **Escape hatch:** Always provide Recovery Mode as fallback
⚠️ **Transparency:** Clearly explain what each protection level does
⚠️ **Consent:** Make strict modes opt-in, not default

## Deliverables

✅ All 5 lock types implemented and working
✅ Lock state persists across reboots
✅ UI for lock selection and unlocking
✅ Anti-tamper mechanisms functional
✅ Uninstall prevention during locks
✅ Tamper attempt logging
✅ Settings protection
✅ Multiple protection levels

## Estimated Time

**Total: 8-10 hours**
- Lock models & state: 1 hour
- Timer lock: 1 hour
- Random text lock: 1 hour
- Schedule lock: 2 hours
- Restart/breakable locks: 1 hour
- Anti-tamper: 2-3 hours
- UI/UX: 2 hours
- Testing: 1-2 hours

## Next Phase

After Phase 4 → **Phase 5: Browser Extensions**
