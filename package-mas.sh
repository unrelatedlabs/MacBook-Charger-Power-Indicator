#!/bin/bash
# Build, sign, and package the app for the Mac App Store, then (optionally)
# upload it to App Store Connect.
#
# Prerequisites (created in your Apple Developer account / Xcode):
#   - "Apple Distribution" certificate           (signs the .app)
#   - "Mac Installer Distribution" certificate   (signs the .pkg)
#   - a Mac App Store provisioning profile for xyz.inteliwear.macos.macbat
#
# Configure via environment variables, e.g.:
#   export MAS_SIGN_APP="Apple Distribution: Inteliwear ... (TEAMID)"
#   export MAS_SIGN_PKG="3rd Party Mac Developer Installer: Inteliwear ... (TEAMID)"
#   export MAS_PROFILE="$HOME/Downloads/MacBook_Charger_Power_Indicator.provisionprofile"
#   # For automatic upload (otherwise use Transporter.app on the .pkg):
#   export MAS_APPLE_ID="you@example.com"
#   export MAS_APP_PW="abcd-efgh-ijkl-mnop"   # app-specific password
#   ./package-mas.sh
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="MacBook Charger Power Indicator"
APP="dist/mas/$APP_NAME.app"
CONTENTS="$APP/Contents"
PKG="dist/mas/MacBook-Charger-Power-Indicator.pkg"
ENTITLEMENTS="MacBat.entitlements"

: "${MAS_SIGN_APP:?Set MAS_SIGN_APP to your 'Apple Distribution: ...' identity}"
: "${MAS_SIGN_PKG:?Set MAS_SIGN_PKG to your 'Mac Installer Distribution: ...' identity}"
: "${MAS_PROFILE:?Set MAS_PROFILE to the path of your .provisionprofile}"
[[ -f "$MAS_PROFILE" ]] || { echo "Profile not found: $MAS_PROFILE"; exit 1; }

echo "==> Universal release build"
swift build -c release --arch arm64 --arch x86_64
BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/MacBat"

echo "==> Assembling $APP"
rm -rf "$APP"; mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
cp "$BIN" "$CONTENTS/MacOS/MacBat"
cp Resources/Info.plist "$CONTENTS/Info.plist"
cp "$MAS_PROFILE" "$CONTENTS/embedded.provisionprofile"

echo "==> Generating icon"
ICONSET="dist/mas/AppIcon.iconset"; rm -rf "$ICONSET"; mkdir -p "$ICONSET"
"$BIN" --icon dist/mas/icon-1024.png >/dev/null
for sz in 16 32 64 128 256 512 1024; do
    sips -z "$sz" "$sz" dist/mas/icon-1024.png --out "$ICONSET/icon_${sz}x${sz}.png" >/dev/null 2>&1
done
cp "$ICONSET/icon_32x32.png"     "$ICONSET/icon_16x16@2x.png"
cp "$ICONSET/icon_64x64.png"     "$ICONSET/icon_32x32@2x.png"
cp "$ICONSET/icon_256x256.png"   "$ICONSET/icon_128x128@2x.png"
cp "$ICONSET/icon_512x512.png"   "$ICONSET/icon_256x256@2x.png"
cp "$ICONSET/icon_1024x1024.png" "$ICONSET/icon_512x512@2x.png"
rm -f "$ICONSET/icon_64x64.png" "$ICONSET/icon_1024x1024.png"
iconutil -c icns "$ICONSET" -o "$CONTENTS/Resources/AppIcon.icns"
rm -rf "$ICONSET" dist/mas/icon-1024.png

echo "==> Signing app (hardened runtime + sandbox entitlements)"
codesign --force --options runtime --timestamp \
    --entitlements "$ENTITLEMENTS" --sign "$MAS_SIGN_APP" "$APP"
codesign --verify --strict --verbose=2 "$APP"

echo "==> Building signed installer package"
productbuild --component "$APP" /Applications --sign "$MAS_SIGN_PKG" "$PKG"
echo "    $PKG"

if [[ -n "${MAS_APPLE_ID:-}" && -n "${MAS_APP_PW:-}" ]]; then
    echo "==> Validating with App Store Connect"
    xcrun altool --validate-app -f "$PKG" -t macos \
        -u "$MAS_APPLE_ID" -p "$MAS_APP_PW"
    echo "==> Uploading to App Store Connect"
    xcrun altool --upload-app -f "$PKG" -t macos \
        -u "$MAS_APPLE_ID" -p "$MAS_APP_PW"
    echo "==> Uploaded. It will appear under your in-flight version shortly."
else
    echo "==> Skipping upload (MAS_APPLE_ID / MAS_APP_PW not set)."
    echo "    Upload the .pkg with Transporter.app, or set those vars to use altool."
fi
