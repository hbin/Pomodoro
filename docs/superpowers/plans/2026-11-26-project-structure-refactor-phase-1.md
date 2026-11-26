# Project Structure Refactor Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move existing Swift sources into an industry-standard, feature-oriented SwiftPM layout without changing behavior.

**Architecture:** Phase 1 is path-only. SwiftPM recursively discovers nested sources, so `Package.swift` does not change. Each owner works in an isolated worktree and commits only file moves plus stale path-reference updates. No type or symbol is split in Phase 1.

**Tech Stack:** Swift 6, SwiftPM, AppKit, SwiftUI, XCTest, shell packaging scripts.

**Spec:** `docs/superpowers/specs/2026-11-26-project-structure-refactor-design.md`

## Global Constraints

- Do not change Swift symbol names, access levels, imports, or behavior.
- Do not change `Package.swift`, dependencies, version numbers, Sparkle assets, entitlements, or `Resources/` contents.
- Use `git mv`; preserve file contents byte-for-byte unless a stale documentation path must change.
- Do not commit, push, or alter another owner's files.
- Work from `codex/standard-project-layout` in an isolated worktree.
- Before delivery, rebase onto `origin/main` only if the integration branch moves; never rewrite another branch.

## Review Focus

- A moved file omitted from the target directory causes an otherwise valid build to fail.
- A path reference in docs, scripts, or tests remains stale after a move.
- Concurrent owners create the same directory but never the same file.
- `Resources/`, localization catalogs, and packaging inputs remain unchanged.
- Import-free moves may accidentally alter file contents while resolving conflicts.

---

### Task 1: Core target layout

**Owner:** JB

**Files:**
- Move: `Sources/PomodoroCore/IntervalDurations.swift` to `Sources/PomodoroCore/Timer/IntervalDurations.swift`
- Move: `Sources/PomodoroCore/TimerState.swift` to `Sources/PomodoroCore/Timer/TimerState.swift`
- Move: `Sources/PomodoroCore/Persistence.swift` to `Sources/PomodoroCore/Persistence/Persistence.swift`

**Interfaces:**
- Consumes: none.
- Produces: unchanged module `PomodoroCore` with all public symbols intact.

- [ ] **Step 1: Confirm clean baseline**

Run: `git status --short`
Expected: no output.

- [ ] **Step 2: Move core files**

```sh
mkdir -p Sources/PomodoroCore/Timer Sources/PomodoroCore/Persistence
git mv Sources/PomodoroCore/IntervalDurations.swift Sources/PomodoroCore/Timer/IntervalDurations.swift
git mv Sources/PomodoroCore/TimerState.swift Sources/PomodoroCore/Timer/TimerState.swift
git mv Sources/PomodoroCore/Persistence.swift Sources/PomodoroCore/Persistence/Persistence.swift
```

- [ ] **Step 3: Verify no content drift**

Run: `git diff --cached --stat`
Expected: three rename entries with 100% similarity.

- [ ] **Step 4: Run tests**

Run: `swift test`
Expected: exit 0, 51 `PomodoroCoreTests`, 7 `PomodoroTests`, 0 failures.

- [ ] **Step 5: Commit**

```sh
git add -A
git commit -m "refactor(core): organize by timer and persistence"
```

### Task 2: UI and design-system layout

**Owner:** VJ

**Files:**
- Move: `Sources/Pomodoro/Model/TimerModel.swift` to `Sources/Pomodoro/Features/Timer/TimerModel.swift`
- Move: `Sources/Pomodoro/Views/PopoverViews.swift` to `Sources/Pomodoro/Features/Timer/Views/PopoverViews.swift`
- Move: `Sources/Pomodoro/Views/DialView.swift` to `Sources/Pomodoro/Features/Timer/Views/DialView.swift`
- Move: `Sources/Pomodoro/Views/AmbientLight.swift` to `Sources/Pomodoro/Features/Timer/Views/AmbientLight.swift`
- Move: `Sources/Pomodoro/Views/SettingsView.swift` to `Sources/Pomodoro/Features/Settings/SettingsView.swift`
- Move: `Sources/Pomodoro/Views/UpdatePanel.swift` to `Sources/Pomodoro/Features/Updates/UpdatePanel.swift`
- Move: `Sources/Pomodoro/Views/Theme.swift` to `Sources/Pomodoro/DesignSystem/Theme.swift`
- Move: `Sources/Pomodoro/Views/Components.swift` to `Sources/Pomodoro/DesignSystem/Components.swift`

**Interfaces:**
- Consumes: unchanged symbols from `PomodoroCore`.
- Produces: unchanged app-module symbols and view signatures.

- [ ] **Step 1: Confirm clean baseline**

Run: `git status --short`
Expected: no output.

- [ ] **Step 2: Move UI files**

```sh
mkdir -p Sources/Pomodoro/Features/Timer/Views
mkdir -p Sources/Pomodoro/Features/Settings
mkdir -p Sources/Pomodoro/Features/Updates
mkdir -p Sources/Pomodoro/DesignSystem
git mv Sources/Pomodoro/Model/TimerModel.swift Sources/Pomodoro/Features/Timer/TimerModel.swift
git mv Sources/Pomodoro/Views/PopoverViews.swift Sources/Pomodoro/Features/Timer/Views/PopoverViews.swift
git mv Sources/Pomodoro/Views/DialView.swift Sources/Pomodoro/Features/Timer/Views/DialView.swift
git mv Sources/Pomodoro/Views/AmbientLight.swift Sources/Pomodoro/Features/Timer/Views/AmbientLight.swift
git mv Sources/Pomodoro/Views/SettingsView.swift Sources/Pomodoro/Features/Settings/SettingsView.swift
git mv Sources/Pomodoro/Views/UpdatePanel.swift Sources/Pomodoro/Features/Updates/UpdatePanel.swift
git mv Sources/Pomodoro/Views/Theme.swift Sources/Pomodoro/DesignSystem/Theme.swift
git mv Sources/Pomodoro/Views/Components.swift Sources/Pomodoro/DesignSystem/Components.swift
```

- [ ] **Step 3: Verify moves only**

Run: `git diff --cached --stat`
Expected: eight rename entries with 100% similarity.

- [ ] **Step 4: Run tests and build**

Run: `swift test`
Expected: exit 0, 58 total tests, 0 failures.

Run: `./scripts/build-app.sh debug`
Expected: exit 0 and `build/Pomodoro.app` produced.

- [ ] **Step 5: Commit**

```sh
git add -A
git commit -m "refactor(ui): group timer settings and design system"
```

### Task 3: App, services, localization, and path references

**Owner:** Maxey

**Files:**
- Move: `Sources/Pomodoro/PomodoroMain.swift` to `Sources/Pomodoro/App/PomodoroMain.swift`
- Keep: `Sources/Pomodoro/App/AppDelegate.swift`
- Keep: `Sources/Pomodoro/App/AppCoordinator.swift`
- Move: `Sources/Pomodoro/App/PopoverController.swift` to `Sources/Pomodoro/App/Popover/PopoverController.swift`
- Move: `Sources/Pomodoro/App/StatusItemController.swift` to `Sources/Pomodoro/App/StatusBar/StatusItemController.swift`
- Move: `Sources/Pomodoro/App/MenuBarIcon.swift` to `Sources/Pomodoro/App/StatusBar/MenuBarIcon.swift`
- Move: `Sources/Pomodoro/App/UpdateController.swift` to `Sources/Pomodoro/Features/Updates/UpdateController.swift`
- Move: `Sources/Pomodoro/Localization.swift` to `Sources/Pomodoro/Localization/Localization.swift`
- Modify: `AGENTS.md` source-layout references only
- Modify: `DEVELOP.md` source-layout references only

**Interfaces:**
- Consumes: unchanged `PomodoroCore` and app-module symbols.
- Produces: unchanged app lifecycle, update, localization, and service behavior.

- [ ] **Step 1: Confirm clean baseline**

Run: `git status --short`
Expected: no output.

- [ ] **Step 2: Move app and localization files**

```sh
mkdir -p Sources/Pomodoro/App/Popover
mkdir -p Sources/Pomodoro/App/StatusBar
mkdir -p Sources/Pomodoro/Features/Updates
mkdir -p Sources/Pomodoro/Localization
git mv Sources/Pomodoro/PomodoroMain.swift Sources/Pomodoro/App/PomodoroMain.swift
git mv Sources/Pomodoro/App/PopoverController.swift Sources/Pomodoro/App/Popover/PopoverController.swift
git mv Sources/Pomodoro/App/StatusItemController.swift Sources/Pomodoro/App/StatusBar/StatusItemController.swift
git mv Sources/Pomodoro/App/MenuBarIcon.swift Sources/Pomodoro/App/StatusBar/MenuBarIcon.swift
git mv Sources/Pomodoro/App/UpdateController.swift Sources/Pomodoro/Features/Updates/UpdateController.swift
git mv Sources/Pomodoro/Localization.swift Sources/Pomodoro/Localization/Localization.swift
```

`AppDelegate.swift` and `AppCoordinator.swift` remain in `Sources/Pomodoro/App/`.

- [ ] **Step 3: Update stale source-path references**

Run: `rg -n 'Sources/Pomodoro/(Model|Views)/|Sources/Pomodoro/Localization\\.swift|Sources/Pomodoro/PomodoroMain\\.swift' AGENTS.md DEVELOP.md`
Expected: list only references that need the new paths; update those references without changing prose or product rules.

- [ ] **Step 4: Verify moves and path scan**

Run: `git diff --cached --stat`
Expected: six rename entries plus documentation text changes.

Run: `rg -n 'Sources/Pomodoro/(Model|Views)/|Sources/Pomodoro/Localization\\.swift|Sources/Pomodoro/PomodoroMain\\.swift' AGENTS.md DEVELOP.md`
Expected: no output.

- [ ] **Step 5: Run tests and build**

Run: `swift test`
Expected: exit 0, 58 total tests, 0 failures.

Run: `./scripts/build-app.sh debug`
Expected: exit 0 and `build/Pomodoro.app` produced.

- [ ] **Step 6: Commit**

```sh
git add -A
git commit -m "refactor(app): separate lifecycle services and localization"
```

### Task 4: Integration review and Phase 1 gate

**Owner:** Lebron

**Files:**
- Review: all Phase 1 changes.
- Create: `.workspace/tasks/2026-11-26-project-layout-refactor.md` and same-directory evidence.

- [ ] **Step 1: Merge owner branches sequentially into `codex/standard-project-layout`**

Run: `git merge --ff-only codex/layout-core`
Then: require VJ to rebase `codex/layout-ui` onto the updated `codex/standard-project-layout`, and merge it with `git merge --ff-only codex/layout-ui`.
Then: require Maxey to rebase `codex/layout-app` onto the updated `codex/standard-project-layout`, and merge it with `git merge --ff-only codex/layout-app`.

Expected: all Phase 1 commits form a linear history. If an owner branch cannot fast-forward, return it to the owner for rebase; do not create a merge commit.

- [ ] **Step 2: Verify tree**

Run: `find Sources Tests -type f | sort`
Expected: target Phase 1 layout, with no files left under `Sources/Pomodoro/Model/` or `Sources/Pomodoro/Views/`.

Run: `git diff --check`
Expected: no output.

- [ ] **Step 3: Run full verification**

Run: `swift test`
Expected: exit 0, 58 tests, 0 failures.

Run: `./scripts/build-app.sh debug`
Expected: exit 0 and `build/Pomodoro.app` produced.

- [ ] **Step 4: Inspect Light and Black themes**

Launch the debug app with `--open-popover --force-light --idle-mode=focus`, inspect, quit, repeat with `--force-dark`.
Expected: timer card remains 340x510; no layout, copy, or behavior change.

- [ ] **Step 5: Write evidence and decide Phase 2**

Record command, output summary, owner, commit SHA, token/time usage, and known exceptions under `.workspace/tasks/2026-11-26-project-layout-refactor/`.

Expected: Phase 1 gate passes or a concrete blocker is returned to its owner. Do not start Phase 2 until Phase 1 is accepted.
