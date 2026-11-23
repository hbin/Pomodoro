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
- [ ] Natural completion increments the focus count and offers the next action.
- [ ] Ending a focus early does not advance the focus count or long-break rhythm.
- [ ] The fourth completed focus recommends a 15-minute long break.
- [ ] Skipping a long break or starting another focus resets the rhythm.
- [ ] Completing a break offers another focus interval.
- [ ] Starting a short or long break from idle uses the 5- or 15-minute
      duration and preserves the completed focus count and rhythm.

### Restoration and wake recovery

- [ ] Relaunching during a running interval restores the correct remaining time.
- [ ] Relaunching after the interval expired completes it exactly once.
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
- [ ] The mode dots and arrows appear only while idle and are hidden while any
      interval is running, paused, or completed.
- [ ] Selecting a break dot and pressing Start begins the existing break
      state, menu-bar treatment, notification, and completion flow.
- [ ] The idle mode dots and arrows select Focus 25, Short break 5, and
      Long break 15; the primary starts the selected mode.
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
- [ ] Settings uses the plain card background; no ambient rim, glow, or shade
      is visible there.
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
- [ ] Starting, pausing, resuming, ending, and switching language keep the
      pending notification consistent with the timer.
- [ ] Chime and ticking settings behave as labeled.
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
