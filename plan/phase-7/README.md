# Phase 7: Distribution & Documentation

**Objective:** Prepare FocusDragon for public release with proper packaging, documentation, and distribution channels.

## Overview

Phase 7 finalizes the project for release:
- Build and packaging
- Code signing (optional but recommended)
- DMG creation
- Documentation (README, user guide)
- GitHub repository setup
- Website/landing page
- Release strategy

## 7.1 Build Configuration

### Release Build Settings

**Xcode Build Settings:**
- Configuration: Release (not Debug)
- Optimization Level: -O (Optimize for Speed)
- Strip Debug Symbols: Yes
- Dead Code Stripping: Yes
- Bitcode: No (macOS doesn't need it)

**Build Script:**

Create `Scripts/build-release.sh`:

```bash
#!/bin/bash
set -e

echo "Building FocusDragon Release..."

# Clean previous builds
xcodebuild clean -project FocusDragon.xcodeproj -configuration Release

# Build main app
xcodebuild build \
    -project FocusDragon.xcodeproj \
    -scheme FocusDragon \
    -configuration Release \
    -derivedDataPath ./build \
    SYMROOT=./build

# Build daemon
xcodebuild build \
    -project FocusDragon.xcodeproj \
    -scheme FocusDragonDaemon \
    -configuration Release \
    -derivedDataPath ./build \
    SYMROOT=./build

# Copy builds to distribution folder
mkdir -p dist
cp -R build/Release/FocusDragon.app dist/
cp build/Release/FocusDragonDaemon dist/

echo "Build complete! Output in dist/"
```

## 7.2 Code Signing & Notarization

### Without Apple Developer Account (Free)

**Self-signed certificate:**

```bash
# Create self-signed cert (one-time)
security create-keychain -p "" build.keychain
security default-keychain -s build.keychain
security unlock-keychain -p "" build.keychain

# Sign the app
codesign --force --deep --sign - FocusDragon.app
```

**User experience:**
- Users will see "Unidentified Developer" warning
- Must right-click → Open to bypass Gatekeeper
- Document this clearly in README

### With Apple Developer Account ($99/year)

**Proper signing:**

```bash
# Sign with Developer ID
codesign --force --deep \
    --sign "Developer ID Application: Your Name (TEAM_ID)" \
    --options runtime \
    FocusDragon.app

# Notarize
xcrun notarytool submit FocusDragon.app.zip \
    --apple-id your@email.com \
    --team-id YOUR_TEAM_ID \
    --password app-specific-password \
    --wait

# Staple notarization
xcrun stapler staple FocusDragon.app
```

**Benefits:**
- No Gatekeeper warnings
- Better user trust
- LaunchDaemon works more reliably

## 7.3 DMG Creation

**Create distributable DMG:**

Create `Scripts/create-dmg.sh`:

```bash
#!/bin/bash

APP_NAME="FocusDragon"
VERSION="1.0.0"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"

# Create temporary folder
mkdir -p dmg-temp
cp -R dist/FocusDragon.app dmg-temp/

# Create README
cat > dmg-temp/README.txt << EOF
FocusDragon - Free Website & Application Blocker

Installation:
1. Drag FocusDragon.app to Applications folder
2. Open FocusDragon
3. Follow onboarding to install daemon
4. Start blocking!

For more info: https://github.com/yourusername/focusdragon
EOF

# Create symbolic link to Applications
ln -s /Applications dmg-temp/Applications

# Create DMG
hdiutil create -volname "${APP_NAME}" \
    -srcfolder dmg-temp \
    -ov -format UDZO \
    "${DMG_NAME}"

# Cleanup
rm -rf dmg-temp

echo "DMG created: ${DMG_NAME}"
```

**DMG Contents:**
```
FocusDragon-1.0.0.dmg
├── FocusDragon.app
├── Applications (symlink)
└── README.txt
```

## 7.4 Installation Scripts

### Daemon Installation Script

Create `Scripts/install-daemon.sh` (embedded in app):

```bash
#!/bin/bash

DAEMON_PATH="/Library/Application Support/FocusDragon/FocusDragonDaemon"
PLIST_PATH="/Library/LaunchDaemons/com.focusdragon.daemon.plist"
LOG_DIR="/var/log/focusdragon"

echo "Installing FocusDragon daemon..."

# Create directories
sudo mkdir -p "/Library/Application Support/FocusDragon"
sudo mkdir -p "$LOG_DIR"

# Copy daemon executable
sudo cp "$1" "$DAEMON_PATH"
sudo chmod 755 "$DAEMON_PATH"

# Copy plist
sudo cp "$2" "$PLIST_PATH"
sudo chmod 644 "$PLIST_PATH"
sudo chown root:wheel "$PLIST_PATH"

# Load daemon
sudo launchctl load -w "$PLIST_PATH"

echo "Daemon installed and started!"
```

### Uninstall Script

Create `Scripts/uninstall.sh`:

```bash
#!/bin/bash

echo "Uninstalling FocusDragon..."

# Unload daemon
sudo launchctl unload /Library/LaunchDaemons/com.focusdragon.daemon.plist 2>/dev/null

# Remove files
sudo rm -f /Library/LaunchDaemons/com.focusdragon.daemon.plist
sudo rm -rf "/Library/Application Support/FocusDragon"
sudo rm -rf /var/log/focusdragon

# Clean hosts file
sudo sed -i '' '/#### FocusDragon Block Start ####/,/#### FocusDragon Block End ####/d' /etc/hosts

# Remove app
rm -rf /Applications/FocusDragon.app

# Remove user data
rm -rf ~/Library/Application\ Support/FocusDragon
rm -rf ~/Library/Preferences/com.focusdragon.*

echo "FocusDragon uninstalled!"
```

## 7.5 Documentation

### README.md

```markdown
# 🐉 FocusDragon

**The toughest free website and application blocker for macOS**

FocusDragon helps you stay focused by blocking distracting websites and applications with powerful tamper-resistance features.

## Features

- ✅ Block websites at DNS level (works in all browsers)
- ✅ Block applications (Steam, Discord, games, etc.)
- ✅ Multiple lock types (timer, random text, schedule, restart-required)
- ✅ Browser extensions for Chrome, Firefox, Safari
- ✅ Tamper-resistant with LaunchDaemon protection
- ✅ Statistics and productivity tracking
- ✅ Pomodoro timer built-in
- ✅ 100% free and open source

## Installation

1. Download `FocusDragon-1.0.0.dmg`
2. Open DMG and drag FocusDragon to Applications
3. Launch FocusDragon
4. Follow onboarding to install system daemon
5. Start blocking!

### Unsigned Build Warning

FocusDragon is not signed with an Apple Developer certificate (to keep it free). You may see:

> "FocusDragon" cannot be opened because it is from an unidentified developer

**To open:**
1. Right-click FocusDragon.app
2. Select "Open"
3. Click "Open" in the dialog

You only need to do this once.

## Usage

### Block Websites
1. Add websites to block list
2. Click "Start Block"
3. Websites become inaccessible

### Block Applications
1. Click "Add Application"
2. Select app from list or browse
3. Click "Start Block"
4. App will close immediately when launched

### Lock Your Blocks
- **Timer Lock**: "Block for 2 hours"
- **Random Text**: Type random string to unlock
- **Schedule**: Block during work hours
- **Restart Required**: Must restart Mac to unlock

## System Requirements

- macOS 11.0 (Big Sur) or later
- Intel or Apple Silicon Mac
- Administrator access (for installation)

## Uninstall

Run the uninstall script:
```bash
curl -O https://raw.githubusercontent.com/yourusername/focusdragon/main/Scripts/uninstall.sh
bash uninstall.sh
```

Or use the built-in uninstaller in Settings → Advanced.

## FAQ

**Q: How is this different from parental controls?**
A: FocusDragon is designed for self-imposed blocking with strong tamper resistance.

**Q: Can I bypass it?**
A: With enough effort and technical knowledge, yes (Recovery Mode). The goal is to make bypassing annoying enough that you stay focused.

**Q: Is it really free?**
A: Yes! 100% free and open source (MIT License).

**Q: Why isn't it in the App Store?**
A: App Store doesn't allow system-level blockers. Also avoids the $99/year fee.

## Contributing

Contributions welcome! See CONTRIBUTING.md

## License

MIT License - see LICENSE file

## Support

- GitHub Issues: https://github.com/yourusername/focusdragon/issues
- Discussions: https://github.com/yourusername/focusdragon/discussions

---

Made with 🐉 by the FocusDragon team
```

### User Guide

Create `GUIDE.md` with comprehensive documentation:
- Getting started
- Detailed feature explanations
- Troubleshooting
- Advanced usage
- Lock mechanism guide
- Browser extension setup

### Contributing Guide

Create `CONTRIBUTING.md`:
- How to contribute
- Code style guidelines
- Pull request process
- Development setup
- Testing requirements

## 7.6 GitHub Repository Setup

### Repository Structure

```
focusdragon/
├── .github/
│   ├── ISSUE_TEMPLATE/
│   │   ├── bug_report.md
│   │   └── feature_request.md
│   └── workflows/
│       └── build.yml
├── FocusDragon/           # Source code
├── Scripts/               # Build & install scripts
├── docs/                  # Documentation
├── .gitignore
├── README.md
├── LICENSE
├── CONTRIBUTING.md
├── CHANGELOG.md
└── PLAN.md (or plan/ folder)
```

### GitHub Actions (Optional)

`.github/workflows/build.yml`:

```yaml
name: Build

on: [push, pull_request]

jobs:
  build:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v2
      - name: Build
        run: |
          xcodebuild build \
            -project FocusDragon.xcodeproj \
            -scheme FocusDragon \
            -configuration Release
```

### Release Checklist

- [ ] Version number updated
- [ ] CHANGELOG.md updated
- [ ] All tests passing
- [ ] DMG created
- [ ] README accurate
- [ ] Screenshots added
- [ ] GitHub release created
- [ ] Tag created (`v1.0.0`)

## 7.7 Website/Landing Page (Optional)

Simple GitHub Pages site:

```html
<!DOCTYPE html>
<html>
<head>
  <title>FocusDragon - Free Mac Blocker</title>
  <meta name="description" content="The toughest free website and application blocker for macOS">
</head>
<body>
  <header>
    <h1>🐉 FocusDragon</h1>
    <p>The toughest free blocker for macOS</p>
    <a href="https://github.com/yourusername/focusdragon/releases/latest">Download Now</a>
  </header>

  <section>
    <h2>Features</h2>
    <ul>
      <li>Block websites & apps</li>
      <li>Tamper-resistant locks</li>
      <li>Browser extensions</li>
      <li>100% free</li>
    </ul>
  </section>

  <footer>
    <a href="https://github.com/yourusername/focusdragon">GitHub</a>
  </footer>
</body>
</html>
```

## 7.8 Release Strategy

### Version 1.0.0 Launch

1. **Pre-launch:**
   - Beta test with 10-20 users
   - Fix critical bugs
   - Polish documentation

2. **Launch:**
   - GitHub release with DMG
   - Post on Reddit (r/MacApps, r/productivity)
   - Hacker News "Show HN"
   - Product Hunt (optional)

3. **Post-launch:**
   - Monitor GitHub issues
   - Respond to feedback
   - Plan v1.1.0 improvements

### Future Versions

- **v1.1.0** - Bug fixes, small features
- **v1.2.0** - Additional lock types
- **v2.0.0** - Major new features

## Deliverables

✅ Release build script
✅ Code signing (or unsigned instructions)
✅ DMG creation
✅ Installation scripts
✅ Uninstall script
✅ Comprehensive README
✅ User guide
✅ Contributing guide
✅ GitHub repo setup
✅ Release checklist
✅ Launch plan

## Testing Criteria

### Fresh Install Test
- [ ] Download DMG on clean Mac
- [ ] Install FocusDragon
- [ ] Complete onboarding
- [ ] Block a website
- [ ] Block an app
- [ ] Test lock mechanism
- [ ] Restart Mac → daemon still running
- [ ] Uninstall cleanly

### Documentation Test
- [ ] README instructions work
- [ ] All links functional
- [ ] Screenshots accurate
- [ ] FAQ answers common questions

### Cross-Platform Test
- [ ] Works on Intel Mac
- [ ] Works on Apple Silicon Mac
- [ ] Works on macOS 11, 12, 13, 14+

## Success Criteria

- App installs without errors on fresh Mac
- All features work as documented
- Users can complete setup in <10 minutes
- Uninstall leaves no traces
- Documentation is clear and complete

## Estimated Time

**Total: 6-8 hours**
- Build configuration: 1 hour
- DMG creation: 1 hour
- Scripts: 1-2 hours
- Documentation: 2-3 hours
- GitHub setup: 1 hour
- Testing: 1-2 hours

## Final Steps

1. Create GitHub release
2. Upload DMG
3. Announce on social media
4. Monitor feedback
5. Plan next version

---

## Project Complete! 🎉

After Phase 7, FocusDragon is ready for public use!
