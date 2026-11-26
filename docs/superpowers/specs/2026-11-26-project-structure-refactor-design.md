# Pomodoro Project Structure Refactor Design

Status: proposed for product-owner approval
Owner: Lebron James
Date: 2026-11-26
Branch: `codex/standard-project-layout`
Parent commit: `bb5421d` (`codex/docs-reorg`)

## Intent

Make the repository easier for a new human contributor to navigate by adopting
an industry-standard SwiftPM layout: app lifecycle in `App/`, user-visible
capabilities in `Features/`, shared visual primitives in `DesignSystem/`,
system integrations in `Services/`, and deterministic domain behavior in
`PomodoroCore`.

The attached diagram is a generic document-style SwiftUI application. Pomodoro
is a menu-bar-only AppKit/SwiftUI application with a separate UI-independent
core and a custom app-bundle build script. The target layout therefore adapts
the diagram's boundaries rather than copying its sample files, scenes, or
`Stats` feature.

## Goals

- Make the responsibility of each top-level source directory obvious.
- Colocate a feature's model and views.
- Keep `TimerEngine` free of AppKit, SwiftUI, notifications, sound, and
  persistence side effects.
- Keep shared colors, typography, and visual primitives in one predictable
  place.
- Keep packaging-only resources and custom build steps explicit.
- Mirror source domains under `Tests/` where it improves discovery.
- Preserve behavior, public core APIs, localization, accessibility, themes,
  notifications, persistence compatibility, and release tooling.

## Non-goals

- No user-visible behavior, copy, timing, layout, animation, or update changes.
- No new features, including a `Stats` feature.
- No new dependencies or SwiftPM products.
- No version bump, tag, release, or README hero change.
- No migration to `WindowGroup`, `MenuBarExtra`, `@Observable`, or a normal
  Dock/window lifecycle.
- No moving `Resources/` into the executable target: the custom packaging
  script assembles the bundle and the project intentionally avoids
  `Bundle.module`.
- No broad rewrite of `TimerEngine` algorithms or state-machine behavior.

## Approaches Considered

### A. Directory-only move

Move files into feature folders without splitting large files.

- Lowest risk and fastest to review.
- Fixes navigation, but leaves 700-line feature files as a discoverability and
  review bottleneck.

### B. Adapted standard layout plus safe file splits

Adopt feature-oriented folders and split only at existing responsibility seams:
independent SwiftUI views, design tokens, and core value types.

- Keeps behavior unchanged while materially improving discoverability.
- Requires import-free moves in one module and careful extraction of private
  view helpers, but no intended logic changes.
- Recommended.

### C. Multiple SwiftPM modules

Split the app into `PomodoroApp`, `PomodoroUI`, `PomodoroServices`, and
`PomodoroCore` targets.

- Enforces boundaries at compile time.
- Significantly increases `Package.swift`, access-control, test, and packaging
  churn for a small app; not justified now.

## Chosen Approach

Approach B: adapted standard layout plus safe file splits.

Phase 1 is mechanical relocation only. Phase 2 extracts independent types and
views without changing behavior. Phase 3 updates contributor documentation and
verification references. Each phase must build and test independently.

## Target Source Layout

```text
Sources/
  Pomodoro/
    App/
      PomodoroMain.swift
      AppDelegate.swift
      AppCoordinator.swift
      Popover/
        PopoverController.swift
        PopoverRootView.swift
      StatusBar/
        StatusItemController.swift
        MenuBarIcon.swift
    Features/
      Timer/
        TimerModel.swift
        Views/
          TimerPopoverView.swift
          CompletionPopoverView.swift
          DialView.swift
          AmbientLight.swift
      Settings/
        SettingsView.swift
        Components/
          DurationColumn.swift
          DurationStepButton.swift
      Updates/
        UpdateController.swift
        UpdatePanel.swift
        UpdateDot.swift
    DesignSystem/
      Theme/
        Palette.swift
        Typography.swift
        ModeColors.swift
        Appearance.swift
      Components/
        AppIconMark.swift
        ButtonStyles.swift
        MiniDial.swift
        ErrorNote.swift
        PopoverHeader.swift
        Backgrounds.swift
    Services/
      NotificationService.swift
      SoundPlayer.swift
    Localization/
      AppLanguage.swift
      LanguagePreference.swift
      L10n.swift
  PomodoroCore/
    Timer/
      Phase.swift
      RunState.swift
      IntervalDurations.swift
      TimerState.swift
      TimerEngine.swift
      TimerEndTransition.swift
    Persistence/
      PersistedState.swift
      StateStore.swift
      StateRecoveryIssue.swift
Tests/
  PomodoroCoreTests/
    Timer/
      TimerEngineTests.swift
    Persistence/
      PersistenceTests.swift
  PomodoroTests/
    Localization/
      AppLanguageTests.swift
      LanguagePreferenceTests.swift
Resources/
  ...unchanged; packaging metadata, entitlements, icons, localization catalogs
```

`PopoverRootView` is the navigation shell shared by Timer and Settings, so it
stays with `PopoverController` under `App/Popover/`. `TimerModel` remains the
single app-layer bridge, but lives with the Timer feature it primarily serves.

## File Mapping

| Current | Target |
| --- | --- |
| `Sources/Pomodoro/PomodoroMain.swift` | `Sources/Pomodoro/App/PomodoroMain.swift` |
| `Sources/Pomodoro/App/AppDelegate.swift` | `Sources/Pomodoro/App/AppDelegate.swift` |
| `Sources/Pomodoro/App/AppCoordinator.swift` | `Sources/Pomodoro/App/AppCoordinator.swift` |
| `Sources/Pomodoro/App/PopoverController.swift` | `Sources/Pomodoro/App/Popover/PopoverController.swift` |
| `Sources/Pomodoro/App/StatusItemController.swift` | `Sources/Pomodoro/App/StatusBar/StatusItemController.swift` |
| `Sources/Pomodoro/App/MenuBarIcon.swift` | `Sources/Pomodoro/App/StatusBar/MenuBarIcon.swift` |
| `Sources/Pomodoro/App/UpdateController.swift` | `Sources/Pomodoro/Features/Updates/UpdateController.swift` |
| `Sources/Pomodoro/Model/TimerModel.swift` | `Sources/Pomodoro/Features/Timer/TimerModel.swift` |
| `Sources/Pomodoro/Localization.swift` | split under `Sources/Pomodoro/Localization/` |
| `Sources/Pomodoro/Views/PopoverViews.swift` | shell view under `App/Popover/`; timer/completion views under `Features/Timer/Views/` |
| `Sources/Pomodoro/Views/DialView.swift` | `Sources/Pomodoro/Features/Timer/Views/DialView.swift` |
| `Sources/Pomodoro/Views/AmbientLight.swift` | `Sources/Pomodoro/Features/Timer/Views/AmbientLight.swift` |
| `Sources/Pomodoro/Views/SettingsView.swift` | `Sources/Pomodoro/Features/Settings/SettingsView.swift` |
| `Sources/Pomodoro/Views/UpdatePanel.swift` | split under `Sources/Pomodoro/Features/Updates/` |
| `Sources/Pomodoro/Views/Theme.swift` | split under `Sources/Pomodoro/DesignSystem/Theme/` |
| `Sources/Pomodoro/Views/Components.swift` | split under `Sources/Pomodoro/DesignSystem/Components/` |
| `Sources/Pomodoro/Services/*.swift` | `Sources/Pomodoro/Services/*.swift` |
| `Sources/PomodoroCore/IntervalDurations.swift` | `Sources/PomodoroCore/Timer/IntervalDurations.swift` |
| `Sources/PomodoroCore/TimerState.swift` | split under `Sources/PomodoroCore/Timer/` |
| `Sources/PomodoroCore/Persistence.swift` | split under `Sources/PomodoroCore/Persistence/` |
| `Tests/PomodoroCoreTests/TimerEngineTests.swift` | split into `Tests/PomodoroCoreTests/Timer/` and `Tests/PomodoroCoreTests/Persistence/` |
| `Tests/PomodoroTests/AppLanguageTests.swift` | `Tests/PomodoroTests/Localization/AppLanguageTests.swift` |
| `Tests/PomodoroTests/LanguagePreferenceTests.swift` | `Tests/PomodoroTests/Localization/LanguagePreferenceTests.swift` |

## Ownership and Work Split

- JB: `PomodoroCore` value-type splits, test mirrors, `TimerModel` relocation.
- VJ: Timer/Settings/Updates feature views, `DesignSystem`, visual regression
  inspection.
- Maxey: `App`, `Services`, `Localization`, contributor docs, build/CI path
  audit, packaging verification.
- Lebron: interface decisions, review, `swift test`, debug app build, Light /
  Black and six-language UI verification, final merge decision.

No two owners edit the same file within one phase. `Resources/` remains owned by
Maxey for path-audit purposes but is not moved.

## Constraints

- SwiftPM discovers nested source files automatically; `Package.swift` target
  paths do not need to change.
- File moves within the `Pomodoro` or `PomodoroCore` module must not add or
  alter imports.
- Splits must preserve symbol names, signatures, and access levels.
- `Resources/`, `scripts/build-app.sh`, entitlements, Info.plist, localization
  catalogs, Sparkle, and appcast behavior remain unchanged except for stale
  documentation references.
- The refactor branch stays stacked on `codex/docs-reorg` until that commit is
  reviewed or merged; delivery will name the final base explicitly.

## Verification

Every implementation phase must pass:

1. `swift test`
2. `./scripts/build-app.sh debug`
3. `git diff --check`
4. Path scan for stale source references in docs and scripts
5. UI launch and inspection in Light and Black themes
6. Settings open in all six languages with notification allowed and denied;
   footer visible without a scroll indicator

For pure moves, test counts remain 51 core tests plus 7 app tests. For splits,
test names and counts remain unchanged unless a test file is moved only.

## Rollback

The refactor is structural and commits are grouped by ownership/phase. Rollback
is `git revert` of the phase commits or reset of the unmerged branch to its
parent; no remote history or release asset changes.

## Open Decision

Approve Approach B, or explicitly request Approach A (moves only) or Approach C
(multi-target modules). No product code changes start before this decision.
