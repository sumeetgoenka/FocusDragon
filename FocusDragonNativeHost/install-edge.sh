#!/bin/bash
set -e

# Build and install the FocusDragon native messaging host for Microsoft Edge

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE="$SCRIPT_DIR/focusdragon-native-host.swift"
BINARY_NAME="focusdragon-native-host"
INSTALL_DIR="/usr/local/bin"
INSTALL_PATH="$INSTALL_DIR/$BINARY_NAME"

# Edge native messaging host manifest location (Chromium-based, same format as Chrome)
EDGE_NM_DIR="$HOME/Library/Application Support/Microsoft Edge/NativeMessagingHosts"
MANIFEST_NAME="com.focusdragon.nativehost.json"

echo "=== FocusDragon Edge Native Host Installer ==="
echo ""

# Step 1: Compile (skip if binary already installed by Chrome installer)
if [ ! -f "$INSTALL_PATH" ]; then
    echo "Compiling native messaging host..."
    swiftc -O -o "$SCRIPT_DIR/$BINARY_NAME" "$SOURCE"
    echo "  ✓ Compiled successfully"

    # Step 2: Install binary
    echo "Installing to $INSTALL_PATH (requires sudo)..."
    sudo mkdir -p "$INSTALL_DIR"
    sudo cp "$SCRIPT_DIR/$BINARY_NAME" "$INSTALL_PATH"
    sudo chmod 755 "$INSTALL_PATH"
    echo "  ✓ Binary installed"

    # Clean up build artifact
    rm -f "$SCRIPT_DIR/$BINARY_NAME"
else
    echo "Native host binary already installed at $INSTALL_PATH"
    echo "  ✓ Skipping compilation"
fi

# Step 3: Install Edge native messaging manifest
echo "Installing Edge native messaging manifest..."
mkdir -p "$EDGE_NM_DIR"

cat > "$EDGE_NM_DIR/$MANIFEST_NAME" << EOF
{
  "name": "com.focusdragon.nativehost",
  "description": "FocusDragon Native Messaging Host",
  "path": "$INSTALL_PATH",
  "type": "stdio",
  "allowed_origins": [
    "chrome-extension://*/*"
  ]
}
EOF

echo "  ✓ Edge manifest installed at $EDGE_NM_DIR/$MANIFEST_NAME"

echo ""
echo "=== Installation complete ==="
echo ""
echo "Next steps:"
echo "  1. Load the Edge extension from FocusDragonExtension-Edge/dist/"
echo "  2. Note the extension ID from edge://extensions"
echo "  3. Update the manifest's allowed_origins with the real extension ID:"
echo "     $EDGE_NM_DIR/$MANIFEST_NAME"
echo ""
echo "  Replace the allowed_origins line with:"
echo '     "allowed_origins": ["chrome-extension://YOUR_EXTENSION_ID/"]'
