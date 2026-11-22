#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SPARKLE_TOOLS="$ROOT/.build/artifacts/sparkle/Sparkle/bin"

VERSION="${VERSION:-}"
ZIP_PATH="${ZIP_PATH:-}"
NOTES_PATH="${NOTES_PATH:-}"
KEY_FILE="${SPARKLE_PRIVATE_KEY_FILE:-}"
OUTPUT_PATH="${OUTPUT_PATH:-}"

usage() {
    cat <<'EOF'
Usage: scripts/make-appcast.sh --version VERSION --key-file PRIVATE_KEY [options]

Options:
  --version VERSION     Release version, for example 0.1.4.
  --zip PATH            Update archive (default: dist/Pomodoro-VERSION.zip).
  --notes PATH          Release notes Markdown file (default: dist/Pomodoro-VERSION.md).
  --key-file PATH       Sparkle EdDSA private key file. Required.
  --output PATH         Appcast output path (default: dist/appcast.xml).
  -h, --help            Show this help.

Environment equivalents: VERSION, ZIP_PATH, NOTES_PATH,
SPARKLE_PRIVATE_KEY_FILE, and OUTPUT_PATH.
EOF
}

while (( $# )); do
    case "$1" in
        --version)
            VERSION="${2:-}"
            shift 2
            ;;
        --zip)
            ZIP_PATH="${2:-}"
            shift 2
            ;;
        --notes)
            NOTES_PATH="${2:-}"
            shift 2
            ;;
        --key-file)
            KEY_FILE="${2:-}"
            shift 2
            ;;
        --output)
            OUTPUT_PATH="${2:-}"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

if [[ -z "$VERSION" ]]; then
    echo "A release version is required (--version or VERSION)." >&2
    exit 1
fi
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Version must be MAJOR.MINOR.PATCH (got $VERSION)." >&2
    exit 1
fi

ZIP_PATH="${ZIP_PATH:-$ROOT/dist/Pomodoro-$VERSION.zip}"
NOTES_PATH="${NOTES_PATH:-$ROOT/dist/Pomodoro-$VERSION.md}"
OUTPUT_PATH="${OUTPUT_PATH:-$ROOT/dist/appcast.xml}"

if [[ -z "$KEY_FILE" ]]; then
    echo "A Sparkle private key file is required (--key-file or SPARKLE_PRIVATE_KEY_FILE)." >&2
    exit 1
fi
if [[ ! -s "$KEY_FILE" ]]; then
    echo "Sparkle private key file is missing or empty: $KEY_FILE" >&2
    exit 1
fi
if [[ ! -f "$ZIP_PATH" ]]; then
    echo "Update archive not found: $ZIP_PATH" >&2
    exit 1
fi
if [[ ! -f "$NOTES_PATH" ]]; then
    echo "Release notes not found: $NOTES_PATH" >&2
    exit 1
fi

STAGE="$(mktemp -d "${TMPDIR:-/tmp}/pomodoro-appcast.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT

STAGED_ZIP="$STAGE/Pomodoro-$VERSION.zip"
STAGED_NOTES="$STAGE/Pomodoro-$VERSION.md"
STAGED_APPCAST="$STAGE/appcast.xml"
cp "$ZIP_PATH" "$STAGED_ZIP"
cp "$NOTES_PATH" "$STAGED_NOTES"

"$SPARKLE_TOOLS/generate_appcast" \
    --ed-key-file "$KEY_FILE" \
    --download-url-prefix "https://github.com/hbin/Pomodoro/releases/download/v$VERSION/" \
    --embed-release-notes \
    --maximum-deltas 0 \
    --maximum-versions 0 \
    -o "$STAGED_APPCAST" \
    "$STAGE"

ENCLOSURE_SIGNATURE="$(xmllint \
    --xpath 'string((//*[local-name()="enclosure"])[1]/@*[local-name()="edSignature"])' \
    "$STAGED_APPCAST")"
if [[ -z "$ENCLOSURE_SIGNATURE" ]]; then
    echo "Generated appcast is missing the ZIP enclosure signature." >&2
    exit 1
fi
if ! grep -qF '<!-- sparkle-signatures:' "$STAGED_APPCAST"; then
    echo "Generated appcast is missing the signed-feed block." >&2
    exit 1
fi

EXPECTED_URL="https://github.com/hbin/Pomodoro/releases/download/v$VERSION/Pomodoro-$VERSION.zip"
ACTUAL_URL="$(xmllint \
    --xpath 'string((//*[local-name()="enclosure"])[1]/@url)' \
    "$STAGED_APPCAST")"
if [[ "$ACTUAL_URL" != "$EXPECTED_URL" ]]; then
    echo "Unexpected enclosure URL in appcast: $ACTUAL_URL" >&2
    exit 1
fi

EXPECTED_LENGTH="$(stat -f %z "$STAGED_ZIP")"
ACTUAL_LENGTH="$(xmllint \
    --xpath 'string((//*[local-name()="enclosure"])[1]/@length)' \
    "$STAGED_APPCAST")"
if [[ "$ACTUAL_LENGTH" != "$EXPECTED_LENGTH" ]]; then
    echo "Unexpected enclosure length in appcast: $ACTUAL_LENGTH (expected $EXPECTED_LENGTH)." >&2
    exit 1
fi

"$SPARKLE_TOOLS/sign_update" \
    --verify \
    --ed-key-file "$KEY_FILE" \
    "$STAGED_ZIP" \
    "$ENCLOSURE_SIGNATURE"

"$SPARKLE_TOOLS/sign_update" \
    --verify \
    --ed-key-file "$KEY_FILE" \
    "$STAGED_APPCAST"

mkdir -p "$(dirname "$OUTPUT_PATH")"
cp "$STAGED_APPCAST" "$OUTPUT_PATH"
echo "Generated signed appcast: $OUTPUT_PATH"
