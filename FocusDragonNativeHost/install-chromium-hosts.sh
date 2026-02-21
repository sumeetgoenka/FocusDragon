#!/bin/bash
set -e

# Build and install the FocusDragon native messaging host for Chromium-based browsers

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE="$SCRIPT_DIR/focusdragon-native-host.swift"
BINARY_NAME="focusdragon-native-host"
INSTALL_DIR="/usr/local/bin"
INSTALL_PATH="$INSTALL_DIR/$BINARY_NAME"
MANIFEST_NAME="com.focusdragon.nativehost.json"

CHROMIUM_DIRS=(
  "$HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts"
  "$HOME/Library/Application Support/Microsoft Edge/NativeMessagingHosts"
  "$HOME/Library/Application Support/Microsoft Edge Beta/NativeMessagingHosts"
  "$HOME/Library/Application Support/Microsoft Edge Dev/NativeMessagingHosts"
  "$HOME/Library/Application Support/Microsoft Edge Canary/NativeMessagingHosts"
  "$HOME/Library/Application Support/BraveSoftware/Brave-Browser/NativeMessagingHosts"
  "$HOME/Library/Application Support/Vivaldi/NativeMessagingHosts"
  "$HOME/Library/Application Support/com.operasoftware.Opera/NativeMessagingHosts"
  "$HOME/Library/Application Support/com.operasoftware.OperaGX/NativeMessagingHosts"
  "$HOME/Library/Application Support/com.operasoftware.OperaDeveloper/NativeMessagingHosts"
  "$HOME/Library/Application Support/Comet/NativeMessagingHosts"
  "$HOME/Library/Application Support/Perplexity/Comet/NativeMessagingHosts"
  "$HOME/Library/Application Support/ai.perplexity.comet/NativeMessagingHosts"
)

echo "=== FocusDragon Chromium Native Host Installer ==="
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

# Step 3: Install manifests
for dir in "${CHROMIUM_DIRS[@]}"; do
  mkdir -p "$dir"
  cat > "$dir/$MANIFEST_NAME" << 'MANIFEST_EOF'
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
  echo "  ✓ Installed manifest at $dir/$MANIFEST_NAME"
done

# Clean up build artifact
rm -f "$SCRIPT_DIR/$BINARY_NAME"

echo ""
echo "=== Installation complete ==="
echo ""
echo "Next steps:"
echo "  1. Load the Chromium extensions from their dist/ folders"
echo "  2. Replace '*' with the actual extension ID for stricter security"
