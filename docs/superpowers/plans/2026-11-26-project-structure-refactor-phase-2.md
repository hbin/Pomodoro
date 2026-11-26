# Project Structure Refactor Phase 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split large Swift files at existing responsibility seams without changing behavior, symbol names, or public APIs.

**Architecture:** Keep the same SwiftPM targets and imports. Split multi-type files into focused files; promote a symbol from `private` to internal only when a sibling file must consume it. `TimerModel` stays intact because cross-file extensions would require exposing private coordination state.

**Tech Stack:** Swift 6, SwiftPM, AppKit, SwiftUI, XCTest.

**Spec:** `docs/superpowers/specs/2026-11-26-project-structure-refactor-design.md`

## Global Constraints

- No behavior, copy, timing, layout, animation, persistence-format, or API changes.
- No new dependencies, targets, products, resources, version changes, or release actions.
- Preserve test names and test counts: 51 core + 7 app.
- Use `git mv` where a file is renamed; split contents without formatting unrelated code.
- Work from `codex/standard-project-layout` at `5dcc559` in an isolated worktree.
- Do not edit another owner's files, push, or merge.
- Every author task ends with `swift test` and `./scripts/build-app.sh debug`; Task 4 is integration review + independent QA, not integrator execution.

## Review Focus

- Split files may lose required imports even though the module still compiles later.
- `private` view helpers used across new files must be promoted deliberately; no broad access relaxation.
- XCTest helpers must not be duplicated after splitting.
- SwiftUI declaration order can affect result-builder type-checking, not behavior; preserve view bodies.
- File moves must not change test discovery or localization resources.

---

### Task 1: Core and test file splits

**Owner:** JB

**Files:**
- Split: `Sources/PomodoroCore/Timer/TimerState.swift`
- Create: `Sources/PomodoroCore/Timer/Phase.swift`
- Create: `Sources/PomodoroCore/Timer/RunState.swift`
- Create: `Sources/PomodoroCore/Timer/TimerEvent.swift`
- Create: `Sources/PomodoroCore/Timer/TimerEngine.swift`
- Create: `Sources/PomodoroCore/Timer/TimerEndTransition.swift`
- Keep: `Sources/PomodoroCore/Timer/TimerState.swift` for `TimerState` only
- Split: `Sources/PomodoroCore/Persistence/Persistence.swift`
- Create: `Sources/PomodoroCore/Persistence/ThemePreference.swift`
- Create: `Sources/PomodoroCore/Persistence/PersistedState.swift`
- Create: `Sources/PomodoroCore/Persistence/LoadResult.swift`
- Keep: `Sources/PomodoroCore/Persistence/Persistence.swift` for `StateStore`
- Split: `Tests/PomodoroCoreTests/TimerEngineTests.swift`
- Create: `Tests/PomodoroCoreTests/TestSupport/TestClock.swift`
- Move/split: `Tests/PomodoroCoreTests/Timer/TimerEngineTests.swift`
- Move/split: `Tests/PomodoroCoreTests/Persistence/PersistenceTests.swift`

**Interfaces:**
- Consumes: existing public core types.
- Produces: identical public symbols and test names with no access-level changes.

- [ ] **Step 1: Split core value types**

Move declarations verbatim:

- `Phase` -> `Phase.swift`
- `RunState` -> `RunState.swift`
- `TimerEvent` -> `TimerEvent.swift`
- `TimerEngine` -> `TimerEngine.swift`
- `TimerEndTransition` -> `TimerEndTransition.swift`
- `ThemePreference` -> `ThemePreference.swift`
- `PersistedState` + private extension -> `PersistedState.swift`
- `StateRecoveryIssue` + `LoadResult` -> `LoadResult.swift`
- `StateStore` -> `Persistence.swift`

Add only the imports each file needs.

- [ ] **Step 2: Split tests**

Move `TestClock` to `TestSupport/TestClock.swift`; move `TimerEngineTests`
verbatim to `Timer/TimerEngineTests.swift`; move `PersistenceTests` verbatim to
`Persistence/PersistenceTests.swift`. Do not rename tests.

- [ ] **Step 3: Verify declarations**

Run: `rg -n '^(public )?(enum|struct|final class) (Phase|RunState|TimerState|TimerEvent|TimerEngine|TimerEndTransition|ThemePreference|PersistedState|StateRecoveryIssue|LoadResult|StateStore|TestClock|TimerEngineTests|PersistenceTests)\\b' Sources Tests`
Expected: exactly one declaration per symbol.

- [ ] **Step 4: Run tests and build**

Run: `swift test`
Expected: 58/58, 0 failures.

Run: `./scripts/build-app.sh debug`
Expected: exit 0.

- [ ] **Step 5: Commit**

```sh
git add Sources Tests
git commit -m "refactor(core): split value types and persistence tests"
```

### Task 2: UI and design-system file splits

**Owner:** VJ

**Files:**
- Split: `Sources/Pomodoro/Features/Settings/SettingsView.swift`
- Create: `Sources/Pomodoro/Features/Settings/Components/DurationControls.swift`
- Split: `Sources/Pomodoro/DesignSystem/Theme.swift`
- Create: `Sources/Pomodoro/DesignSystem/Theme/Appearance.swift`
- Create: `Sources/Pomodoro/DesignSystem/Theme/Palette.swift`
- Create: `Sources/Pomodoro/DesignSystem/Theme/Typography.swift`
- Create: `Sources/Pomodoro/DesignSystem/Theme/Surfaces.swift`
- Split: `Sources/Pomodoro/DesignSystem/Components.swift`
- Create: `Sources/Pomodoro/DesignSystem/Components/AppIconMark.swift`
- Create: `Sources/Pomodoro/DesignSystem/Components/ButtonStyles.swift`
- Create: `Sources/Pomodoro/DesignSystem/Components/MiniDial.swift`
- Create: `Sources/Pomodoro/DesignSystem/Components/Feedback.swift`
- Split: `Sources/Pomodoro/Features/Timer/Views/PopoverViews.swift`
- Create: `Sources/Pomodoro/App/Popover/PopoverRootView.swift`
- Create: `Sources/Pomodoro/Features/Timer/Views/ControlMetrics.swift`
- Create: `Sources/Pomodoro/Features/Timer/Views/TimerPopoverView.swift`
- Create: `Sources/Pomodoro/Features/Timer/Views/CompletionPopoverView.swift`
- Create: `Sources/Pomodoro/Features/Timer/Views/TimerControlStyles.swift`
- Split: `Sources/Pomodoro/Features/Updates/UpdatePanel.swift`
- Create: `Sources/Pomodoro/Features/Updates/UpdateDot.swift`
- Keep: `Sources/Pomodoro/Features/Updates/UpdatePanel.swift` for panel + private button style

**Interfaces:**
- Consumes: existing `Palette`, `Typo`, `ModeColors`, view models, and `PopoverRootView`.
- Produces: unchanged view names and render tree. Promote only cross-file helpers: `DurationColumn`, `ControlMetrics`, `PrimaryButtonLabel`.

- [ ] **Step 1: Split Settings**

Move `DurationColumn` and `DurationStepButton` verbatim to
`Features/Settings/Components/DurationControls.swift`. `DurationColumn` becomes
internal; `DurationStepButton` stays private.

- [ ] **Step 2: Split DesignSystem**

Move declarations verbatim:

- `LaunchAppearance` + `ThemePreference` extension -> `Theme/Appearance.swift`
- `ModeColors`, `Palette`, `Color` extension -> `Theme/Palette.swift`
- `Typo` -> `Theme/Typography.swift`
- `PaperGrain`, `SplitMix64`, `InstrumentFace`, `PopoverBackground`, `Hairline` -> `Theme/Surfaces.swift`
- `AppIconMark` -> `Components/AppIconMark.swift`
- four button styles -> `Components/ButtonStyles.swift`
- `MiniDial` -> `Components/MiniDial.swift`
- `ErrorNote`, `PopoverHeader` -> `Components/Feedback.swift`

Do not alter view bodies or style values.

- [ ] **Step 3: Split popover views**

Keep root-shell-only private metrics/overlay in `App/Popover/PopoverRootView.swift`.
Move shared `ControlMetrics` to its own internal file. Move `TimerPopoverView`
and `CompletionPopoverView` verbatim. Move `PrimaryButtonLabel` to
`TimerControlStyles.swift` as internal; keep `EndControlButtonStyle` there.

- [ ] **Step 4: Split update panel**

Move `UpdateDot` verbatim to `UpdateDot.swift`; keep `UpdatePrimaryButtonStyle`
private beside `UpdatePanel`.

- [ ] **Step 5: Run tests and build**

Run: `swift test`
Expected: 58/58, 0 failures.

Run: `./scripts/build-app.sh debug`
Expected: exit 0.

- [ ] **Step 6: Commit**

```sh
git add Sources
git commit -m "refactor(ui): split feature views and design system"
```

### Task 3: Localization split and contributor paths

**Owner:** Maxey

**Files:**
- Split: `Sources/Pomodoro/Localization/Localization.swift`
- Create: `Sources/Pomodoro/Localization/AppLanguage.swift`
- Create: `Sources/Pomodoro/Localization/LanguagePreference.swift`
- Create: `Sources/Pomodoro/Localization/L10n.swift`
- Move: `Tests/PomodoroTests/AppLanguageTests.swift` to `Tests/PomodoroTests/Localization/AppLanguageTests.swift`
- Move: `Tests/PomodoroTests/LanguagePreferenceTests.swift` to `Tests/PomodoroTests/Localization/LanguagePreferenceTests.swift`
- Modify: `AGENTS.md`, `DEVELOP.md` only for final source-path references

**Interfaces:**
- Consumes: existing language preference storage and string catalogs.
- Produces: unchanged `AppLanguage`, `LanguagePreference`, `LanguagePreferenceStore`, and `L10n`.

- [ ] **Step 1: Split localization**

Move `AppLanguage` verbatim; move `LanguagePreference` and
`LanguagePreferenceStore` verbatim; move `L10n` verbatim. Do not change keys,
fallback behavior, plural handling, or `Bundle` lookup.

- [ ] **Step 2: Mirror localization tests**

Use `git mv` for both test files. Do not rename test classes or methods.

- [ ] **Step 3: Update only stale active paths**

Run: `rg -n 'Sources/Pomodoro/Localization\\.swift|Sources/Pomodoro/(Model|Views)/|Tests/PomodoroTests/(AppLanguage|LanguagePreference)Tests\\.swift' AGENTS.md DEVELOP.md`
Expected: update active contributor docs only; leave historical specs unchanged.

- [ ] **Step 4: Run tests and build**

Run: `swift test`
Expected: 58/58, 0 failures.

Run: `./scripts/build-app.sh debug`
Expected: exit 0.

- [ ] **Step 5: Commit**

```sh
git add Sources Tests AGENTS.md DEVELOP.md
git commit -m "refactor(localization): split language and string lookup"
```

### Task 4: Integration and Phase 2 gate

**Owner:** James（集成与签字）/ Embiid（独立 QA）

- [ ] Merge/rebase owner branches in Core -> UI -> Localization order.
- [ ] Verify `git diff --check`, final tree, old file absence, declaration uniqueness.
- [ ] Record the final candidate SHA; do not run `swift test` / build / 13-case smoke (PROCESS §5).
- [ ] Embiid: cold build or CI on the final SHA; run the full 13-case smoke; inspect timer and Settings in Light and Black; write the QA report with PASS / SKIP / FAIL, state hash, uncovered items.
- [ ] James: review diff, QA report and hashes; sign; dispatch failures to the owning developer; do not re-run QA.
- [ ] Record evidence, time/token estimate, and known exceptions.

Expected: 58/58 tests and 0 smoke failures evidenced by CI or Embiid; no UI/layout changes, state restored.
