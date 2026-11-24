# Minimal Update Indicator

**Feature design specification**

- Status: Approved
- Date: 2026-11-22
- Platform: macOS 15+

## Summary

Remove the permanent **Updates** section from Settings. The only always-visible
update affordance is a small dot immediately after the version number in the
footer.

The dot opens a compact panel above the footer. The panel contains update
status, an install or check action, and the automatic-update preference. The
panel is dismissed by clicking the dot again, choosing **Later**, clicking
anywhere else in the Settings content area, or closing Settings. Clicking
outside the panel only dismisses it and does not activate the Settings control
underneath; a second click is required.

Settings collapses from its timer height to a compact **520-point** height so
the removed update section does not leave an empty block above the footer. The
width remains **380 points**, and returning to the timer restores the **544-point**
height.

## Visual behavior

- Neutral state: a 4.5-point muted dot.
- Update available: a 5-point tomato dot with a faint two-step halo.
- The dot has a 20-point interaction target without making the visible mark
  larger.
- The dot never installs an update directly. It only opens the update panel.
- The mouse pointer shows a help label: **Update settings** or **Update
  available**.
- VoiceOver announces the same state and that the button opens update
  controls.

## Panel states

### Up to date or no update known

- Title: **Updates**
- Quiet **Check Now** action in the header.
- Status line: **Pomodoro is up to date**, or the current automatic-update
  description when no check result is known.
- Compact text choices for **Notify**, **Download**, and **Never**.

### Update available

- Tomato status mark and **Version X.Y.Z is available**.
- One emphasized **Install Update** button.
- Quiet **Later** action in the header.
- The same compact automatic-update choices remain below the action.
- Choosing **Later** closes the panel without changing the dot; the update
  remains discoverable.

### Update downloaded

- Status changes to **Version X.Y.Z is ready to install**.
- **Install Update** remains available.
- In Download mode, Pomodoro uses Sparkle's immediate-install handler when one
  is available; otherwise the button presents Sparkle's normal update flow.
- If the user does nothing, Sparkle still installs the update when Pomodoro
  quits.

### Updates unavailable

- The dot remains neutral.
- The panel says updates are unavailable in this build.
- Update actions and preferences are disabled.

## Automatic-update choices

The three choices remain functionally unchanged:

- **Notify**: check daily and let the user choose when to install.
- **Download**: check and download automatically, then install on quit.
- **Never**: disable automatic checks; manual checks still work.

They appear as compact text options inside the panel, not as a permanent
segmented control.

## Sparkle integration

- `UpdateController` becomes the Sparkle updater delegate.
- `didFindValidUpdate` publishes the available version.
- `didDownloadUpdate` publishes the ready-to-install state.
- `didNotFindUpdate` clears the available-update signal.
- The delegate captures Sparkle's immediate-install handler when an automatic
  update is ready to install on quit.
- `Install Update` invokes the immediate handler when possible. Otherwise it
  starts Sparkle's normal update flow.
- Manual **Check for Updates...** menu commands continue to use Sparkle's
  standard user interface.
- The existing Sparkle standard user driver remains in use. Building a custom
  Sparkle user driver is outside this change.

## Acceptance criteria

- Settings no longer contains an **Updates** section or permanent update
  segmented control.
- The version footer shows `vX.Y.Z` followed by the neutral or tomato dot.
- Clicking the dot opens the compact panel; clicking it again closes it.
- Clicking the Settings content area outside the open panel dismisses only the
  panel without activating the control underneath.
- A found update is visible as a tomato dot without enlarging the footer.
- **Install Update** starts the Sparkle update flow and **Later** preserves the
  dot state.
- Update modes can still be changed from the panel.
- Debug builds without an update feed show a neutral dot and disabled update
  controls.
- Settings remains within its fixed 380-point width, collapses to 520 points,
  and shows no clipping.
- Keyboard focus and VoiceOver labels describe the dot and panel actions.

## Non-goals

- Custom release-notes rendering.
- A custom Sparkle user driver.
- New automatic-update modes.
- Changes to release packaging, the appcast, or signing.
