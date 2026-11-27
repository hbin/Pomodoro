#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_DIR="$ROOT"
MAIN_REF="origin/main"
VERSION_FILE=""
TAG="${GITHUB_REF_NAME:-}"

usage() {
    cat <<'EOF'
Usage: scripts/release-preflight.sh [options] [TAG]

Options:
  --repo-dir DIR       Repository to inspect (default: this repository).
  --main-ref REF       Commit/ref that the tag must be reachable from
                       (default: origin/main).
  --version-file FILE  Info.plist to read (default: Resources/Info.plist).
  -h, --help           Show this help.

Secrets are read only as presence checks from the environment:
  SPARKLE_PRIVATE_KEY, MACOS_CERTIFICATE, MACOS_CERTIFICATE_PASSWORD,
  APPLE_ID, APPLE_TEAM_ID, APPLE_APP_PASSWORD
EOF
}

while (( $# )); do
    case "$1" in
        --repo-dir)
            REPO_DIR="${2:-}"
            shift 2
            ;;
        --main-ref)
            MAIN_REF="${2:-}"
            shift 2
            ;;
        --version-file)
            VERSION_FILE="${2:-}"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -*)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
        *)
            TAG="$1"
            shift
            ;;
    esac
done

fail() {
    echo "release-preflight: $*" >&2
    exit 1
}

[[ -n "$TAG" ]] || fail "a tag is required (argument or GITHUB_REF_NAME)"
[[ "$TAG" =~ '^v[0-9]+\.[0-9]+\.[0-9]+(-beta\.[0-9]+)?$' ]] \
    || fail "tag must be vMAJOR.MINOR.PATCH or vMAJOR.MINOR.PATCH-beta.N (got $TAG)"

REPO_DIR="$(cd "$REPO_DIR" && pwd)"
VERSION_FILE="${VERSION_FILE:-$REPO_DIR/Resources/Info.plist}"
[[ -r "$VERSION_FILE" ]] || fail "version file is not readable: $VERSION_FILE"

TAG_TYPE="$(git -C "$REPO_DIR" cat-file -t "refs/tags/$TAG" 2>/dev/null || true)"
[[ "$TAG_TYPE" == "tag" ]] \
    || fail "tag $TAG must be annotated (git cat-file -t returned ${TAG_TYPE:-missing})"

TAG_OBJECT_SHA="$(git -C "$REPO_DIR" rev-parse "refs/tags/$TAG")"
PEELED_SHA="$(git -C "$REPO_DIR" rev-parse "$TAG^{}")"
MAIN_SNAPSHOT="$(git -C "$REPO_DIR" rev-parse "$MAIN_REF")"

git -C "$REPO_DIR" merge-base --is-ancestor "$PEELED_SHA" "$MAIN_SNAPSHOT" \
    || fail "tag $TAG peels to $PEELED_SHA, which is not reachable from $MAIN_REF ($MAIN_SNAPSHOT)"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$VERSION_FILE")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$VERSION_FILE")"

[[ "$VERSION" =~ '^[0-9]+\.[0-9]+\.[0-9]+(-beta\.[0-9]+)?$' ]] \
    || fail "CFBundleShortVersionString is malformed: $VERSION"
[[ "$BUILD" =~ '^[0-9]+$' ]] || fail "CFBundleVersion must be a whole number: $BUILD"
[[ "$TAG" == "v$VERSION" ]] \
    || fail "tag $TAG does not match Resources/Info.plist version v$VERSION"

if [[ "$VERSION" == *-beta.* ]]; then
    CHANNEL="beta"
else
    CHANNEL="stable"
fi

DEV_SECRETS=(
    MACOS_CERTIFICATE
    MACOS_CERTIFICATE_PASSWORD
    APPLE_ID
    APPLE_TEAM_ID
    APPLE_APP_PASSWORD
)

[[ -n "${SPARKLE_PRIVATE_KEY:-}" ]] || fail "SPARKLE_PRIVATE_KEY is required"

if [[ "$CHANNEL" == "stable" ]]; then
    for name in "${DEV_SECRETS[@]}"; do
        [[ -n "${(P)name:-}" ]] || fail "$name is required for a stable release"
    done
    SIGNING_KIND="developer-id"
else
    present=0
    for name in "${DEV_SECRETS[@]}"; do
        if [[ -n "${(P)name:-}" ]]; then
            (( present += 1 ))
        fi
    done

    if (( present == 0 )); then
        SIGNING_KIND="adhoc"
    elif (( present == ${#DEV_SECRETS} )); then
        SIGNING_KIND="developer-id"
    else
        fail "beta must provide all signing/notary secrets or none of them"
    fi
fi

print -u2 -- "release-preflight: accepted $TAG ($CHANNEL, $SIGNING_KIND)"
printf 'VERSION=%s\n' "$VERSION"
printf 'BUILD=%s\n' "$BUILD"
printf 'CHANNEL=%s\n' "$CHANNEL"
printf 'TAG=%s\n' "$TAG"
printf 'TAG_OBJECT_SHA=%s\n' "$TAG_OBJECT_SHA"
printf 'PEELED_SHA=%s\n' "$PEELED_SHA"
printf 'MAIN_SNAPSHOT=%s\n' "$MAIN_SNAPSHOT"
printf 'SIGNING_KIND=%s\n' "$SIGNING_KIND"
