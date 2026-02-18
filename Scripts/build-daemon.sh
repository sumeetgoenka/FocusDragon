#!/bin/bash
set -e

PROJECT_DIR="/Users/anaygoenka/Documents/FocusDragon"
cd "$PROJECT_DIR"

echo "========================================="
echo "Building FocusDragon Daemon"
echo "========================================="

# Clean previous builds
echo "Cleaning previous builds..."
rm -rf build/

# Build daemon
echo "Building daemon executable..."
xcodebuild build \
  -project FocusDragon.xcodeproj \
  -scheme FocusDragonDaemon \
  -configuration Release \
  -derivedDataPath ./build \
  SYMROOT=./build

# Find executable
DAEMON_PATH="build/Release/FocusDragonDaemon"

if [ ! -f "$DAEMON_PATH" ]; then
    echo "❌ ERROR: Daemon not found at $DAEMON_PATH"
    exit 1
fi

# Make executable
chmod +x "$DAEMON_PATH"

# Display info
echo ""
echo "✅ Build successful!"
echo "========================================="
echo "Executable: $DAEMON_PATH"
echo "Size: $(du -h "$DAEMON_PATH" | cut -f1)"
echo ""
echo "File info:"
file "$DAEMON_PATH"
echo ""
echo "========================================="
echo "Next steps:"
echo "  1. Test manually: sudo $DAEMON_PATH"
echo "  2. Install: ./Scripts/install-daemon.sh"
echo "========================================="
