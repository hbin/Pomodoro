#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="${CONFIG:-release}"
UNIVERSAL="${UNIVERSAL:-0}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT/dist}"
APP_NAME="Pomodoro"
APP="$ROOT/build/$APP_NAME.app"
STAGE="$ROOT/build/dmg"
DMG_NAME="${DMG_NAME:-$APP_NAME.dmg}"
DMG="$OUTPUT_DIR/$DMG_NAME"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/Resources/Info.plist")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$ROOT/Resources/Info.plist")"

UNIVERSAL="$UNIVERSAL" SIGN_IDENTITY="$SIGN_IDENTITY" "$ROOT/scripts/build-app.sh" "$CONFIG"

rm -rf "$STAGE"
mkdir -p "$STAGE" "$OUTPUT_DIR"
ditto "$APP" "$STAGE/$APP_NAME.app"
ln -s /Applications "$STAGE/Applications"

rm -f "$DMG"
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGE" \
    -format UDZO \
    -ov \
    "$DMG" >/dev/null

if [[ "$SIGN_IDENTITY" != "-" ]]; then
    echo "Signing disk image…"
    codesign --force --sign "$SIGN_IDENTITY" --timestamp "$DMG"
fi

(
    cd "$OUTPUT_DIR"
    shasum -a 256 "$DMG_NAME" > "$DMG_NAME.sha256"
)

echo "Packaged $DMG"
echo "Version $VERSION ($BUILD)"
