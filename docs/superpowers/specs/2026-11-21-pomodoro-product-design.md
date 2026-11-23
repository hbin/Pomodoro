# Pomodoro for macOS

**Product design specification**

- Status: Implemented (v1); later features are specified separately
- Date: 2026-11-21
- Working name: Pomodoro
- Platform: macOS 15+
- Delivery: Local builds and GitHub Releases with Sparkle updates

Later changes amend this spec: see
`2026-11-22-minimal-update-indicator.md`,
`2026-11-23-four-language-localization.md`, and
`2026-11-23-in-app-language-picker.md`. Statements below about local-only
delivery and no network requests describe the original v1 scope.

## 1. Summary

Pomodoro is a personal, menu-bar-only interval timer for macOS. It does one
thing: run a classic Pomodoro rhythm with the calm presence of a small desk
instrument.

There are no projects, tasks, to-do lists, notes, scores, streaks, charts, or
session history. The user chooses a focus duration, starts the timer, and is
left alone. The app keeps the current interval visible in its menu-bar
popover and stays out of the way otherwise.

## 2. Intent and why

Pomodoro assists the practice of the Pomodoro Technique rather than offering a
general-purpose countdown. That stance decides two things elsewhere in this
spec: the break after each focus interval is part of the rhythm rather than an
optional extra, and the focus-completion state offers that break instead of
another focus.

The user wants the benefit of a Pomodoro timer without adopting another
productivity system. Existing apps often bundle timers with task management,
reporting, or gamification. Those layers add setup and mental overhead before
the timer has done anything useful.

This app deliberately removes that overhead. Its value is rhythm, visibility,
and restraint.

## 3. Goals

1. Start a focus interval in as few interactions as possible.
2. Keep the remaining time visible without demanding attention.
3. Preserve an active or paused interval across sleep, quit, and relaunch.
4. Make breaks available without turning them into a workflow.
5. Feel calm, tactile, and distinctly crafted.
6. Remain local, offline, and free of accounts or tracking.

### Success criteria

- The user can start the default 25-minute interval in two interactions from
  the menu bar: open the popover, then press Start.
- The timer is accurate across pause, sleep, quit, and relaunch.
- The app never asks the user to name a task, create a project, or review work.
- The popover updates in place, so starting and running never feel like
  separate screens.
- After a week, using the timer feels automatic rather than like maintaining a
  system.
- Nothing in the app implies that stopping early or skipping a break is a
  failure.

## 4. Non-goals

Version one does not include:

- Tasks, projects, tags, priorities, due dates, or notes.
- A focus queue or “up next” action.
- Completed-task tracking or any historical session log.
- Analytics, charts, heatmaps, scores, streaks, or productivity totals.
- Gamification, mascots, or moralizing copy.
- App or website blocking.
- Accounts, sync, cloud storage, or network requests.
- AI features.
- Multiple concurrent timers.
- Automatic focus/break cycles.
- Launch at login.
- A global keyboard shortcut.
- iOS, iPadOS, Windows, or web versions.
- App Store or public distribution.

## 5. Product principles

### One timer

The product has one current interval at a time. There is no larger backlog for
the user to manage.

### Quiet by default

The app is silent and still unless the user starts an interval or a timer
reaches zero.

### Guide, do not drive

The app may offer the next break or focus step. It never starts a transition
automatically.

### Classic rhythm, light flexibility

The default is 25 minutes of focus and 5 minutes of rest. The user can choose a
different focus length before starting without entering a settings system.

### Trust through continuity

An interval must survive ordinary interruptions. Closing the popover, quitting the
app, sleeping the Mac, or pausing must not lose time or state.

### Craft without costume

The analog character comes from proportion, material, and motion. It must not
hide controls or require the user to decode a decorative metaphor.

## 6. Approaches considered

### A. Menu-bar-only compact timer — selected

All interaction stays inside one menu-bar popover, with no floating window.
The idle screen becomes the running screen in place, keeping the same dial and
primary action position.

**Why it wins:** It makes starting direct, keeps one interface for every timer
state, and avoids a second window competing for attention.

**Tradeoff:** The popover has to fit every state, so running controls must stay
compact and avoid introducing a second layout.

### B. Menu-bar timer with a floating analog card

A custom menu-bar status item opens a compact SwiftUI popover for starting the
timer, while a separate floating AppKit panel shows the analog card during an
interval.

**Why it loses:** It splits the timer across two surfaces, adds a thin AppKit
layer, and makes the running state feel like a jump away from the popover.

### C. Task-backed Pomodoro app

A timer combined with an action queue, completion tracking, and recent
context.

**Why it loses:** The owner explicitly removed task and project tracking. This
shape adds management before focus and conflicts with the “simple timer”
intent.

### D. Desktop web wrapper

A web interface packaged as a Mac app.

**Why it loses:** It is heavier, less native, and adds packaging complexity
without improving the timer experience.

## 7. Core experience

### 7.1 App presence

- The app has no Dock icon.
- It appears only as a custom status item in the macOS menu bar.
- Clicking the status item opens the timer popover.
- Clicking the status item again while the popover is open closes it.
- Clicking elsewhere dismisses the popover; the next status-item click opens
  it again.
- The status item uses a large monochrome dial that fills the 22-point canvas.
  Its resting outline stays legible beside system menu-bar icons.
- The dial's outline becomes a bold remaining-time arc that starts at 12
  o'clock, while the hand moves counterclockwise as the interval counts down.
- During a break, a cup replaces the hand inside the same progress dial.
- While running, it also shows the remaining whole minutes, for example `18m`.
- While paused, the hand becomes a centered pause mark, the remaining time
  stays visible, and the item keeps a fixed width.
- When the interval completes, the remaining-time arc empties, the hand returns
  to its starting position, and the resting ring turns gray.
- No launch-at-login item is installed.

### 7.2 First run

On first launch:

1. The menu-bar popover opens automatically so the user learns where the app
   lives.
2. The default `25m` duration is selected.
3. A single dismissible line explains that the app stays in the menu bar.
4. Notification permission is requested when the user starts the first
   interval.

There is no onboarding tour, account, theme picker, or configuration step.

If notification permission is denied, the timer still works. The completion
state and optional chime remain available, and Settings shows that notifications
are off.

### 7.3 Idle state

The popover contains only:

- A short status line, such as `Ready to focus`.
- Duration chips: `15m`, `25m`, and `45m`.
- A primary button labelled with the selected duration, such as
  `Start 25-minute focus`.
- A settings control that switches the popover to Settings without opening
  another window.

`25m` is selected whenever the app returns to an idle state.

Starting:

- Requires no task or text input.
- Keeps the popover open and updates the same screen in place.
- Keeps the dial, controls, and primary action in the same positions to avoid a
  visual jump.
- Schedules one local notification for the expected end time.

### 7.4 Running state

The running state keeps the popover's instrument character and replaces the
duration chooser with live interval information.

It contains:

- The analog dial with a precise central digital readout.
- The same primary button position, switched to pause/resume.
- A quiet end-interval action with an inline confirmation.
- A quiet `Ends at…` line based on the current expected finish time.

It does not contain a task title, project, notes, checklist, or progress rating.

Behavior:

- Closing the popover does not pause or end the interval.
- The menu bar continues to show remaining whole minutes.
- Reopening the popover restores the same running or paused state.
- There is no separate running window or floating card.

### 7.5 Timer behavior

- Focus durations: 15, 25, or 45 minutes.
- The default is 25 minutes.
- Remaining time is derived from an absolute end timestamp, not a decrementing
  counter.
- Pausing freezes the remaining duration and cancels the pending notification.
- Resuming creates a new end timestamp and reschedules the notification.
- Paused time does not count toward the interval.
- The dial stops moving while paused; the readout and copy make the state
  explicit.
- If tick sound is enabled, one soft tick plays for each whole second while a
  focus interval is actively counting down.
- Tick sound stops immediately when the interval is paused or ended. It does
  not play during breaks.
- Scheduling the tick must not drift the timer or double-play after wake.
- Sleeping or locking the Mac does not corrupt elapsed time.
- On wake or relaunch, the app reconciles stored state with the current time.
- Ending early requires one confirmation because it discards the current
  interval.
- Ending early does not count toward the long-break rhythm.

### 7.6 Natural completion

When the focus interval reaches zero:

1. A short original chime plays if the completion chime is enabled.
2. One local notification appears if notifications are authorized and the app
   is not frontmost.
3. If the popover is visible, the completion state and chime replace the notification
   so the user is not alerted twice.
4. The popover changes to a calm completion state.

The completion state contains:

- `Focus complete`.
- A primary action for the appropriate break:
  - `Take a 5-minute break` normally.
  - `Take a 15-minute break` after every fourth completed focus interval.
- A quiet `Done for now` action that returns to the idle state.

The break is part of the rhythm, so the completion state does not offer a
second focus. Starting one without a break is still possible by choosing
`Done for now` and pressing Start again; the app neither advertises nor blocks
that path.

No task completion is recorded or requested.

### 7.7 Breaks

- Short break: 5 minutes.
- Long break: 15 minutes.
- A long break is offered after every four naturally completed focus
  intervals.
- Ending a focus interval early does not advance the rhythm.
- Skipping an offered long break resets the rhythm for the next group of four.
- The break state uses the same popover with a calmer sage/brass
  treatment.
- Break copy is supportive and non-judgmental, for example `Step away` and
  `Break`.
- The user may end or skip a break early.
- No focus or break transition starts automatically.
- When a break ends, the popover offers `Start another focus` and `Done for now`.
- Break sessions are not stored.

### 7.8 Settings

Settings stays intentionally small:

- Opens inside the menu-bar popover. A back control in the title row returns
  to the timer while leaving the popover open.
- Completion chime on/off.
- Tick sound on/off; default off.
- Show remaining minutes in the menu bar on/off.
- Notification status and a way to open the relevant macOS settings.
- Version information.

There are no duration presets to configure. Per-interval duration changes live
on the idle screen.

## 8. States

### Idle

- Popover shows `Ready to focus`.
- `25m` is selected unless the user changes it for the next interval.
- Start is enabled.

### Focus running

- The popover updates in place to show the running interval.
- Menu-bar item shows remaining whole minutes.
- `Pause` and `End` are the primary controls.

### Focus paused

- Readout remains at the paused remaining time.
- Popover and menu bar clearly indicate pause.
- Primary control becomes `Resume`.
- Clicking elsewhere in the popover does not resume accidentally.

### Focus complete

- Popover shows the recommended break; `Done for now` is the only other action.
- Nothing begins until the user chooses.

### Break running

- Calmer color treatment.
- No focus language.
- Skip/end remains available.
- Menu bar shows the break countdown.

### Break complete

- `Start another focus` and `Done for now`.

### Notifications unavailable

- Timer remains fully usable.
- Settings shows `Notifications are off`.
- The app does not repeatedly ask for permission.

### Corrupt saved state

- Preserve unreadable data as a backup.
- Recover with a clean timer state.
- Show one quiet, dismissible error.
- Do not crash or silently erase recoverable data.

## 9. Visual direction

### 9.1 Form

The popover should feel like a small, well-made desk instrument:

- Warm bone or cream face.
- Thin brass outer rim.
- Slightly inset paper surface with restrained texture.
- Muted tomato-red hand and live-interval controls, with a leaf-green action
  that starts an interval.
- Dark warm ink for typography and controls.
- Rounded rectangular body rather than a literal tomato or mascot.

The material treatment should be believable but restrained. Avoid ornamental
parts that reduce clarity.

### 9.2 Palette

Light mode:

- Warm bone: `#F6EFE2`
- Deeper paper: `#ECE2D2`
- Ink: `#2B2520`
- Muted ink: `#756858`
- Tomato: `#C6533F`
- Deep tomato: `#A53D2E`
- Brass: `#B48A58`
- Light brass: `#DCC29B`
- Leaf, primary actions only: `#7C9F5C` with an ink label
- Sage, breaks only: `#7F8C72`

Dark mode:

- Espresso and charcoal surfaces replace the bone field.
- Cream text replaces ink.
- Tomato, brass, and sage remain recognizable.
- Contrast is maintained without turning the popover into a glowing object.

The primary action keeps one fill in every mode, including breaks, pause, and
resume. Mode is carried by the dial, the pointer, the mode dots, and the mode
label, so the button stays a constant target while the face changes. Sage and
tomato are too low-contrast to fill a button with legible text.

### 9.3 Typography

- Interface copy: Avenir Next or the system sans-serif.
- Countdown digits: a monospaced or tabular system face for stable width.
- Short status copy may use a warm serif when it improves the instrument
  character.
- Small labels use restrained uppercase letter spacing.

No task-title typography is required.

### 9.4 Dial

The dial is a 60-minute clock:

- The hand marks the remaining minutes on a 60-minute face. One full
  revolution is an hour, not the selected interval.
- The hand stands at the selected duration while idle and counts back
  toward 12 o'clock as the interval runs. Starting an interval therefore
  leaves the hand where it was.
- A thin arc in the chapter ring, between the minute ticks and the brass
  rim, shows the same value as the hand. It starts at 12 o'clock and ends
  at the hand's angle, so the two always agree without touching.
- The arc has square ends and no glow; it reads as an inlay in the bezel
  rather than a drawn highlight.
- Tick marks are decorative and unlabelled; the central readout is
  authoritative.
- The central plaque shows `MM:SS` and `REMAINING`.
- The plaque is a raised disc with a hairline brass edge, so the hand reads as
  mounted on it rather than floating on the face.
- The hand and arc use the tomato accent.
- The plaque covers the dial center, so this dial has no visible pivot; the
  brass pivot appears only in the app and menu-bar icons.
- The dial remains legible at the popover's supported size.

Break intervals use the same geometry with the sage accent.

The menu-bar icon is a session gauge rather than a clock: its arc starts full
and empties counterclockwise as the interval runs, with the hand riding the
emptying edge. Both surfaces reach zero when the interval ends; they differ
only in how full they are at the start.

### 9.5 Motion

- The hand advances smoothly enough to feel mechanical without continuous
  high-frame-rate rendering.
- State changes use a short settle rather than a bounce.
- Completion uses one calm transition of the face and readout.
- No looping pulses, confetti, shaking, or attention-seeking effects.
- Reduce Motion replaces interpolation and transitions with direct state
  changes.

### 9.6 Sound

- One short, original two-note chime for natural completion.
- Warm, soft, wood or marimba-like character.
- Under one second.
- Optional ticking: a quiet, mechanical tick once per second while a focus
  interval is actively running.
- Tick sound is off by default and is independent of the completion chime.
- Tick sound stops on pause, end, completion, or lost active timer state.
- Breaks remain silent; the tick is a focus cue.
- Tick volume should sit below the completion chime and should be comfortable
  for long sessions.
- The tick must be generated from the timer's second boundary and must not
  double-play after sleep or wake.
- No sound on every button press.
- Settings can mute the chime and tick sound independently.
- Do not layer the system notification sound on top of the app chime.

### 9.7 Icons

- App icon: bone rounded-square field, tomato dial, and a brass hand pointing
  to the 25-minute mark, with a brass pivot.
- Menu-bar icon: grand monochrome dial that fills the 22-point canvas, with a
  readable resting outline and bold remaining-time arc.
- Active menu bar: icon plus remaining whole minutes.
- Break menu bar: the same progress dial and minutes with a cup in place of the
  focus hand.
- Paused menu bar: same time plus a centered pause mark inside the dial.
- Completed menu bar: the hand at its starting position, a gray resting ring,
  and no minute label.
- No red badge, exclamation mark, or alarm-style iconography.

## 10. Accessibility

- All controls have explicit VoiceOver labels and values.
- The timer exposes phase, remaining time, and paused/running state.
- Clock values are read naturally rather than character by character.
- Completion, pause, resume, and break transitions post appropriate
  accessibility announcements.
- Tick sound is optional and never carries information that is unavailable
  visually or through VoiceOver.
- Do not announce every second or minute.
- The popover is fully keyboard navigable.
- Focus order follows visual order.
- Escape dismisses the popover.
- Space toggles pause/resume only when the popover has keyboard focus.
- Increase Contrast and Reduce Transparency are respected.
- Color is never the only signal for selected, paused, completed, or error
  states.
- All interactive targets meet comfortable macOS click-target sizes.
- The interface remains usable at larger system text sizes without clipping.

## 11. Data and persistence

### Stored state

The app stores only what the timer needs:

- Selected focus duration.
- Current phase: focus, short break, or long break.
- Absolute end timestamp while running.
- Remaining duration while paused.
- Completed-focus count for the long-break rhythm.
- Completion chime, tick sound, and menu-bar display preferences.
- First-run tip state.

No task, project, note, or session-history data is stored.

### Persistence behavior

- Versioned local state in the app's Application Support container.
- Writes are atomic.
- Save on start, pause, resume, end, settings changes, and termination.
- Restore active and paused intervals on launch.
- On unreadable state, retain a backup and recover with a clean state.

## 12. Privacy and technical shape

- Native SwiftUI application with a thin AppKit shell.
- Custom `NSStatusItem` and `NSPopover` for the menu-bar experience.
- Menu-bar accessory app with no Dock icon.
- Swift 6 language mode and `@MainActor` UI state.
- Timer behavior separated into a deterministic engine with an injectable
  current-date source for tests.
- Notification scheduling isolated behind a small protocol.
- No third-party dependencies.
- App Sandbox enabled.
- No network entitlement or requests.
- No analytics or telemetry.
- No access to Screen Recording, Accessibility, Calendar, Reminders, or
  automation APIs.
- Deployment target: macOS 15.0 or later.
- Local development build; no signing, notarization, or App Store requirements.

## 13. Edge cases

- App quit during focus or break.
- Sleep/wake during an interval.
- Notification fires while the app is closed.
- Notification permission denied or later revoked.
- Chime or tick sound muted, system volume at zero, or output device
  unavailable.
- Popover dismissed and later reopened while the timer runs.
- Rapid repeated start, pause, resume, or end actions do not create duplicate
  timers or notifications.
- Clock changes that make an end timestamp nonsensical are handled
  conservatively without silently discarding the active interval.

## 14. Acceptance criteria

### App shell

- The app launches without a Dock icon.
- A custom menu-bar item is present.
- Clicking it opens the popover.
- Clicking it again closes the popover.
- Clicking elsewhere dismisses the popover without an immediate reopen.
- The settings control switches the popover to Settings instead of opening a
  separate window.
- The Settings back control returns to the timer in the same popover.
- Quitting and relaunching restores a running or paused interval.

### Timer

- The idle screen offers 15, 25, and 45 minutes.
- Starting requires no task or text input.
- Starting keeps the same popover open and updates it in place.
- No separate running window or floating card appears.
- The timer is accurate across pause, sleep, quit, and relaunch.
- Pausing freezes the remaining duration and cancels the pending notification.
- Resuming reschedules the notification.
- Tick sound defaults off.
- When enabled, tick sound plays once per second during active focus, stops on
  pause or end, and does not play during breaks.
- The tick-sound preference persists across launches.
- Ending early requires one confirmation and does not advance the long-break
  rhythm.

### Completion and breaks

- Natural completion plays the chime once when enabled.
- A notification appears once when authorized and appropriate.
- The completion state offers the recommended break without a second modal.
- A long break is offered after every fourth completed focus interval.
- No transition starts automatically.
- Break completion offers another focus or the idle state.

### Simplicity

- No task, project, note, queue, history, score, or analytics surface exists.
- No network requests are made.
- No account or onboarding flow is required.

### Accessibility and resilience

- VoiceOver can operate all timer controls.
- Reduce Motion removes nonessential animation.
- Notification denial does not block core functionality.
- Corrupt state does not crash the app or silently delete recoverable data.

## 15. Decisions

- Personal, local-only Mac app.
- Menu-bar presence only; the popover is the single timer surface.
- Standalone timer with no tasks, projects, or history.
- Classic 25/5 rhythm with 15/25/45 focus choices.
- Long break after every four completed focus intervals.
- Manual guided transitions.
- Quiet analog visual direction.
- Chime plus notification.
- Optional tick sound, off by default.
- Native SwiftUI plus AppKit.
- Manual launch only.
- Menu-bar access only; no global shortcut.

### Builder calls

- Versioned JSON state rather than a database.
- 60-minute clock dial in the popover, with the menu-bar icon as the session
  gauge, rather than one shared full-circle session dial.
- Notification suppressed in the foreground because the popover is already
  visible.
- Completion chime and tick sound are separate preferences.
- Light and dark appearance support.
- App Sandbox enabled with no network entitlement.
- Iowan Old Style and Avenir Next, with system fallbacks.

## 16. Roadmap

### Rotating footer taglines

**Status:** Future consideration; version one uses one fixed tagline.

**Intent:** Let the idle-state footer surface a curated set of calm,
non-gamified lines without turning the timer into a marketing surface.

Approved direction:

- `Enjoy the rhythm of focused time.`
- `Find your focus rhythm.`
- `Settle into your focus rhythm.`
- `Just time, your rhythm.`

Guardrails if this work is promoted:

- Rotate at most once per app launch, and never while the popover is open.
- Use no animation or attention-grabbing transition.
- Keep each line short enough to remain on one line at the current footer size.
- Keep the copy non-judgmental and free of tasks, scores, streak pressure, or
  implicit productivity ratings.
- Rotation is local-only and requires no network access or account data.
- Allow the feature to be disabled, falling back to the current fixed tagline.

Possible increment: choose deterministically from a bundled copy list once per
app launch.

### Project and task tracking

**Status:** Future consideration; explicitly excluded from version one.

**Intent:** Let users who want more context associate an interval with a
project or task and optionally review what their time was spent on.

This remains a separate, opt-in extension of the timer. It must not change the
default experience or make the simple timer feel incomplete.

Guardrails if this work is promoted:

- The timer must remain fully usable with no project or task selected.
- Project/task tracking is off by default and enabled as a deliberate choice.
- Starting a timer must never require naming a task or choosing a project.
- Keep the model lightweight at first: a task title and an optional project.
- Avoid subprojects, dependencies, estimates, recurring tasks, and complex
  status systems until the simpler layer proves useful.
- Keep any active queue short and subordinate to the timer.
- Do not introduce scores, streak pressure, productivity ratings, or a
  dashboard.
- Preserve the same quiet visual language and local-only privacy model.
- Existing intervals and preferences must continue to work when the feature is
  disabled.

Possible increments:

1. Optional task attached to the current interval.
2. Lightweight project list with tasks assigned to projects.
3. Optional review of completed tasks and recent intervals.

## 17. Open item

The final product name is still provisional. `Pomodoro` is the working name for
the project, bundle, and documentation. Renaming it later should not change the
product behavior.
