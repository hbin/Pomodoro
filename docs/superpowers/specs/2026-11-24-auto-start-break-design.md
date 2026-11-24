# Pomodoro Auto-start Break

**Product specification**

| Field | Value |
| --- | --- |
| Status | Implemented |
| Date | 2026-11-24 |
| Platform | macOS 15+ |
| Amends | `2026-11-21-pomodoro-product-design.md`, `2026-11-24-guided-next-step-design.md` |

## 1. Summary

Auto-start break is a setting, on by default. When it is on, a naturally
completed focus starts the recommended short or long break immediately in the
running state, but the break's end date is pushed out by the completion chime,
so the countdown stays at full until the chime finishes. When it is off, the
existing guided break-ready screen waits for Start.

The setting applies only to the focus-to-break transition. A completed break
still shows the focus-ready screen and never starts the next focus by itself.

## 2. Behavior

### 2.1 Setting

- Location: Settings → FOCUS → `Auto-start break`.
- Default: on.
- Persisted as `autoStartBreak` in `PersistedState`; older state files without
  the field decode as on. An explicit off choice is preserved.
- Changing the setting takes effect at the next observed focus completion.
  Turning it on while a focus is running applies to that focus.
- Turning it on while the focus-completion ready screen is already visible does
  not retroactively start the break; the user presses Start.
- Turning it off while a break is running does not stop that break.
- Turning it off during the chime does not stop the already-started break; it
  applies to the next focus completion.

### 2.2 Focus completion with the setting on

1. The completion chime plays when enabled.
2. The recommended break starts immediately in the running state. The popover
   goes directly from the focus-running screen to the break-running screen; no
   focus-completion or break-ready screen appears.
3. The break's end date is pushed out by the chime duration plus a small
   audio-output margin, so the displayed countdown stays at `05:00` or `15:00`
   while the chime plays and begins moving when the chime ends. The wait is a
   fixed part of the behavior, not a setting.
4. The break uses the existing 5- or 15-minute duration and the existing rhythm
   recommendation. The fourth naturally completed focus still recommends the
   15-minute long break.
5. The break-end notification is scheduled for the delayed end date; pause,
   resume, end early, sleep/wake, and restoration use the existing break paths.
   The focus-completion notification keeps a neutral body, `Time for a break.`,
   so it is accurate whether the break starts automatically or waits because
   the app was closed.
6. The menu bar shows the running break treatment and remaining minutes
   immediately; the minutes stay full during the chime hold.
7. The focus-complete VoiceOver announcement is skipped; the existing
   break-start announcement is posted when the break starts.
8. If the chime is off, the delay is zero and the countdown starts immediately.
9. Pause and End remain normal break controls during the hold. Disabling the
   setting during the hold does not stop the already-started break.

### 2.3 Focus completion with the setting off

The existing guided behavior applies: the popover shows the recommended break
ready screen, and the user presses Start.

### 2.4 Break completion

Auto-start break does not apply here. A completed break shows the focus-ready
screen, and the next focus always waits for Start.

### 2.5 Restoration

Auto-start break is part of a live completion event. If the app launches with
an already-expired focus, it completes the interval and shows the break-ready
screen; it does not start a break retroactively. This avoids starting a break
after an unknown amount of away time.

Sleep/wake recovery that observes the completion live starts the break,
because the completion event is handled at wake.

If the app quits after a live completion has started the break, the break is a
normal running break and restores with its delayed end date.

### 2.6 State and persistence

- No timer-state field or new run state is added.
- The preference is a single Boolean in `PersistedState`.
- The auto-start action calls the existing recommended-break operation with the
  chime delay added to the end date.

## 3. Settings copy

| Key | English source |
| --- | --- |
| `settings.section.focus` | **FOCUS** |
| `settings.focus.auto_break.title` | **Auto-start break** |
| `settings.focus.auto_break.detail` | **Starts the recommended break after the focus chime ends.** |
| `notifications.focus.body` | **Time for a break.** |

The Settings card gains one section and one row. It is at least 592 points tall
and grows to whatever its measured content and footer need, so the new row, the
notification explanation, and the footer all fit without a scrollbar.

## 4. Accessibility

- The toggle exposes `Auto-start break` as its accessible label.
- The break-start announcement follows the chime; the focus-complete
  announcement is not duplicated.
- The toggle state is exposed by the standard switch control.
- The new Settings row fits in all four supported languages in both themes.

## 5. Non-goals

- Starting the next focus automatically after a break.
- Starting a break retroactively when an expired focus is restored at launch.
- Auto-starting a break after an early-ended focus.
- Making the chime wait configurable or changing the chime length.
- Notification action buttons that start a break.
- New timer-state fields, a new run state, or a full automatic focus/break
  countdown cycle.
- Changing break durations or the long-break cadence.
- Changing the manual Start path or the guided break-ready screen when the
  setting is off.

## 6. Acceptance criteria

- `Auto-start break` is on by default, including for older state files; an
  explicit off choice is preserved.
- The setting survives quit and relaunch.
- With the setting on, a natural focus completion goes directly to the running
  break screen; no completion or break-ready screen appears.
- The break's end date includes the chime delay, and the countdown stays at the
  full 5- or 15-minute value until the chime finishes.
- With the setting on and the chime off, the countdown starts immediately.
- Pause and End work normally during the chime hold; disabling the setting
  during the hold does not stop the already-started break.
- The fourth completed focus still starts the 15-minute long break.
- An auto-started break schedules its end notification and updates the menu bar.
- The focus-completion notification body fits both the auto-started and
  still-waiting cases.
- With the setting off, the focus-completion ready screen remains unchanged.
- An early-ended focus does not start a break.
- An expired focus restored at launch shows the break-ready screen instead of
  starting a break retroactively.
- A completed break still waits for Start focus.
- Turning the setting on during a running focus applies to that completion.
- Turning the setting on while the focus-completion ready screen is visible does
  not retroactively start the break.
- Settings shows the new FOCUS section and toggle in all four languages, in both
  themes, without clipping or a visible scrollbar.
- `swift test` and `./scripts/build-app.sh debug` pass.

## 7. Verification

The built debug app was inspected with the setting off and on. The off path
showed the break-ready screen; the on path went directly from the focus-running
screen to the running break screen without a completion flash. The countdown
held at the full duration during the chime and then decreased; with the chime
off, it decreased immediately. The existing break-start path continues to own
the menu-bar update and the break-end notification. Default-on and explicit-off
decoding, round-trip persistence, restore-at-launch, and break-completion paths
were checked. The Settings row was inspected in both themes and all four
languages.
