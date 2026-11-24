# Session Dial

**Product specification**

| Field | Value |
| --- | --- |
| Status | Implemented; the bezel lane and tick treatment are amended by the three-mode color system |
| Date | 2026-11-24 |
| Platform | macOS 15+ |
| Parent design | `2026-11-21-pomodoro-product-design.md` |
| Supersedes | The 60-minute popover dial in the parent design, `2026-11-24-configurable-durations-design.md` §5.2, and the idle-pointer details in `2026-11-23-direct-break-design.md` |
| Related | [`2026-11-24-mode-color-system.md`](2026-11-24-mode-color-system.md) |

## 1. Summary

The popover dial is a session gauge, not a 60-minute clock. The hand is
removed. The remaining fraction of the current interval is a mode-colored arc
in an empty recessed channel between thin brass outer and inner edges: it sweeps
to full at 12 o'clock when an interval starts, then drains counterclockwise to
empty. The central `MM:SS` readout remains authoritative.

The idle and completed dials have an empty channel but keep the fixed 60-tick
face. The menu-bar icon keeps its compact hand and shows the same
remaining-session fraction in miniature.

## 2. Why this change

- Durations are configurable from 1 to 180 minutes. A 60-minute hand and arc
  clamp at the full-hour position, so a 90-minute interval sits still for its
  first 30 minutes and a 180-minute interval for its first two hours. The
  session gauge gives every interval the same full circle.
- Without a hand, a 60-minute arc has no reference for why it starts at a
  particular angle. Full and empty are self-explanatory.
- Both surfaces now use one remaining-proportion rule. The menu bar keeps its
  hand because the 22-point icon needs a compact directional cue; the popover
  uses the larger channel instead.

## 3. Visual rules

- The popover dial has no hand or visible pivot in idle, running, paused, and
  completed states. The app icon, menu-bar icon, and tiny header mark keep their
  hands.
- The empty recessed channel occupies the bezel lane: outside the 60 fixed
  ticks, between thin brass outer and inner edges. It is not a brass fill track
  and it has no separate thin progress ring.
- Idle shows an empty channel, the configured duration, and `READY`. Starting an
  interval sweeps the mode-colored arc clockwise from 12 o'clock to full in 0.3
  seconds.
- From full, the gap grows counterclockwise from 12 o'clock; the channel is
  empty at completion.
- Pausing freezes the arc at the current fraction. Resuming continues from the
  same fraction.
- Completed shows an empty channel. The completion screen shows the offered
  duration in the readout; there is no pointer preview.
- The arc uses the mode accent: brick for Focus, deep sage for Short break, and
  deeper sage for Long break.
- The 60 marks are fixed divisions of the face, not minutes, and are never
  labelled. All remain visible; only the 12, 3, 6 and 9 o'clock marks are larger.
  One full revolution is the selected interval, not an hour.
- The plaque remains a raised disc with a hairline brass edge. The brass pivot
  appears only in the icons.
- The running and paused caption names the mode; idle and completion keep
  `READY`.

## 4. Motion

- The channel arc drains smoothly between displayed seconds; no continuous
  high-frame-rate rendering.
- Starting sweeps the arc from empty to full clockwise over 0.3 seconds; the
  first drain then reverses from 12 o'clock. Idle mode changes move only the
  readout, mode accents, and ambient light; no hand moves and the channel stays
  empty.
- State changes use a short settle; no looping pulses, glow, or confetti.
- Reduce Motion replaces interpolation and transitions with direct state
  changes.

## 5. Accessibility

- The channel arc is decorative and hidden from VoiceOver. The existing dial
  label, value, and time readout continue to expose phase, remaining time, and
  state.
- Do not announce every second or minute.

## 6. Acceptance criteria

- No hand appears in the popover dial in any state.
- The channel arc sweeps from empty to full clockwise in 0.3 seconds at the
  start of focus and break intervals, then drains counterclockwise, freezes when
  paused, and is empty when idle or completed.
- A 5-minute, 25-minute, 90-minute, and 180-minute interval each use the full
  channel at their own scale; no value clamps at 60 minutes.
- The central readout always shows the true `MM:SS` and the configured or
  captured duration.
- All 60 marks remain fixed; only the 12, 3, 6 and 9 o'clock marks are larger,
  and no minute labels are added.
- The channel uses the active mode accent, and the running/paused caption names
  the mode.
- The menu-bar icon, its hand, cup, pause glyph, and progress arc are unchanged.
- Light, Black, System, and reduced-transparency states remain legible; Reduce
  Motion removes interpolation.
- `swift test` and `./scripts/build-app.sh debug` pass; the built app is
  inspected in the affected states.

## 7. Out of scope

- Removing the hand from the menu-bar icon, app icon, or header mark.
- Further changes to the channel width or fixed-tick geometry beyond the
  accepted three-mode color system.
- Adding labels, numbers, or a new progress track.
