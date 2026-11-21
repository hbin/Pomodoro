#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="${1:-debug}"
UNIVERSAL="${UNIVERSAL:-0}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
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

BUILD_ARGS=(-c "$CONFIG" --disable-sandbox)
if [[ "$UNIVERSAL" == "1" ]]; then
    BUILD_ARGS+=(--arch arm64 --arch x86_64)
fi

ARCH_LABEL=""
if [[ "$UNIVERSAL" == "1" ]]; then
    ARCH_LABEL=" (universal)"
fi

echo "Building $CONFIG$ARCH_LABEL…"
swift build "${BUILD_ARGS[@]}"
BIN_PATH="$(swift build "${BUILD_ARGS[@]}" --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_PATH/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

if [[ "$SIGN_IDENTITY" == "-" ]]; then
    echo "Signing locally (ad hoc)…"
    SIGN_ARGS=(--timestamp=none)
else
    echo "Signing with $SIGN_IDENTITY…"
    SIGN_ARGS=(--options runtime --timestamp)
fi

if ! codesign \
    --force \
    --sign "$SIGN_IDENTITY" \
    --entitlements "$ROOT/Resources/Pomodoro.entitlements" \
    "${SIGN_ARGS[@]}" \
    "$APP" >/dev/null 2>&1; then
    if [[ "$SIGN_IDENTITY" != "-" ]]; then
        echo "Signing with $SIGN_IDENTITY failed." >&2
        exit 1
    fi
    echo "Sandbox signing failed; signing without entitlements."
    codesign --force --sign - --timestamp=none "$APP" >/dev/null
fi

codesign --verify --strict "$APP"

echo "Built $APP"
