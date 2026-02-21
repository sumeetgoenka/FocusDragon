#!/bin/bash

# Build FocusDragon Firefox Extension

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DIST_DIR="$SCRIPT_DIR/dist"

echo "Building FocusDragon Firefox Extension..."

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

cp "$SCRIPT_DIR/manifest.json" "$DIST_DIR/"
cp "$SCRIPT_DIR/background.js" "$DIST_DIR/"
cp "$SCRIPT_DIR/blocked.html" "$DIST_DIR/"
cp "$SCRIPT_DIR/blocked.css" "$DIST_DIR/"
cp -r "$SCRIPT_DIR/popup" "$DIST_DIR/"
cp -r "$SCRIPT_DIR/icons" "$DIST_DIR/"

chmod +x "$SCRIPT_DIR/build.sh" || true

echo ""
echo "Build complete! Extension in dist/"
echo ""
echo "To install:"
echo "  1. Open about:debugging#/runtime/this-firefox"
echo "  2. Click 'Load Temporary Add-on...'"
echo "  3. Select dist/manifest.json"
