#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="${1:-debug}"
APP_NAME="Pomodoro"
APP="$ROOT/build/$APP_NAME.app"

export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-/tmp/pomodoro-cache/clang}"
export SWIFTPM_MODULECACHE_PATH="${SWIFTPM_MODULECACHE_PATH:-/tmp/pomodoro-cache/swiftpm}"
mkdir -p "$CLANG_MODULE_CACHE_PATH" "$SWIFTPM_MODULECACHE_PATH"

cd "$ROOT"

if [[ ! -f "$ROOT/Resources/AppIcon.icns" ]]; then
    echo "Generating app icon…"
    swift "$ROOT/scripts/make-icon.swift" "$ROOT"
fi

echo "Building $CONFIG…"
swift build -c "$CONFIG" --disable-sandbox
BIN_PATH="$(swift build -c "$CONFIG" --disable-sandbox --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_PATH/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

echo "Signing locally (ad hoc)…"
codesign \
    --force \
    --sign - \
    --entitlements "$ROOT/Resources/Pomodoro.entitlements" \
    --timestamp=none \
    "$APP" >/dev/null 2>&1 || {
        echo "Sandbox signing failed; signing without entitlements."
        codesign --force --sign - --timestamp=none "$APP" >/dev/null
    }

echo "Built $APP"
