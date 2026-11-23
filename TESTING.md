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
- [ ] Duration selection, start, pause, resume, end early, skip, and done actions work.
- [ ] The menu-bar icon, optional minutes, progress, and paused/completed states
      match the timer state.
- [ ] Left-click opens the popover and right-click opens the menu.
- [ ] Settings, About, Check for Updates, and Quit work from their menus.
- [ ] The first-run tip, notification status, and saved-state error messages
      are understandable and dismissible.
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
