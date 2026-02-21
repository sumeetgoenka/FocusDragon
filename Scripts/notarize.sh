#!/bin/bash

set -e

APP_PATH="build/Release/FocusDragon.app"
ZIP_PATH="build/FocusDragon.zip"

# ─── Configuration ───
# Set these environment variables or replace the placeholders:
#   APPLE_ID       – your Apple Developer email
#   TEAM_ID        – your 10-character team ID
#   APP_PASSWORD   – app-specific password (generate at appleid.apple.com)

APPLE_ID="${APPLE_ID:-YOUR_APPLE_ID}"
TEAM_ID="${TEAM_ID:-9STH9GD9MP}"
APP_PASSWORD="${APP_PASSWORD:-YOUR_APP_SPECIFIC_PASSWORD}"

if [[ "$APPLE_ID" == "YOUR_APPLE_ID" || "$APP_PASSWORD" == "YOUR_APP_SPECIFIC_PASSWORD" ]]; then
    echo "Error: Set APPLE_ID and APP_PASSWORD environment variables before running."
    echo ""
    echo "  export APPLE_ID=\"you@example.com\""
    echo "  export APP_PASSWORD=\"xxxx-xxxx-xxxx-xxxx\""
    echo ""
    exit 1
fi

if [[ ! -d "$APP_PATH" ]]; then
    echo "Error: $APP_PATH not found. Run Scripts/build-release.sh first."
    exit 1
fi

echo "=== FocusDragon Notarization ==="
echo ""

# Create ZIP for notarization
echo "→ Creating ZIP..."
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

# Upload for notarization and wait
echo "→ Submitting for notarization (this may take several minutes)..."
xcrun notarytool submit "$ZIP_PATH" \
    --apple-id "$APPLE_ID" \
    --team-id "$TEAM_ID" \
    --password "$APP_PASSWORD" \
    --wait

# Staple notarization ticket to app
echo ""
echo "→ Stapling ticket..."
xcrun stapler staple "$APP_PATH"

# Clean up zip
rm -f "$ZIP_PATH"

echo ""
echo "=== Notarization complete! ==="
echo "App is ready for distribution: $APP_PATH"
