#!/bin/bash
set -e

PLIST_PATH="/Library/LaunchDaemons/com.focusdragon.daemon.plist"
DAEMON_DIR="/Library/Application Support/FocusDragon"
LOG_DIR="/var/log/focusdragon"

echo "========================================="
echo "FocusDragon Daemon Uninstallation"
echo "========================================="
echo ""
echo "This will remove the FocusDragon daemon and all related files."
echo "You will be prompted for your password."
echo ""
read -p "Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Uninstallation cancelled."
    exit 0
fi

echo ""
echo "Uninstalling daemon..."
echo ""

# Unload daemon
if [ -f "$PLIST_PATH" ]; then
    echo "Unloading daemon..."
    sudo launchctl unload "$PLIST_PATH" 2>/dev/null || true

    echo "Removing plist..."
    sudo rm "$PLIST_PATH"
else
    echo "Plist not found (may already be uninstalled)"
fi

# Remove daemon files
if [ -d "$DAEMON_DIR" ]; then
    echo "Removing daemon files..."
    sudo rm -rf "$DAEMON_DIR"
else
    echo "Daemon directory not found"
fi

# Ask about logs
echo ""
read -p "Remove log files? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if [ -d "$LOG_DIR" ]; then
        echo "Removing logs..."
        sudo rm -rf "$LOG_DIR"
    fi
else
    echo "Keeping logs at $LOG_DIR"
fi

# Verify uninstallation
echo ""
if sudo launchctl list | grep -q "com.focusdragon.daemon"; then
    echo "========================================="
    echo "⚠️  Warning: Daemon still in launchctl"
    echo "========================================="
    echo ""
    echo "Try manual cleanup:"
    echo "  sudo launchctl remove com.focusdragon.daemon"
    echo ""
else
    echo "========================================="
    echo "✅ Uninstallation complete!"
    echo "========================================="
    echo ""
fi
