# Configurable Interval Durations

**Product specification**

| Field | Value |
| --- | --- |
| Status | Implemented |
| Date | 2026-11-24 |
| Platform | macOS 15+ |
| Parent design | `2026-11-21-pomodoro-product-design.md` |

> **Amended 2026-11-24:** The popover dial is now a session gauge without a
> hand; the former 60-minute clamp is removed. See
> [`2026-11-24-session-dial-design.md`](2026-11-24-session-dial-design.md).

## 1. Summary

The three intervals were fixed at 25, 5, and 15 minutes. They are now three
independent user preferences in Settings.

The focus, both direct breaks, the recommended break, the completion offer, and
the auto-start paths all read the configured lengths. The idle dial and start
labels show the configured values, and the menu-bar countdown follows the
interval that is actually running. Active and paused intervals keep the length
they started with.

## 2. Goals

1. Let the user set focus, short-break, and long-break lengths independently.
2. Keep the three values visible together so the rhythm is easy to read.
3. Preserve the classic 25/5/15 defaults for new and existing installs.
4. Let the user enter a value directly and also nudge it by one minute with
   buttons on either side.
5. Apply changes to the next interval without disturbing a running or paused
   interval.
6. Preserve all existing rhythm, notification, sound, persistence, and
   accessibility behavior.

## 3. Settings UI

The three lengths sit inside the existing TIMER section, above Auto-start break
and Auto-start focus. The card starts with TIMER, SOUND, and MENU BAR, then
APPEARANCE and NOTIFICATIONS. MENU BAR remains its own section; it is not merged
with appearance or notifications.


```text
────────────────────────────────────
TIMER
Time (minutes)
  Focus          Short break        Long break
[− 25 +]        [−  5 +]           [− 15 +]

Auto-start break                    [switch]
Starts the recommended break after the focus chime ends.

Auto-start focus                 [switch]
Starts the next focus when a break ends.
```

- A left-aligned `Time (minutes)` caption sits below the TIMER label and
  carries the unit for the whole block. It uses 10.5-point medium ink.
- The three equal columns replace the former three settings rows. Each column
  has a 10.5-point muted interval name centered above one compact field.
- The control is 28 points high with the same 9-point-radius plaque fill and
  brass hairline as the language menu. A 26-point minus button and a 26-point
  plus button flank the editable value. The value shows only the number, in
  13-point digits; no unit is repeated inside the fields.
- The center value is a button at rest. Clicking the number replaces it with a
  focused, digits-only text field, selects the current number, and turns the
  border tomato.
- The minus and plus buttons use a 10-point glyph, adjust by one minute, show a
  faint ink wash on hover, and disable at 1 and 180.
- The column title remains visible above the control.
- There are no internal hairlines inside the section. The Time (minutes)
  block and both Auto-start rows are separated by spacing only, and the
  Auto-start rows use the same row spacing as the two SOUND rows. This
  no-internal-divider rule also applies to the Appearance and Sound sections.
  The section separator is the hairline *above* each section label, so the
  label stays visually attached to its content. Section rules use a 1-point
  line rather than a sub-point hairline so they remain visible at 1x; the
  footer keeps its own rule. There is no separate durations section.
- The three fields fill their columns evenly and align across all four
  languages.
- Hovering over a resting field adds a faint brass border. Editing adds the
  tomato border and the system text selection. Reduce Motion removes the short
  hover/focus transitions.
- The caption and bare values keep the Settings card at about 705 points in
  English, 708 in Chinese, and 703 in Japanese. The scroll content has 8 points
  of bottom padding before the footer rule, and `settingsMaxHeight` remains
  760, which leaves room for the notifications-denied explanation and the
  footer.

### 3.1 Direct entry behavior

- Clicking the number enters input; there is no separate edit button.
- The current number is selected when the field opens, so typing replaces it.
- The whole 28-point value area is a click target. The click that opens the
  editor also focuses it and selects the number, even when it lands near the
  plaque's top or bottom edge, so the first typed digit replaces the old value.
- The field accepts digits only and at most three digits.
- Each typed digit applies immediately, before the field loses focus or the
  user presses Enter. The preference, idle interval, labels, and dial update
  while the editor is still open. The field text itself is not rewritten while
  typing; it normalizes when editing ends.
- Enter leaves edit mode. Clicking another duration field applies the current
  draft and opens the next one; moving focus to another Settings control
  applies the draft and closes the editor.
- The minus and plus buttons change the value by one minute. At rest, the new
  value saves immediately. While the number is being edited, they commit the
  draft, apply the step, and leave edit mode.
- An empty value leaves the last applied value in place; committing an empty
  field restores that value in the field.
- Values below 1 or above 180 apply clamped to 1 or 180 while typing, and the
  field text settles to the clamped value when editing ends.
- Escape keeps the existing app behavior: it dismisses the Settings popover.
  Digits already applied while typing remain in effect.
- The help tooltip and accessibility hint explain the click-to-type interaction
  and the 1–180 range.

## 4. Preference model and persistence

The core value type is:

```swift
public struct IntervalDurations: Codable, Sendable, Equatable {
    public static let allowedMinutes = 1...180
    public var focusMinutes: Int
    public var shortBreakMinutes: Int
    public var longBreakMinutes: Int
    public func minutes(for phase: Phase) -> Int
    public mutating func setMinutes(_ minutes: Int, for phase: Phase)
}
```

- The default is 25/5/15.
- The initializer and setter clamp to the allowed range.
- `PersistedState` contains `durations`; missing or partial objects decode to the
  per-field defaults.
- Existing state files without `durations` load with 25/5/15 and are rewritten
  with the new field on the next save.
- `TimerModel` owns the published preference and saves on every committed
  change.
- `TimerModel` passes the preference to `TimerEngine` on load and calls
  `TimerEngine.applyDurations` after a change.
- `TimerState.selectedFocusMinutes` remains for older state files and for the
  active-interval snapshot. It is no longer the source of truth for a new
  focus; `durations.focusMinutes` is.

## 5. Timer behavior

`TimerEngine` owns a validated `IntervalDurations` value:

- `init(state:durations:now:)` sanitizes idle state to the configured focus
  length and keeps the stored length of a running, paused, or completed
  interval.
- `applyDurations` updates the preference. It refreshes the idle state's
  selected focus, total, and remaining time immediately. It leaves a running,
  paused, or completed interval's total, remaining time, and end date alone.
- `startFocus` uses `focusMinutes`; the selected focus and absolute end date
  follow.
- `startBreak` uses the matching configured short- or long-break length.
- `recommendedBreak` uses `shortBreakMinutes` or `longBreakMinutes`. The fourth
  naturally completed focus still selects the long break.
- `startRecommendedBreak` and `startAnother` use the configured values, so the
  completion offer and the interval it starts always agree.
- `toIdle` returns to the configured focus length after ending early, skipping
  a break, or choosing `Done for now`.
- Auto-start break and auto-start focus use the configured break and focus
  lengths, including the chime hold delay.
- The menu-bar countdown, notification end date, pause/resume, sleep/wake, and
  restoration paths continue to derive from the interval's absolute end date.

### 5.1 Idle modes

- Focus, Short break, and Long break read their lengths from the preference.
- The idle title, dial readout, empty session ring, primary label,
  accessibility value, and mode-dot label use the configured value.
- The three mode dots remain ordered Focus → Short break → Long break. The
  arrows and labels do not change; only the durations update.
- The primary action starts the selected mode with the configured length.

### 5.2 Dial and long durations

The popover dial is a session gauge rather than a 60-minute clock. The ring
starts full and drains counterclockwise over the configured interval; the
central readout shows the true `MM:SS` value. There is no clamp at 60 minutes:
a 5-minute, 90-minute, or 180-minute interval each uses the full circle at its
own scale. The Start label and accessibility copy always use the full
configured length.

## 6. Completion and auto-start

- The focus-completion screen offers the configured short or long break and
  shows that duration on the dial with `READY`.
- A break-completion screen offers the configured focus length.
- Changing a duration while the completion screen is visible updates the offer
  without changing the completed interval.
- Auto-start break starts the configured recommended break after focus.
- Auto-start focus starts the configured focus after a break.
- An expired interval restored at launch still shows its ready screen and does
  not auto-start retroactively, as before.

## 7. Accessibility

- Each column exposes three controls in visual order: a minus button, the
  editable value, and a plus button. Each has the interval name in its label,
  the current value, and the range hint; the step buttons announce themselves
  as “Decrease Focus” and “Increase Focus”, for example.
- At rest, the center value is a button with the interval name as its label, the
  localized minutes string as its value, and “Edit a length from 1 to 180
  minutes” as its hint. Keyboard focus reaches it in column order; Return or
  Space opens the editor.
- While editing, the text field is focused and labeled with the interval name.
  VoiceOver reads and edits the number directly. The `Time (minutes)` caption
  carries the visual unit; each field's accessibility value still spells out
  the localized minutes so the unit is never lost.
- The visible column title names the interval; the center value's accessible
  label repeats it so the control is self-contained.
- Disabled states are not used; all values are editable from 1 through 180.
- Focus and hover are visible in both themes and with Reduce Transparency.
- The idle mode dots continue to expose the configured minutes as their
  accessibility value.

## 8. Localization

| Key | English source |
| --- | --- |
| `settings.durations.value` | **%lld min** |
| `settings.durations.time_header` | **Time (minutes)** |
| `settings.durations.help` | **Click a number to type a length from 1 to 180 minutes.** |
| `settings.durations.a11y_hint` | **Edit a length from 1 to 180 minutes.** |
| `settings.durations.decrease` | **Decrease %@** |
| `settings.durations.increase` | **Increase %@** |

The three column titles reuse `timer.mode.focus`, `timer.mode.short_break`, and
`timer.mode.long_break`. All values include English, Simplified Chinese,
Traditional Chinese, and Japanese.

## 9. Acceptance

### Settings

- [x] TIMER shows the three duration fields above the two Auto-start rows with
      no internal hairline; spacing alone groups them with the section.
- [x] The controls show 25/5/15 on a clean install and after loading a state
      file without durations.
- [x] The Time (minutes) caption is visible above the columns, and the fields
      show bare numbers without repeating the unit.
- [x] Clicking a number selects it and accepts typed digits; a click anywhere
      in the value plaque, including near its edges, focuses the editor; each
      digit applies immediately without leaving the field; Enter and clicking
      another duration field end editing; empty and out-of-range input resolve
      to a valid 1–180 value.
- [x] The minus and plus buttons flank the editable number, adjust one minute,
      save at rest, commit an active draft before stepping, and disable at 1
      and 180.
- [x] Changes persist across relaunch.
- [x] The three columns align in English, Simplified Chinese, Traditional
      Chinese, and Japanese in Light and Black.
- [x] The notifications-denied explanation and the footer are visible with no
      scrollbar.
- [x] VoiceOver can read, enter, and commit each duration field.

### Timer

- [x] Starting a focus uses the configured focus length.
- [x] Direct short and long breaks use their configured lengths.
- [x] The recommended break uses the configured short or long length, and the
      fourth completed focus still selects the long break.
- [x] The completion offer shows the configured next length and starts that
      same length.
- [x] Auto-start break and auto-start focus use the configured lengths.
- [x] The idle dial, title, primary label, accessibility value, and menu-bar
      countdown show configured values.
- [x] Editing a duration while an interval runs or is paused leaves the active
      interval untouched; the next interval uses the new value.
- [x] A restored active or paused interval keeps its stored duration.
- [x] Durations above 60 minutes show their true readout; the session ring
      starts full and drains at the configured length without clamping.
- [x] `swift test` passes.
- [x] `./scripts/build-app.sh debug` passes.
- [x] The built app is inspected in the affected states.

## 10. Follow-ups

- Decide whether Escape should cancel an in-progress edit without closing the
  popover, rather than preserving the app-wide dismissal behavior.
- Consider whether short and long break lengths need any relationship rule.
- Refresh README screenshots when preparing a release if the default idle
  screen changes.
