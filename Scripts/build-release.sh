#!/bin/bash

set -e

TEAM_ID="9STH9GD9MP"
PROJECT="FocusDragon.xcodeproj"
SCHEME="FocusDragon"
ARCHIVE_PATH="build/FocusDragon.xcarchive"
EXPORT_PATH="build/Release"

echo "=== FocusDragon Release Build ==="
echo ""

# Clean
echo "→ Cleaning..."
xcodebuild clean -project "$PROJECT" -scheme "$SCHEME" -quiet

# Build archive
echo "→ Archiving..."
xcodebuild archive \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -archivePath "$ARCHIVE_PATH" \
    -configuration Release \
    CODE_SIGN_STYLE=Automatic \
    DEVELOPMENT_TEAM="$TEAM_ID"

# Export app
echo "→ Exporting..."
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist ExportOptions.plist

APP_PATH="$EXPORT_PATH/FocusDragon.app"

echo ""
echo "→ Build complete: $APP_PATH"
echo ""

# Verify code signing
echo "→ Verifying code signature..."
codesign -vvv --deep --strict "$APP_PATH"

# Check architectures
echo ""
echo "→ Architecture info:"
lipo -info "$APP_PATH/Contents/MacOS/FocusDragon" 2>/dev/null || true

# Check Gatekeeper (only works with Developer ID, not Apple Development)
echo ""
echo "→ Gatekeeper check (requires Developer ID signing):"
spctl -a -vvv "$APP_PATH" 2>&1 || echo "  (expected to fail with Apple Development certificate — use Developer ID for distribution)"

echo ""
echo "=== Done ==="
