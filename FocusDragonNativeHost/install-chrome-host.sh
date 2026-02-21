#!/bin/bash
set -e

# Build and install the FocusDragon native messaging host for Chrome

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE="$SCRIPT_DIR/focusdragon-native-host.swift"
BINARY_NAME="focusdragon-native-host"
INSTALL_DIR="/usr/local/bin"
INSTALL_PATH="$INSTALL_DIR/$BINARY_NAME"

# Chrome native messaging host manifest location
CHROME_NM_DIR="$HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts"
MANIFEST_NAME="com.focusdragon.nativehost.json"

echo "=== FocusDragon Chrome Native Host Installer ==="
echo ""

# Step 1: Compile
echo "Compiling native messaging host..."
swiftc -O -o "$SCRIPT_DIR/$BINARY_NAME" "$SOURCE"
echo "  ✓ Compiled successfully"

# Step 2: Install binary
echo "Installing to $INSTALL_PATH (requires sudo)..."
sudo mkdir -p "$INSTALL_DIR"
sudo cp "$SCRIPT_DIR/$BINARY_NAME" "$INSTALL_PATH"
sudo chmod 755 "$INSTALL_PATH"
echo "  ✓ Binary installed"

# Step 3: Install Chrome native messaging manifest
echo "Installing Chrome native messaging manifest..."
mkdir -p "$CHROME_NM_DIR"

cat > "$CHROME_NM_DIR/$MANIFEST_NAME" << 'MANIFEST_EOF'
{
  "name": "com.focusdragon.nativehost",
  "description": "FocusDragon Native Messaging Host",
  "path": "/usr/local/bin/focusdragon-native-host",
  "type": "stdio",
  "allowed_origins": [
    "chrome-extension://*/*"
  ]
}
MANIFEST_EOF

echo "  ✓ Chrome manifest installed at $CHROME_NM_DIR/$MANIFEST_NAME"

# Clean up build artifact
rm -f "$SCRIPT_DIR/$BINARY_NAME"

echo ""
echo "=== Installation complete ==="
echo ""
echo "Next steps:"
echo "  1. Load the Chrome extension from FocusDragonExtension-Chrome/dist/"
echo "  2. If you want to lock it down, replace '*' with the actual extension ID"
