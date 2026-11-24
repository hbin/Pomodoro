# Pomodoro Auto-start Next Focus

**Product specification**

| Field | Value |
| --- | --- |
| Status | Implemented |
| Date | 2026-11-24 |
| Platform | macOS 15+ |
| Setting | `Auto-start focus` |
| Amends | `2026-11-21-pomodoro-product-design.md`, `2026-11-24-guided-next-step-design.md`, `2026-11-24-auto-start-break-design.md` |

> **Amended 2026-11-24:** The next focus length now comes from the configurable
> interval durations; the `25:00` example below is the default rather than a
> fixed length. See
> [`2026-11-24-configurable-durations-design.md`](2026-11-24-configurable-durations-design.md).

> **Amended 2026-11-24:** The Settings row is labeled **Auto-start focus** to
> match the app's Focus terminology. The internal key
> `settings.focus.auto_pomodoro.*` and the persisted field `autoStartFocus`
> keep their historical names.

> **Amended 2026-11-24:** The setting also controls the next Focus after a
> Break ended with the end control. That transition uses a fixed one-second
> full-countdown handoff rather than the chime duration. See
> [`2026-11-24-pause-end-control-design.md`](2026-11-24-pause-end-control-design.md).

## 1. Summary

Auto-start focus is an off-by-default setting that starts the next focus
when a break reaches zero or is ended with the end control. For natural
completion, the focus begins in the running state immediately, but its end date
is pushed out by the break completion chime, so the countdown stays at `25:00`
until the chime finishes. An early-ended break uses a fixed one-second
full-countdown handoff.

When the setting is off, the existing focus-ready screen waits for Start. The
two automatic settings are independent; enabling both creates a full
focus-to-break-to-focus cycle.

## 2. Behavior

### 2.1 Setting

- Location: Settings → TIMER → `Auto-start focus`.
- Default: off, preserving the existing next-focus-waits behavior.
- Persisted as `autoStartFocus` in `PersistedState`; older state files without
  the field decode as off. An explicit on choice is preserved.
- Changing the setting takes effect at the next observed break completion.
  Turning it on while a break is running applies to that break.
- Turning it on while the focus-ready screen is already visible does not
  retroactively start the focus; the user presses Start.
- Turning it off while a focus is running does not stop that focus.
- Turning it off during the break chime does not stop the already-started
  focus; it applies to the next break completion.

### 2.2 Break completion with the setting on

1. The break completion chime plays when enabled.
2. The next focus starts immediately in the running state. The popover goes
   directly from the break-running screen to the focus-running screen; no
   focus-ready screen appears.
3. The focus's end date is pushed out by the break chime duration plus a small
   audio-output margin, so the displayed countdown stays at `25:00` while the
   chime plays and begins moving when the chime ends. The wait is fixed, not a
   setting.
4. The focus uses the stored focus duration and leaves the Focus-cycle position
   and long-break cadence unchanged.
5. The focus-end notification is scheduled for the delayed end date; pause,
   resume, end early, sleep/wake, and restoration use the existing focus paths.
6. The menu bar shows the running focus treatment and remaining minutes
   immediately; the minutes stay full during the chime hold.
7. The break-complete VoiceOver announcement is skipped; the existing
   focus-start announcement is posted when the focus starts.
8. If the chime is off, the delay is zero and the countdown starts immediately.
9. Pause and End remain normal focus controls during the hold. Disabling the
   setting during the hold does not stop the already-started focus.

### 2.4 Break ended with the end control

1. The break completion chime plays when enabled. The break does not change the
   four-focus rhythm.
2. The interface moves directly to the next Focus; no Completion page appears.
3. With Auto-start focus on, the running focus screen appears immediately and
   its countdown stays full for one second before starting. This one-second
   handoff applies even when the completion chime is off.
4. With Auto-start focus off, the Focus waits on its ready screen.
5. The original break notification is cancelled. No extra foreground
   notification is emitted; an auto-started focus schedules its own end
   notification.

### 2.3 Break completion with the setting off

The existing behavior applies: the popover shows the focus-ready screen, and
the user presses Start.

### 2.4 Focus completion

Auto-start focus applies only to the break-to-focus transition. Auto-start
break independently controls the focus-to-break transition. Neither setting
implicitly enables the other.

### 2.5 Restoration

Auto-start focus is part of a live completion event. If the app launches
with an already-expired break, it completes the interval and shows the
focus-ready screen; it does not start a focus retroactively.

Sleep/wake recovery that observes the break completion live starts the focus,
because the completion event is handled at wake.

If the app quits after a live completion has started the focus, the focus is a
normal running interval and restores with its delayed end date.

### 2.6 State and persistence

- No timer-state field or new run state is added.
- The preference is a single Boolean in `PersistedState`.
- The auto-start action calls the existing start-another-focus operation with
  the break chime delay added to the end date.

## 3. Settings copy

| Key | English source |
| --- | --- |
| `settings.focus.auto_pomodoro.title` | **Auto-start focus** |
| `settings.focus.auto_pomodoro.detail` | **Starts the next focus when a break ends.** |
| `notifications.break.body` | **Time to focus.** |

The Settings card grows with the new row. The footer must remain visible
without a scrollbar in all four languages, both themes, and with notifications
allowed or denied.

## 4. Accessibility

- The toggle exposes `Auto-start focus` as its accessible label.
- The focus-start announcement follows the break chime; the break-complete
  announcement is not duplicated.
- The toggle state is exposed by the standard switch control.
- The new Settings row fits in all four supported languages in both themes.

## 5. Non-goals

- Starting the recommended break automatically after focus; that is Auto-start
  break.
- Starting a focus retroactively when an expired break is restored at launch.
- Making the chime wait configurable or changing the chime length.
- Notification action buttons that start a focus.
- New timer-state fields, a new run state, or a full automatic cycle without the
  two explicit settings.
- Changing focus durations or the long-break cadence.
- Changing the manual Start path or the focus-ready screen when the setting is
  off.

## 6. Acceptance criteria

- `Auto-start focus` is off by default, including for older state files; an
  explicit on choice is preserved.
- The setting survives quit and relaunch.
- With the setting on, a break completion goes directly to the running focus
  screen; no focus-ready or completion screen appears.
- The focus's end date includes the break chime delay, and the countdown stays
  at the full focus duration until the chime finishes.
- With the setting on and the chime off, the countdown starts immediately.
- With the setting on, a Break ended with the end control goes directly to the
  running Focus; its full countdown begins after one second, even with the
  chime off.
- Pause and End work normally during the chime hold; disabling the setting
  during the hold does not stop the already-started focus.
- The completed-focus count and long-break cadence are unchanged.
- With the setting off, the focus-ready screen remains unchanged.
- With the setting off, a Break ended with the end control stops on the
  focus-ready screen.
- An expired break restored at launch shows the focus-ready screen instead of
  starting a focus retroactively.
- The focus completion still follows Auto-start break independently.
- Settings shows both auto-start toggles in all four languages and both themes,
  with the footer visible and no scrollbar, including the denied-notification
  detail.
- `swift test` and `./scripts/build-app.sh debug` pass.

## 7. Verification

The built debug app was inspected with Auto-start focus off and on. The off
path left the focus-ready screen; the on path went directly from the
break-running screen to the running focus at `25:00`, with no ready-screen
flash. The focus end date included the break chime delay, and the countdown
started after the chime. Settings was checked in English, Simplified Chinese,
Traditional Chinese, and Japanese, in Light and Black, including the denied
notification detail; the card grew to fit and the footer remained visible
without a scrollbar. `swift test` covered the delayed focus start, refresh
tolerance, persistence default, and explicit preference round-trip.
