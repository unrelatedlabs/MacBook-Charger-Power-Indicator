#!/bin/bash
# Build and assemble a runnable .app bundle in ./build/
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="MacBook Charger Power Indicator"
APP="build/$APP_NAME.app"
CONTENTS="$APP/Contents"

echo "==> Building release binary"
swift build -c release

BIN="$(swift build -c release --show-bin-path)/MacBat"

echo "==> Assembling $APP"
rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
cp "$BIN" "$CONTENTS/MacOS/MacBat"
cp Resources/Info.plist "$CONTENTS/Info.plist"

echo "==> Ad-hoc code signing"
codesign --force --sign - "$APP" >/dev/null 2>&1 || true

echo "==> Done: $APP"
echo "    Run with:  open \"$APP\""
