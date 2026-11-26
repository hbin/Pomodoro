#!/bin/zsh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="${1:-$ROOT/build/Pomodoro.app}"
OUTPUT="${2:-/tmp/pomodoro-motion-qa-$(date +%Y%m%d-%H%M%S)}"
if [[ "$APP" != /* ]]; then
    APP="$PWD/$APP"
fi
STATE="$HOME/Library/Containers/com.hb.pomodoro/Data/Library/Application Support/Pomodoro/state.json"
WORK="$(mktemp -d /tmp/pomodoro-motion.XXXXXX)"
LOCK="/tmp/pomodoro-motion.lock"
AX_BIN="$WORK/MotionAX"
ANALYZER="$WORK/MotionAnalysis"
FAILURES=0
CLEANED=0
BACKUP_READY=0

usage() {
    cat <<'USAGE'
Usage: ./scripts/record-motion-baseline.sh [app-bundle] [output-dir]

Records four 60fps clips (5/5/5 and 5/5/15, Light and Black), extracts
per-frame readout metrics, and writes summary.tsv plus one verdict per clip.
The real Pomodoro state is backed up and restored.
USAGE
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    usage
    exit 0
fi

for command in swiftc ffmpeg ffprobe screencapture open osascript pkill pgrep shasum rg; do
    command -v "$command" >/dev/null 2>&1 || {
        echo "missing command: $command" >&2
        exit 2
    }
done

[[ -d "$APP" ]] || {
    echo "app bundle missing: $APP" >&2
    exit 2
}

if [[ -d "$LOCK" ]]; then
    owner=""
    [[ -f "$LOCK/pid" ]] && owner="$(<"$LOCK/pid")"
    if [[ -n "$owner" ]] && kill -0 "$owner" >/dev/null 2>&1; then
        echo "another motion QA run is active (pid $owner)" >&2
        exit 2
    fi
    rm -r "$LOCK"
fi
mkdir "$LOCK"
print -r -- "$$" > "$LOCK/pid"

mkdir -p "$OUTPUT"
if [[ -n "$(find "$OUTPUT" -maxdepth 1 -name '*.mov' -print -quit)" ]]; then
    echo "output directory already contains .mov files: $OUTPUT" >&2
    exit 2
fi

quit_pomodoro() {
    pkill -CONT -x Pomodoro >/dev/null 2>&1 || true
    osascript -e 'tell application id "com.hb.pomodoro" to quit' >/dev/null 2>&1 || true
    local i
    for i in {1..50}; do
        pgrep -x Pomodoro >/dev/null 2>&1 || return 0
        sleep 0.1
    done
    pkill -TERM -x Pomodoro >/dev/null 2>&1 || true
    for i in {1..20}; do
        pgrep -x Pomodoro >/dev/null 2>&1 || return 0
        sleep 0.1
    done
    pkill -KILL -x Pomodoro >/dev/null 2>&1 || true
    sleep 0.2
    ! pgrep -x Pomodoro >/dev/null 2>&1
}

state_hash() {
    shasum -a 256 "$STATE" | awk '{print $1}'
}

restore_original_state() {
    quit_pomodoro || return 1
    cp -p "$WORK/state.before.json" "$STATE" || return 1
    [[ "$(state_hash)" == "$(awk '{print $1}' "$WORK/state.before.sha256")" ]]
}

cleanup() {
    if (( CLEANED == 1 )); then
        return 0
    fi
    CLEANED=1
    trap - EXIT INT TERM
    local restored=no
    if (( BACKUP_READY == 1 )); then
        if restore_original_state; then
            restored=yes
        else
            echo "FAIL state restore or hash verification failed" >&2
            FAILURES=$((FAILURES + 1))
        fi
    else
        quit_pomodoro >/dev/null 2>&1 || true
    fi
    if [[ -d "$LOCK" ]]; then
        rm -r "$LOCK"
    fi
    echo "STATE_RESTORED=$restored"
    echo "OUTPUT=$OUTPUT"
    exit $(( FAILURES > 0 ? 1 : 0 ))
}

trap cleanup EXIT INT TERM

if [[ ! -f "$STATE" ]]; then
    echo "state.json missing; refusing to seed" >&2
    exit 2
fi

quit_pomodoro || {
    echo "could not terminate existing Pomodoro instance" >&2
    exit 2
}
cp -p "$STATE" "$WORK/state.before.json"
shasum -a 256 "$WORK/state.before.json" > "$WORK/state.before.sha256"
BACKUP_READY=1

swiftc -O "$ROOT/scripts/motion-qa/MotionAX.swift" -o "$AX_BIN"
swiftc -O "$ROOT/scripts/motion-qa/MotionAnalysis.swift" -o "$ANALYZER"

seed_state() {
    local focus="$1"
    local short="$2"
    local long="$3"

    quit_pomodoro || return 1
    cp -p "$WORK/state.before.json" "$STATE" || return 1
    [[ "$(state_hash)" == "$(awk '{print $1}' "$WORK/state.before.sha256")" ]] || return 1
    cat > "$STATE" <<JSON
{"durations":{"focusMinutes":$focus,"shortBreakMinutes":$short,"longBreakMinutes":$long},"chimeEnabled":false,"tickEnabled":false,"showMenuBarMinutes":true,"autoStartBreak":false,"autoStartFocus":false,"themePreference":"light","firstRunTipDismissed":true,"timer":{"version":1,"selectedFocusMinutes":$focus,"phase":"focus","runState":"idle","totalSeconds":$((focus * 60)),"remainingSeconds":$((focus * 60)),"endDate":null,"completedFocusCount":0,"focusCyclePosition":0}}
JSON
}

open_app() {
    local theme="$1"

    quit_pomodoro || return 1
    open -na "$APP" --args \
        -AppleLanguages '(en)' \
        -AppleLocale en_US \
        -PomodoroLanguagePreference en \
        --open-popover \
        --force-$theme \
        --idle-mode=focus >/dev/null 2>&1 || return 1

    local i
    PID=""
    for i in {1..50}; do
        PID="$(pgrep -x Pomodoro | head -1)"
        [[ -n "$PID" ]] && break
        sleep 0.1
    done
    [[ -n "$PID" ]] || return 1
    sleep 3
    kill -0 "$PID" >/dev/null 2>&1
}

window_geometry() {
    local i output
    for i in {1..30}; do
        if output="$("$AX_BIN" "$PID" geometry 2>/dev/null)"; then
            print -r -- "$output"
            return 0
        fi
        sleep 0.1
    done
    return 1
}

record_case() {
    local label="$1"
    local focus="$2"
    local short="$3"
    local long="$4"
    local theme="$5"
    local threshold="$6"
    local movie="$OUTPUT/$label.mov"
    local frames_tsv="$OUTPUT/$label.frames.tsv"
    local verdict="$OUTPUT/$label.verdict.txt"
    local raw="$WORK/$label.gray"
    local geometry x y w h fps rate

    seed_state "$focus" "$short" "$long" || {
        echo "FAIL seed guard refused for $label" >&2
        FAILURES=$((FAILURES + 1))
        return 1
    }
    open_app "$theme" || {
        echo "FAIL app launch failed for $label" >&2
        FAILURES=$((FAILURES + 1))
        return 1
    }
    geometry="$(window_geometry)" || {
        echo "FAIL window geometry unavailable for $label" >&2
        FAILURES=$((FAILURES + 1))
        return 1
    }
    read -r x y w h <<< "$geometry"
    if ! awk -v w="$w" -v h="$h" 'BEGIN { exit !(w == 340 && h == 510) }'; then
        echo "FAIL $label window expected 340x510, got ${w}x${h}" >&2
        FAILURES=$((FAILURES + 1))
        return 1
    fi

    [[ ! -e "$movie" ]] || {
        echo "FAIL $label movie already exists" >&2
        FAILURES=$((FAILURES + 1))
        return 1
    }
    screencapture -x -v -V 4 \
        -R "$(printf '%.0f' "$x"),$(printf '%.0f' "$y"),$(printf '%.0f' "$w"),$(printf '%.0f' "$h")" \
        "$movie" >/dev/null 2>&1 &
    local recorder=$!
    sleep 1.8
    "$AX_BIN" "$PID" press desc "Next mode" >/dev/null
    wait "$recorder"

    "$AX_BIN" "$PID" dial > "$OUTPUT/$label.after-dial.txt"
    if ! rg -q 'desc=Short break timer.*valueDesc=5 minutes, ready' "$OUTPUT/$label.after-dial.txt"; then
        echo "FAIL $label did not settle on Short break 5 minutes" >&2
        FAILURES=$((FAILURES + 1))
        quit_pomodoro || true
        return 1
    fi
    quit_pomodoro || {
        echo "FAIL app did not quit after $label" >&2
        FAILURES=$((FAILURES + 1))
        return 1
    }

    rate="$(ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate \
        -of default=noprint_wrappers=1:nokey=1 "$movie")"
    fps="$(awk -F/ -v rate="$rate" 'BEGIN { split(rate, a, "/"); printf "%.6f", a[1] / a[2] }')"
    if ! awk -v fps="$fps" 'BEGIN { exit !(fps >= 55 && fps <= 61) }'; then
        echo "FAIL $label recording rate $fps is not near 60fps" >&2
        FAILURES=$((FAILURES + 1))
        return 1
    fi
    ffprobe -v error -select_streams v:0 -show_entries stream=width,height,r_frame_rate,avg_frame_rate,duration,nb_frames \
        -of default=noprint_wrappers=1 "$movie" > "$OUTPUT/$label.ffprobe.txt"
    ffmpeg -v error -i "$movie" -vf format=gray -f rawvideo -pix_fmt gray "$raw"

    if ! "$ANALYZER" "$raw" "$frames_tsv" "$verdict" "$label" "$theme" "$fps" "$threshold" 340 510 \
        | tee -a "$OUTPUT/summary.tsv"; then
        FAILURES=$((FAILURES + 1))
        echo "FAIL $label frame checks" >&2
    fi
}

{
    echo "timestamp=$(TZ=Asia/Singapore date '+%Y/%m/%d %H:%M:%S')"
    echo "commit=$(git -C "$ROOT" rev-parse HEAD)"
    echo "app=$APP"
    echo "binary_sha256=$(shasum -a 256 "$APP/Contents/MacOS/Pomodoro" | awk '{print $1}')"
    echo "state_before_sha256=$(awk '{print $1}' "$WORK/state.before.sha256")"
} | tee "$OUTPUT/run-meta.txt"

printf 'STATUS\tlabel\ttheme\tframes\tfps\tstart\tend\tduration_ms\tblank_frames\ty_min_variation\ty_max_variation\tend_center_delta\tmax_width_ratio\tdirection\n' \
    | tee "$OUTPUT/summary.tsv"

record_case "555-light" 5 5 5 light 120
record_case "555-dark" 5 5 5 dark 190
record_case "5515-light" 5 5 15 light 120
record_case "5515-dark" 5 5 15 dark 190

restore_original_state || {
    echo "FAIL final state restore or hash verification failed" >&2
    FAILURES=$((FAILURES + 1))
}
echo "state_after_sha256=$(state_hash)" | tee -a "$OUTPUT/run-meta.txt"
echo "pomodoro_pids=$(pgrep -x Pomodoro | tr '\n' ' ' || true)" | tee -a "$OUTPUT/run-meta.txt"

if (( FAILURES == 0 )); then
    echo PASS > "$OUTPUT/verdict.txt"
else
    echo FAIL > "$OUTPUT/verdict.txt"
fi

echo "MOTION_BASELINE=$(cat "$OUTPUT/verdict.txt")"
echo "SUMMARY=$OUTPUT/summary.tsv"
