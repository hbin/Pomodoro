# Pomodoro for macOS

**Product design specification**

- Status: Implemented (v1); later features are specified separately
- Date: 2026-11-21
- Working name: Pomodoro
- Platform: macOS 15+
- Delivery: Local builds and GitHub Releases with Sparkle updates

Later changes amend this spec: see
`2026-11-22-minimal-update-indicator.md`,
`2026-11-23-four-language-localization.md`,
`2026-11-23-in-app-language-picker.md`,
`2026-11-24-guided-next-step-design.md`,
`2026-11-24-auto-start-break-design.md`,
`2026-11-24-auto-start-pomodoro-design.md`,
`2026-11-24-configurable-durations-design.md`,
`2026-11-24-session-dial-design.md`, and
`2026-11-24-pause-end-control-design.md`. Statements below about local-only
delivery and no network requests describe the original v1 scope. Statements
that fix the focus, short-break, or long-break length at 25, 5, or 15 minutes
are superseded by configurable interval durations. §9.4, §9.5, and the Builder
calls are updated to the session dial described in the session-dial design.

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
- Automatic focus/break countdown cycles, except for the Auto-start break and
  Auto-start focus settings.
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

The app may move the completion screen to the next break or focus step. It
starts an interval automatically only when the corresponding Auto-start setting
is enabled. Auto-start break and Auto-start focus are both off by default
and can be enabled independently.

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
- A primary button labelled `Start`; the selected mode and duration remain
  visible in the mode selector and dial.
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
- The same primary button position, switched to `Pause`.
- A quiet end-interval action, shown only while the interval is running, that
  ends focus or break immediately without confirmation, then advances to the
  next interval in the Pomodoro cycle. Its fixed geometry and styling are
  specified in the pause/end control design.
- A quiet `Ends at…` line based on the current expected finish time.

The primary has exactly two visible labels across Focus, Short break, Long
break, and completion: `Start` while idle, paused, or ready to begin the
offered interval, and `Pause` while running. The mode and duration are carried
by the surrounding title, dial, and status line rather than repeated in the
button.

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
- Ending early happens immediately without confirmation and advances to the
  next interval in the Pomodoro cycle.
- An early-ended focus counts toward the four-focus long-break rhythm but is
  not a natural completion; an early-ended break does not change that rhythm.
- If the next interval's Auto-start setting is on, its running screen appears
  immediately while the countdown holds at full for one second; otherwise the
  next interval waits on its ready screen.

### 7.6 Natural completion

When the focus interval reaches zero:

1. A short original chime plays if the completion chime is enabled.
2. One local notification appears if notifications are authorized and the app
   is not frontmost.
3. If the popover is visible, the completion state and chime replace the notification
   so the user is not alerted twice.
4. Unless Auto-start break is on, the popover moves automatically to the
   recommended break's ready screen.

The focus-completion ready screen contains:

- `Take a short break` or `Take a long break`.
- A dial at `05:00` or `15:00` with the `READY` caption and the break accent.
- `Focus complete. Ready for a break?`.
- A primary `Start` action that begins the offered break:
  - the 5-minute break normally;
  - the 15-minute break after the fourth focus interval in a cycle.
- A quiet `Done for now` action that returns to the idle state.

The break is part of the rhythm, so the completion state does not offer a
second focus. Starting one without a break is still possible by choosing
`Done for now` and pressing Start again; the app neither advertises nor blocks
that path.

No countdown starts until the user chooses, unless Settings → Focus →
Auto-start break is on. With that option on, the popover goes directly to the
running break screen; the break's end date includes the chime, so the countdown
stays at full until the chime finishes. The option is off by default. The focus
after a break is controlled independently by Auto-start focus, which is also
off by default.

No task completion is recorded or requested.

### 7.7 Breaks

- Short break: 5 minutes.
- Long break: 15 minutes.
- A long break follows every fourth focus interval in the cycle, whether the
  focus interval completed naturally or was ended early.
- Ending a focus interval early advances the rhythm without counting as a
  natural completion.
- Skipping an offered long break resets the rhythm for the next group of four.
- The break state uses the same popover with a calmer sage/brass
  treatment.
- Break copy is supportive and non-judgmental, for example `Step away` and
  `Break`.
- The user may end or skip a break early.
- The next focus does not start automatically by default. Auto-start focus
  can start it after the break chime; it is off by default.
- When a break reaches zero, the popover moves automatically to the focus
  ready screen:
  - `Ready to focus`;
  - a `25:00` dial with the `READY` caption;
  - `Break complete. Ready for another focus?`;
  - a primary `Start` action;
  - a quiet `Done for now` action.
- No countdown starts until the user chooses.
- Break sessions are not stored.

### 7.8 Settings

Settings stays intentionally small:

- Opens inside the menu-bar popover. A back control in the title row returns
  to the timer while leaving the popover open.
- Shares the timer card's 340-point width. Its height follows its content
  (592-point minimum, 760-point maximum) and may change with language or new
  rows; the width never changes.
- Completion chime on/off.
- Tick sound on/off; default off.
- Auto-start break on/off; default off. When on, a completed focus goes directly
  to the running break; the break's end date includes the chime, so the
  countdown stays at full until the chime finishes.
- Auto-start focus on/off; default off. When on, a completed break goes
  directly to the running focus; the focus's end date includes the break chime,
  so the countdown stays at full until the chime finishes.
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
- Primary control returns to `Start`.
- Clicking elsewhere in the popover does not resume accidentally.

### Focus complete

- Popover automatically shows the recommended break ready to start.
- `Done for now` is the only other action.
- Nothing counts down until the user chooses, unless Auto-start break is on, in
  which case the running break screen appears immediately and its countdown
  begins when the chime finishes. This ready state is skipped.

### Break running

- Calmer color treatment.
- No focus language.
- Skip/end remains available.
- Menu bar shows the break countdown.

### Break complete

- While Auto-start focus is off, the popover shows the next focus ready to
  start, with `Start` and `Done for now`.
- With Auto-start focus on, the running focus screen appears immediately and
  the countdown holds at full until the break chime finishes. This ready state
  is skipped.
- Nothing counts down until the user chooses unless Auto-start focus is on.

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
- Thin brass outer and inner edges around an empty recessed bezel channel.
- Slightly inset paper surface with restrained texture.
- Mode-colored dial accents and live-interval controls: brick Focus, leaf Short
  break, and deep sage Long break.
- Dark warm ink for typography and controls.
- Rounded rectangular body rather than a literal tomato or mascot.

The material treatment should be believable but restrained. Avoid ornamental
parts that reduce clarity.

**Fixed card geometry (product requirement).**

- The timer card is **340×510 points (2:3)**. Do not change either dimension,
  including for a translation, without an explicit product decision.
- Settings uses the **same 340-point width** and a content-measured height
  (592–760 points). Settings height may grow or shrink with language and
  settings content; its width must not.
- The panel may change height between the timer and Settings. Its horizontal
  center stays anchored across that change.

**Language-stable layout (product requirement).**

- Switching the interface language changes copy only. Icons, buttons, the dial,
  dots, toggles, pickers, separators and other non-text elements keep their
  frames, positions, sizes and alignment.
- On the timer, the title slot, dial row, mode/status row, primary/end
  controls and footer keep fixed geometry. The title slot reserves its full
  line height so a translated or scaled title cannot move the dial. Prefer
  shorter Japanese copy over shrinking the type.
- In Settings, text may wrap and the card may grow or shrink vertically, but
  horizontal geometry stays fixed. Section hairlines span the same content
  width at the same leading and trailing insets in every language; they are
  never sized to the label text. Leading copy, trailing toggles, the language
  picker and footer controls keep their slots.
- Check all four languages side by side. Any non-text movement between
  languages is a bug, not an acceptable layout adaptation.

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
- Mode accents: Focus deep tomato `#A53D2E`; Short break deep sage
  `#5F6B52`; Long break deeper sage `#4E5A43`.
- Primary fills: Focus `#B84A37 → #A53D2E`; Short break
  `#7FA160 → #789A58`; Long break `#5F6B52 → #4E5A43`. Labels are cream
  on Focus and Long break, ink on Short break.

Dark mode:

- Espresso and charcoal surfaces replace the bone field.
- Cream text replaces ink.
- Tomato, brass, leaf, and deep sage remain recognizable; the mode fills use
  the Black values in the three-mode color system.
- Contrast is maintained without turning the popover into a glowing object.

The primary action uses the active mode fill in every state: Start, Pause, and
completion. Only the label and play/pause glyph change; there is no
second ink-key or rail treatment. Mode remains explicit through the channel arc,
the mode dots, the mode label, and the running caption. Each fill is tuned for
a legible label rather than reusing one constant action color.

### 9.3 Typography

- Interface copy: Avenir Next or the system sans-serif.
- Countdown digits: a monospaced or tabular system face for stable width.
- Short status copy may use a warm serif when it improves the instrument
  character.
- Small labels use restrained uppercase letter spacing.

No task-title typography is required.

### 9.4 Dial

The dial is a session gauge on a clock-like face:

- There is no hand or visible pivot. One full revolution is the selected
  interval, not an hour.
- An empty recessed channel between thin brass outer and inner edges carries
  the remaining fraction of the interval. It is empty at idle; starting an
  interval sweeps the mode-colored arc clockwise to full in 0.3 seconds, then it
  drains counterclockwise to empty.
- The arc has square ends and no glow; it reads as an inlay in the channel
  rather than a drawn highlight.
- At idle the plaque shows the selected duration with `READY`.
- While paused the arc freezes at the current fraction. At completion it is
  empty; the completion screen shows the offered duration in the readout.
- The 60 chapter marks are fixed divisions, not minutes; all remain visible,
  and only the 12, 3, 6, and 9 o'clock marks are larger. The central readout is
  authoritative.
- The central plaque shows `MM:SS` and a caption: `READY` at idle or
  completion, or `FOCUS` / `SHORT BREAK` / `LONG BREAK` while running or paused.
- The plaque is a raised disc with a hairline brass edge.
- The channel arc uses the mode accent: brick for Focus, deep sage for Short
  break, and deeper sage for Long break.
- The brass pivot appears only in the app and menu-bar icons.
- The dial remains legible at the popover's supported size.

Break intervals use the same geometry with their mode accent.

The menu-bar icon is a session gauge rather than a clock: its arc starts full
and empties counterclockwise as the interval runs, with the hand riding the
emptying edge. The popover ring uses the same session fraction without a hand;
both surfaces are full at the start and empty at the end.

### 9.5 Motion

- The ring drains smoothly enough to feel mechanical without continuous
  high-frame-rate rendering.
- Starting an interval sweeps the ring from empty to full clockwise over 0.3
  seconds, then it begins draining counterclockwise.
- State changes use a short settle rather than a bounce.
- Changing the idle duration slides the readout toward the side the incoming
  mode sits on, clipped by the plaque; the empty ring does not move.
- Completion uses one calm transition of the face and readout.
- No looping pulses, confetti, shaking, or attention-seeking effects.
- Reduce Motion replaces interpolation and transitions with direct state
  changes.

### 9.6 Sound

- A short, original two-note chime for natural completion, in two related
  variants: a rising phrase for focus and a lower, descending mirror for break.
- Both variants share the warm, soft, wood or marimba-like character.
- Each variant is under one second and plays once.
- Optional ticking: a quiet, mechanical tick once per second while a focus
  interval is actively running.
- Tick sound is off by default and is independent of the completion chime.
- Tick sound stops on pause, end, completion, or lost active timer state.
- Tick sound never plays during breaks; the completion chime still plays when a
  break ends.
- Tick volume should sit below the completion chime and should be comfortable
  for long sessions.
- The tick must be generated from the timer's second boundary and must not
  double-play after sleep or wake.
- No sound on every button press.
- The single Completion chime switch mutes both phase variants; Settings can
  mute the chime and tick sound independently.
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
- An auto-started break posts the break-start announcement without repeating
  the focus-complete announcement.
- An auto-started focus posts the focus-start announcement without repeating
  the break-complete announcement.
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
- Changing the language keeps non-text controls and focus order stable; only
  copy and the content-measured Settings height may change.

## 11. Data and persistence

### Stored state

The app stores only what the timer needs:

- Selected focus duration.
- Current phase: focus, short break, or long break.
- Absolute end timestamp while running.
- Remaining duration while paused.
- Focus-cycle position for the long-break rhythm, including early-ended Focus
  intervals; natural completion remains a separate state.
- Completion chime, tick sound, auto-start break, auto-start focus, and
  menu-bar display preferences.
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

### Layout stability

- The timer card is 340×510 (2:3), and Settings uses the same 340-point width
  with a content-measured height.
- Switching languages changes only copy: no dial, button, icon, toggle, picker
  or separator moves. Settings section hairlines keep identical horizontal
  insets in every language.

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
- Ending early is immediate and advances to the next interval. An early-ended
  focus counts toward the four-focus long-break rhythm but is not a natural
  completion; an early-ended break does not change that rhythm.

### Completion and breaks

- Natural completion plays its phase's chime once when enabled: the rising
  phrase after focus and the lower descending mirror after break.
- The single Completion chime switch mutes both phase variants.
- A notification appears once when authorized and appropriate.
- With Auto-start break off, focus completion automatically shows the
  recommended break's duration and a Start action without a second modal.
- With Auto-start break on, focus completion goes directly to the running break
  screen; the break's end date includes the chime, so the countdown holds at
  full until the chime finishes. With the chime off, it starts immediately.
- Auto-start break defaults off, survives relaunch, and older state files
  without the field load as off; an explicit on choice is preserved.
- Auto-start break does not start the next focus; Auto-start focus is the
  separate setting for that transition.
- Auto-start focus defaults off, survives relaunch, and older state files
  without the field load as off; an explicit on choice is preserved.
- With Auto-start focus on, break completion goes directly to the running
  focus screen; the focus's end date includes the break chime, so the countdown
  holds at full until the chime finishes. With the chime off, it starts
  immediately.
- Auto-start focus does not start a break.
- Ending focus early moves to the recommended break ready to start when
  Auto-start break is off, or to the running break when it is on. The
  auto-started break holds its countdown at full for one second first.
- Ending a break early moves to the next focus ready to start when Auto-start
  focus is off, or to the running focus when it is on. The auto-started focus
  holds its countdown at full for one second first.
- An expired focus restored at launch shows the break-ready screen instead of
  starting retroactively; an expired break restored at launch shows the
  focus-ready screen.
- The long-break recommendation follows every fourth focus interval in the
  cycle, including one ended early.
- No countdown starts automatically unless the corresponding Auto-start setting
  is enabled.
- While Auto-start focus is off, break completion shows the next focus ready
  to start; `Done for now` remains the idle path. With it on, the running focus
  appears immediately.
- The completion dial shows the next interval's duration with `READY`, not
  `00:00` with `COMPLETE`.

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
- Long break after every four Focus intervals, including one ended early.
- Guided transitions that present the next interval without starting it,
  except the Auto-start break and Auto-start focus settings.
- Auto-start break off by default; it starts only the recommended break after
  focus.
- Auto-start focus off by default; it starts only the focus after a break.
- Quiet analog visual direction.
- Chime plus notification.
- Optional tick sound, off by default.
- Native SwiftUI plus AppKit.
- Manual launch only.
- Menu-bar access only; no global shortcut.

### Builder calls

- Versioned JSON state rather than a database.
- A full-circle session gauge in both surfaces: the popover uses the ring and
  digital readout, and the menu-bar icon keeps its compact hand.
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

### Multiple completion sound schemes

**Status:** Future consideration; the phase-aware Focus/Break pair ships with
one pass. Repetition and alternative sound sets remain future work.

**Intent:** If real use shows that one pass is missed, or users want a different
character, add a two-pass variant and a small curated set of completion sound
schemes. Decide after real user feedback; do not add sound settings
speculatively.

Current baseline:

- Focus completion: rising two-note phrase.
- Break completion: descending mirror of the same two notes, slightly lower and
  shorter.
- Both play once and share the Completion chime switch.

Guardrails if this work is promoted:

- A repeat must be at most two passes, with the second pass softer; the pair
  must read as one gesture, not an alarm.
- Keep both variants under roughly 2.5 seconds.
- Keep the existing Completion chime switch as the only sound control until
  users ask for more; do not add per-phase toggles or a sound picker first.
- Preserve the quiet instrument character: no alarm-style variation, no sound
  on every button press, and no custom audio import.
- Sound remains optional and never the only signal; keep the visual ready
  screens, notifications, and accessibility announcements.
- Evaluate with real users before choosing a repeat count or adding alternative
  sound sets.
- Keep any alternative sound sets local and bundled; no network or account data.

Possible increments:

1. A two-pass variant if users report missing the single chime.
2. A small curated set of completion sound schemes in Settings, only if the
   first increment proves useful.

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

### Global start/pause hotkey

**Status:** Future consideration; not implemented and not scheduled for a release.

**Intent:** Let a person start or pause the current interval from anywhere without
opening the popover or moving the pointer to the menu bar.

Agreed direction:

- The hotkey performs the same state-dependent action as the primary button:
  start when idle, pause while running, resume while paused, and start the
  offered interval on the completion screen. The idle-mode choice and its
  wording are settled in the feature's own specification.
- It does not open the popover. The menu bar's dial, minutes, and accessibility
  announcements remain the feedback surface; no HUD, notification, or new
  window is added.
- It is opt-in and configurable. A registration conflict must be visible in
  Settings rather than silently disabling the shortcut.
- Use a system-wide hotkey that does not require Accessibility or Input
  Monitoring permission, and do not add a dependency for it.
- A menu item's key equivalent is app-local and must not be presented as the
  global shortcut. Show the real shortcut in Settings; the status menu may
  carry an action item as a secondary discovery path.
- The hotkey action must respect the current context: do not bypass a
  confirmation layer or act behind Settings.
- Adding the Settings row grows the card; recheck the measured height in all
  four languages and at the shortest supported screen size.

Guardrails if this work is promoted:

- Clicking the status item remains the primary entry and keeps the existing
  icon-anchored popover position.
- The hotkey must never move or resize an open popover.
- If a later hotkey opens the popover, its non-spatial position is a separate
  decision; it must not change the click-anchored behavior.
- The feature stays local: no accounts, network access, or telemetry.

## 17. Open item

The final product name is still provisional. `Pomodoro` is the working name for
the project, bundle, and documentation. Renaming it later should not change the
product behavior.
