# Three-Mode Color System — Implementation To-Do

**Execution checklist for the approved direction**

| Field | Value |
| --- | --- |
| Status | Implemented and verified in the working tree. Not committed or released. |
| Date | 2026-11-24 |
| Design | [`2026-11-24-mode-color-system.md`](2026-11-24-mode-color-system.md) |
| Scope | Popover presentation only; no timer, persistence, notification, sound, menu-bar or Settings behavior changes. The end control and its direct-end behavior were left to a separate change; see `2026-11-24-pause-end-control-design.md`. |
| Owner | Product owner |

> This is the change-specific to-do list. It is not a roadmap. The pre-flight
> choices are resolved; the source, localization, and documentation changes are
> in the working tree. Nothing has been committed, tagged, or released.
>
> **Follow-up 2026-11-24.** The primary's visible copy is now limited to
> `Start` and `Pause`; references below to `Resume` record the earlier state.
>
> **Follow-up 2026-11-24 (end control).** The running end control is superseded
> by `2026-11-24-pause-end-control-design.md`: a quiet muted-ink
> `forward.end.fill` shown only while running, with no resting plate and no
> tomato or mode fill. Checked items below describe this earlier color change
> only; the current end action ends immediately without confirmation.

## 0. Confirmed decisions

- [x] Long break stays in the same green family as Short break and is the
      deeper tier. Brass does not become the Long-break mode color or Start
      fill.
- [x] The primary keeps the mode fill in every state: Start, Pause,
      and completion. No second ink-key/rail button style.
- [x] The running/paused dial caption becomes `FOCUS` / `SHORT BREAK` /
      `LONG BREAK`; `READY` stays unchanged.
- [x] The running break title becomes `Short break` / `Long break` instead
      of the shared `Step away`; Focus keeps `Focus in progress`, paused keeps
      `Paused`. Reuses `timer.mode.*`; no new visible copy.
- [x] The Short break / Long break dial accessibility labels are added:
      `Short break timer` / `Long break timer`. This changes only the
      VoiceOver name; it adds no visible UI or layout change.
- [x] The dial bezel is an empty recessed channel with thin brass inner and
      outer edges. The thick brass fill track and the separate thin progress
      ring are removed. The remaining session is a mode-colored arc in the
      channel. The 60 ticks stay fixed; all are small and light except the 12,
      3, 6 and 9 o'clock marks, which are larger. The ticks do not disappear
      with the arc; at 0% the channel is empty but the tick ring and frame
      remain. The flush-face/vanishing-tick variant is not chosen.
- [x] The change is implemented in the working tree. It is not committed,
      tagged, or released.

## 0.1 Pre-flight decisions (resolved)

The implementation request accepted the recommended values for all four.

- [x] Black hierarchy: Short break becomes light leaf
      `#7FA160 → #789A58` with ink text; Long break uses the deeper forest
      `#2F6B3A → #285D32` with white text.
- [x] Long-break ambient: keep the existing brass light as a material accent;
      the mode accent, channel arc, dots, label and primary are deep green.
- [x] Focus stays brick/coral: Light `#B84A37 → #A53D2E`, Black
      `#D46A54 → #CE6853`.
- [x] Long-break depth: Light `#5F6B52 → #4E5A43`, Black
      `#2F6B3A → #285D32`.

## 1. Theme tokens

- [x] Add a `ModeColors` value in `Sources/Pomodoro/Views/Theme.swift` with
      `accent`, `buttonTop`, `buttonBottom` and `onButton`.
- [x] Add Light tokens:
      Focus accent `#A53D2E`, fill `#B84A37 → #A53D2E`, on `#FBF6EC`;
      Short accent `#5F6B52`, fill `#7FA160 → #789A58`, on `#2B2520`;
      Long accent `#4E5A43`, fill `#5F6B52 → #4E5A43`, on `#FBF6EC`.
- [x] Add Black tokens:
      Focus accent `#D46A54`, fill `#D46A54 → #CE6853`, on `#1D1916`;
      Short accent `#94A284`, fill `#7FA160 → #789A58`, on `#1D1916`;
      Long accent `#7F8C72`, fill `#2F6B3A → #285D32`, on `#FFFFFF`.
- [x] Add `modeShort` and `modeLong` values, or a `modeColors(for:)` switch.
- [x] Update `Palette.accent(for:)` so Long break is no longer sage.
- [x] Update `deepAccent(for:)` consistently.
- [x] Keep `IdleMode.glowColor` and the active long-break ambient on brass
      unless the fully green ambient decision chooses otherwise.
- [x] Verify the closest contrast pairs after coding: Light Short bottom
      4.73:1, Light Long top 4.74:1, Black Long label 4.90:1.

## 2. Primary button

- [x] Give `PrimaryCTAButtonStyle` in
      `Sources/Pomodoro/Views/Components.swift` the current mode and always
      use its fill and label color. Do not add a second `.inkKey` treatment
      or a rail.
- [x] Mode gradient, `onButton` label, trailing play/pause glyph in the label
      color, existing shadow, radius, press scale and Reduce Motion.
- [x] Use the same filled style for idle, completion, running and paused
      primary actions; only the label and glyph change between Start, Pause
      and the paused Start state.
- [x] Keep `PrimaryButtonLabel` unchanged; no separate icon-color override is
      needed.
- [x] Confirm the 49 pt height, 12 pt radius, shadow and press behavior did
      not change.

## 3. Mode accents and controls

- [x] Dial channel arc uses the mode accent; Long break uses deep
      sage/forest, not sage-both.
- [x] Mode dots and the mode label use the active mode accent; keep one
      active dot wider.
- [x] Keep the existing per-mode ambient pose. Brass stays the long-break
      ambient light and the thin bezel edges/trim, not a mode color.
- [x] Replace the thick brass rim in `DialView` with the empty channel: thin
      brass outer and inner edges, a recessed cream channel, and a subtle inner
      shadow. Remove the brass fill track and the separate thin progress ring.
- [x] Draw the remaining mode-colored arc in the channel with butt caps. Idle
      and completion leave the channel empty; starting fills it; it drains
      counterclockwise; paused freezes.
- [x] Keep all 60 ticks fixed just inside the channel. Make them small and
      light, with only the 12, 3, 6 and 9 o'clock marks longer and heavier. Do
      not tie ticks to the arc, hide them at 0%, or clip them against the arc.
- [x] Completion screen uses the offered mode's fill and channel-arc accent.
- [x] At the time of this color change, do not change the stop glyph or end
      confirmation; the stop control was out of scope and scheduled separately.
- [x] Verify no button uses `palette.leaf` unconditionally after the change.

## 4. Dial caption and running title

- [x] In `Sources/Pomodoro/Views/PopoverViews.swift`, set the running and
      paused caption to the mode name
      (`IdleMode(phase:).selectorLabel`).
- [x] Set the running break title to the mode name
      (`IdleMode(phase:).selectorLabel`) instead of `timer.title.break`
      (`Step away`). Keep `Focus in progress` for focus and `Paused` for the
      paused state.
- [x] Keep the idle and completion caption `READY`.
- [x] Apply uppercase presentation to the caption in `DialView`; do not
      change the title font, size or position.
- [x] Confirm the caption and title reuse `timer.mode.*`; add no visible copy
      keys. The old `timer.title.break` key may remain unused or be removed in
      a separate cleanup.
- [x] Confirm the paused state remains clear from the `Paused` title and the
      `Start` button.
- [x] Check the title fits `Short break` / `Long break` in all four languages
      without clipping or a layout shift.

## 5. Localization and accessibility

- [x] Add `timer.a11y.short_break_dial` and
      `timer.a11y.long_break_dial` to
      `Resources/Localization/Localizable.xcstrings` in English, Simplified
      Chinese, Traditional Chinese and Japanese:
      `Short break timer` / `Long break timer`;
      `短休息计时器` / `长休息计时器`;
      `短休息計時器` / `長休息計時器`;
      `短い休憩タイマー` / `長い休憩タイマー`.
- [x] Use the new long-break label in `TimerPopoverView` and
      `CompletionPopoverView`; keep the short-break label distinct.
- [x] Confirm VoiceOver does not announce the caption every second.
- [x] Confirm the dial label/value still names the mode while running and
      paused.
- [x] Verify Reduce Motion, Reduce Transparency and increased contrast.

## 6. Documentation

- [x] Amend `2026-11-21-pomodoro-product-design.md` §9.2 (primary fill rule)
      and §9.4 (long-break accent) when the code lands.
- [x] Update the Long break row in `docs/design/ambient-motion.md`: brass is
      the ambient light/trim, the mode accent and Start button are deep green.
- [x] Add or update the three-mode recognition entry in `TESTING.md`.
- [x] Amend `2026-11-24-session-dial-design.md` when the code lands: the thin
      inner ring and thick brass rim are superseded by the empty channel and
      mode-colored arc; update its acceptance criteria for the empty channel,
      the fixed 60-tick ring with four larger cardinals, and the 0% frame.
- [x] Keep the spec and this to-do linked; tick items as they are completed.
- [x] Do not regenerate `README.md` screenshots mid-cycle; note they are stale
      until the next release.

## 7. Verification

- [x] `swift test` passes.
- [x] `./scripts/build-app.sh debug` passes, including the localization
      catalog validator and entitlement checks.
- [x] Inspect idle, running, paused and completion states for Focus, Short
      break and Long break in Light and Black.
- [x] Confirm Long is visibly deeper than Short in the channel arc, mode label
      and Start button.
- [x] Check the green pair in grayscale or a color-blind simulation; confirm
      the mode label and caption remain the fallback.
- [x] Confirm the Black Short leaf button does not read as disabled in the
      resting, pressed and increased-contrast states.
- [x] Confirm the channel arc drains counterclockwise; idle and completion
      leave it empty; pausing freezes it.
- [x] Confirm the thin inner ring and the thick brass fill track are gone and
      no second progress ring remains.
- [x] Confirm all 60 ticks stay fixed; only the 12, 3, 6 and 9 o'clock marks
      are larger; the ticks do not change with the arc; 0% still draws all of
      them.
- [x] Confirm the 0% dial still reads as an instrument: the thin brass edges,
      recessed channel, fixed tick ring, face shadow, plaque and time remain.
- [x] Confirm Pause and the paused Start use the same mode fill as idle Start and do not
      introduce a second button color; the label and pause glyph are
      unambiguous.
- [x] At the time of this color change, the stop control and end confirmation
      were unchanged; the later end-control change supersedes both.
- [x] Switch all four languages at runtime; confirm the caption, running
      title and a11y labels update without a relaunch.
- [x] Confirm the running Short/Long title reads `Short break` / `Long break`;
      Focus still reads `Focus in progress`; paused still reads `Paused`.
- [x] Open Settings and confirm the card still fits without a scrollbar.
- [x] Verify no timer, persistence, notification, sound, menu-bar or Settings
      behavior changed.

## 8. Hand-off

- [x] Report the changed files, test/build results and inspected states.
- [ ] Do not commit, tag, push or publish unless explicitly requested.
- [ ] If a release is requested, update `docs/screenshots` at that point.
- [x] The design, code, localization, docs and verification items above are done.

### Definition of done

- Focus, Short break and Long break are distinguishable at a glance in all
  four states and both themes, with explicit mode text as the fallback.
- Both breaks stay in one green family; Long is the deeper tier; brass is not
  a mode color.
- The primary keeps the mode fill in every state; Start and Pause use
  the same button color for a given mode, with only the label and glyph
  changing.
- The dial uses the empty recessed channel; the mode-colored arc drains while
  the fixed tick ring stays, and the 0% frame still reads as an instrument.
- The dial caption names the mode while running or paused, and the running
  break title names Short/Long directly.
- All text and non-text contrast checks pass.
- `swift test` and `./scripts/build-app.sh debug` pass.
- The product design, ambient-motion doc, TESTING entry and this checklist are
  updated.
