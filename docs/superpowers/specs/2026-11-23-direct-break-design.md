# Pomodoro Direct Break

**Product specification**

| Field | Value |
| --- | --- |
| Status | Draft for approval |
| Target release | 0.4.0 |
| Feature branch | `codex/direct-break-v0.4` |
| Product stance | Pomodoro remains a one-off timer |
| Date | 2026-11-23 |
| Platform | macOS 15+ |
| Parent roadmap | `2026-11-23-interaction-milestones-design.md` (main repository) |
| Visual study | [Ambient motion](../../design/ambient-motion.md) |

> **Amended 2026-11-24:** The completion presentation now moves directly to the
> recommended break's ready screen. The later Auto-start break setting can start
> the recommended break without waiting for Start, holding its countdown until
> the chime ends; it adds one Settings row and raises the Settings height. The
> direct-break behavior in this spec is unchanged; see
> [`2026-11-24-guided-next-step-design.md`](2026-11-24-guided-next-step-design.md)
> and
> [`2026-11-24-auto-start-break-design.md`](2026-11-24-auto-start-break-design.md).

## Contents

1. [Summary](#1-summary)
2. [Competitive basis](#2-competitive-basis)
3. [Goals](#3-goals)
4. [Non-goals](#4-non-goals)
5. [Idle experience](#5-idle-experience)
6. [Timer engine](#6-timer-engine)
7. [Persistence](#7-persistence)
8. [Menu bar, notifications, and sound](#8-menu-bar-notifications-and-sound)
9. [Localization](#9-localization)
10. [Accessibility](#10-accessibility)
11. [Visual and layout direction](#11-visual-and-layout-direction)
12. [Risks and mitigations](#12-risks-and-mitigations)
13. [Edge cases](#13-edge-cases)
14. [Acceptance criteria](#14-acceptance-criteria)
15. [Dependencies and sequencing](#15-dependencies-and-sequencing)
16. [Implementation decisions](#16-implementation-decisions)
17. [Follow-ups](#17-follow-ups)
18. [References](#18-references)

## 1. Summary

Pomodoro currently offers a break only after a focus interval reaches its
natural completion. This feature lets a person start a five-minute short break
or fifteen-minute long break directly from the idle screen.

The addition is intentionally small. A break is a timer state, not a workflow.
Starting one manually does not advance or reset focus rhythm. The existing
phase glyph, notification, pause/resume, sleep/wake, and restoration behavior
apply unchanged.

This branch has no dependency on the deferred Focus Note concept and does not
introduce session context or task behavior. The idle visual direction is
documented in the [ambient motion study](../../design/ambient-motion.md) and
summarized in [§11.2](#112-ambient-motion-study); it is a design reference for
the idle surface, not a second workflow.

## 2. Competitive basis

PomoFocus makes Pomodoro, Short Break, and Long Break available from one timer
surface. That directness is useful, but its ability to switch phases during an
active interval would discard timer context without enough protection.

Pomodoro adapts the idea conservatively: direct break access is available only
while idle. Mid-interval switching remains excluded.

## 3. Goals

1. Let a person start a short or long break without first completing a focus.
2. Keep the mode selector secondary to the primary Start action.
3. Preserve focus count, long-break cadence, and all existing rhythm rules.
4. Reuse the existing break timer, menu-bar icon, notifications, sounds, and
   restoration behavior.
5. Keep the mode selector unavailable whenever changing phase could discard an
   active interval.

### Success criteria

- Selecting Short break and pressing Start begins an accurate five-minute
  interval.
- Selecting Long break and pressing Start begins an accurate fifteen-minute
  interval.
- Manual breaks do not change the completed focus count.
- The fourth naturally completed focus still recommends a long break.
- The mode selector is available only in idle.
- A running or paused break supports the existing pause, resume, end-early,
  notification, sleep/wake, and relaunch behavior.
- The idle screen remains usable in all four supported languages.
- The idle light follows the selected mode dot — 25m upper left, 5m overhead,
  15m upper right — in both themes.

## 4. Non-goals

- Switching phases while a focus or break is running or paused.
- Pausing a focus and switching directly to a break.
- Auto-starting a break after focus completion except through the Auto-start
  break setting.
- Changing the five- or fifteen-minute durations.
- Configurable break durations or long-break cadence.
- Focus durations other than 25 minutes in the idle mode selector.
- Tasks, projects, estimates, or history.
- Focus notes or any other session context.
- Keyboard shortcuts.
- A global hotkey.
- A floating timer window.
- Accounts, sync, reports, rankings, ads, or premium features.

### Anti-goals

The feature fails if it:

- makes a manual break look like a primary workflow;
- makes an early-ended focus count toward rhythm;
- changes the fourth-focus long-break recommendation;
- allows an accidental destructive phase switch; or
- makes the idle screen feel like a control panel.

## 5. Idle experience

The idle surface follows the approved design study. From top to bottom it shows:

- the title: `Ready to focus`, `Take a short break`, or `Take a long break`;
- the dial at `25:00`, `05:00`, or `15:00`; the pointer sits at that duration's
  minute position on the 60-minute dial (25 at five o'clock, 5 at one o'clock,
  15 at three o'clock);
- the three mode dots with previous and next arrows; the current mode label
  below the dots. The arrows do not wrap: Focus has no previous arrow and Long
  break has no next arrow, so the end of the range is the end of the control;
- the primary Start button;
- the existing footer.

The three dots are the mode selector, ordered Focus (25), Short break (5),
Long break (15). The current mode name is shown below the dots in the mode
accent; the active dot is wider, and the arrows step through the three modes
without wrapping. The ambient light follows the selected mode: left, overhead,
right. The idle pointer keeps the tomato color while the selector changes; only
the running phase accent changes the pointer.

Selecting a mode updates the title, dial duration, accent, primary copy, and
ambient light. The readout slides instead of rolling: the outgoing duration
leaves the way the arrow points, cut off at the edge of the plaque, and the
incoming one follows it in from the other side. The two never share the plaque,
and the hand sweeps to the new position while they trade places. Pressing Start
starts the selected mode:

- Focus starts a 25-minute focus.
- Short break starts the existing five-minute direct break.
- Long break starts the existing fifteen-minute direct break.

The primary action remains the only filled action; the dots, mode label, and
arrows are secondary. The primary Start uses a leaf-green fill with a centered
label and a trailing play glyph; light uses ink text and dark uses white. The
mode accent stays in the dial, pointer, dots, mode label, and ambient light. The
former 15/25/45 focus-length chips and the pair of separate break buttons are
removed. The dots, arrows, and primary are the direct-break entry point.

### 5.1 Visibility

- The mode dots, current mode label, and arrows are visible only when the timer
  is idle.
- They are hidden during focus running, focus paused, focus completed, break
  running, break paused, and break completed.
- The focus-completion screen continues to offer its recommended break exactly
  as it does today.
- While running or paused, the status line (`Ends at ...` or `Paused · ...`)
  occupies the mode row below the dial. The dial and primary keep their idle
  vertical positions.
- Rapid repeated selection cannot start more than one interval or schedule more
  than one notification.
- Returning to idle resets the selector to Focus.

### 5.2 Starting a selection

Focus uses `selectFocusMinutes(25)` and the existing focus-start operation.
It does not change the focus count or break cadence.

Starting a selected direct break:

- sets the phase to `shortBreak` or `longBreak`;
- uses the existing five- or fifteen-minute duration;
- sets an absolute end date;
- enters the running state;
- updates the menu-bar break icon and remaining minutes;
- schedules one completion notification; and
- persists the active break through the existing state model.

It does not:

- change `completedFocusCount`;
- reset or advance the long-break cadence;
- mark a focus as complete;
- count the break in any history.

### 5.3 While the break runs

- The status line sits in the mode row below the dial.
- The existing break dial, colors, copy, and menu-bar cup icon remain.
- Pause freezes the remaining break time and cancels the pending notification.
- Resume creates a new end date and reschedules the notification.
- End early returns to idle.
- Sleep, screen lock, quit, and relaunch use the existing reconciliation path.
- Completion uses the existing break-complete state.
- A completed manual break offers **Start another focus** and **Done for now**
  exactly like a completion-triggered break.

### 5.4 State matrix

| State | Mode selector | Start allowed |
| --- | --- | --- |
| Idle | Available | Focus, short break, or long break |
| Focus running | Hidden | No |
| Focus paused | Hidden | No |
| Focus completed | Hidden | No; use the recommended-break action |
| Break running | Hidden | No |
| Break paused | Hidden | No |
| Break completed | Hidden | No |

## 6. Timer engine

- Add one engine operation that starts a specified break while idle.
- The operation must reject focus phases and any non-idle run state.
- It must use the existing short- and long-break durations.
- It must preserve `completedFocusCount`.
- Completion, pause, resume, restore, and early-end behavior reuse existing
  break logic.

Deterministic tests must use `TestClock`; no wall-clock sleeps.

## 7. Persistence

- No new persisted field is required.
- The existing `phase`, `runState`, `totalSeconds`, `remainingSeconds`, and
  `endDate` fields store a direct break.
- Existing state files remain readable.
- Active and paused manual breaks restore exactly like recommended breaks.
- No session-context or task field is added.

## 8. Menu bar, notifications, and sound

- The menu bar shows the same cup and remaining-time treatment used by existing
  breaks.
- Manual and recommended breaks schedule the same notification content.
- The completion chime and notification rules remain unchanged.
- Tick sound does not play during breaks.
- Notifications never contain user-entered context.

## 9. Localization

All new copy belongs in `Resources/Localization/Localizable.xcstrings` with
English, Simplified Chinese, Traditional Chinese, and Japanese values. Resolve
it through `L10n`.

Required semantic keys and English source values:

| Key | English source |
| --- | --- |
| `timer.break.short_with_minutes` | **Short break · %lld min** |
| `timer.break.long_with_minutes` | **Long break · %lld min** |
| `timer.title.short_break` | **Take a short break** |
| `timer.title.long_break` | **Take a long break** |
| `timer.mode.focus` | **Focus** |
| `timer.mode.short_break` | **Short break** |
| `timer.mode.long_break` | **Long break** |
| `timer.action.start` | **Start %lld-minute focus** |
| `timer.action.start_break` | **Start %lld-minute break** |
| `timer.action.previous_mode` | **Previous mode** |
| `timer.action.next_mode` | **Next mode** |
| `timer.a11y.start_break_hint` | **Starts a break interval in this popover** |

Use whole localized sentences with numeric placeholders rather than concatenating
a localized label and duration.

## 10. Accessibility

- Each mode dot and each arrow has a localized accessible name; the selected
  dot exposes the selected trait. The arrows also announce the current mode as
  their value.
- Keyboard focus reaches the previous arrow, the next arrow, the three mode
  dots, then Start, before the footer.
- The dots, arrows, and primary action are reachable with the keyboard and
  VoiceOver.
- Starting a break posts the existing localized break-start announcement.
- The selected mode does not depend on color alone: the mode label names it and
  the active dot is wider.

## 11. Visual and layout direction

### 11.1 Idle layout

- Use only `Palette`, `Typo`, and existing shared components.
- The three mode dots sit above a 9-point uppercase current-mode label in the
  mode accent; the active dot is wider and all three use the mode accent. The
  arrows are 32-point outlined circles with a 44-point hit area and hover help.
  Each arrow keeps its 44-point slot when it is unavailable, so hiding it does
  not move the dial: it fades out, shrinks slightly, and drifts toward its own
  edge. The title and the mode label swap at once, because cross-fading two
  different strings reads as a smudge; only the readout moves, and it moves
  sideways behind its own clipped box.
  The primary Start is the only filled action; it uses the leaf-green fill with
  a centered label and a trailing play glyph. A clean 0.8-point highlight and a
  subtle black shadow replace any colored glow.
- Do not restore the former 15/25/45 focus-length chips or the separate pair of
  break buttons.
- Do not reduce the 215-point dial.
- Preserve the 380-point popover width.
- Use a 506-point card height; the top mode row is removed and the current mode
  sits below the dial; the primary/footer spacing is preserved.
- Keep the Settings card and layout; the later Auto-start break setting adds
  one row and raises the card height. The card is never shorter than 592 points
  and grows to the height its measured content and footer need, so a row or a
  notification explanation never falls into a scrollbar. Settings uses the
  plain card background without the ambient rim, glow, or shade; the light
  study is limited to the clock page.
- The status line uses the mode row; the dial and primary do not move.
- Verify Light, Black, System appearance, and Reduce Transparency.
- Do not animate break start. The ambient light follows the selected mode.

### 11.2 Ambient motion study

The native idle surface uses the ambient motion study for its three mode dots:
Focus 25 is left, Short break 5 is overhead, and Long break 15 is right. The
study uses the same left → overhead → right order. The light follows the
selected mode dot; the dots and arrows are the only mode controls, the current
mode label names the state, and break start is not animated.

**Black theme**

<p align="center">
  <img src="../../design/ambient-motion-black.gif" width="420" alt="Black theme ambient motion from Pomodoro to Short Break to Long Break and back to Pomodoro">
</p>

<p align="center"><em>Pomodoro → Short Break → Long Break → Pomodoro. The top rim, dial face, plaque, and inner shade move together.</em></p>

**Light theme**

<p align="center">
  <img src="../../design/ambient-motion-light.gif" width="420" alt="Light theme ambient motion from Pomodoro to Short Break to Long Break and back to Pomodoro">
</p>

<p align="center"><em>Pomodoro → Short Break → Long Break → Pomodoro. The paper angle, dial face, plaque, and cast shadow share one light direction.</em></p>

**Light-position rule**

| Position | Native mode | Design-study dot | Light paper angle | Dial highlight | Plaque highlight | Cast shadow |
| --- | --- | --- | --- | --- | --- | --- |
| Left | Focus 25 | Pomodoro | 163° | 30% / 24% | 30% / 22% | Lower right |
| Center | Short break 5 | Short break | 180° | 50% / 14% | 50% / 12% | Straight down |
| Right | Long break 15 | Long break | 197° | 70% / 24% | 70% / 22% | Lower left |

The native modes are Focus → Short break → Long break; the study's dots are
Pomodoro → Short break → Long break. Both use the same positions and left →
overhead → right light order.

The dial and plaque positions apply to both themes. The paper-angle column is
Light-only: Black keeps its dark paper at 180° and carries direction with the
top rim, dial face, plaque, and inner shade; its external cast shadow is not a
primary signal. In Light, the paper gradient rotates with the mode and the
centered top wash stays symmetric. No paper, dial, plaque, or shadow surface
keeps a fixed directional highlight; the brass bezel's conic is a fixed
material treatment, not a second light source.

The standalone study passed the measured still and GIF hold-frame gates on
2026-11-23. The native app was inspected at 25m, 5m, and 15m in Light and
Black. The repeatable study measurements are in the
[ambient motion verification](../../design/ambient-motion.md#verification).

| Theme | Focus 25 | Short break 5 | Long break 15 |
| --- | --- | --- | --- |
| Light | Top left; plaque left; shadow right | Symmetric | Top right; plaque right; shadow left |
| Black | Top left; plaque left | Symmetric | Top right; plaque right |

## 12. Risks and mitigations

| Risk | Mitigation |
| --- | --- |
| An active interval is replaced by an accidental phase switch | The mode selector is hidden unless idle; the engine rejects focus phases and non-idle run states. |
| A manual break advances or resets rhythm | Direct start preserves `completedFocusCount`; deterministic tests cover the unchanged fourth-focus cadence. |
| Rapid selection starts two intervals or schedules two notifications | The idle-only engine guard permits one start; tests cover repeated selection and one notification. |
| Relaunch completes an expired break more than once | Existing reconciliation completes at most once; relaunch tests cover before and after the end date. |
| Localized copy overflows the idle layout | Four-language copy uses whole sentences with placeholders; inspect all four languages before completion. |
| The mode label or arrows dilute the primary Start action | Keep Start as the only filled action; use a small mode label and two secondary arrows. |
| The idle surface reads as lit from the wrong side | Apply the shared light-position rule in [§11.2](#112-ambient-motion-study); the measured still and GIF gates must pass. |
| The ambient light is mistaken for a second control | It is visual only; the arrows are the controls and the mode label names the state. |

## 13. Edge cases

- A direct break can be started immediately after ending a focus early, because
  ending early returns the app to idle.
- A manual long break does not reset a partially completed four-focus cadence.
- A manual break cannot begin while any other interval is active or paused.
- Closing the popover leaves the break running.
- Relaunching during a manual break restores it without creating a completion
  before the end date.
- Relaunching after a manual break expired completes it exactly once.
- Notification denial does not block the break.
- Language changes reschedule the pending break notification at the same end
  date.
- A corrupt state file follows the existing backup and reset behavior.

## 14. Acceptance criteria

- The mode dots, label, and arrows appear only on idle.
- The dots and arrows choose Focus 25, Short break 5, and Long break 15.
- The primary starts the selected mode: 25:00 focus, 5:00 short break, or
  15:00 long break.
- The title, dial duration, accent, and primary copy match the selected mode.
- The idle pointer points at the selected duration: 25 minutes at five
  o'clock, 5 minutes at one o'clock, 15 minutes at three o'clock.
- Starting a focus or break keeps the dial and primary in their idle vertical
  positions; the status line appears in the mode row below the dial.
- Switching idle modes does not recolor the pointer; the idle pointer stays
  tomato.
- Settings shows the plain card background without the ambient light.
- Selecting a break does not change `completedFocusCount` or the long-break
  cadence.
- The fourth natural focus completion still recommends a long break.
- The mode selector is absent during running, paused, and completed states.
- A manual break supports pause, resume, end early, notifications, sleep/wake,
  and relaunch.
- The menu-bar break icon and minutes are correct.
- The idle and break screens fit in all four languages.
- The idle light follows the selected mode: 25m upper left, 5m overhead,
  15m upper right.
- Changing the mode animates the light over 850 ms; Reduce Motion updates the
  pose without movement.
- Light, Black, System, and reduced-transparency states remain legible; Reduce
  Transparency keeps the ambient layers readable.
- The former 15/25/45 focus-length chips and the separate break-button pair are
  absent.
- No keyboard shortcut, task behavior, or history is added.
- `TESTING.md` gains coverage for direct short breaks, direct long breaks,
  rhythm neutrality, restoration, and mode-selector visibility.
- Because the home popover changes, `README.md` and its screenshots are updated.
- The feature spec includes both ambient-motion GIFs and the light-position
  rule; the measured direction gates pass.
- `swift test` passes.
- New deterministic `TestClock` tests cover direct break start, pause/resume,
  completion, early end, restoration, and unchanged focus counting.
- `swift scripts/check-localizations.swift .` passes.
- `./scripts/build-app.sh debug` passes.
- The built app is inspected in the affected states and appearances.

## 15. Dependencies and sequencing

- Target version 0.4.0.
- Start and finish this branch directly from `main`; no rebase onto Focus Note
  is required.
- Focus Note and Add Task are deferred until the product moves beyond a
  one-off timer.
- The local Space shortcut and custom rhythm controls remain later follow-ups.

## 16. Implementation decisions

- Keep direct breaks available only from idle.
- Do not copy PomoFocus's always-available phase tabs.
- The mode dots, label, and arrows are the only idle mode selector; do not add
  a separate break-button pair.
- The focus mode is fixed at 25 minutes; do not restore the former 15/45
  duration chips.
- Reuse existing break durations, notifications, menu-bar state, and sound
  rules.
- Keep manual breaks rhythm-neutral.
- Do not add a persisted field or task behavior.
- Use `L10n` and shared design tokens for every new string and view.
- Do not add keyboard shortcuts in this branch.
- Keep ambient motion idle-only; do not animate break start.
- Derive the ambient pose from the selected mode.
- Reset the idle mode to Focus when returning to idle.
- Respect Reduce Motion by snapping the pose and Reduce Transparency by
  omitting translucent ambient layers.
- Regenerate both theme GIFs from the same light-position rule when the visual
  study changes.

## 17. Follow-ups

These affect the idle visual study, not the direct-break behavior:

- The native ambient light is always on in 0.4.0; decide whether to expose a
  setting.
- Confirm whether the native Long break mode should keep the design study's
  faint brass glow or use sage only.

## 18. References

- [Pomodoro product design](2026-11-21-pomodoro-product-design.md)
- Parent roadmap: `2026-11-23-interaction-milestones-design.md` (main
  repository)
- [Ambient motion study](../../design/ambient-motion.md)
- Generated assets: [`ambient-motion-black.gif`](../../design/ambient-motion-black.gif),
  [`ambient-motion-light.gif`](../../design/ambient-motion-light.gif)
