#!/usr/bin/env bash
set -euo pipefail

APP_NAME="TouchTouch"
DISPLAY_NAME="TouchTouch Pro"
BUNDLE_ID="com.local.TouchTouch"
MIN_SYSTEM_VERSION="13.0"
ICON_NAME="AppIcon"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_DIR="$ROOT_DIR/script"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES_DIR="$CONTENTS/Resources"
BINARY="$MACOS_DIR/$APP_NAME"
INFO_PLIST="$CONTENTS/Info.plist"
DMG_STAGING="$DIST_DIR/dmg_staging"
DMG_PATH="$DIST_DIR/$APP_NAME.dmg"

echo "==> Cleaning dist ..."
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

echo "==> Building $APP_NAME ..."
swift build -c release --arch arm64 --arch x86_64

UNIVERSAL_BIN="$ROOT_DIR/.build/apple/Products/Release/$APP_NAME"
if [ -f "$UNIVERSAL_BIN" ]; then
    BUILD_BINARY="$UNIVERSAL_BIN"
else
    BUILD_BINARY="$(swift build -c release --show-bin-path)/$APP_NAME"
fi
echo "==> Binary: $BUILD_BINARY"
echo "==> Architectures: $(lipo -info "$BUILD_BINARY" 2>/dev/null | sed 's/.*: //' || echo "single")"

echo "==> Generating app icon ..."
swift "$SCRIPT_DIR/generate_icon.swift" "$DIST_DIR"
ICONSET="$DIST_DIR/$ICON_NAME.iconset"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$DIST_DIR/$ICON_NAME.png" \
        --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    double_size=$((size * 2))
    sips -z "$double_size" "$double_size" "$DIST_DIR/$ICON_NAME.png" \
        --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$DIST_DIR/$ICON_NAME.icns"
rm -rf "$ICONSET"

echo "==> Creating app bundle ..."
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$BUILD_BINARY" "$BINARY"
chmod +x "$BINARY"
cp "$DIST_DIR/$ICON_NAME.icns" "$RESOURCES_DIR/$ICON_NAME.icns"

# Copy kb-brightness helper tool into bundle
KB_BIN="$ROOT_DIR/.build/apple/Products/Release/kb-brightness"
if [ -f "$KB_BIN" ]; then
    cp "$KB_BIN" "$MACOS_DIR/kb-brightness"
    chmod +x "$MACOS_DIR/kb-brightness"
    echo "    Included kb-brightness helper"
else
    echo "ERROR: kb-brightness not found: $KB_BIN" >&2
    exit 1
fi

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>$DISPLAY_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$DISPLAY_NAME</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleIconFile</key>
    <string>$ICON_NAME</string>
    <key>LSMinimumSystemVersion</key>
    <string>$MIN_SYSTEM_VERSION</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
PLIST

echo "==> Ad-hoc code signing ..."
/usr/bin/codesign --force --sign - --deep "$APP_BUNDLE"

echo "==> Creating DMG ..."
rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"
cp -R "$APP_BUNDLE" "$DMG_STAGING/"

if command -v create-dmg &>/dev/null; then
    create-dmg \
        --volname "$APP_NAME" \
        --window-pos 200 120 \
        --window-size 480 360 \
        --icon-size 100 \
        --icon "$APP_NAME.app" 140 160 \
        --app-drop-link 340 160 \
        --no-internet-enable \
        "$DMG_PATH" \
        "$DMG_STAGING"
else
    echo "    create-dmg not found, using hdiutil ..."
    DMG_TEMP="$DIST_DIR/${APP_NAME}_tmp.dmg"
    DMG_MOUNT="/Volumes/$APP_NAME"

    hdiutil create -srcfolder "$DMG_STAGING" -volname "$APP_NAME" \
        -fs HFS+ -fsargs "-c c=64,a=16,e=16" \
        -format UDRW -size 50m "$DMG_TEMP"

    hdiutil attach -readwrite -noverify -noautoopen "$DMG_TEMP"

    if [ -d "$DMG_MOUNT" ]; then
        ln -sf /Applications "$DMG_MOUNT/Applications"
        sleep 1
        hdiutil detach "$DMG_MOUNT"
    fi

    hdiutil convert "$DMG_TEMP" -format UDZO \
        -imagekey zlib-level=9 -o "$DMG_PATH"
    rm -f "$DMG_TEMP"
fi

rm -rf "$DMG_STAGING"

echo ""
echo "==> Done: $DMG_PATH"
