# Pomodoro Guided Next Step

**Product specification**

| Field | Value |
| --- | --- |
| Status | Implemented |
| Date | 2026-11-24 |
| Platform | macOS 15+ |
| Amends | `2026-11-21-pomodoro-product-design.md` |

## 1. Summary

When an interval reaches zero, the popover moves directly to the next
interval's ready screen. A completed focus shows the recommended break; a
completed break shows the next focus. The countdown never starts by itself, so
the rhythm becomes automatic without taking the choice away from the user.

This replaces the former `00:00` / `COMPLETE` completion screen. The chime,
notification, persistence, menu-bar completed treatment, and rhythm rules are
unchanged.

## 2. Behavior

### 2.1 Focus completes

1. The completion chime plays when enabled.
2. One notification appears when authorized and the popover is not visible.
3. The popover moves automatically to the recommended break's ready screen:
   - title `Take a short break` or `Take a long break`;
   - dial at `05:00` or `15:00`, caption `READY`, break accent;
   - body `Focus complete. Ready for a break?`;
   - primary `Start 5-minute break` or `Start 15-minute break`;
   - quiet `Done for now`.
4. The fourth naturally completed focus recommends the 15-minute long break.
5. Starting the break uses the existing recommended-break action and schedules
   the existing break notification.
6. `Done for now` declines the break and returns to idle. Declining an offered
   long break resets the rhythm exactly as before.
7. No countdown starts until the user chooses.

### 2.2 Break completes

1. The completion chime plays when enabled.
2. One notification appears when authorized and the popover is not visible.
3. The popover moves automatically to the focus ready screen:
   - title `Ready to focus`;
   - dial at `25:00`, caption `READY`, focus accent;
   - body `Break complete. Ready for another focus?`;
   - primary `Start 25-minute focus`;
   - quiet `Done for now`.
4. Starting another focus uses the existing start-another action.
5. `Done for now` returns to idle. The completed focus count and rhythm are
   unchanged.
6. No countdown starts until the user chooses.

### 2.3 Closed popover

Closing the popover does not change the flow. The completion notification names
the next step, and opening the popover shows the matching ready screen. Nothing
counts down while the popover is closed.

### 2.4 Menu bar

The completed menu-bar treatment remains until the next interval starts. This
feature does not add a menu-bar prompt or a new menu-bar state.

## 3. State model

No persisted fields or schema migration are added.

- The completed interval keeps `runState == .completed`.
- `phase` still names the interval that just finished.
- `TimerModel.completionOffer` derives the next phase and duration:
  - completed focus → `recommendedBreak`;
  - completed break → focus with the stored focus duration.
- `TimerModel` continues to own the start actions; the completion view only
  presents the offer.

This keeps restoration, pause/resume, notification rescheduling, and rhythm
behavior on their existing paths.

## 4. Copy

The screen reuses existing semantic keys and updates two body strings.

| Key | English source |
| --- | --- |
| `timer.title.short_break` | **Take a short break** |
| `timer.title.long_break` | **Take a long break** |
| `timer.title.idle` | **Ready to focus** |
| `timer.caption.ready` | **READY** |
| `timer.action.start_break` | **Start %lld-minute break** |
| `timer.action.start` | **Start %lld-minute focus** |
| `completion.body.focus_done` | **Focus complete. Ready for a break?** |
| `completion.body.break_ready` | **Break complete. Ready for another focus?** |
| `completion.action.done` | **Done for now** |
| `announcements.break_complete` | **Break complete. Ready for another focus.** |

The primary action uses the same label as the corresponding idle screen so the
presentation reads as the next mode, not as a second workflow.

## 5. Accessibility

- The dial exposes the next duration and reads as ready, not complete.
- The primary action keeps the existing start-focus or start-break hint.
- The focus dial and break dial keep their existing accessible names.
- The break-completion announcement now names the next focus.
- The completion screen has two controls, primary then `Done for now`, and no
  mode dots or arrows.

## 6. Non-goals

- Starting a focus or break countdown automatically.
- Opening the popover automatically when an interval ends.
- Notification action buttons that start an interval.
- New persisted fields or a new run state.
- Changing focus or break durations, the long-break cadence, or the manual
  direct-break behavior.
- Changing the menu-bar completed treatment.
- New tasks, notes, history, or session context.

## 7. Acceptance criteria

- A naturally completed focus shows the recommended break ready to start.
- A naturally completed fourth focus shows the 15-minute long break ready to
  start.
- A naturally completed break shows the 25-minute focus ready to start.
- Both ready screens show the next duration with `READY`, not `00:00` with
  `COMPLETE`.
- No countdown starts without a Start action.
- `Done for now` still returns to idle and preserves the existing long-break
  decline rule.
- The chime, notification, menu-bar completed treatment, restoration, and
  language switching behave as before.
- The completion screen fits in English, Simplified Chinese, Traditional
  Chinese, and Japanese in both Light and Black themes.
- `swift test` and `./scripts/build-app.sh debug` pass.
- The built app is inspected in the short-break offer, long-break offer, and
  focus offer states.

## 8. Verification

The completion screens were inspected in the built debug app with seeded
completed-focus and completed-break states, plus live focus and break
transitions. Light and Black themes and all four languages were checked.
`Done for now` and both start actions remain on the existing engine paths
covered by `swift test`.
