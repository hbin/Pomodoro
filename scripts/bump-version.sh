#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLIST="$ROOT/Resources/Info.plist"
PLIST_BUDDY="/usr/libexec/PlistBuddy"
MODE="${1:-}"

usage() {
    cat <<'EOF'
Usage: scripts/bump-version.sh <patch|minor|major|build>

  patch  Increment the patch version (0.1.0 -> 0.1.1).
  minor  Increment the minor version (0.1.1 -> 0.2.0).
  major  Increment the major version (0.2.0 -> 1.0.0).
  build  Keep the version and increment only the build number.

Every mode increments CFBundleVersion, the internal build number.
EOF
}

if [[ -z "$MODE" ]]; then
    usage
    exit 1
fi

if [[ ! -f "$PLIST" ]]; then
    echo "Missing $PLIST" >&2
    exit 1
fi

CURRENT_VERSION="$("$PLIST_BUDDY" -c 'Print :CFBundleShortVersionString' "$PLIST")"
CURRENT_BUILD="$("$PLIST_BUDDY" -c 'Print :CFBundleVersion' "$PLIST")"

if ! printf '%s\n' "$CURRENT_VERSION" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    echo "CFBundleShortVersionString must use MAJOR.MINOR.PATCH: $CURRENT_VERSION" >&2
    exit 1
fi

if ! printf '%s\n' "$CURRENT_BUILD" | grep -Eq '^[0-9]+$'; then
    echo "CFBundleVersion must be a whole number: $CURRENT_BUILD" >&2
    exit 1
fi

MAJOR="${CURRENT_VERSION%%.*}"
REST="${CURRENT_VERSION#*.}"
MINOR="${REST%%.*}"
PATCH="${REST#*.}"
NEW_BUILD=$((CURRENT_BUILD + 1))

case "$MODE" in
    patch)
        PATCH=$((PATCH + 1))
        ;;
    minor)
        MINOR=$((MINOR + 1))
        PATCH=0
        ;;
    major)
        MAJOR=$((MAJOR + 1))
        MINOR=0
        PATCH=0
        ;;
    build)
        ;;
    -h|--help|help)
        usage
        exit 0
        ;;
    *)
        echo "Unknown mode: $MODE" >&2
        usage >&2
        exit 1
        ;;
esac

NEW_VERSION="$MAJOR.$MINOR.$PATCH"

"$PLIST_BUDDY" -c "Set :CFBundleShortVersionString $NEW_VERSION" "$PLIST"
"$PLIST_BUDDY" -c "Set :CFBundleVersion $NEW_BUILD" "$PLIST"

echo "Pomodoro v$CURRENT_VERSION ($CURRENT_BUILD) -> v$NEW_VERSION ($NEW_BUILD)"
