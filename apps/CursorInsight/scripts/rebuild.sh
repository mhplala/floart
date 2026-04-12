#!/usr/bin/env bash
# Rebuild Floart and relaunch the running instance.
# Use during development — keeps bundle.sh pure for release builds.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_BUNDLE="$(cd "$SCRIPT_DIR/.." && pwd)/build/Floart.app"

"$SCRIPT_DIR/bundle.sh"

echo ""
echo "Stopping any running Floart instance..."
pkill -f "Floart.app/Contents/MacOS/Floart" 2>/dev/null || true
sleep 0.5

echo "Launching $APP_BUNDLE..."
open "$APP_BUNDLE"
echo "Done."
