# Release Testing Checklist

Add or update the relevant case whenever a feature or bug fix lands, and keep
it while that behavior exists. Update or remove the case when the behavior is
intentionally changed or removed.

Execute this full checklist only when preparing a Pomodoro release. It does not
replace `swift test`, which must still run after every code change. The matrix
below is the pre-release gate for behavior that is not exhaustively covered by
automated tests.

## Release record

- Version:
- Build:
- Tester:
- Date:
- macOS version:

## Before tagging

### Automated checks

- [ ] `swift test` passes with no failures.
- [ ] `./scripts/build-app.sh debug` passes, including String Catalog
      validation, signing, entitlement verification, and resource installation.
- [ ] `Resources/Info.plist` contains the intended
      `CFBundleShortVersionString` and `CFBundleVersion`.
- [ ] `Package.resolved` is committed and matches `Package.swift`.

### Timer and rhythm

- [ ] Starting a focus uses an absolute end date and displays the full duration.
- [ ] Pause freezes the remaining time; resume schedules the remaining time.
- [ ] Pausing at zero completes the interval once without double-counting.
- [ ] Natural completion increments the focus count and moves the popover to the
      recommended break ready to start while Auto-start break is off.
- [ ] The focus-completion screen shows the recommended 5- or 15-minute break,
      its duration on the dial with `READY`, and a Start break action; no
      countdown starts.
- [ ] Auto-start break defaults off, survives relaunch, older state files without
      the field load as off, and an explicit on choice is preserved.
- [ ] With Auto-start break on, a natural focus completion goes directly from
      the focus-running screen to the running break screen; no completion or
      break-ready screen flashes.
- [ ] The auto-started break's countdown stays at full during the chime and
      begins decreasing after the chime; with the chime off it decreases
      immediately.
- [ ] Pause and End work during the chime hold; disabling Auto-start break
      during the hold does not stop the running break.
- [ ] Auto-start break still selects the 15-minute long break on the fourth
      completed focus.
- [ ] Auto-start break does not start a break after an early-ended focus.
- [ ] With Auto-start pomodoro off, a completed break waits for Start focus;
      Auto-start break alone does not start it.
- [ ] Auto-start pomodoro defaults off, survives relaunch, older state files
      without the field load as off, and an explicit on choice is preserved.
- [ ] With Auto-start pomodoro on, a natural break completion goes directly from
      the break-running screen to the running focus screen; no focus-ready or
      completion screen flashes.
- [ ] The auto-started focus's countdown stays at full during the break chime
      and begins decreasing after the chime; with the chime off it decreases
      immediately.
- [ ] Pause and End work during the focus chime hold; disabling Auto-start
      pomodoro during the hold does not stop the running focus.
- [ ] Auto-start pomodoro does not start a break.
- [ ] An early-ended break does not start a focus, and an expired break restored
      at launch shows the focus-ready screen instead of starting retroactively.
- [ ] With both Auto-start break and Auto-start pomodoro on, the focus-to-break
      and break-to-focus cycle continues with the correct durations.
- [ ] Enabling Auto-start pomodoro while a break runs applies to that
      completion; enabling it on the completed focus-ready screen does not
      retroactively start the focus.
- [ ] Enabling Auto-start break while focus runs applies to that completion;
      enabling it on the completed ready screen does not retroactively start
      the break.
- [ ] Ending a focus early does not advance the focus count or long-break rhythm.
- [ ] Ending a focus early asks for confirmation before discarding the interval;
      ending a break does not.
- [ ] The fourth completed focus recommends a 15-minute long break.
- [ ] Declining an offered long break with `Done for now` resets the rhythm
      before the next focus.
- [ ] Completing a break moves the popover to the 25-minute focus ready screen
      with `Start 25-minute focus`; no countdown starts.
- [ ] Starting a short or long break from idle uses the 5- or 15-minute
      duration and preserves the completed focus count and rhythm.

### Restoration and wake recovery

- [ ] Relaunching during a running interval restores the correct remaining time.
- [ ] Relaunching after the interval expired completes it exactly once.
- [ ] Relaunching after an expired focus with Auto-start break on shows the
      break-ready screen instead of starting a break retroactively.
- [ ] Relaunching a paused interval preserves its stored remainder.
- [ ] Sleep/wake recovery completes an expired interval only once.
- [ ] Moving the system clock backwards does not extend an interval past its
      total duration.

### Persistence

- [ ] A missing state file is treated as first run.
- [ ] A partial state file uses defaults for missing fields.
- [ ] A corrupt state file is backed up and the app recovers with a clear message.
- [ ] Recovery still reports a reset when the backup cannot be written.
- [ ] Timer state and preferences survive a normal quit and relaunch.

### Popover and menu bar

- [ ] Idle, running, paused, completed, and break states render correctly.
- [ ] The completion screen shows the next interval's duration with `READY`, not
      `00:00` with `COMPLETE`.
- [ ] The completion ambient light follows the next interval: break offer sage
      or brass, focus offer tomato; starting the offered interval keeps that
      pose.
- [ ] The completion primary starts the offered break or focus and schedules
      its notification; `Done for now` returns to idle.
- [ ] The mode dots and arrows appear only while idle and are hidden while any
      interval is running, paused, or completed.
- [ ] Selecting a break dot and pressing Start begins the existing break
      state, menu-bar treatment, notification, and completion flow.
- [ ] The idle mode dots and arrows select Focus 25, Short break 5, and
      Long break 15; the primary starts the selected mode.
- [ ] The arrows do not wrap: Focus shows only the next arrow, Long break only
      the previous one, Short break both. A hidden arrow keeps its slot, so the
      dial does not move, and it cannot be clicked or reached by VoiceOver.
- [ ] Changing the idle mode slides the dial readout out toward the arrow that
      was pressed, cut off at the plaque edge rather than floating over its
      face, and the next duration follows it in from the other side; the hand
      sweeps to the new position at the same time. Reduce Motion swaps it
      without motion.
- [ ] Rapid mode changes leave no stuck or duplicated readout: each swap
      replaces the previous one, and the duration always settles centered.
- [ ] All three mode dots use the mode accent at full opacity; only the active
      dot is wider. A single current-mode label below the dots names the mode;
      the 32-point arrows expose hover help and announce the current mode.
- [ ] The primary Start uses the leaf-green fill with a centered label and a
      trailing play glyph; light uses ink text and dark uses white, without a
      colored glow.
- [ ] The idle ambient light follows the selected mode dot: Focus upper left,
      Short break overhead, Long break upper right.
- [ ] The idle pointer points at the selected duration: 25m at five o'clock,
      5m at one o'clock, 15m at three o'clock.
- [ ] Switching idle modes does not recolor the pointer.
- [ ] Starting a focus or break keeps the dial and primary in place; the status
      line appears in the mode row below the dial.
- [ ] The dial's progress arc sits in the chapter ring outside the minute
      ticks, a square-ended hairline against the brass rim with no glow.
- [ ] A paused interval shows the paused status line and the paused footer tip.
- [ ] Idle mode labels and footer tips reach 4.5:1 against the popover in both
      themes; light mode uses the deeper mode accents.
- [ ] Settings uses the plain card background; no ambient rim, glow, or shade
      is visible there.
- [ ] The Settings back control returns to the timer without closing the popover.
- [ ] Settings shows the FOCUS section with Auto-start break and Auto-start
      pomodoro both off by default; both choices survive relaunch.
- [ ] The Settings card grows to fit its content: both FOCUS rows, the
      notifications explanation, and the footer all stay visible with no
      scrollbar, in all four languages, both themes, and with notifications
      allowed or denied. The card is never shorter than the timer page's card
      plus the settings rows, and switching Settings on and off returns the
      popover to 506 points.
- [ ] Changing the mode animates the light over 850 ms; with Reduce Motion
      enabled the pose updates without movement.
- [ ] Reduce Transparency keeps the ambient layers legible and does not
      wash out the mode controls.
- [ ] Mode selection, start, pause, resume, end early, skip, and done actions work.
- [ ] The menu-bar icon, optional minutes, progress, and paused/completed states
      match the timer state.
- [ ] Completing a break returns the menu-bar icon to the resting focus dial.
- [ ] Left-click opens the popover and right-click opens the menu.
- [ ] Settings, About, Check for Updates, and Quit work from their menus.
- [ ] Notification status and saved-state error messages are understandable
      and dismissible.
- [ ] Light, Black, and System appearances are checked.
- [ ] Reduced Transparency is checked and does not make content unreadable.
- [ ] VoiceOver labels and announcements are meaningful for the main timer actions.

### Localization

- [ ] English, Simplified Chinese, Traditional Chinese, and Japanese are
      available in the language picker.
- [ ] The home popover and completion states fit without clipping in all four
      languages.
- [ ] Settings rows stay aligned across all four languages in both themes, with
      no visible scrollbar.
- [ ] Switching language updates the popover, menus, status-item copy, and
      typography immediately without restarting the timer.
- [ ] A pending notification is rescheduled for the existing end date after a
      language change.
- [ ] String Catalogs contain every required key in all four localizations.

### Notifications and sound

- [ ] Notification permission states are represented correctly.
- [ ] The focus-completion notification reads `Time for a break.` and fits both
      a waiting break and an auto-started break.
- [ ] The break-completion notification reads `Time to focus.`, fits both a
      waiting focus and an auto-started focus, and fires once when the popover
      is closed.
- [ ] An auto-started focus schedules its focus-end notification and updates the
      menu bar to the running focus state.
- [ ] An auto-started break schedules its break-end notification and updates the
      menu bar to the running break state.
- [ ] Starting, pausing, resuming, ending, and switching language keep the
      pending notification consistent with the timer.
- [ ] Chime and ticking settings behave as labeled.
- [ ] Focus completion plays the rising chime; break completion plays the lower
      descending mirror; the single Completion chime switch mutes both.
- [ ] Sleep/wake does not cause duplicate completion notifications or sounds.

### Updates

- [ ] Notify, Download, and Never modes behave as documented.
- [ ] Check Now and Check for Updates work and report availability correctly.
- [ ] The update-available dot only appears in the documented states.
- [ ] Update UI is readable in all supported languages and both themes.

### Documentation

- [ ] If the home popover UI changed, `README.md` copy and screenshots are updated.
- [ ] `DEVELOP.md` reflects any changed build, signing, localization, or release steps.

## After publishing

- [ ] The tag matches `v` plus `CFBundleShortVersionString`.
- [ ] CI publishes `Pomodoro.dmg`, `Pomodoro.dmg.sha256`,
      `Pomodoro-VERSION.zip`, its `.sha256`, and `appcast.xml`.
- [ ] The Sparkle feed and update archive are publicly readable.
- [ ] The appcast contains valid EdDSA signatures for the feed and enclosure.
- [ ] The disk image is notarized and stapled when the required secrets are present.
- [ ] The GitHub release summary and release notes are correct.
- [ ] A clean download can be installed and launched.

## Sign-off

- [ ] Every applicable item is checked, or the exception and reason are recorded.
- [ ] The release is approved for publishing.
