#!/bin/bash
# Install MacBat to ~/Applications, launch it, and enable "Start at Login".
# Login is managed by the app itself via SMAppService (also toggleable from the
# menu-bar dropdown). Re-running updates the installed copy. --uninstall removes.
set -euo pipefail

cd "$(dirname "$0")"

LABEL="com.pkuhar.macbat"
DEST="$HOME/Applications/MacBat.app"
LEGACY_PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
DOMAIN="gui/$(id -u)"

remove_legacy_agent() {
    # Older versions used a LaunchAgent; tear it down if present.
    launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
    rm -f "$LEGACY_PLIST"
}

if [[ "${1:-}" == "--uninstall" ]]; then
    echo "==> Disabling login item"
    [[ -d "$DEST" ]] && open "$DEST" --args --disable-login 2>/dev/null || true
    sleep 1
    remove_legacy_agent
    pkill -f "Applications/MacBat.app" 2>/dev/null || true
    echo "==> Removing $DEST"
    rm -rf "$DEST"
    echo "==> Uninstalled (the source repo is untouched)."
    exit 0
fi

# Prefer the packaged (universal, icon'd) build; fall back to a plain dev build.
if [[ -d dist/MacBat.app ]]; then
    SRC="dist/MacBat.app"
elif [[ -d build/MacBat.app ]]; then
    SRC="build/MacBat.app"
else
    echo "==> No build found; building first"
    ./build-app.sh
    SRC="build/MacBat.app"
fi

echo "==> Installing $SRC to $DEST"
remove_legacy_agent
pkill -f "Applications/MacBat.app" 2>/dev/null || true
sleep 1
mkdir -p "$HOME/Applications"
rm -rf "$DEST"
cp -R "$SRC" "$DEST"

echo "==> Launching and enabling Start at Login"
open "$DEST" --args --enable-login

echo "==> Done. MacBat is running and will start at every login."
echo "    Toggle it anytime from the menu-bar dropdown (\"Start at Login\")."
echo "    Uninstall with: ./install-login-item.sh --uninstall"
