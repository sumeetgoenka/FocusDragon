# FocusDragon — Project Overview

## Vision

**FocusDragon is the toughest free website and application blocker on the internet.**

It's designed for people who want to eliminate distractions but struggle with self-control. Unlike simple browser extensions that can be disabled with one click, FocusDragon uses system-level blocking with tamper resistance that makes bypassing annoying enough to keep you focused.

## The Problem

Existing solutions have limitations:

**Browser Extensions** (StayFocusd, LeechBlock, etc.)
- ❌ Only work in one browser
- ❌ Easy to disable or bypass (incognito mode)
- ❌ Don't block applications
- ❌ No system-level enforcement

**Paid Apps** (Cold Turkey, Freedom.to)
- ❌ Cost $30-100+
- ❌ Subscription models
- ❌ Closed source
- ❌ Privacy concerns

**macOS Parental Controls**
- ❌ Designed for parents, not self-imposed
- ❌ Limited customization
- ❌ No lock mechanisms
- ❌ Easy to circumvent

## The Solution: FocusDragon

FocusDragon combines multiple blocking layers:

### Layer 1: DNS-Level Blocking (Hosts File)
- Modifies `/etc/hosts` to redirect blocked domains to `0.0.0.0`
- Works across **all browsers** (Safari, Chrome, Firefox, Edge, Brave, Opera, etc.)
- Blocks before network request even happens
- VPN-proof (hosts file checked before DNS)

### Layer 2: Process Monitoring
- Continuously monitors running applications
- Terminates blocked apps within 1-2 seconds of launch
- Works with bundle IDs (can't be bypassed by renaming)
- Survives app restarts

### Layer 3: Background Daemon
- Runs as root with elevated privileges
- Auto-starts on boot
- Protects hosts file from tampering
- Can't be killed without admin access
- Automatically restarts if terminated

### Layer 4: Browser Extensions
- Redundant blocking for Chrome, Firefox, Safari
- Blocks access by IP address (hosts file doesn't catch this)
- Works in incognito/private mode
- Detects and reports tamper attempts

### Layer 5: Lock Mechanisms
- **Timer Lock:** "Block for 4 hours, cannot unlock early"
- **Random Text Lock:** Type 40-character random string to unlock
- **Schedule Lock:** "Block 9 AM - 5 PM weekdays"
- **Restart Lock:** Must restart Mac to unlock
- **Breakable Lock:** 60-second delay before unlock

### Layer 6: Anti-Tamper
- Prevents uninstallation during locks
- Blocks System Settings during locks (prevents time change)
- Optional blocking of Terminal, Activity Monitor
- Detects and logs bypass attempts

## Why It's Tough

**Bypassing FocusDragon requires:**

1. Knowing the exact mechanism (open source helps learning)
2. Administrator password
3. Disabling the LaunchDaemon
4. Editing protected system files
5. During lock: waiting for timer, restarting Mac, or typing random text

**vs. Browser extension:** Disable in 2 clicks, 5 seconds

The goal isn't to make bypassing impossible (that's not possible with physical access), but to make it **annoying enough** that you'll stay focused instead.

## Why Free & Open Source?

1. **Accessibility:** Everyone deserves powerful productivity tools
2. **Trust:** Users can audit the code for security/privacy
3. **Community:** Open to contributions and improvements
4. **Learning:** Help others understand system-level macOS development
5. **No Lock-In:** No subscriptions or paywalls

## Core Principles

### 1. User Sovereignty
- Users have full control
- Always provide an escape hatch (Recovery Mode)
- Transparent about what the app does
- No data collection or telemetry

### 2. Simplicity
- Easy to set up (<5 minutes)
- Intuitive interface
- Sane defaults
- Power users can dig deeper

### 3. Effectiveness
- Actually blocks (not just "nudges")
- Multiple bypass-prevention layers
- Locks that work

### 4. Native Experience
- True macOS app (SwiftUI)
- Follows Apple Human Interface Guidelines
- Fast and responsive
- Feels professional

### 5. Open & Transparent
- MIT License
- Public development
- Documented architecture
- Community-driven

## Target Users

### Primary Audience
- **Procrastinators:** People who want to force focus
- **Students:** Need to block distractions during study
- **Remote Workers:** Work-from-home distractions
- **Content Creators:** Avoid social media rabbit holes
- **Anyone with ADHD:** Need strong external structure

### Use Cases
- "Block Reddit during work hours"
- "No YouTube while studying for exams"
- "Block all games from 9 AM - 5 PM"
- "Lock myself out of Twitter for a week"
- "Pomodoro: 25 min work, 5 min break, block during work"

## What FocusDragon Is NOT

- ❌ **Not** parental control software (self-imposed only)
- ❌ **Not** a monitoring/spying tool (no tracking)
- ❌ **Not** a productivity app (just a blocker)
- ❌ **Not** unbreakable (Recovery Mode always works)
- ❌ **Not** a cure for procrastination (just a tool)

## Success Criteria

### For Users
- ✅ Can block distractions effectively
- ✅ Locks prevent impulsive disabling
- ✅ Doesn't drain battery or slow down Mac
- ✅ Easy to set up and use
- ✅ Free forever

### For Developers
- ✅ Clean, maintainable codebase
- ✅ Well-documented architecture
- ✅ Easy to contribute
- ✅ Passes all tests
- ✅ No security vulnerabilities

### For Community
- ✅ Active development
- ✅ Responsive to issues
- ✅ Welcomes contributions
- ✅ Helps people stay focused

## Competitive Analysis

| Feature | FocusDragon | Cold Turkey | Freedom.to | Browser Extensions |
|---------|-------------|-------------|------------|-------------------|
| **Price** | Free | $39 | $40/year | Free |
| **Open Source** | ✅ Yes | ❌ No | ❌ No | Some |
| **Block Websites** | ✅ Yes | ✅ Yes | ✅ Yes | ✅ Yes |
| **Block Apps** | ✅ Yes | ✅ Yes | ✅ Yes | ❌ No |
| **System-Level** | ✅ Yes | ✅ Yes | ✅ Yes | ❌ No |
| **Lock Mechanisms** | ✅ 5 types | ✅ Yes | ✅ Limited | ❌ No |
| **macOS Native** | ✅ SwiftUI | ⚠️ Electron | ⚠️ Electron | N/A |
| **Browser Extensions** | ✅ Yes | ✅ Yes | ✅ Yes | ✅ Yes |
| **Statistics** | ✅ Yes | ✅ Yes | ✅ Yes | Limited |
| **Pomodoro** | ✅ Yes | ❌ No | ✅ Yes | Some |

**FocusDragon's advantages:**
- Free and open source
- True native macOS app (faster, better battery)
- More lock types
- Community-driven

**Disadvantages:**
- No iOS app (yet)
- No cloud sync (yet)
- Requires technical install (DMG, not App Store)

## Roadmap (Future)

### Version 1.0 (This Plan)
- Website & app blocking
- LaunchDaemon
- Lock mechanisms
- Browser extensions
- Statistics
- DMG distribution

### Version 1.x (Future)
- Improved UI/UX based on feedback
- Additional lock types
- More preset lists
- Performance optimizations

### Version 2.0 (Future)
- iOS companion app (limited by iOS restrictions)
- Cloud sync across devices
- Team/family features
- Plugin system for custom blocks

### Version 3.0 (Far Future)
- Machine learning to detect procrastination patterns
- Integration with Focus modes
- API for third-party integrations

## Philosophy

> "The best way to overcome temptation is to make it inconvenient."

FocusDragon doesn't try to eliminate all possibility of distraction (impossible). Instead, it adds enough friction that:

1. **Impulsive browsing is blocked** - Can't just click and go to Reddit
2. **Deliberate bypassing is annoying** - Have to think "is this worth the effort?"
3. **Future-you protects present-you** - Set locks when motivated, stay blocked when weak

It's a tool for **self-discipline**, not external control.

## Core Values

1. **User Empowerment** - Give users power over their digital lives
2. **Transparency** - No hidden behavior or data collection
3. **Accessibility** - Free for everyone, forever
4. **Quality** - Professional, polished, reliable
5. **Community** - Built by users, for users

## Technical Philosophy

### Keep It Simple
- Minimal dependencies
- Standard macOS APIs
- No complex frameworks
- Readable code

### Security First
- Principle of least privilege
- Input validation
- Safe defaults
- Regular audits

### Performance Matters
- Low CPU usage (<5%)
- Small memory footprint (<100MB)
- Fast startup (<1 second)
- Responsive UI (<100ms)

### User Experience
- Intuitive flows
- Clear feedback
- Helpful errors
- Delightful animations

## Measuring Success

### Downloads
- Goal: 10,000 in first year
- Metric: GitHub releases, DMG downloads

### User Satisfaction
- Goal: >4.5/5 rating
- Metric: GitHub stars, user feedback

### Community
- Goal: 50+ contributors
- Metric: GitHub contributors, PRs merged

### Impact
- Goal: Help 10,000+ people stay focused
- Metric: User testimonials, usage statistics (opt-in)

## Conclusion

FocusDragon aims to be the **best free productivity blocker** available. Not because it's the most feature-rich or the most aggressive, but because it:

- Actually works
- Respects users
- Is accessible to everyone
- Empowers self-discipline

If we achieve this, we'll have created something genuinely useful that helps people reclaim their time and attention.

---

**Next:** [01-technical-architecture.md](./01-technical-architecture.md) - Deep dive into how it all works
