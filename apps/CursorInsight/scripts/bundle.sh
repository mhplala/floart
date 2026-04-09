#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_NAME="CursorInsight"
BUNDLE_ID="com.automemory.cursorinsight"
VERSION="0.1.0"
BUILD_DIR="$PROJECT_DIR/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "Building $APP_NAME..."
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build -c release \
  --package-path "$PROJECT_DIR"

BINARY="$PROJECT_DIR/.build/release/$APP_NAME"
if [[ ! -f "$BINARY" ]]; then
  echo "Error: binary not found at $BINARY" >&2
  exit 1
fi

echo "Assembling .app bundle at $APP_BUNDLE..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BINARY" "$MACOS_DIR/$APP_NAME"

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>CursorInsight</string>
    <key>CFBundleIdentifier</key>
    <string>com.automemory.cursorinsight</string>
    <key>CFBundleVersion</key>
    <string>0.1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleExecutable</key>
    <string>CursorInsight</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>26.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSScreenCaptureUsageDescription</key>
    <string>CursorInsight needs screen recording permission to capture the area around your cursor for OCR analysis.</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>CursorInsight needs accessibility access for smart window detection.</string>
</dict>
</plist>
PLIST

echo "Signing with ad-hoc signature..."
codesign --force --sign - "$APP_BUNDLE"

echo ""
echo "Done! .app bundle is at:"
echo "$APP_BUNDLE"
