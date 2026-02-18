#!/bin/bash
set -e

PROJECT_DIR="/Users/anaygoenka/Documents/FocusDragon"
DAEMON_SOURCE="$PROJECT_DIR/build/Release/FocusDragonDaemon"
DAEMON_DEST="/Library/Application Support/FocusDragon/FocusDragonDaemon"
PLIST_SOURCE="$PROJECT_DIR/FocusDragonDaemon/Resources/com.focusdragon.daemon.plist"
PLIST_DEST="/Library/LaunchDaemons/com.focusdragon.daemon.plist"

echo "========================================="
echo "FocusDragon Daemon Installation"
echo "========================================="
echo ""

# Check if daemon executable exists
if [ ! -f "$DAEMON_SOURCE" ]; then
    echo "❌ ERROR: Daemon not built."
    echo "Run: ./Scripts/build-daemon.sh"
    exit 1
fi

# Check if plist exists
if [ ! -f "$PLIST_SOURCE" ]; then
    echo "❌ ERROR: Plist not found at $PLIST_SOURCE"
    exit 1
fi

echo "This will install the FocusDragon daemon with root privileges."
echo "You will be prompted for your password."
echo ""
read -p "Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Installation cancelled."
    exit 0
fi

echo ""
echo "Installing daemon..."
echo ""

# Create directories
echo "Creating directories..."
sudo mkdir -p "/Library/Application Support/FocusDragon"
sudo mkdir -p "/var/log/focusdragon"

# Copy daemon executable
echo "Installing daemon executable..."
sudo cp "$DAEMON_SOURCE" "$DAEMON_DEST"
sudo chmod 755 "$DAEMON_DEST"
sudo chown root:wheel "$DAEMON_DEST"

# Copy plist
echo "Installing LaunchDaemon plist..."
sudo cp "$PLIST_SOURCE" "$PLIST_DEST"
sudo chmod 644 "$PLIST_DEST"
sudo chown root:wheel "$PLIST_DEST"

# Unload if already loaded (for reinstalls)
if sudo launchctl list | grep -q "com.focusdragon.daemon"; then
    echo "Unloading existing daemon..."
    sudo launchctl unload "$PLIST_DEST" 2>/dev/null || true
fi

# Load daemon
echo "Loading daemon..."
sudo launchctl load -w "$PLIST_DEST"

# Wait for daemon to start
echo "Waiting for daemon to start..."
sleep 3

# Check if running
echo ""
if sudo launchctl list | grep -q "com.focusdragon.daemon"; then
    echo "========================================="
    echo "✅ Installation successful!"
    echo "========================================="
    echo ""
    echo "Daemon status:"
    sudo launchctl list | grep focusdragon || echo "  (daemon loaded)"
    echo ""
    echo "Useful commands:"
    echo "  View logs:      tail -f /var/log/focusdragon/daemon.log"
    echo "  View errors:    tail -f /var/log/focusdragon/daemon-stderr.log"
    echo "  Reload config:  sudo kill -HUP \$(pgrep FocusDragonDaemon)"
    echo "  Uninstall:      ./Scripts/uninstall-daemon.sh"
    echo ""
    echo "========================================="
else
    echo ""
    echo "========================================="
    echo "❌ Installation failed - daemon not running"
    echo "========================================="
    echo ""
    echo "Check logs for errors:"
    echo "  sudo tail /var/log/focusdragon/daemon-stderr.log"
    echo ""
    exit 1
fi
