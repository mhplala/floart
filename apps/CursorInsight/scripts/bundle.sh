#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_NAME="Floart"
BUNDLE_ID="com.automemory.floart"
VERSION="0.1.0"
BUILD_DIR="$PROJECT_DIR/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "Building $APP_NAME..."
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  build -scheme "$APP_NAME" -destination 'platform=macOS' -configuration Release \
  -derivedDataPath "$BUILD_DIR/DerivedData" \
  2>&1 | tail -3

BINARY="$BUILD_DIR/DerivedData/Build/Products/Release/$APP_NAME"
if [[ ! -f "$BINARY" ]]; then
  echo "Error: binary not found at $BINARY" >&2
  exit 1
fi

echo "Assembling .app bundle at $APP_BUNDLE..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BINARY" "$MACOS_DIR/$APP_NAME"

# Copy app icon if it exists
ICNS_SRC="$BUILD_DIR/Floart.icns"
if [[ -f "$ICNS_SRC" ]]; then
  echo "Copying app icon..."
  cp "$ICNS_SRC" "$RESOURCES_DIR/Floart.icns"
else
  echo "Warning: $ICNS_SRC not found. Run scripts/generate_icon.swift first."
fi

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>Floart</string>
    <key>CFBundleIdentifier</key>
    <string>com.automemory.floart</string>
    <key>CFBundleVersion</key>
    <string>0.1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleExecutable</key>
    <string>Floart</string>
    <key>CFBundleIconFile</key>
    <string>Floart</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <false/>
    <key>NSScreenCaptureUsageDescription</key>
    <string>Floart needs screen recording permission to capture the area around your cursor for OCR analysis.</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>Floart needs accessibility access for smart window detection.</string>
</dict>
</plist>
PLIST

echo "Signing with Developer ID..."
codesign --force --sign "Developer ID Application: Stev Wang (UK68KKX58X)" "$APP_BUNDLE"

echo ""
echo "Done! .app bundle is at:"
echo "$APP_BUNDLE"
