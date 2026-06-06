#!/bin/bash
# Build a distributable MacBat: universal binary, generated icon, ad-hoc signed,
# packaged as dist/MacBat.dmg and dist/MacBat.zip.
set -euo pipefail

cd "$(dirname "$0")"

APP="dist/MacBat.app"
CONTENTS="$APP/Contents"
DMG="dist/MacBat.dmg"
ZIP="dist/MacBat.zip"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Resources/Info.plist 2>/dev/null || echo 1.0)"

echo "==> Building universal release binary (arm64 + x86_64)"
swift build -c release --arch arm64 --arch x86_64
BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/MacBat"
echo "    archs: $(lipo -archs "$BIN")"

echo "==> Assembling $APP"
rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
cp "$BIN" "$CONTENTS/MacOS/MacBat"
cp Resources/Info.plist "$CONTENTS/Info.plist"

echo "==> Generating app icon"
ICONSET="dist/AppIcon.iconset"
rm -rf "$ICONSET"; mkdir -p "$ICONSET"
"$BIN" --icon dist/icon-1024.png >/dev/null
for sz in 16 32 64 128 256 512 1024; do
    sips -z "$sz" "$sz" dist/icon-1024.png --out "$ICONSET/icon_${sz}x${sz}.png" >/dev/null 2>&1
done
# Build the @2x / retina names iconutil expects.
cp "$ICONSET/icon_32x32.png"   "$ICONSET/icon_16x16@2x.png"
cp "$ICONSET/icon_64x64.png"   "$ICONSET/icon_32x32@2x.png"
cp "$ICONSET/icon_256x256.png" "$ICONSET/icon_128x128@2x.png"
cp "$ICONSET/icon_512x512.png" "$ICONSET/icon_256x256@2x.png"
cp "$ICONSET/icon_1024x1024.png" "$ICONSET/icon_512x512@2x.png"
rm -f "$ICONSET/icon_64x64.png" "$ICONSET/icon_1024x1024.png"
iconutil -c icns "$ICONSET" -o "$CONTENTS/Resources/AppIcon.icns"
rm -rf "$ICONSET" dist/icon-1024.png

echo "==> Code signing (ad-hoc)"
codesign --force --deep --sign - "$APP"
codesign --verify --verbose "$APP" 2>&1 | sed 's/^/    /'

echo "==> Building $ZIP"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "==> Building $DMG"
rm -f "$DMG"
STAGE="dist/dmg-stage"
rm -rf "$STAGE"; mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "MacBat $VERSION" -srcfolder "$STAGE" \
    -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"

echo
echo "==> Done."
echo "    $APP"
echo "    $DMG  ($(du -h "$DMG" | cut -f1))"
echo "    $ZIP  ($(du -h "$ZIP" | cut -f1))"
echo
echo "    Not notarized (no Developer ID cert). On another Mac, first launch:"
echo "      right-click the app -> Open -> Open,  or:  xattr -dr com.apple.quarantine /Applications/MacBat.app"
