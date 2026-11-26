# Pomodoro Development Guide

This file contains durable instructions for AI coding agents working in this
repository. Keep it focused on how to develop and verify this project. Put
user-facing documentation in `README.md` and detailed workflow notes in
`DEVELOP.md`.

## Project overview

Pomodoro is a native macOS 15+ menu-bar focus timer built with Swift 6 and
SwiftPM. The app has no Dock presence and is composed of two main targets:

- `Sources/PomodoroCore`: UI-independent timer state, timer behavior, and
  persistence.
- `Sources/Pomodoro`: the AppKit/SwiftUI application shell, menu-bar
  integration, timer orchestration, notifications, sounds, themes, and Sparkle
  updates.
- `Tests/PomodoroCoreTests`: deterministic XCTest coverage for the core.
- `Tests/PomodoroTests`: app-language resolution and language-preference tests.
- `Resources`: bundle metadata, entitlements, and the app icon.
- `scripts`: local build, packaging, versioning, icon, and appcast helpers.
- `docs/superpowers/specs`: product and design specifications. Read the
  relevant spec before changing an existing designed flow.

There is no checked-in Xcode project. Add Swift files to the appropriate
SwiftPM target and let SwiftPM discover them.

## Requirements

- macOS 15 or later
- Xcode 16 or later with the Swift 6 toolchain
- Network access for the initial dependency resolution

Commands are intended to run from the repository root.

## Common commands

```sh
# Run all tests
swift test

# Build without creating the app bundle
swift build

# Resolve dependencies after changing Package.swift
swift package resolve

# Build and validate a locally signed debug app bundle
./scripts/build-app.sh debug
open build/Pomodoro.app

# Build an optimized local app
./scripts/build-app.sh release

# Test release packaging, including the universal build
UNIVERSAL=1 ./scripts/package-dmg.sh
```

Use `./scripts/build-app.sh` rather than hand-assembling or modifying an app
bundle. The script copies resources and Sparkle, repairs runtime paths, signs
nested components in the required order, and verifies entitlements.

## Architecture and invariants

### Timer core

- `TimerEngine` is the source of truth for timer behavior. Keep it free of
  AppKit, SwiftUI, notifications, sounds, and persistence side effects.
- Timing is based on an absolute `endDate` and an injectable `now` closure.
  Do not replace it with a counter that decrements on every UI tick.
- The app ticker should call `refresh()` and reconcile restored, sleeping, or
  woken state rather than independently calculating remaining time.
- Preserve the rhythm rules: every Focus interval advances the four-focus
  cycle, including one ended early; the fourth Focus interval recommends a long
  break. Keep "counts toward the cycle" distinct from "completed naturally" so
  the completion UI and any future completion count are not fabricated for an
  early-ended Focus.
- New timer behavior needs deterministic tests using `TestClock`. Do not use
  wall-clock sleeps or depend on the real current time in tests.

### App layer

- `TimerModel` is the `@MainActor` bridge between `TimerEngine`, `StateStore`,
  platform services, and SwiftUI. Route UI actions through it and publish
  committed engine state as immutable snapshots.
- Keep platform integration in its existing ownership areas: app lifecycle and
  menu-bar shell in `App/`, notifications and sound in `Services/`, features in
  `Features/`, and shared design tokens/components in `DesignSystem/`.
- The app is menu-bar-only (`LSUIElement`). Do not add a normal Dock/window
  lifecycle unless the task explicitly requires it.
- Preserve sleep/wake handling, notification cancellation/rescheduling, and
  energy-conscious ticking.

### Persistence

- `StateStore` writes ISO 8601 JSON atomically to the app sandbox's
  `~/Library/Containers/com.hb.pomodoro/Data/Library/Application Support/Pomodoro/state.json`.
- Decoding intentionally supplies defaults for missing fields so older state
  files remain readable. Preserve that backward-compatibility behavior.
- Corrupt state must continue to be backed up and recovered from rather than
  overwritten silently.
- Tests must use temporary directories and clean them up.

### UI

- Centralize colors and typography through `Palette`, `Typo`, and the shared
  components in `Theme.swift`. Avoid introducing unrelated one-off colors or
  fonts.
- Verify changes in both Light and Black themes and with reduced transparency.
- The app supports these launch arguments for focused UI checks:
  `--open-popover`, `--open-settings`, `--force-light`, `--force-dark`, and
  `--idle-mode=focus|short|long`.
- Quit Pomodoro and wait for the process to exit before launching with
  arguments. `open` treats an already-running app as an activation and silently
  drops `--args`, so a stale instance shows the previous theme or language.
- Runtime language is switchable in Settings. Use `L10n` for runtime copy
  instead of SwiftUI `Text("key")` literals so the interface updates without a
  relaunch; keep `Typo` language-aware and refresh menus, status-item copy, and
  pending notifications when the preference changes.
- Treat the timer card as fixed at 340×510 points (2:3). Settings uses the
  same 340-point width and a content-measured height; do not change either
  dimension without an explicit product decision.
- Switching languages must not move non-text elements. On the timer, the title
  slot, dial, mode/status row, buttons and footer keep their geometry; reserve
  the title's full line height and prefer shorter Japanese copy over shrinking
  type. In Settings, text may wrap and the card height may change, but section
  hairlines, toggles, the language picker and footer controls keep their
  horizontal slots. Check all six languages side by side.
- There are no UI snapshot tests. For visual changes, build the app, launch it,
  and inspect the affected states in both themes.
- Check the Settings card for overflow after every change to its content or
  layout, not only before a release. The card is 340 points wide, is 592 points
  at its shortest, and grows to the measured content plus footer, so a new row,
  a longer translation, or a notification-state line must never push the last
  row or the footer into a scrollbar. Open Settings in all six languages, with
  notifications allowed and denied, in both themes, and confirm the footer is
  visible without a scroll indicator; a scrollbar here is a bug, not a fallback.
- Do not regenerate the README screenshots with each UI change. Refresh
  `docs/assets/readme` only when preparing a release, and tell the user the
  screenshots are stale instead of updating them mid-cycle.
- Do not touch the README hero copy (the centered title block) unless the task
  explicitly asks for it. Never add usage or Settings instructions to the
  tagline; keep it to what the app is plus the focus-rhythm line. Leave
  `README.md` unchanged for UI or feature work the user did not ask to document.

## Dependencies and platform services

- Sparkle is pinned to exactly `2.10.1`. Keep the exact dependency and commit
  the matching `Package.resolved` whenever dependency resolution changes.
- Do not change Sparkle's feed URL behavior, EdDSA key handling, or the
  required `appcast.xml` asset name without updating the release workflow and
  documentation together.
- Never print, copy into the repository, or commit a Sparkle private key.
  Debug bundles intentionally omit `SUFeedURL` and `SUPublicEDKey`; release
  bundles require both.
- Avoid adding dependencies for small utilities. If a dependency is necessary,
  explain why, update `Package.resolved` through SwiftPM, and document any
  release or signing impact.

## Testing and completion checks

- Run `swift test` before claiming a code change is complete.
- Add or update tests in `Tests/PomodoroCoreTests` for changes to timer,
  rhythm, persistence, or recovery behavior.
- Run `./scripts/build-app.sh debug` for app-level or UI changes. This also
  checks signing and required entitlements.
- Do not describe a visual change as verified unless the built app was
  launched and inspected.
- `docs/development/testing.md` is the coverage checklist for releases. Every
  feature or bug fix must add or update its checklist entry before the change
  is complete, and keep that entry while the behavior exists. Run the full
  checklist only when preparing a release; routine changes still require
  `swift test` and targeted
  verification for the affected area.
- Keep unrelated test or build failures separate from the current change
  rather than fixing them incidentally.

## Versions, generated files, and releases

- Before any version bump, tag, publication, or release-repair request, read
  and follow `docs/development/release-runbook.md` in full.
- Normal feature and bug-fix work should not change
  `CFBundleShortVersionString` or `CFBundleVersion` in `Resources/Info.plist`.
- Use `scripts/bump-version.sh` for release version changes. A release tag must
  be exactly `v` plus the `CFBundleShortVersionString`.
- Before creating a release tag, complete the pre-tag checks in
  `docs/development/testing.md`.
  After publishing, complete the artifact checks in the same file.
- Releases are tag-driven through `.github/workflows/release.yml`. Do not
  create or push a release tag unless explicitly requested.
- Do not edit or commit generated output in `.build/`, `build/`, or `dist/`.
- Do not hand-edit `Package.resolved`; regenerate it with SwiftPM.
- Update `DEVELOP.md` when commands, tooling, signing, or release behavior
  changes. Update `README.md` for user-visible installation or product changes.

## Change discipline

- Make the smallest coherent change that solves the requested problem and
  follow the surrounding Swift style.
- New user-facing copy must use a semantic key in
  `Resources/Localization/Localizable.xcstrings` and include English,
  Simplified Chinese, Traditional Chinese, Japanese, Vietnamese, and Korean
  values (`en`, `zh-Hans`, `zh-Hant`, `ja`, `vi`, `ko`). Info.plist copy
  belongs in `InfoPlist.xcstrings`. Resolve runtime copy through `L10n` so the
  in-app language picker updates immediately. Do not hardcode English UI copy,
  use `Bundle.module`, or add a locale-specific code path. Run
  `./scripts/build-app.sh debug` so the catalog validator and resource
  installation both run.
- Preserve existing accessibility, appearance, notification, persistence, and
  update behavior unless the task explicitly changes them.
- Do not commit, push, tag, or publish unless explicitly requested.
