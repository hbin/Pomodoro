#!/bin/zsh
#
# verify-release.sh — read-only post-publish verification for Pomodoro releases.
#
# The JSON release manifest (PROCESS.md §4, schema 1) is the only source of
# expectations. Every row prints EXPECTED vs ACTUAL. The script never writes to
# GitHub: every API call is a GET, and all local work stays in a work directory
# that is removed on success unless --keep is passed.
#
# Usage:
#   ./scripts/verify-release.sh --manifest .team/records/releases/v0.4.3.json
#
# Exit codes (the first failing category wins):
#   0  every check passed
#   1  usage error, or the manifest does not conform to schema 1
#   2  missing local tool, missing Sparkle sign_update, or gh not authenticated
#   3  a public URL did not return 200, or a download failed
#   4  asset inventory, asset metadata, or checksum mismatch
#   5  artifact verification failed (zip, DMG, bundle, signature, appcast)
#   6  release, git, CI, or feed metadata mismatch

set -uo pipefail
export LC_ALL=C

REPO_SLUG="hbin/Pomodoro"
ACCOUNT="com.hb.pomodoro"

EXIT_USAGE=1
EXIT_ENV=2
EXIT_URL=3
EXIT_ASSET=4
EXIT_ARTIFACT=5
EXIT_METADATA=6

TAG=""
VERSION=""
BUILD=""
MANIFEST=""
WORKDIR=""
SIGN_UPDATE=""
REPORT=""
KEEP=0
SKIP_EDDSA=0
QUIET=0
GRANDFATHERED=0
VALIDATE_ONLY=0

CHECKS=0
FAILURES=0
SKIPS=0
EXIT_CODE=0
ELAPSED=0
RESULTS=""
DMG_MOUNT=""
NETWORK_DOWN=0

SEP=$'\x1f'

usage() {
    cat <<'EOF'
Usage: verify-release.sh --manifest FILE [options]

  --manifest FILE      Release manifest (schema 1). Required: it is the only
                       source of expectations.
  --tag NAME           Cross-check NAME against release.tag.
  --version X.Y.Z      Cross-check against release.version.
  --build N            Cross-check against release.build.
  --repo OWNER/NAME    Default: hbin/Pomodoro.
  --workdir DIR        Work directory (default: a fresh mktemp directory).
  --keep               Keep the work directory when every check passes.
  --report FILE        Also write the PASS/FAIL table as TSV to FILE.
  --sign-update PATH   Sparkle sign_update binary (default: repo artifact).
  --skip-eddsa         Skip both EdDSA checks (not recommended).
  --quiet              Print only failing rows.
  --grandfathered      Downgrade missing required fields to SKIP rows. Use only
                       for manifests grandfathered before the 2026-11-26 freeze
                       (currently v0.4.2); present values are still validated.
  --check-manifest     Validate the manifest and exit; no network, no artifacts.
  -h, --help           Show this help.

Environment:
  REPO_DIR             Repository root used to locate sign_update.
                       Default: the current directory, then $HOME/Developer/Pomodoro.

Exit codes:
  0 all checks passed          4 asset inventory/checksum mismatch
  1 usage or manifest error    5 artifact verification failed
  2 environment/auth problem   6 release/git/CI/feed metadata mismatch
  3 public URL or download failed
EOF
}

die() {
    print -u2 -- "verify-release: $2"
    exit "$1"
}

cleanup() {
    if [[ -n "$DMG_MOUNT" && -d "$DMG_MOUNT" ]]; then
        hdiutil detach "$DMG_MOUNT" >/dev/null 2>&1 \
            || hdiutil detach -force "$DMG_MOUNT" >/dev/null 2>&1
    fi
}

trap cleanup EXIT INT TERM HUP

record() {
    local group="$1" name="$2" expected="$3" actual="$4" result="$5" note="${6:-}"
    CHECKS=$((CHECKS + 1))
    [[ "$result" == "SKIP" ]] && SKIPS=$((SKIPS + 1))
    print -r -- "$group$SEP$name$SEP$expected$SEP$actual$SEP$result$SEP$note" >> "$RESULTS"
}

ok() { record "$1" "$2" "$3" "$4" "PASS" "${5:-}"; }

bad() {
    record "$1" "$2" "$3" "$4" "FAIL" "${5:-}"
    FAILURES=$((FAILURES + 1))
}

skip_row() { record "$1" "$2" "$3" "$4" "SKIP" "${5:-}"; }

set_exit() {
    if (( EXIT_CODE == 0 )); then
        EXIT_CODE="$1"
    fi
}

check_eq() {
    # group | name | expected | actual | exit code | note
    local group="$1" name="$2" expected="$3" actual="$4" code="${5:-$EXIT_METADATA}" note="${6:-}"
    if [[ "$expected" == "$actual" ]]; then
        ok "$group" "$name" "$expected" "$actual" "$note"
    else
        bad "$group" "$name" "$expected" "${actual:-<missing>}" "$note"
        set_exit "$code"
    fi
}

check_in() {
    # group | name | expected (slash-separated alternatives) | actual | code | note
    local group="$1" name="$2" expected="$3" actual="$4" code="${5:-$EXIT_METADATA}" note="${6:-}"
    local option matched=0
    for option in "${(@s:/:)expected}"; do
        if [[ "$option" == "$actual" ]]; then
            matched=1
            break
        fi
    done
    if (( matched )); then
        ok "$group" "$name" "$expected" "$actual" "$note"
    else
        bad "$group" "$name" "$expected" "${actual:-<missing>}" "$note"
        set_exit "$code"
    fi
}

manifest_get() {
    awk -F '\037' -v key="$1" '$1 == key {print $2; exit}' "$WORKDIR/manifest.flat"
}

manifest_has() {
    awk -F '\037' -v key="$1" '$1 == key {found=1} END {exit found ? 0 : 1}' "$WORKDIR/manifest.flat"
}

expect_eq() {
    # group | name | manifest key | actual | exit code | note
    local group="$1" name="$2" key="$3" actual="$4" code="${5:-$EXIT_METADATA}" note="${6:-}"
    if manifest_has "$key"; then
        check_eq "$group" "$name" "$(manifest_get "$key")" "$actual" "$code" "$note"
    else
        skip_row "$group" "$name" "(no $key in manifest)" "${actual:-<none>}" \
            "field absent; grandfathered manifest"
    fi
}

manifest_count() {
    python3 - "$MANIFEST" "$1" <<'PY'
import json
import sys

value = json.load(open(sys.argv[1])).get(sys.argv[2])
print(len(value) if isinstance(value, (list, dict)) else 0)
PY
}

sha256() {
    shasum -a 256 "$1" | awk '{print $1}'
}

fetch() {
    curl -fsSL --connect-timeout 10 --retry 5 --retry-all-errors --retry-delay 2 --max-time 180 -o "$2" "$1"
}

gh_api() {
    local attempt=1
    local attempts=3
    (( NETWORK_DOWN )) && attempts=1
    while (( attempt <= attempts )); do
        if gh api "$@" > "$WORKDIR/gh.out" 2>"$WORKDIR/gh.err"; then
            cat "$WORKDIR/gh.out"
            return 0
        fi
        grep -q "HTTP 404" "$WORKDIR/gh.err" 2>/dev/null && return 1
        if network_error; then
            NETWORK_DOWN=1
            return 1
        fi
        sleep $((attempt * 2))
        attempt=$((attempt + 1))
    done
    return 1
}

url_status() {
    local code
    code="$(curl -sS -L -o /dev/null --connect-timeout 10 --max-time 60 \
        --retry 3 --retry-all-errors --retry-delay 1 -w '%{http_code}' "$1" 2>/dev/null)" \
        || code="000"
    print -r -- "${code:-000}"
}

network_error() {
    grep -Eq "error connecting|dial tcp|no such host|TLS handshake|could not resolve" "$WORKDIR/gh.err"
}

appcast_fields() {
    # Emits ITEM_COUNT, SHORT_VERSION, BUILD, TITLE, URL, LENGTH, SIGLEN.
    python3 - "$1" 2>/dev/null <<'PY'
import sys
import xml.etree.ElementTree as ET

namespace = "{http://www.andymatuschak.org/xml-namespaces/sparkle}"
channel = ET.parse(sys.argv[1]).getroot().find("./channel")
items = channel.findall("item")
print("ITEM_COUNT=%d" % len(items))
if not items:
    for key in ("SHORT_VERSION", "BUILD", "TITLE", "URL", "LENGTH", "SIGLEN"):
        print("%s=" % key)
    raise SystemExit(0)
item = items[0]
enclosure = item.find("enclosure")
print("SHORT_VERSION=%s" % (item.findtext(namespace + "shortVersionString") or ""))
print("BUILD=%s" % (item.findtext(namespace + "version") or ""))
print("TITLE=%s" % (item.findtext("title") or ""))
print("URL=%s" % (enclosure.get("url", "") if enclosure is not None else ""))
print("LENGTH=%s" % (enclosure.get("length", "") if enclosure is not None else ""))
print("SIGLEN=%d" % len(enclosure.get(namespace + "edSignature", "") if enclosure is not None else ""))
PY
}

field() {
    print -r -- "$1" | awk -F= -v key="$2" '$1 == key {sub(/^[^=]*=/, ""); print; exit}'
}

enclosure_signature() {
    python3 - "$1" <<'PY'
import sys
import xml.etree.ElementTree as ET

namespace = "{http://www.andymatuschak.org/xml-namespaces/sparkle}edSignature"
item = ET.parse(sys.argv[1]).getroot().find("./channel/item")
enclosure = item.find("enclosure")
print(enclosure.get(namespace, "") if enclosure is not None else "")
PY
}

signing_kind() {
    local details
    details="$(codesign -dv --verbose=4 "$1" 2>&1 || true)"
    if print -r -- "$details" | grep -q "Signature=adhoc"; then
        print -r -- "adhoc"
    elif print -r -- "$details" | grep -q "Authority=Developer ID Application"; then
        print -r -- "developer-id"
    else
        print -r -- "unknown"
    fi
}

notarization_state() {
    local output
    if output="$(spctl -a -t exec -vv "$1" 2>&1)"; then
        if print -r -- "$output" | grep -q "Notarized Developer ID"; then
            print -r -- "notarized"
        else
            print -r -- "accepted-not-notarized"
        fi
    else
        print -r -- "not-accepted"
    fi
}

while (( $# > 0 )); do
    case "$1" in
        --manifest) MANIFEST="${2:-}"; shift 2 ;;
        --tag) TAG="${2:-}"; shift 2 ;;
        --version) VERSION="${2:-}"; shift 2 ;;
        --build) BUILD="${2:-}"; shift 2 ;;
        --repo) REPO_SLUG="${2:-}"; shift 2 ;;
        --workdir) WORKDIR="${2:-}"; shift 2 ;;
        --report) REPORT="${2:-}"; shift 2 ;;
        --sign-update) SIGN_UPDATE="${2:-}"; shift 2 ;;
        --keep) KEEP=1; shift ;;
        --skip-eddsa) SKIP_EDDSA=1; shift ;;
        --quiet) QUIET=1; shift ;;
        --grandfathered) GRANDFATHERED=1; shift ;;
        --check-manifest) VALIDATE_ONLY=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) usage >&2; die "$EXIT_USAGE" "unknown argument: $1" ;;
    esac
done

[[ -n "$MANIFEST" ]] || die "$EXIT_USAGE" "--manifest is required"
[[ -r "$MANIFEST" ]] || die "$EXIT_USAGE" "manifest is not readable: $MANIFEST"

if [[ -z "$WORKDIR" ]]; then
    WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/pomodoro-verify.XXXXXX")" \
        || die "$EXIT_ENV" "could not create a work directory"
else
    mkdir -p "$WORKDIR" || die "$EXIT_ENV" "could not create $WORKDIR"
fi
RESULTS="$WORKDIR/results.tsv"
: > "$RESULTS"

# ---------------------------------------------------------------- manifest ---

python3 - "$MANIFEST" "$WORKDIR" > "$WORKDIR/manifest.errors" <<'PY'
import datetime
import json
import re
import sys

path, outdir = sys.argv[1], sys.argv[2]
errors = []
ALLOWED_BY = {"JB", "VJ", "Maxey", "Lebron James", "Embiid"}


def fail(where, message):
    errors.append("INVALID\t%s\t%s" % (where, message))


def missing(where, message):
    errors.append("MISSING\t%s\t%s" % (where, message))


def is_time(value, date_only=False):
    if not isinstance(value, str) or not value:
        return False
    if date_only and re.fullmatch(r"\d{4}-\d{2}-\d{2}", value):
        try:
            datetime.date.fromisoformat(value)
            return True
        except ValueError:
            return False
    text = value[:-1] + "+00:00" if value.endswith("Z") else value
    try:
        datetime.datetime.fromisoformat(text)
        return True
    except ValueError:
        return False


def check_keys(obj, base, required, optional=()):
    for key in sorted(required):
        if key not in obj:
            missing("%s.%s" % (base, key), "missing required key")
    for key in obj:
        if key not in required and key not in optional:
            fail("%s.%s" % (base, key), "unexpected key for schema 1")


def check_scalar(obj, base, key, kind):
    if key not in obj:
        missing("%s.%s" % (base, key), "missing required key")
        return None
    value = obj[key]
    if isinstance(value, bool) != (kind is bool) or not isinstance(value, kind):
        fail("%s.%s" % (base, key), "expected %s" % kind.__name__)
        return None
    return value


def check_time(obj, base, key, date_only=False):
    value = check_scalar(obj, base, key, str)
    if value is not None and not is_time(value, date_only):
        where = "%s.%s" % (base, key)
        fail(where, "not ISO 8601" + ("" if date_only else " (date-only allowed only in verification[].verified_at)"))
    return value


def check_sha(obj, base, key, length):
    value = check_scalar(obj, base, key, str)
    if value is not None and not re.fullmatch(r"[0-9a-f]{%d}" % length, value):
        fail("%s.%s" % (base, key), "expected %d lowercase hex characters" % length)
    return value


try:
    with open(path, encoding="utf-8") as handle:
        manifest = json.load(handle)
except Exception as exc:  # noqa: BLE001 - report any parse failure verbatim
    print("INVALID\troot\tnot valid JSON: %s" % exc)
    raise SystemExit(0)

if not isinstance(manifest, dict):
    print("INVALID\troot\texpected a JSON object")
    raise SystemExit(0)

check_keys(
    manifest,
    "root",
    {
        "schema", "release", "git", "ci", "assets", "appcast", "package",
        "verification", "caveats", "process_exceptions", "rollback",
    },
    {"note"},
)

schema = check_scalar(manifest, "root", "schema", int)
if schema is not None and schema != 1:
    fail("schema", "this script supports schema 1; found %d (bump the script with the schema)" % schema)


def object_at(name):
    value = manifest.get(name)
    if name not in manifest:
        missing(name, "missing required object")
        return {}
    if not isinstance(value, dict):
        fail(name, "expected an object")
        return {}
    return value


release = object_at("release")
check_keys(release, "release", {
    "version", "build", "tag", "channel", "release_id", "release_url",
    "created_at", "published_at", "draft", "prerelease", "immutable",
})
release_version = check_scalar(release, "release", "version", str)
check_scalar(release, "release", "build", str)
release_tag = check_scalar(release, "release", "tag", str)
channel = check_scalar(release, "release", "channel", str)
check_scalar(release, "release", "release_id", int)
check_scalar(release, "release", "release_url", str)
check_time(release, "release", "created_at")
check_time(release, "release", "published_at")
for key in ("draft", "prerelease", "immutable"):
    check_scalar(release, "release", key, bool)

if channel is not None and channel not in ("stable", "beta"):
    fail("release.channel", "expected stable or beta")
if release_version and release_tag and release_tag != "v" + release_version:
    fail("release.tag", "must be v + release.version")
if release_version and channel:
    is_beta = "-beta." in release_version
    if is_beta != (channel == "beta"):
        fail("release.channel", "does not match the version suffix")

git = object_at("git")
check_keys(git, "git", {"main_snapshot", "commit_sha", "tag_object_sha", "tag_peel", "tag_message"}, {"note"})
for key in ("main_snapshot", "commit_sha", "tag_object_sha", "tag_peel"):
    check_sha(git, "git", key, 40)
check_scalar(git, "git", "tag_message", str)

ci = object_at("ci")
check_keys(ci, "ci", {
    "run_id", "run_url", "run_attempt", "event", "head_branch", "head_sha", "conclusion",
}, {"note"})
if "run_id" not in ci:
    missing("ci.run_id", "missing required key")
elif ci.get("run_id") is None:
    if "note" not in ci:
        fail("ci.run_id", "null requires an adjacent note")
else:
    check_scalar(ci, "ci", "run_id", int)
check_scalar(ci, "ci", "run_url", str)
check_scalar(ci, "ci", "run_attempt", int)
for key in ("event", "head_branch", "conclusion"):
    check_scalar(ci, "ci", key, str)
check_sha(ci, "ci", "head_sha", 40)

assets = manifest.get("assets")
if "assets" not in manifest:
    missing("assets", "missing required object")
    assets = {}
elif not isinstance(assets, dict) or not assets:
    fail("assets", "expected a non-empty object")
    assets = {}
for name, entry in assets.items():
    base = "assets.%s" % name
    if not name or "/" in name:
        fail(base, "invalid asset name")
    if not isinstance(entry, dict):
        fail(base, "expected object")
        continue
    check_keys(entry, base, {"asset_id", "size", "sha256", "uploaded_at"})
    check_scalar(entry, base, "asset_id", int)
    size = check_scalar(entry, base, "size", int)
    if size is not None and size <= 0:
        fail(base + ".size", "expected a positive byte count")
    check_sha(entry, base, "sha256", 64)
    check_time(entry, base, "uploaded_at")

appcast = object_at("appcast")
check_keys(appcast, "appcast", {
    "short_version", "build", "enclosure_url", "enclosure_length",
    "eddsa_appcast_verified", "eddsa_enclosure_verified",
    "beta_appcast_sha256", "latest_resolves_to",
})
for key in ("short_version", "build", "enclosure_url", "latest_resolves_to"):
    check_scalar(appcast, "appcast", key, str)
check_scalar(appcast, "appcast", "enclosure_length", int)
for key in ("eddsa_appcast_verified", "eddsa_enclosure_verified"):
    check_scalar(appcast, "appcast", key, bool)
check_sha(appcast, "appcast", "beta_appcast_sha256", 64)

package = object_at("package")
check_keys(package, "package", {
    "bundle_short_version", "bundle_version", "minimum_system_version",
    "architectures", "locales", "signing", "notarized", "dmg_verify",
    "zip_integrity",
})
for key in ("bundle_short_version", "bundle_version", "minimum_system_version"):
    check_scalar(package, "package", key, str)
for key in ("architectures", "locales"):
    if key not in package:
        missing("package." + key, "missing required array")
        continue
    value = package[key]
    if not isinstance(value, list) or not value or not all(isinstance(item, str) and item for item in value):
        fail("package." + key, "expected a non-empty array of strings")
signing = check_scalar(package, "package", "signing", str)
if signing is not None and signing not in ("adhoc", "developer-id"):
    fail("package.signing", "expected adhoc or developer-id")
check_scalar(package, "package", "notarized", bool)
dmg_verify = check_scalar(package, "package", "dmg_verify", str)
if dmg_verify is not None and dmg_verify not in ("VALID", "FAILED"):
    fail("package.dmg_verify", "expected VALID or FAILED")
zip_integrity = check_scalar(package, "package", "zip_integrity", str)
if zip_integrity is not None and zip_integrity not in ("ok", "failed"):
    fail("package.zip_integrity", "expected ok or failed")

verification = manifest.get("verification")
if "verification" not in manifest:
    missing("verification", "missing required array")
    verification = []
elif not isinstance(verification, list):
    fail("verification", "expected an array")
    verification = []
for index, entry in enumerate(verification):
    base = "verification.%d" % index
    if not isinstance(entry, dict):
        fail(base, "expected object")
        continue
    check_keys(entry, base, {"by", "role", "result", "verified_at"}, {"note"})
    by = check_scalar(entry, base, "by", str)
    if by is not None and by not in ALLOWED_BY:
        fail(base + ".by", "not an allowed reviewer name")
    check_scalar(entry, base, "role", str)
    result = check_scalar(entry, base, "result", str)
    if result is not None and (not result or len(result) > 160):
        fail(base + ".result", "expected one clause of at most 160 characters")
    check_time(entry, base, "verified_at", date_only=True)

caveats = manifest.get("caveats")
if "caveats" not in manifest:
    missing("caveats", "missing required array")
elif not isinstance(caveats, list) or not all(isinstance(item, str) for item in caveats):
    fail("caveats", "expected an array of strings")

exceptions = manifest.get("process_exceptions")
if "process_exceptions" not in manifest:
    missing("process_exceptions", "missing required array")
    exceptions = []
elif not isinstance(exceptions, list):
    fail("process_exceptions", "expected an array")
    exceptions = []
for index, entry in enumerate(exceptions):
    base = "process_exceptions.%d" % index
    if not isinstance(entry, dict):
        fail(base, "expected object")
        continue
    check_keys(entry, base, {
        "what", "rule_violated", "approval", "approved_at", "recorded_post_hoc", "impact",
    })
    for key in ("what", "rule_violated", "approval", "impact"):
        check_scalar(entry, base, key, str)
    check_time(entry, base, "approved_at")
    check_scalar(entry, base, "recorded_post_hoc", bool)

rollback = object_at("rollback")
check_keys(rollback, "rollback", {
    "previous_good_tag", "previous_good_tag_object_sha", "local_backup_refs",
})
check_scalar(rollback, "rollback", "previous_good_tag", str)
check_sha(rollback, "rollback", "previous_good_tag_object_sha", 40)
check_scalar(rollback, "rollback", "local_backup_refs", str)


def render(value):
    if isinstance(value, bool):
        return "true" if value else "false"
    if value is None:
        return ""
    return str(value)


lines = []


def walk(value, prefix):
    if isinstance(value, dict):
        for key, item in value.items():
            walk(item, "%s.%s" % (prefix, key) if prefix else key)
        return
    if isinstance(value, list):
        if all(not isinstance(item, (dict, list)) for item in value):
            lines.append((prefix, " ".join(sorted(render(item) for item in value))))
            return
        for index, item in enumerate(value):
            walk(item, "%s.%d" % (prefix, index))
        return
    lines.append((prefix, render(value)))


for top_key, top_value in manifest.items():
    if top_key != "assets":
        walk(top_value, top_key)

with open(outdir + "/manifest.flat", "w", encoding="utf-8") as handle:
    for key, value in lines:
        handle.write("%s\x1f%s\n" % (key, value))

with open(outdir + "/manifest.assets", "w", encoding="utf-8") as handle:
    for name in sorted(assets):
        entry = assets[name] if isinstance(assets[name], dict) else {}
        row = [name, render(entry.get("asset_id")), render(entry.get("size")),
               render(entry.get("sha256")), render(entry.get("uploaded_at"))]
        handle.write("\x1f".join(row) + "\n")

unique = []
seen = set()
for line in errors:
    kind, where, message = line.split("\t", 2)
    if where.startswith("root."):
        where = where[5:]
    key = (kind, where)
    if key in seen:
        continue
    seen.add(key)
    unique.append("%s\t%s\t%s" % (kind, where, message))

for line in unique:
    print(line)
PY

INVALID_FIELDS="$(grep '^INVALID' "$WORKDIR/manifest.errors" || true)"
MISSING_FIELDS="$(grep '^MISSING' "$WORKDIR/manifest.errors" || true)"
if [[ -n "$INVALID_FIELDS" ]]; then
    print -u2 -- "verify-release: manifest does not conform to schema 1:"
    print -r -- "$INVALID_FIELDS" | awk -F '\t' '{printf "  %s: %s\n", $2, $3}' >&2
    exit "$EXIT_USAGE"
fi

MANIFEST_TAG="$(manifest_get release.tag)"
MANIFEST_VERSION="$(manifest_get release.version)"
MANIFEST_BUILD="$(manifest_get release.build)"

if (( GRANDFATHERED )) && [[ "$MANIFEST_TAG" != "v0.4.2" ]]; then
    die "$EXIT_USAGE" "--grandfathered only applies to the v0.4.2 manifest (manifest tag: ${MANIFEST_TAG:-<missing>})"
fi

if [[ -n "$MISSING_FIELDS" && "$GRANDFATHERED" != "1" ]]; then
    print -u2 -- "verify-release: manifest is missing required schema-1 fields:"
    print -r -- "$MISSING_FIELDS" | awk -F '\t' '{printf "  %s\n", $2}' >&2
    print -u2 -- "pass --grandfathered only for manifests recorded before the 2026-11-26 freeze"
    exit "$EXIT_USAGE"
fi

[[ -n "$TAG" ]] || TAG="$MANIFEST_TAG"
[[ -n "$VERSION" ]] || VERSION="$MANIFEST_VERSION"
[[ -n "$BUILD" ]] || BUILD="$MANIFEST_BUILD"

[[ "$TAG" == "$MANIFEST_TAG" ]] || die "$EXIT_USAGE" "--tag $TAG does not match manifest tag $MANIFEST_TAG"
[[ "$VERSION" == "$MANIFEST_VERSION" ]] || die "$EXIT_USAGE" "--version $VERSION does not match manifest version $MANIFEST_VERSION"
[[ "$BUILD" == "$MANIFEST_BUILD" ]] || die "$EXIT_USAGE" "--build $BUILD does not match manifest build $MANIFEST_BUILD"

CHANNEL="$(manifest_get release.channel)"

if (( VALIDATE_ONLY )); then
    print -r -- "manifest:  $MANIFEST"
    print -r -- "tag:       ${TAG:-<missing>}"
    print -r -- "version:   ${VERSION:-<missing>}   build: ${BUILD:-<missing>}   channel: ${CHANNEL:-<missing>}"
    print -r -- "assets:    $(manifest_count assets)"
    if (( GRANDFATHERED )); then
        print -r -- "mode:      GRANDFATHERED (v0.4.2 missing fields -> SKIP)"
    fi
    if [[ -n "$MISSING_FIELDS" ]]; then
        print -r -- "grandfathered gaps:"
        print -r -- "$MISSING_FIELDS" | awk -F '\t' '{printf "  %s (%s)\n", $2, $3}'
    fi
    print -r -- "RESULT: PASS — manifest conforms to schema 1"
    exit 0
fi

for tool in curl gh python3 plutil lipo ditto unzip hdiutil shasum codesign spctl awk; do
    command -v "$tool" >/dev/null 2>&1 || die "$EXIT_ENV" "required tool not found: $tool"
done

START=$SECONDS

REPO_DIR="${REPO_DIR:-}"
if [[ -z "$REPO_DIR" ]]; then
    if [[ -d "$PWD/.build/artifacts/sparkle/Sparkle/bin" ]]; then
        REPO_DIR="$PWD"
    elif [[ -d "$HOME/Developer/Pomodoro/.build/artifacts/sparkle/Sparkle/bin" ]]; then
        REPO_DIR="$HOME/Developer/Pomodoro"
    fi
fi
if [[ -z "$SIGN_UPDATE" && -n "$REPO_DIR" ]]; then
    SIGN_UPDATE="$REPO_DIR/.build/artifacts/sparkle/Sparkle/bin/sign_update"
fi

if (( SKIP_EDDSA == 0 )); then
    [[ -n "$SIGN_UPDATE" && -x "$SIGN_UPDATE" ]] \
        || die "$EXIT_ENV" "Sparkle sign_update not found; pass --sign-update PATH or build the app once"
fi
gh auth status >/dev/null 2>&1 || die "$EXIT_ENV" "gh is not authenticated"

ok "MANIFEST" "schema conforms" "schema 1" "schema 1"

if (( GRANDFATHERED )); then
    ok "MANIFEST" "GRANDFATHERED MODE" "v0.4.2 only" "$MANIFEST_TAG" \
        "missing schema-1 fields are reported as SKIP; present values are still enforced"
fi

if [[ -n "$MISSING_FIELDS" ]]; then
    while IFS=$'\t' read -r _kind where message; do
        [[ -n "$where" ]] || continue
        skip_row "MANIFEST" "missing $where" "required by schema 1" "absent" "grandfathered; $message"
    done <<< "$MISSING_FIELDS"
fi

BASE="https://github.com/$REPO_SLUG/releases"
ZIP_NAME="Pomodoro-$VERSION.zip"

print -r -- ""
print -r -- "Pomodoro release verification"
print -r -- "repo:     $REPO_SLUG"
print -r -- "tag:      $TAG   version: $VERSION   build: $BUILD   channel: $CHANNEL"
print -r -- "manifest: $MANIFEST"
print -r -- "workdir:  $WORKDIR"
print -r -- "mode:     read-only (GET requests only)"
if (( GRANDFATHERED )); then
    print -r -- "mode:     GRANDFATHERED (v0.4.2 missing fields -> SKIP)"
fi
print -r -- ""

# ----------------------------------------------------------- consistency ---

expect_eq "CONSISTENCY" "release.version = appcast.short_version" appcast.short_version "$VERSION" "$EXIT_USAGE"
expect_eq "CONSISTENCY" "release.version = package.bundle_short_version" package.bundle_short_version "$VERSION" "$EXIT_USAGE"
expect_eq "CONSISTENCY" "release.build = appcast.build" appcast.build "$BUILD" "$EXIT_USAGE"
expect_eq "CONSISTENCY" "release.build = package.bundle_version" package.bundle_version "$BUILD" "$EXIT_USAGE"
check_eq "CONSISTENCY" "tag = v + version" "v$VERSION" "$TAG" "$EXIT_USAGE"

# --------------------------------------------------------------- release ---

release_json="$WORKDIR/release.json"
RELEASE_EXISTS=1
if gh_api "repos/$REPO_SLUG/releases/tags/$TAG" > "$release_json"; then
    ok "RELEASE" "release exists" "$TAG" "200"
else
    bad "RELEASE" "release exists" "$TAG" "$(head -1 "$WORKDIR/gh.err")"
    if network_error; then
        set_exit "$EXIT_ENV"
    else
        set_exit "$EXIT_METADATA"
    fi
    RELEASE_EXISTS=0
fi

if (( RELEASE_EXISTS )) && [[ -s "$release_json" ]]; then
    python3 - "$release_json" "$WORKDIR/release.flat" <<'PY'
import json
import sys

data = json.load(open(sys.argv[1]))
fields = ("draft", "prerelease", "immutable", "id", "tag_name", "html_url",
          "created_at", "published_at", "updated_at")
with open(sys.argv[2], "w", encoding="utf-8") as handle:
    for key in fields:
        value = data.get(key)
        if isinstance(value, bool):
            text = "true" if value else "false"
        elif value is None:
            text = ""
        else:
            text = str(value)
        handle.write("%s\x1f%s\n" % (key, text))
PY

    rget() { awk -F '\037' -v key="$1" '$1 == key {print $2; exit}' "$WORKDIR/release.flat"; }

    expect_eq "RELEASE" "draft state" release.draft "$(rget draft)" "$EXIT_METADATA"
    expect_eq "RELEASE" "prerelease state" release.prerelease "$(rget prerelease)" "$EXIT_METADATA"
    check_eq "RELEASE" "tag name" "$TAG" "$(rget tag_name)" "$EXIT_METADATA"
    expect_eq "RELEASE" "release id" release.release_id "$(rget id)" "$EXIT_METADATA"
    expect_eq "RELEASE" "release url" release.release_url "$(rget html_url)" "$EXIT_METADATA"
    expect_eq "RELEASE" "created_at" release.created_at "$(rget created_at)" "$EXIT_METADATA"
    expect_eq "RELEASE" "published_at" release.published_at "$(rget published_at)" "$EXIT_METADATA"
    expect_eq "RELEASE" "immutable flag" release.immutable "$(rget immutable)" "$EXIT_METADATA"
    if [[ "$(manifest_get release.immutable)" == "false" ]]; then
        published_at="$(rget published_at)"
        updated_at="$(rget updated_at)"
        if [[ -z "$published_at" ]]; then
            skip_row "RELEASE" "no edit after publish (updated_at)" "publication time" "${updated_at:-<missing>}" \
                "draft; publication time not set"
        elif [[ "$updated_at" == "$published_at" ]]; then
            ok "RELEASE" "no edit after publish (updated_at)" "$published_at" "$updated_at" \
                "an edit to the release body or settings after publication pushes updated_at past published_at; asset overwrite is covered by asset id/sha256/uploaded_at"
        else
            bad "RELEASE" "no edit after publish (updated_at)" "$published_at" "$updated_at" \
                "updated_at crossed published_at; the release body or settings changed after publication"
            set_exit "$EXIT_METADATA"
        fi
    fi

    python3 - "$release_json" > "$WORKDIR/api-assets.tsv" <<'PY'
import json
import sys

data = json.load(open(sys.argv[1]))
for asset in sorted(data.get("assets", []), key=lambda item: item["name"]):
    digest = (asset.get("digest") or "").removeprefix("sha256:")
    print("%s\x1f%s\x1f%s\x1f%s\x1f%s" % (
        asset["name"], asset.get("id", ""), asset.get("size", ""),
        asset.get("state", ""), digest,
    ))
PY
else
    skip_row "RELEASE" "release metadata" "$TAG" "not fetched" "release lookup failed"
fi

# ------------------------------------------------------------------- git ---

expected_main="$(manifest_get git.main_snapshot)"
expected_commit="$(manifest_get git.commit_sha)"
expected_tag_object="$(manifest_get git.tag_object_sha)"
expected_tag_peel="$(manifest_get git.tag_peel)"

tag_json="$WORKDIR/tag-ref.json"
if gh_api "repos/$REPO_SLUG/git/ref/tags/$TAG" > "$tag_json"; then
    tag_type="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("object",{}).get("type",""))' "$tag_json")"
    tag_object="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("object",{}).get("sha",""))' "$tag_json")"
    check_eq "GIT" "tag is annotated" "tag" "$tag_type" "$EXIT_METADATA"
    check_eq "GIT" "tag object sha" "$expected_tag_object" "$tag_object" "$EXIT_METADATA"

    if [[ "$tag_type" == "tag" ]]; then
        tag_body="$WORKDIR/tag-body.json"
        if gh_api "repos/$REPO_SLUG/git/tags/$tag_object" > "$tag_body"; then
            peeled="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("object",{}).get("sha",""))' "$tag_body")"
            message="$(python3 -c 'import json,sys;print((json.load(open(sys.argv[1])).get("message","") or "").rstrip())' "$tag_body")"
            check_eq "GIT" "tag peeled commit" "$expected_tag_peel" "$peeled" "$EXIT_METADATA"
            check_eq "GIT" "tag message" "$(manifest_get git.tag_message)" "$message" "$EXIT_METADATA"
        else
            bad "GIT" "tag object readable" "annotated tag body" "$(head -1 "$WORKDIR/gh.err")"
            set_exit "$EXIT_METADATA"
        fi
    fi
else
    bad "GIT" "tag exists" "$TAG" "$(head -1 "$WORKDIR/gh.err")"
    set_exit "$EXIT_METADATA"
fi

check_eq "GIT" "commit_sha = tag_peel" "$expected_tag_peel" "$expected_commit" "$EXIT_USAGE"

if [[ -n "$expected_main" && -n "$expected_commit" ]]; then
    compare_result="$(gh_api "repos/$REPO_SLUG/compare/$expected_main...$expected_commit" --jq .status 2>/dev/null || print -r -- "")"
    check_in "GIT" "release commit contained in main_snapshot" "identical/ahead" "$compare_result" "$EXIT_METADATA" \
        "main_snapshot is main at release time, not current main"
fi

current_main="$(gh_api "repos/$REPO_SLUG/git/ref/heads/main" --jq .object.sha 2>/dev/null || print -r -- "")"
if [[ -n "$current_main" && -n "$expected_commit" ]]; then
    compare_result="$(gh_api "repos/$REPO_SLUG/compare/$expected_commit...$current_main" --jq .status 2>/dev/null || print -r -- "")"
    check_in "GIT" "release commit contained in current main" "identical/ahead" "$compare_result" "$EXIT_METADATA" \
        "diverged means history was rewritten and the tag no longer matches main"
    if [[ "$current_main" == "$expected_main" ]]; then
        ok "GIT" "main advanced since release" "$expected_main" "$current_main"
    else
        skip_row "GIT" "main advanced since release" "$expected_main" "$current_main" \
            "expected for any release after the next merge; not a failure"
    fi
else
    bad "GIT" "current main readable" "refs/heads/main" "missing"
    set_exit "$EXIT_METADATA"
fi

# -------------------------------------------------------------------- ci ---

run_id="$(manifest_get ci.run_id)"
if [[ -n "$run_id" ]]; then
    ci_json="$WORKDIR/ci.json"
    if gh_api "repos/$REPO_SLUG/actions/runs/$run_id" > "$ci_json"; then
        python3 - "$ci_json" > "$WORKDIR/ci.flat" <<'PY'
import json
import sys

data = json.load(open(sys.argv[1]))
for key in ("id", "html_url", "run_attempt", "event", "head_branch", "head_sha", "conclusion"):
    value = data.get(key)
    print("%s\x1f%s" % (key, "" if value is None else value))
PY
        cget() { awk -F '\037' -v key="$1" '$1 == key {print $2; exit}' "$WORKDIR/ci.flat"; }

        check_eq "CI" "run id" "$run_id" "$(cget id)" "$EXIT_METADATA"
        expect_eq "CI" "run url" ci.run_url "$(cget html_url)" "$EXIT_METADATA"
        expect_eq "CI" "run attempt" ci.run_attempt "$(cget run_attempt)" "$EXIT_METADATA"
        expect_eq "CI" "event" ci.event "$(cget event)" "$EXIT_METADATA"
        expect_eq "CI" "head branch" ci.head_branch "$(cget head_branch)" "$EXIT_METADATA"
        expect_eq "CI" "head sha" ci.head_sha "$(cget head_sha)" "$EXIT_METADATA"
        check_eq "CI" "head sha = release commit" "$expected_commit" "$(cget head_sha)" "$EXIT_METADATA"
        expect_eq "CI" "conclusion" ci.conclusion "$(cget conclusion)" "$EXIT_METADATA"
    else
        bad "CI" "run exists" "$run_id" "$(head -1 "$WORKDIR/gh.err")"
        set_exit "$EXIT_METADATA"
    fi
else
    skip_row "CI" "run recorded" "(null in manifest)" "-" "grandfathered: the original run was never recorded"
fi

# ---------------------------------------------------------------- assets ---

canonical_assets=(
    "appcast.xml"
    "$ZIP_NAME"
    "$ZIP_NAME.sha256"
    "Pomodoro.dmg"
    "Pomodoro.dmg.sha256"
)
for name in "${canonical_assets[@]}"; do
    if awk -F '\037' -v n="$name" '$1 == n {found=1} END {exit found ? 0 : 1}' "$WORKDIR/manifest.assets"; then
        ok "ASSETS" "manifest lists $name" "present" "present"
    else
        bad "ASSETS" "manifest lists $name" "present" "missing"
        set_exit "$EXIT_ASSET"
    fi
done

if (( RELEASE_EXISTS )) && [[ -s "$WORKDIR/api-assets.tsv" ]]; then
    while IFS=$'\x1f' read -r name asset_id size sha uploaded; do
        [[ -n "$name" ]] || continue
        line="$(awk -F '\037' -v n="$name" '$1 == n {print; exit}' "$WORKDIR/api-assets.tsv")"
        if [[ -z "$line" ]]; then
            bad "ASSETS" "asset present: $name" "present" "missing"
            set_exit "$EXIT_ASSET"
            continue
        fi
        IFS=$'\x1f' read -r _ api_id api_size api_state api_digest <<< "$line"
        expected_meta="id=$asset_id size=$size"
        actual_meta="id=$api_id size=$api_size state=$api_state"
        if [[ "$asset_id" == "$api_id" && "$size" == "$api_size" && "$api_state" == "uploaded" ]]; then
            ok "ASSETS" "asset metadata: $name" "$expected_meta" "$actual_meta"
        else
            bad "ASSETS" "asset metadata: $name" "$expected_meta" "$actual_meta"
            set_exit "$EXIT_ASSET"
        fi
        if [[ -z "$sha" ]]; then
            skip_row "ASSETS" "asset sha256: $name" "(no manifest sha256)" "$api_digest" "field absent; grandfathered manifest"
        elif [[ "$sha" == "$api_digest" ]]; then
            ok "ASSETS" "asset sha256: $name" "${sha:0:16}..." "${api_digest:0:16}..."
        else
            bad "ASSETS" "asset sha256: $name" "$sha" "${api_digest:-<none>}"
            set_exit "$EXIT_ASSET"
        fi
        api_uploaded="$(python3 - "$WORKDIR/release.json" "$name" <<'PY'
import json
import sys

data = json.load(open(sys.argv[1]))
for asset in data.get("assets", []):
    if asset.get("name") == sys.argv[2]:
        print(asset.get("created_at", ""))
        break
PY
)"
        if [[ -z "$uploaded" ]]; then
            skip_row "ASSETS" "asset uploaded_at: $name" "(no manifest uploaded_at)" "$api_uploaded" "field absent; grandfathered manifest"
        else
            check_eq "ASSETS" "asset uploaded_at: $name" "$uploaded" "$api_uploaded" "$EXIT_ASSET"
        fi
    done < "$WORKDIR/manifest.assets"

    manifest_count="$(wc -l < "$WORKDIR/manifest.assets" | tr -d ' ')"
    api_count="$(wc -l < "$WORKDIR/api-assets.tsv" | tr -d ' ')"
    check_eq "ASSETS" "asset count" "$manifest_count" "$api_count" "$EXIT_ASSET"

    unexpected="$(awk -F '\037' 'NR == FNR {want[$1]; next} !($1 in want) {print $1}' \
        "$WORKDIR/manifest.assets" "$WORKDIR/api-assets.tsv" | tr '\n' ' ')"
    if [[ -z "$unexpected" ]]; then
        ok "ASSETS" "unexpected assets" "none" "none"
    else
        bad "ASSETS" "unexpected assets" "none" "$unexpected"
        set_exit "$EXIT_ASSET"
    fi
else
    skip_row "ASSETS" "asset inventory" "manifest vs API" "not fetched" "release lookup failed"
fi

# ------------------------------------------------------------------ urls ---

urls=(
    "$BASE/latest/download/appcast.xml"
    "$BASE/download/$TAG/$ZIP_NAME"
    "$BASE/download/$TAG/$ZIP_NAME.sha256"
    "$BASE/download/$TAG/Pomodoro.dmg"
    "$BASE/download/$TAG/Pomodoro.dmg.sha256"
    "$BASE/download/beta/appcast.xml"
)
for url in "${urls[@]}"; do
    code="$(url_status "$url")"
    label="${url#*releases/}"
    if [[ "$code" == "200" ]]; then
        ok "PUBLIC" "url 200" "200" "$code" "$label"
    else
        bad "PUBLIC" "url 200" "200" "$code" "$label"
        set_exit "$EXIT_URL"
    fi
done

# -------------------------------------------------------------- download ---

mkdir -p "$WORKDIR/assets"
downloads=(
    "$ZIP_NAME"
    "$ZIP_NAME.sha256"
    "Pomodoro.dmg"
    "Pomodoro.dmg.sha256"
    "appcast.xml"
)
for name in "${downloads[@]}"; do
    if fetch "$BASE/download/$TAG/$name" "$WORKDIR/assets/$name"; then
        ok "DOWNLOAD" "download $name" "200" "$(stat -f%z "$WORKDIR/assets/$name") bytes"
    else
        bad "DOWNLOAD" "download $name" "200" "curl failed"
        set_exit "$EXIT_URL"
    fi
done
if fetch "$BASE/latest/download/appcast.xml" "$WORKDIR/assets/latest-appcast.xml"; then
    ok "DOWNLOAD" "download latest appcast" "200" "$(stat -f%z "$WORKDIR/assets/latest-appcast.xml") bytes"
else
    bad "DOWNLOAD" "download latest appcast" "200" "curl failed"
    set_exit "$EXIT_URL"
fi
if fetch "$BASE/download/beta/appcast.xml" "$WORKDIR/assets/beta-appcast.xml"; then
    ok "DOWNLOAD" "download beta appcast" "200" "$(stat -f%z "$WORKDIR/assets/beta-appcast.xml") bytes"
else
    bad "DOWNLOAD" "download beta appcast" "200" "curl failed"
    set_exit "$EXIT_URL"
fi

# ------------------------------------------------------------------- sha ---

LATEST_TAG="$(gh_api "repos/$REPO_SLUG/releases/latest" --jq .tag_name 2>/dev/null || print -r -- "")"
SUPERSEDED=0
if [[ "$CHANNEL" == "stable" && -n "$LATEST_TAG" && "$LATEST_TAG" != "$TAG" ]]; then
    SUPERSEDED=1
fi

for name in "$ZIP_NAME" "Pomodoro.dmg" "appcast.xml"; do
    file="$WORKDIR/assets/$name"
    [[ -f "$file" ]] || continue
    actual="$(sha256 "$file")"
    expected="$(awk -F '\037' -v n="$name" '$1 == n {print $4; exit}' "$WORKDIR/manifest.assets")"
    if [[ -z "$expected" ]]; then
        skip_row "SHA256" "sha256 $name" "(no manifest sha256)" "$actual" "field absent; grandfathered manifest"
    else
        check_eq "SHA256" "sha256 $name" "$expected" "$actual" "$EXIT_ASSET"
    fi
done

if [[ -f "$WORKDIR/assets/latest-appcast.xml" ]]; then
    if [[ "$CHANNEL" == "beta" ]]; then
        skip_row "SHA256" "sha256 latest appcast" "$(manifest_get appcast.latest_resolves_to)" \
            "beta release" "latest stays on the last stable release"
    elif (( SUPERSEDED )); then
        skip_row "SHA256" "sha256 latest appcast" "$TAG" "$LATEST_TAG" \
            "release is superseded; releases/latest now serves $LATEST_TAG"
    else
        expected="$(awk -F '\037' -v n="appcast.xml" '$1 == n {print $4; exit}' "$WORKDIR/manifest.assets")"
        check_eq "SHA256" "sha256 latest appcast" "$expected" "$(sha256 "$WORKDIR/assets/latest-appcast.xml")" "$EXIT_METADATA" \
            "releases/latest/download/appcast.xml must serve this release's feed"
    fi
fi
if [[ -f "$WORKDIR/assets/beta-appcast.xml" ]]; then
    expect_eq "SHA256" "sha256 beta appcast" appcast.beta_appcast_sha256 \
        "$(sha256 "$WORKDIR/assets/beta-appcast.xml")" "$EXIT_METADATA"
fi

# -------------------------------------------------------------- checksums ---

for pair in "$ZIP_NAME" "Pomodoro.dmg"; do
    sha_file="$WORKDIR/assets/$pair.sha256"
    [[ -f "$sha_file" && -f "$WORKDIR/assets/$pair" ]] || continue
    if ( cd "$WORKDIR/assets" && shasum -a 256 -c "$pair.sha256" >/dev/null 2>&1 ); then
        ok "CHECKSUM" "checksum file $pair.sha256" "OK" "OK"
    else
        bad "CHECKSUM" "checksum file $pair.sha256" "OK" "mismatch"
        set_exit "$EXIT_ASSET"
    fi
done

# -------------------------------------------------------------- artifacts ---

zip_path="$WORKDIR/assets/$ZIP_NAME"
if [[ -f "$zip_path" ]]; then
    if unzip -t "$zip_path" >"$WORKDIR/unzip.log" 2>&1; then
        expect_eq "ARTIFACT" "zip integrity" package.zip_integrity "ok" "$EXIT_ARTIFACT"
    else
        bad "ARTIFACT" "zip integrity" "$(manifest_get package.zip_integrity)" "failed: $(tail -1 "$WORKDIR/unzip.log")"
        set_exit "$EXIT_ARTIFACT"
    fi

    if [[ -d "$WORKDIR/app" ]]; then
        rm -r "$WORKDIR/app"
    fi
    mkdir -p "$WORKDIR/app"
    if ditto -x -k "$zip_path" "$WORKDIR/app" 2>"$WORKDIR/ditto.err"; then
        ok "ARTIFACT" "zip extract" "Pomodoro.app" "Pomodoro.app"
    else
        bad "ARTIFACT" "zip extract" "Pomodoro.app" "$(head -1 "$WORKDIR/ditto.err")"
        set_exit "$EXIT_ARTIFACT"
    fi
fi

dmg_path="$WORKDIR/assets/Pomodoro.dmg"
if [[ -f "$dmg_path" ]]; then
    if hdiutil verify "$dmg_path" >"$WORKDIR/hdiutil.log" 2>&1; then
        expect_eq "ARTIFACT" "dmg verify" package.dmg_verify "VALID" "$EXIT_ARTIFACT"
    else
        bad "ARTIFACT" "dmg verify" "$(manifest_get package.dmg_verify)" "FAILED: $(tail -1 "$WORKDIR/hdiutil.log")"
        set_exit "$EXIT_ARTIFACT"
    fi
fi

# ----------------------------------------------------------------- bundle ---

APP="$WORKDIR/app/Pomodoro.app"
if [[ -d "$APP" ]]; then
    actual_version="$(plutil -extract CFBundleShortVersionString raw "$APP/Contents/Info.plist" 2>/dev/null || print -r -- "")"
    actual_build="$(plutil -extract CFBundleVersion raw "$APP/Contents/Info.plist" 2>/dev/null || print -r -- "")"
    actual_minimum="$(plutil -extract LSMinimumSystemVersion raw "$APP/Contents/Info.plist" 2>/dev/null || print -r -- "")"
    expect_eq "BUNDLE" "CFBundleShortVersionString" package.bundle_short_version "$actual_version" "$EXIT_ARTIFACT"
    expect_eq "BUNDLE" "CFBundleVersion" package.bundle_version "$actual_build" "$EXIT_ARTIFACT"
    expect_eq "BUNDLE" "LSMinimumSystemVersion" package.minimum_system_version "$actual_minimum" "$EXIT_ARTIFACT"

    actual_archs="$(lipo -archs "$APP/Contents/MacOS/Pomodoro" 2>/dev/null | tr ' ' '\n' | sort | tr '\n' ' ' | sed 's/ $//')"
    expect_eq "BUNDLE" "architectures" package.architectures "$actual_archs" "$EXIT_ARTIFACT"

    actual_locales="$(find "$APP/Contents/Resources" -maxdepth 1 -type d -name '*.lproj' -exec basename {} .lproj \; | sort | tr '\n' ' ' | sed 's/ $//')"
    expect_eq "BUNDLE" "localizations" package.locales "$actual_locales" "$EXIT_ARTIFACT"

    if codesign --verify --deep --strict "$APP" >"$WORKDIR/codesign.log" 2>&1; then
        ok "BUNDLE" "codesign verify" "valid" "valid"
    else
        bad "BUNDLE" "codesign verify" "valid" "$(tail -1 "$WORKDIR/codesign.log")"
        set_exit "$EXIT_ARTIFACT"
    fi

    expect_eq "BUNDLE" "signing kind" package.signing "$(signing_kind "$APP")" "$EXIT_ARTIFACT"

    notarized="$(notarization_state "$APP")"
    if [[ "$(manifest_get package.notarized)" == "true" ]]; then
        check_eq "BUNDLE" "notarization" "notarized" "$notarized" "$EXIT_ARTIFACT"
    else
        if [[ "$notarized" == "notarized" ]]; then
            bad "BUNDLE" "notarization" "not notarized (manifest)" "$notarized"
            set_exit "$EXIT_ARTIFACT"
        else
            ok "BUNDLE" "notarization" "not notarized (manifest)" "$notarized"
        fi
    fi
else
    skip_row "BUNDLE" "app bundle checks" "Pomodoro.app" "not extracted" "zip missing or unreadable"
fi

# ------------------------------------------------------------------- dmg ---

if [[ -f "$dmg_path" ]]; then
    mkdir -p "$WORKDIR/dmg"
    if hdiutil attach -nobrowse -readonly -mountpoint "$WORKDIR/dmg" "$dmg_path" >"$WORKDIR/dmg-attach.log" 2>&1; then
        DMG_MOUNT="$WORKDIR/dmg"
        dmg_app="$(find "$WORKDIR/dmg" -maxdepth 1 -name '*.app' -type d | head -1)"
        if [[ -n "$dmg_app" ]]; then
            dmg_version="$(plutil -extract CFBundleShortVersionString raw "$dmg_app/Contents/Info.plist" 2>/dev/null || print -r -- "")"
            dmg_build="$(plutil -extract CFBundleVersion raw "$dmg_app/Contents/Info.plist" 2>/dev/null || print -r -- "")"
            expect_eq "DMG" "dmg bundle version" package.bundle_short_version "$dmg_version" "$EXIT_ARTIFACT"
            expect_eq "DMG" "dmg bundle build" package.bundle_version "$dmg_build" "$EXIT_ARTIFACT"
        else
            bad "DMG" "dmg contains app" "*.app" "none"
            set_exit "$EXIT_ARTIFACT"
        fi
        hdiutil detach "$DMG_MOUNT" >/dev/null 2>&1 || hdiutil detach -force "$DMG_MOUNT" >/dev/null 2>&1
        DMG_MOUNT=""
    else
        bad "DMG" "dmg mounts" "read-only mount" "$(tail -1 "$WORKDIR/dmg-attach.log")"
        set_exit "$EXIT_ARTIFACT"
    fi
fi

# --------------------------------------------------------------- appcast ---

appcast="$WORKDIR/assets/appcast.xml"
if [[ -f "$appcast" ]]; then
    fields="$(appcast_fields "$appcast")"
    check_eq "APPCAST" "item count" "1" "$(field "$fields" ITEM_COUNT)" "$EXIT_ARTIFACT"
    expect_eq "APPCAST" "shortVersionString" appcast.short_version "$(field "$fields" SHORT_VERSION)" "$EXIT_ARTIFACT"
    expect_eq "APPCAST" "version (build)" appcast.build "$(field "$fields" BUILD)" "$EXIT_ARTIFACT"
    expect_eq "APPCAST" "enclosure url" appcast.enclosure_url "$(field "$fields" URL)" "$EXIT_ARTIFACT"
    expect_eq "APPCAST" "enclosure length" appcast.enclosure_length "$(field "$fields" LENGTH)" "$EXIT_ARTIFACT"
    check_eq "APPCAST" "edSignature length" "88" "$(field "$fields" SIGLEN)" "$EXIT_ARTIFACT"

    if [[ "$(manifest_get appcast.eddsa_appcast_verified)" == "true" ]] && (( SKIP_EDDSA == 0 )); then
        if "$SIGN_UPDATE" --verify --account "$ACCOUNT" "$appcast" >"$WORKDIR/ed-appcast.log" 2>&1; then
            ok "APPCAST" "EdDSA appcast" "valid" "valid"
        else
            bad "APPCAST" "EdDSA appcast" "valid" "$(head -1 "$WORKDIR/ed-appcast.log")"
            set_exit "$EXIT_ARTIFACT"
        fi
    else
        skip_row "APPCAST" "EdDSA appcast" "valid" "-" "--skip-eddsa or manifest records false"
    fi

    if [[ "$(manifest_get appcast.eddsa_enclosure_verified)" == "true" ]] && (( SKIP_EDDSA == 0 )); then
        signature="$(enclosure_signature "$appcast")"
        if [[ -n "$signature" && -f "$zip_path" ]] && \
            "$SIGN_UPDATE" --verify --account "$ACCOUNT" "$zip_path" "$signature" >"$WORKDIR/ed-zip.log" 2>&1; then
            ok "APPCAST" "EdDSA enclosure" "valid" "valid"
        else
            bad "APPCAST" "EdDSA enclosure" "valid" "$(head -1 "$WORKDIR/ed-zip.log" 2>/dev/null)"
            set_exit "$EXIT_ARTIFACT"
        fi
    else
        skip_row "APPCAST" "EdDSA enclosure" "valid" "-" "--skip-eddsa, manifest records false, or zip missing"
    fi
fi

# ----------------------------------------------------------------- feeds ---

beta_feed="$WORKDIR/assets/beta-appcast.xml"
if [[ -f "$beta_feed" ]]; then
    if (( SUPERSEDED )); then
        skip_row "FEED" "beta feed matches stable" "$TAG" "$(field "$(appcast_fields "$beta_feed")" SHORT_VERSION)" \
            "release is superseded; the rolling beta feed now follows $LATEST_TAG"
    elif cmp -s "$appcast" "$beta_feed"; then
        ok "FEED" "beta feed matches stable" "byte-identical" "identical"
    else
        beta_fields="$(appcast_fields "$beta_feed")"
        check_eq "FEED" "beta feed version" "$VERSION" "$(field "$beta_fields" SHORT_VERSION)" "$EXIT_METADATA"
        check_eq "FEED" "beta feed build" "$BUILD" "$(field "$beta_fields" BUILD)" "$EXIT_METADATA"
        check_eq "FEED" "beta feed enclosure" "$BASE/download/$TAG/$ZIP_NAME" "$(field "$beta_fields" URL)" "$EXIT_METADATA"
    fi
fi

if [[ "$CHANNEL" == "beta" ]]; then
    skip_row "FEED" "releases/latest" "not $TAG (prerelease)" "${LATEST_TAG:-missing}"
elif (( SUPERSEDED )); then
    skip_row "FEED" "releases/latest resolves to" "$TAG" "$LATEST_TAG" \
        "release is superseded; this row is only meaningful immediately after publication"
else
    expect_eq "FEED" "releases/latest resolves to" appcast.latest_resolves_to "$LATEST_TAG" "$EXIT_METADATA"
fi

# -------------------------------------------------------------- rollback ---

previous_tag="$(manifest_get rollback.previous_good_tag)"
if [[ -n "$previous_tag" ]]; then
    if gh_api "repos/$REPO_SLUG/releases/tags/$previous_tag" > "$WORKDIR/previous-release.json"; then
        ok "ROLLBACK" "previous good release exists" "$previous_tag" "200"
        if gh_api "repos/$REPO_SLUG/git/ref/tags/$previous_tag" > "$WORKDIR/previous-tag.json"; then
            previous_object="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("object",{}).get("sha",""))' "$WORKDIR/previous-tag.json")"
            expect_eq "ROLLBACK" "previous tag object sha" rollback.previous_good_tag_object_sha "$previous_object" "$EXIT_METADATA"
        else
            bad "ROLLBACK" "previous tag readable" "$previous_tag" "$(head -1 "$WORKDIR/gh.err")"
            set_exit "$EXIT_METADATA"
        fi
    else
        bad "ROLLBACK" "previous good release exists" "$previous_tag" "$(head -1 "$WORKDIR/gh.err")"
        set_exit "$EXIT_METADATA"
    fi
fi
skip_row "ROLLBACK" "local backup refs" "not machine-verifiable" "$(manifest_get rollback.local_backup_refs)" \
    "recorded as free text in the manifest"

# ---------------------------------------------------------------- record ---

verification_count="$(manifest_count verification)"
if (( verification_count > 0 )); then
    ok "RECORD" "verification entries" "at least 1" "$verification_count records"
else
    skip_row "RECORD" "verification entries" "at least 1" "none yet" "record sign-off before closing the release"
fi
ok "RECORD" "caveats recorded" "recorded" "$(manifest_count caveats) item(s)" "known product/quality limits"
ok "RECORD" "process exceptions recorded" "recorded" "$(manifest_count process_exceptions) item(s)" \
    "rule violations needing approval; empty is the normal case"

# --------------------------------------------------------------- summary ---

ELAPSED=$((SECONDS - START))

python3 - "$RESULTS" "$QUIET" <<'PY'
import sys

path, quiet = sys.argv[1], sys.argv[2] == "1"
rows = []
with open(path, encoding="utf-8") as handle:
    for line in handle:
        line = line.rstrip("\n")
        if line:
            rows.append(line.split("\x1f"))


def clip(text, limit):
    return text if len(text) <= limit else text[: limit - 1] + "…"


visible = [row for row in rows if not quiet or row[4] == "FAIL"]
if not visible:
    print("no failing checks")
    raise SystemExit(0)

widths = [4, 38, 34, 34, 6, 52]
header = ["GROUP", "CHECK", "EXPECTED", "ACTUAL", "RESULT", "NOTE"]
for index, title in enumerate(header):
    widths[index] = max(widths[index], len(title))
for row in visible:
    for index in range(6):
        cell = row[index] if index < len(row) else ""
        widths[index] = max(widths[index], min(len(cell), 60))


def render(cells):
    parts = []
    for index, cell in enumerate(cells):
        limit = 60
        parts.append(clip(cell, limit).ljust(widths[index]))
    print("  " + "  ".join(parts).rstrip())


current = None
counts = {}
for row in visible:
    group = row[0]
    if group != current:
        if current is not None:
            print("")
        current = group
        counts.setdefault(group, {"PASS": 0, "FAIL": 0, "SKIP": 0})
        render([group, "", "", "", "", ""])
        render(header)
    result = row[4]
    counts.setdefault(group, {"PASS": 0, "FAIL": 0, "SKIP": 0})[result] += 1
    render(row)

print("")
for group in counts:
    tally = counts[group]
    print("%-14s PASS %2d  FAIL %2d  SKIP %2d" % (group, tally["PASS"], tally["FAIL"], tally["SKIP"]))
PY

if [[ -n "$REPORT" ]]; then
    mkdir -p "$(dirname "$REPORT")" 2>/dev/null \
        || die "$EXIT_ENV" "could not create the report directory for $REPORT"
    tr '\037' '\t' < "$RESULTS" > "$REPORT" \
        || die "$EXIT_ENV" "could not write report to $REPORT"
fi

PASSED=$((CHECKS - FAILURES - SKIPS))
print -r -- ""
if (( FAILURES == 0 )); then
    print -r -- "SUMMARY: PASS — $PASSED passed, $SKIPS skipped, 0 failed (${ELAPSED}s)"
    if (( KEEP == 1 )); then
        print -r -- "artifacts: $WORKDIR"
    else
        rm -r "$WORKDIR"
    fi
    exit 0
fi

print -r -- "SUMMARY: FAIL — $PASSED passed, $SKIPS skipped, $FAILURES failed (${ELAPSED}s)"
print -r -- "artifacts: $WORKDIR"
print -r -- "exit: $EXIT_CODE"
exit "$EXIT_CODE"
