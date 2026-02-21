#!/bin/bash
set -e

PROJECT_DIR="/Users/anaygoenka/Documents/FocusDragon"
HOST_DIR="$PROJECT_DIR/FocusDragonNativeHost"

"$HOST_DIR/install-chromium-hosts.sh"
"$HOST_DIR/install-firefox.sh"

echo ""
echo "Native messaging host installed for Chromium browsers and Firefox."
