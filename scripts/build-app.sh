#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="${1:-debug}"
UNIVERSAL="${UNIVERSAL:-0}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
APP_NAME="Pomodoro"
APP="$ROOT/build/$APP_NAME.app"
SPARKLE_ARTIFACT="$ROOT/.build/artifacts/sparkle/Sparkle"
SPARKLE_FRAMEWORK="$SPARKLE_ARTIFACT/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
FRAMEWORKS="$APP/Contents/Frameworks"

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
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$FRAMEWORKS"
cp "$BIN_PATH/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

if [[ ! -d "$SPARKLE_FRAMEWORK" ]]; then
    echo "Sparkle framework not found at $SPARKLE_FRAMEWORK" >&2
    exit 1
fi
ditto "$SPARKLE_FRAMEWORK" "$FRAMEWORKS/Sparkle.framework"

if [[ "$CONFIG" == "debug" ]]; then
    /usr/libexec/PlistBuddy -c 'Delete :SUFeedURL' "$APP/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c 'Delete :SUPublicEDKey' "$APP/Contents/Info.plist"
else
    FEED_URL="$(/usr/libexec/PlistBuddy -c 'Print :SUFeedURL' "$APP/Contents/Info.plist")"
    PUBLIC_KEY="$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' "$APP/Contents/Info.plist")"
    if [[ -z "$FEED_URL" || -z "$PUBLIC_KEY" ]]; then
        echo "Release builds require SUFeedURL and SUPublicEDKey." >&2
        exit 1
    fi
fi

EXECUTABLE="$APP/Contents/MacOS/$APP_NAME"
RPATHS=("${(@f)$(otool -l "$EXECUTABLE" \
    | awk '/cmd LC_RPATH/{getline; getline; print $2}' \
    | sort -u)}")
for rpath in "${RPATHS[@]}"; do
    if [[ -z "$rpath" ]]; then
        continue
    fi
    if [[ "$rpath" == /* && "$rpath" != "/usr/lib/swift" ]]; then
        install_name_tool -delete_rpath "$rpath" "$EXECUTABLE"
    fi
done
if [[ " ${RPATHS[*]} " != *" @executable_path/../Frameworks "* ]]; then
    install_name_tool -add_rpath "@executable_path/../Frameworks" "$EXECUTABLE"
fi

if [[ "$SIGN_IDENTITY" == "-" ]]; then
    echo "Signing locally (ad hoc)…"
    APP_SIGN_ARGS=(--timestamp=none)
    NESTED_SIGN_ARGS=(--options runtime --timestamp=none)
else
    echo "Signing with $SIGN_IDENTITY…"
    APP_SIGN_ARGS=(--options runtime --timestamp)
    NESTED_SIGN_ARGS=(--options runtime --timestamp)
fi

SPARKLE_VERSION_DIR="$FRAMEWORKS/Sparkle.framework/Versions/B"
sign_nested() {
    local component="$1"
    shift
    if [[ ! -e "$component" ]]; then
        echo "Missing Sparkle component: $component" >&2
        exit 1
    fi
    codesign --force --sign "$SIGN_IDENTITY" "$@" "${NESTED_SIGN_ARGS[@]}" "$component"
}

sign_nested "$SPARKLE_VERSION_DIR/XPCServices/Installer.xpc" --preserve-metadata=entitlements
sign_nested "$SPARKLE_VERSION_DIR/XPCServices/Downloader.xpc" --preserve-metadata=entitlements
sign_nested "$SPARKLE_VERSION_DIR/Autoupdate"
sign_nested "$SPARKLE_VERSION_DIR/Updater.app"
sign_nested "$FRAMEWORKS/Sparkle.framework"

codesign \
    --force \
    --sign "$SIGN_IDENTITY" \
    --entitlements "$ROOT/Resources/Pomodoro.entitlements" \
    "${APP_SIGN_ARGS[@]}" \
    "$APP"

codesign --verify --deep --strict --verbose=2 "$APP"

ENTITLEMENTS_DUMP="$(mktemp "${TMPDIR:-/tmp}/pomodoro-entitlements.XXXXXX")"
trap 'rm -f "$ENTITLEMENTS_DUMP"' EXIT
codesign -d --entitlements :- "$APP" > "$ENTITLEMENTS_DUMP" 2>/dev/null
for entitlement in \
    "com.apple.security.app-sandbox" \
    "com.apple.security.network.client"; do
    value="$(/usr/libexec/PlistBuddy -c "Print :$entitlement" "$ENTITLEMENTS_DUMP" 2>/dev/null || true)"
    if [[ "$value" != "true" ]]; then
        echo "Missing required entitlement: $entitlement" >&2
        exit 1
    fi
done
MACH_SERVICES=(
    "com.hb.pomodoro-spks"
    "com.hb.pomodoro-spki"
)
index=0
for expected in "${MACH_SERVICES[@]}"; do
    value="$(/usr/libexec/PlistBuddy \
        -c "Print :com.apple.security.temporary-exception.mach-lookup.global-name:$index" \
        "$ENTITLEMENTS_DUMP" 2>/dev/null || true)"
    if [[ "$value" != "$expected" ]]; then
        echo "Missing required mach lookup entitlement: $expected" >&2
        exit 1
    fi
    (( index += 1 ))
done

echo "Built $APP"
