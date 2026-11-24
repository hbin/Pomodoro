#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLIST="$ROOT/Resources/Info.plist"
PLIST_BUDDY="/usr/libexec/PlistBuddy"
MODE="${1:-}"
TARGET="${2:-}"

usage() {
    cat <<'EOF'
Usage: scripts/bump-version.sh <patch|minor|major|beta|final|build>

  patch  Increment the patch version (0.1.0 -> 0.1.1).
  minor  Increment the minor version (0.1.1 -> 0.2.0).
  major  Increment the major version (0.2.0 -> 1.0.0).
  beta   Start or advance a beta build (0.3.1 -> 0.3.2-beta.1, or
         0.4.0-beta.1 -> 0.4.0-beta.2). Pass patch, minor, or major to
         choose the base of a new beta series (default: patch).
  final  Promote a beta to its release version (0.4.0-beta.3 -> 0.4.0).
  build  Keep the version and increment only the build number.

Every mode increments CFBundleVersion, the internal build number. The final
release after a beta series must keep a higher build number than every beta.
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

if ! printf '%s\n' "$CURRENT_VERSION" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+(-beta\.[0-9]+)?$'; then
    echo "CFBundleShortVersionString must use MAJOR.MINOR.PATCH or MAJOR.MINOR.PATCH-beta.N: $CURRENT_VERSION" >&2
    exit 1
fi

if ! printf '%s\n' "$CURRENT_BUILD" | grep -Eq '^[0-9]+$'; then
    echo "CFBundleVersion must be a whole number: $CURRENT_BUILD" >&2
    exit 1
fi

BASE_VERSION="${CURRENT_VERSION%%-beta.*}"
IS_BETA=0
BETA_NUMBER=0
if [[ "$CURRENT_VERSION" == *-beta.* ]]; then
    IS_BETA=1
    BETA_NUMBER="${CURRENT_VERSION##*-beta.}"
fi

MAJOR="${BASE_VERSION%%.*}"
REST="${BASE_VERSION#*.}"
MINOR="${REST%%.*}"
PATCH="${REST#*.}"
NEW_BUILD=$((CURRENT_BUILD + 1))
NEW_BETA=0

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
    beta)
        if (( IS_BETA )); then
            if [[ -n "$TARGET" ]]; then
                echo "Already on a beta series; the next beta increments automatically." >&2
                exit 1
            fi
            NEW_BETA=$((BETA_NUMBER + 1))
        else
            TARGET="${TARGET:-patch}"
            case "$TARGET" in
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
                *)
                    echo "Unknown beta base: $TARGET (expected patch, minor, or major)." >&2
                    exit 1
                    ;;
            esac
            NEW_BETA=1
        fi
        ;;
    final)
        if (( ! IS_BETA )); then
            echo "Current version is not a beta: $CURRENT_VERSION" >&2
            exit 1
        fi
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

if [[ "$MODE" == "build" ]]; then
    NEW_VERSION="$CURRENT_VERSION"
elif (( NEW_BETA > 0 )); then
    NEW_VERSION="$MAJOR.$MINOR.$PATCH-beta.$NEW_BETA"
else
    NEW_VERSION="$MAJOR.$MINOR.$PATCH"
fi

"$PLIST_BUDDY" -c "Set :CFBundleShortVersionString $NEW_VERSION" "$PLIST"
"$PLIST_BUDDY" -c "Set :CFBundleVersion $NEW_BUILD" "$PLIST"

echo "Pomodoro v$CURRENT_VERSION ($CURRENT_BUILD) -> v$NEW_VERSION ($NEW_BUILD)"
