#!/bin/bash

# Build FocusDragon Chrome Extension

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DIST_DIR="$SCRIPT_DIR/dist"

echo "Building FocusDragon Chrome Extension..."

# Clean dist directory
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

# Copy extension files
cp "$SCRIPT_DIR/manifest.json" "$DIST_DIR/"
cp "$SCRIPT_DIR/background.js" "$DIST_DIR/"
cp "$SCRIPT_DIR/blocked.html" "$DIST_DIR/"
cp "$SCRIPT_DIR/blocked.css" "$DIST_DIR/"
cp "$SCRIPT_DIR/rules.json" "$DIST_DIR/"
cp -r "$SCRIPT_DIR/popup" "$DIST_DIR/"
cp -r "$SCRIPT_DIR/icons" "$DIST_DIR/"

echo ""
echo "Build complete! Extension in dist/"
echo ""
echo "To install:"
echo "  1. Open chrome://extensions/"
echo "  2. Enable 'Developer mode'"
echo "  3. Click 'Load unpacked'"
echo "  4. Select the dist/ directory"
