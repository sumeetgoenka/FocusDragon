# FocusDragon — Complete Development Plan

> **A free, open-source, tamper-resistant website and application blocker for macOS**

## Quick Start

This plan folder contains a complete, step-by-step guide to building FocusDragon from scratch.

### For Developers

1. Start with [00-overview.md](./00-overview.md) to understand the project
2. Review [01-technical-architecture.md](./01-technical-architecture.md) for system design
3. Follow phases sequentially: Phase 1 → Phase 2 → ... → Phase 7
4. Each phase has detailed implementation guides in its folder

### For AI Assistants

This plan is designed to be consumed by AI coding assistants (Claude, GPT-4, etc.):
- Each section has complete context and code examples
- Tasks are concrete and actionable
- Success criteria are clearly defined
- No ambiguity in requirements

## Project Overview

**FocusDragon** is a native macOS application that blocks distracting websites and applications at the system level. Unlike browser-only blockers, FocusDragon:

- ✅ Blocks at DNS level (modifies `/etc/hosts`)
- ✅ Terminates blocked applications on launch
- ✅ Runs a privileged background daemon (LaunchDaemon)
- ✅ Provides tamper-resistant lock mechanisms
- ✅ Includes browser extensions for redundancy
- ✅ Is 100% free and open source

**Distribution:** DMG download (not Mac App Store) to avoid $99/year Apple Developer fee.

## Development Phases

### [Phase 1: Foundation & Basic Website Blocking](./phase-1/)
**Time:** 4-6 hours | **Objective:** Minimal viable blocker

Build a SwiftUI app that can block websites by modifying `/etc/hosts`.

**Key Deliverables:**
- Xcode project setup
- Basic UI to add/remove domains
- Hosts file manipulation with admin privileges
- Start/Stop blocking

**Success:** Can block YouTube in all browsers

---

### [Phase 2: Application Blocking](./phase-2/)
**Time:** 5-7 hours | **Objective:** Add app blocking

Monitor running processes and terminate blocked applications.

**Key Deliverables:**
- App selection UI
- Process monitoring service
- App termination (graceful + force)
- Notifications

**Success:** Can block Steam - it closes within 2 seconds of launch

---

### [Phase 3: Background Service (LaunchDaemon)](./phase-3/)
**Time:** 6-8 hours | **Objective:** Persistent, tamper-resistant blocking

Create root-level daemon that enforces blocks even when app is closed.

**Key Deliverables:**
- LaunchDaemon running as root
- IPC between app and daemon
- Hosts file protection
- Auto-start on boot

**Success:** Blocks persist after Mac restart, daemon can't be killed

---

### [Phase 4: Lock Mechanisms & Tamper Resistance](./phase-4/)
**Time:** 8-10 hours | **Objective:** Make bypassing difficult

Implement locks that prevent easy disabling of blocks.

**Key Deliverables:**
- Timer lock (block for X hours)
- Random text lock
- Schedule lock (work hours)
- Restart-required lock
- Anti-tamper mechanisms

**Success:** Cannot disable timer lock until it expires

---

### [Phase 5: Browser Extensions](./phase-5/)
**Time:** 6-8 hours | **Objective:** Redundant blocking layer

Create extensions for Chrome, Firefox, Safari.

**Key Deliverables:**
- Chrome extension (Manifest V3)
- Firefox extension
- Safari extension
- Native messaging
- IP address blocking

**Success:** Extensions block even when hosts file bypassed

---

### [Phase 6: Advanced Features & Polish](./phase-6/)
**Time:** 10-15 hours | **Objective:** Production-ready features

Add statistics, presets, Pomodoro, and polish UX.

**Key Deliverables:**
- Statistics dashboard
- Pre-built block lists
- Import/export
- Pomodoro mode
- Menu bar app mode
- Onboarding flow

**Success:** App feels professional and complete

---

### [Phase 7: Distribution & Documentation](./phase-7/)
**Time:** 6-8 hours | **Objective:** Public release

Package app, write documentation, prepare for distribution.

**Key Deliverables:**
- DMG creation
- Code signing (optional)
- Complete README
- Installation scripts
- GitHub repo setup

**Success:** Users can download and install without issues

---

## Total Estimated Time

**45-60 hours** for a complete, production-ready application

- Experienced Swift developer: ~45 hours
- Learning Swift/SwiftUI: ~60+ hours
- AI-assisted development: ~30-40 hours

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                    User Interface                       │
│                  (SwiftUI Mac App)                      │
│  ┌──────────┬──────────┬──────────┬─────────────────┐ │
│  │   Main   │  Block   │   Lock   │    Settings     │ │
│  │   View   │   List   │   UI     │                 │ │
│  └──────────┴──────────┴──────────┴─────────────────┘ │
└────────────────────────┬────────────────────────────────┘
                         │ IPC (XPC or File)
┌────────────────────────▼────────────────────────────────┐
│           LaunchDaemon (runs as root)                   │
│  ┌──────────────┬──────────────┬───────────────────┐  │
│  │   Hosts      │   Process    │      Lock         │  │
│  │   Watcher    │   Monitor    │    Enforcer       │  │
│  └──────────────┴──────────────┴───────────────────┘  │
└────────────────────────┬────────────────────────────────┘
                         │
           ┌─────────────┴─────────────┐
           │                           │
    ┌──────▼──────┐           ┌────────▼────────┐
    │  /etc/hosts │           │    Running      │
    │  (DNS)      │           │   Processes     │
    └─────────────┘           └─────────────────┘

┌────────────────────────────────────────────────────────┐
│              Browser Extensions                        │
│   ┌──────────┬──────────┬──────────┐                  │
│   │  Chrome  │ Firefox  │  Safari  │                  │
│   └──────────┴──────────┴──────────┘                  │
│          │ Native Messaging │                          │
└──────────┴──────────────────┴──────────────────────────┘
```

## Technology Stack

- **Language:** Swift
- **UI:** SwiftUI (native macOS)
- **Background Service:** Swift executable as LaunchDaemon
- **IPC:** XPC or JSON file-based
- **Extensions:** JavaScript (Chrome/Firefox), Swift (Safari)
- **Permissions:** Authorization Services, sudo
- **Storage:** UserDefaults, JSON files

## Key Technical Components

### 1. Hosts File Blocking
```
Location: /etc/hosts
Format: 0.0.0.0 domain.com
Markers: #### FocusDragon Block Start/End ####
Requires: Root access, DNS flush
```

### 2. Process Monitoring
```swift
NSWorkspace.shared.runningApplications
NSRunningApplication.terminate()
kill(pid, SIGKILL) // force kill
```

### 3. LaunchDaemon
```xml
/Library/LaunchDaemons/com.focusdragon.daemon.plist
UserName: root
KeepAlive: true
RunAtLoad: true
```

### 4. Lock State
```swift
enum LockType {
    case timer, randomText, schedule,
         restartRequired, breakable
}
```

## File Structure

```
FocusDragon/
├── plan/                           # This folder
│   ├── README.md                   # You are here
│   ├── 00-overview.md
│   ├── 01-technical-architecture.md
│   ├── 02-security-considerations.md
│   ├── phase-1/
│   │   ├── 1.1-environment-setup.md
│   │   ├── 1.2-project-initialization.md
│   │   ├── 1.3-swiftui-interface.md
│   │   ├── 1.4-hosts-file-manipulation.md
│   │   └── 1.5-block-toggle-logic.md
│   ├── phase-2/
│   │   ├── 2.1-app-selection-ui.md
│   │   ├── 2.2-process-monitoring.md
│   │   └── 2.3-phase-2-completion.md
│   ├── phase-3/
│   │   └── README.md
│   ├── phase-4/
│   │   └── README.md
│   ├── phase-5/
│   │   └── README.md
│   ├── phase-6/
│   │   └── README.md
│   └── phase-7/
│       └── README.md
├── FocusDragon/                    # Main app source
├── FocusDragonDaemon/              # Daemon source
├── FocusDragonShared/              # Shared code
├── Extensions/                     # Browser extensions
├── Scripts/                        # Build & install scripts
├── README.md                       # Project README
└── LICENSE                         # MIT License
```

## Prerequisites

### For Development
- macOS 11.0+ (Big Sur or later)
- Xcode 13.0+ (latest recommended)
- Basic Swift/SwiftUI knowledge
- Administrator access on Mac

### For Users
- macOS 11.0+
- Administrator privileges (for installation)
- ~50MB disk space

## Getting Started

1. **Read the overview documents:**
   - [00-overview.md](./00-overview.md) - Project goals and design
   - [01-technical-architecture.md](./01-technical-architecture.md) - System design
   - [02-security-considerations.md](./02-security-considerations.md) - Security notes

2. **Start with Phase 1:**
   - Go to [phase-1/](./phase-1/)
   - Follow sections 1.1 through 1.5 in order
   - Test thoroughly before moving to Phase 2

3. **Complete each phase sequentially**
   - Don't skip phases
   - Test after each section
   - Commit code after each phase

## Success Metrics

### Functionality
- ✅ Blocks websites in all major browsers
- ✅ Blocks applications within 2 seconds
- ✅ Survives Mac restart
- ✅ Locks prevent early unlock
- ✅ Extensions provide redundancy

### Performance
- ✅ CPU usage <5% when active
- ✅ Memory usage <100MB
- ✅ UI responds in <100ms
- ✅ No battery drain

### User Experience
- ✅ Setup in <5 minutes
- ✅ Intuitive interface
- ✅ Clear error messages
- ✅ Professional appearance

### Code Quality
- ✅ No crashes
- ✅ Handles errors gracefully
- ✅ Clean, documented code
- ✅ Passes all tests

## Support & Contributing

This is an open-source project. Contributions welcome!

- **Issues:** Report bugs or request features
- **Pull Requests:** Submit improvements
- **Documentation:** Help improve these guides
- **Testing:** Try on different Mac configurations

## License

MIT License - Free for personal and commercial use

## Acknowledgments

Inspired by:
- Cold Turkey Blocker (Windows/Mac)
- Freedom.to
- Self Control (Mac)

Built with:
- Swift & SwiftUI
- macOS system frameworks
- Open source tools

---

## Next Steps

👉 **Start here:** [00-overview.md](./00-overview.md)

Then move to Phase 1: [phase-1/1.1-environment-setup.md](./phase-1/1.1-environment-setup.md)

Good luck building FocusDragon! 🐉
