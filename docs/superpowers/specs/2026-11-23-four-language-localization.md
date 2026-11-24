# Four-Language Localization

**Feature design specification**

- Status: Approved; amended by the in-app language picker specification
- Date: 2026-11-23
- Platform: macOS 15+
- Locales: English, Simplified Chinese, Traditional Chinese, Japanese

## 1. Summary

Pomodoro currently presents all runtime copy in English. This change adds
complete localization for English, Simplified Chinese, Traditional Chinese,
and Japanese while preserving the current timer behavior, visual direction,
and fixed popover dimensions.

Language follows the macOS app-language selection by default. An app-only
language picker in Settings can override that choice for Pomodoro and apply a
new language immediately without relaunching. The explicit choice persists
across launches. English remains the development language and fallback.

See `2026-11-23-in-app-language-picker.md` for the picker's product and UI
requirements.

This is a product localization change, not a localization framework for future
features. The implementation should leave one clear, reusable workflow for
adding another language later.

## 2. Goals and success criteria

### Goals

1. Let the app render every user-facing surface in the selected macOS app
   language.
2. Let people switch between System Default, English, Simplified Chinese,
   Traditional Chinese, and Japanese from Settings without relaunching.
3. Keep the English experience unchanged in wording, layout, and typography.
4. Make Chinese and Japanese feel intentionally typeset rather than like
   Latin-font fallback.
5. Keep timer, persistence, notification, and update behavior unchanged.
6. Add a build-time guard against incomplete localization resources.
7. Document how future copy and languages are added.

### Success criteria

- macOS lists Pomodoro under per-app language settings with English,
  简体中文, 繁體中文, and 日本語.
- Choosing each supported language in Settings updates the running interface
  immediately and produces no untranslated runtime copy except brand names,
  technical identifiers, and fixed clock values.
- Every popover state, menu, notification, update message, accessibility
  label, and recovery error is localized.
- Chinese and Japanese copy fits the existing fixed popover sizes without
  clipping or truncated controls.
- Light theme, Black theme, and reduced-transparency presentation remain
  intact in every language.
- An incomplete or format-invalid String Catalog fails the app build.

## 3. Locale model

| Locale | Meaning | Convention |
| --- | --- | --- |
| `en` | English | Development language and fallback |
| `zh-Hans` | Simplified Chinese | Mainland China conventions |
| `zh-Hant` | Traditional Chinese | Taiwan conventions |
| `ja` | Japanese | Standard Japanese conventions |

Rules:

- Use these exact locale identifiers in runtime resources and
  `CFBundleLocalizations`.
- Keep `CFBundleDevelopmentRegion` set to `en`.
- Traditional Chinese targets Taiwan vocabulary and punctuation. Hong Kong
  Cantonese and `zh-HK` are not part of this change.
- System language resolution and per-app language selection come from macOS.
  Settings offers a compact override using System Default, English, 简体中文,
  繁體中文, and 日本語. Store only that app-local override; do not add a
  launch-time language prompt or a locale field to `PersistedState`.
- Do not force `Locale` or SwiftUI's locale environment. Dates, times, and
  other system-formatted values continue to use the user's current locale.
- If a locale resource is unavailable in the future, Foundation may fall back
  to English. The initial release ships all four localizations completely.

## 4. Localization scope

### 4.1 Surfaces that must be localized

| Surface | Required copy |
| --- | --- |
| App menu and status-item menu | About, Check for Updates, Settings, Quit |
| Menu-bar item | Compact remaining minutes, tooltip, accessibility label/value |
| Timer popover | Idle, running, paused, end control, completion, footer tips |
| Dial | Phase captions, ready/remaining/paused/complete captions, accessibility |
| Settings | Headings, descriptions, theme and language names, notification status/actions |
| Update controls | Dot help/accessibility, panel title, statuses, actions, modes |
| Notifications | Focus-complete and break-complete title and body |
| Accessibility | Control labels, hints, timer values, transition announcements |
| Errors | Save failures and unreadable-state recovery messages |
| About panel | Localized `NSHumanReadableCopyright` through `InfoPlist.strings` |

The implementation must migrate copy in:

- `Sources/Pomodoro/App/AppCoordinator.swift`
- `Sources/Pomodoro/App/StatusItemController.swift`
- `Sources/Pomodoro/App/UpdateController.swift`
- `Sources/Pomodoro/Model/TimerModel.swift`
- `Sources/Pomodoro/Services/NotificationService.swift`
- `Sources/Pomodoro/Views/Components.swift`
- `Sources/Pomodoro/Views/DialView.swift`
- `Sources/Pomodoro/Views/PopoverViews.swift`
- `Sources/Pomodoro/Views/SettingsView.swift`
- `Sources/Pomodoro/Views/Theme.swift`
- `Sources/Pomodoro/Views/UpdatePanel.swift`
- `Sources/PomodoroCore/Persistence.swift`

### 4.2 Content that remains unchanged

- The product name `Pomodoro` and the `POMODORO` brand wordmark.
- The app bundle name, executable name, bundle identifier, and file paths.
- `POMODORO`, `Pomodoro`, and version strings in diagnostics.
- `MM:SS` clock readouts.
- SF Symbol names, notification identifiers, URLs, preference keys, persisted
  JSON keys, and process-activity reasons.
- Sound synthesis and menu-bar artwork.
- Sparkle's own standard user interface. Sparkle provides its own
  localizations for the languages it supports.

## 5. Copy and terminology

### Voice

Translations preserve the existing quiet, concise, non-judgmental voice. Avoid
exclamation marks, productivity pressure, motivational slogans, or literal
word-for-word phrasing that sounds unnatural in the target language.

Use whole-sentence localization keys rather than concatenating localized
fragments. Word order and grammar must remain under the translator's control.

### Glossary

| English concept | Simplified Chinese | Traditional Chinese | Japanese |
| --- | --- | --- | --- |
| Focus | 专注 | 專注 | 集中 |
| Break | 休息 | 休息 | 休憩 |
| Settings | 设置 | 設定 | 設定 |
| Appearance | 外观 | 外觀 | 外観 |
| Sound | 声音 | 音效 | サウンド |
| Menu bar | 菜单栏 | 選單列 | メニューバー |
| Notifications | 通知 | 通知 | 通知 |
| Updates | 更新 | 更新 | アップデート |
| System | 系统 | 系統 | システム |
| Light | 浅色 | 淺色 | ライト |
| Black | 黑色 | 黑色 | ブラック |

Additional copy rules:

- Keep `Pomodoro` unchanged inside translated sentences.
- Use Simplified Chinese full-width punctuation, Taiwan Traditional Chinese
  punctuation, and standard Japanese punctuation.
- Use `…` rather than three periods for menu and continuation text.
- Preserve placeholder order through the String Catalog rather than manually
  reordering sentences in source code.
- Use String Catalog plural variations for English count-bearing copy. Chinese
  and Japanese use a single grammatical form.
- Treat the three target-language drafts as complete but pending native-speaker
  review. Record this review state in the catalog comments and release
  checklist; do not replace translations with English placeholders.

## 6. Technical design

### 6.1 String resources

Add:

- `Resources/Localization/Localizable.xcstrings` for all runtime interface and
  accessibility copy.
- `Resources/Localization/InfoPlist.xcstrings` for
  `NSHumanReadableCopyright`.

Both catalogs use `en` as their source language and contain all four
localizations. Catalog comments identify the surface and meaning where a
string could otherwise be ambiguous.

Key names use a stable semantic namespace, not English copy:

- `common.*`
- `menu.*`
- `status_bar.*`
- `timer.*`
- `completion.*`
- `settings.*`
- `notification_status.*`
- `notifications.*`
- `updates.*`
- `accessibility.*`
- `announcements.*`
- `errors.*`
- `info_plist.*`

Examples: `timer.idle.title`, `settings.sound.chime.detail`,
`updates.status.available`, and `menu.settings`.

### 6.2 Lookup behavior

- All runtime copy uses `L10n.string`, `L10n.format`, or `L10n.count`. Do not
  use bare SwiftUI `Text("key")` for runtime copy because it does not re-resolve
  against the in-app language override.
- `L10n` selects the bundle for the active `AppLanguage` and falls back to the
  main bundle if a locale resource is unavailable.
- Dynamically built values use a localized whole-sentence format with `%lld`
  for integer counts and `%@` for already-formatted strings such as the timer
  readout or end time.
- Do not use `Bundle.module`. The project builds a hand-assembled app bundle,
  not SwiftPM resource bundles.
- Do not localize by comparing or switching on English copy.

### 6.3 Build and app-bundle integration

Because the app bundle is assembled by `scripts/build-app.sh`, the build script
must install compiled resources directly into the app:

```sh
xcrun xcstringstool installloc "$ROOT/Resources/Localization" \
  --output-directory "$APP/Contents/Resources"
```

This command must run after the empty app bundle is created and before signing.
It must apply equally to debug and release builds. The resulting app must
contain:

- `Contents/Resources/en.lproj/Localizable.strings`
- `Contents/Resources/zh-Hans.lproj/Localizable.strings`
- `Contents/Resources/zh-Hant.lproj/Localizable.strings`
- `Contents/Resources/ja.lproj/Localizable.strings`
- The matching `InfoPlist.strings` files

Add `CFBundleLocalizations` to `Resources/Info.plist` with exactly:

- `en`
- `zh-Hans`
- `zh-Hant`
- `ja`

Add no target resources to `Package.swift`, no new runtime dependency, and no
language-specific state to `PersistedState`.

### 6.4 Catalog validation

Add a small Swift validation script at
`scripts/check-localizations.swift` and invoke it from `scripts/build-app.sh`
before compilation.

The validator must fail with a specific key and locale when:

- A catalog does not declare English as its source language.
- `en`, `zh-Hans`, `zh-Hant`, or `ja` is missing.
- A key, plural variation, or localized value is empty.
- Format placeholders in a translated value do not match the English source.

The build script must also verify that every expected `.lproj` directory and
`Localizable.strings` file exists after `xcstringstool installloc` runs.

### 6.5 Core and persistence boundary

`PomodoroCore` must remain free of UI localization. Replace the English
recovery string in `LoadResult` with a semantic issue:

```swift
public enum StateRecoveryIssue: Sendable, Equatable {
    case unreadableStateBackedUp
    case unreadableStateReset
}

public var recoveryIssue: StateRecoveryIssue?
```

`TimerModel` maps the issue to localized error copy. The existing behavior
remains:

- Move an unreadable state file to a timestamped backup when possible.
- Recover with a clean timer state.
- Show one dismissible recovery note.
- Never silently overwrite corrupt state.

Remove `LoadResult.recoveryMessage` and update all callers and tests. The
on-disk JSON schema does not change.

### 6.6 Presentation changes

- Build app-menu and status-menu titles with localized strings.
- Remove locale-dependent display text from `MenuBarDescriptor`. Add a
  locale-neutral `showsRemainingMinutes` signal and format the compact title in
  `StatusItemController` using a localized minutes format.
- Localize the status-item tooltip and complete accessibility value, including
  pause and completion states.
- Localize `TimerModel` phase labels, captions, notification statuses,
  announcements, save errors, and recovery copy.
- Localize notification titles and bodies when the request is scheduled.
- Localize custom update-mode titles, descriptions, status messages, dot help,
  and panel actions. Keep Sparkle's standard user driver untouched.
- Localize `ThemePreference` titles used by the appearance picker.
- Ensure every dial caller supplies a localized accessibility label and value;
  do not rely on lowercasing an English caption.

### 6.7 Typography

Typography selection follows the active language used by `L10n`, not the
user's region setting. Changing the in-app language must immediately switch
the interface fonts as well as copy.

| Locale | Interface sans | Display serif |
| --- | --- | --- |
| English | Avenir Next | Iowan Old Style |
| `zh-Hans` | PingFang SC | Songti SC |
| `zh-Hant` | PingFang TC | Songti TC |
| `ja` | Hiragino Sans | Hiragino Mincho ProN |

Implementation requirements:

- English retains the current font names and point sizes.
- Use `PingFangSC-Regular`, `PingFangSC-Medium`, and `PingFangSC-Semibold`;
  apply the equivalent PingFang TC family for Traditional Chinese.
- Use `STSongti-SC-Regular` and `STSongti-TC-Regular` for CJK display titles.
- Use `HiraginoSans-W3`, `HiraginoSans-W5`, and `HiraginoSans-W6` for
  Japanese interface weights, and `HiraMinProN-W3` for Japanese display titles.
- Keep countdown digits in the existing tabular Avenir Next face across all
  locales for stable width.
- Remove extra uppercase letter spacing from localized Chinese and Japanese
  labels. The `POMODORO` wordmark keeps its existing Latin treatment.
- Fall back to the system font if a named font is unavailable.

### 6.8 Layout

The popover remains 380 points wide, 544 points high in timer states, and 520
points high in Settings. Do not introduce per-language window sizes.

- Shorten translations rather than truncating controls.
- Allow descriptions to wrap to two lines where necessary.
- Keep primary-button labels to one line at the existing type size.
- Preserve the 304-point update-panel width and ensure localized modes fit.
- Confirm the menu-bar minute label remains compact; localized Chinese and
  Japanese may use `25 分钟`, `25 分鐘`, or `25分`.
- Do not alter dial geometry, panel anchoring, or appearance behavior.

### 6.9 Notification and language changes

- Notification content uses the app language active when the notification is
  scheduled.
- An in-app language change reschedules the pending notification at the same
  `endDate` without restarting or changing the running timer.
- A language change made in macOS System Settings is captured the next time
  Pomodoro launches while **System Default** is selected.
- Live-updating an already delivered notification is not required.
- The app menu is rebuilt and status-item copy is refreshed immediately after
  an in-app language change. The standard About panel remains launch-localized
  because it is provided by AppKit.

## 7. Validation and testing

### Automated checks

- Run `swift test`.
- Add persistence tests covering:
  - Unreadable state with a successful backup reports
    `.unreadableStateBackedUp`.
  - Unreadable state whose backup also fails reports
    `.unreadableStateReset`.
  - Missing persisted fields still decode with defaults.
  - Valid saved state still round-trips.
- Run the new catalog validator through the app build.
- Run `./scripts/build-app.sh debug`.
- Run `UNIVERSAL=1 ./scripts/package-dmg.sh` to verify release packaging and
  signing include the localization resources.

### Manual language checks

Test the in-app picker by launching the built app, opening Settings, and
choosing System Default, English, Simplified Chinese, Traditional Chinese, and
Japanese. Every change should apply without a relaunch. Restart Pomodoro after
an explicit selection and confirm that selection persists.

To test `System Default` against a specific macOS app language, clear the
app-only override and relaunch with explicit arguments:

```sh
defaults delete com.hb.pomodoro PomodoroLanguagePreference 2>/dev/null || true
open build/Pomodoro.app --args --open-settings \
  -AppleLanguages '(zh-Hans)' -AppleLocale zh_CN
```

Quit any running Pomodoro instance before each launch so the language
arguments apply to a fresh process.

Use the matching values for the other languages:

- `zh-Hant` with `zh_TW`
- `ja` with `ja_JP`
- `en` with `en_US`

Also verify native per-app selection in macOS System Settings after installing
or registering the app. That external selection applies on the next launch
while `System Default` is active.

For each language, inspect:

- Idle, running, paused, end control, focus-complete, and break-complete
  popover states.
- Settings, all theme choices, notification states, and the update panel.
- App menu titles, status-item menu, tooltip, and compact menu-bar title.
- Both Light and Black themes.
- At least one reduced-transparency run and enlarged system text check.
- No clipped labels, orphaned punctuation, raw keys, or unintended English.
- VoiceOver labels, values, hints, and announcements.
- At least one scheduled notification's title and body.
- An active timer stays unchanged while language changes, while its pending
  notification is rescheduled.

### Final copy audit

Search the app target for remaining quoted English copy. Any remaining literal
must be a brand wordmark, SF Symbol name, URL, identifier, font PostScript
name, format specifier, or other non-user-facing value.

## 8. Documentation

- Update `README.md` with a short **Languages** section naming English,
  简体中文, 繁體中文, and 日本語 and explaining the in-app picker, persistence,
  and the System Default relaunch behavior. Keep the existing English
  screenshots.
- Update `DEVELOP.md` with:
  - Supported locale identifiers.
  - String Catalog locations and key conventions.
  - How to add or change copy.
  - The catalog validator and build command.
  - Commands for launching each language during QA.
  - The native-review requirement for Chinese and Japanese.
- Add a durable localization rule to `AGENTS.md`: new
  user-facing copy must use the String Catalog and include all supported
  locales.
- Do not bump `CFBundleShortVersionString` or `CFBundleVersion`.

## 9. Acceptance criteria

- macOS offers English, Simplified Chinese, Traditional Chinese, and Japanese
  for Pomodoro.
- Selecting any supported app language in Settings immediately localizes the
  entire runtime interface, and the choice persists across launches.
- No untranslated English copy remains in the target locales except approved
  brand names and technical values.
- Menus, notifications, recovery errors, update status, and VoiceOver copy are
  localized.
- Chinese and Japanese use intentional font stacks and label spacing.
- The popover remains 380 points wide and uses its existing fixed heights with
  no clipping.
- The Settings language picker fits at 520 points without a persistent
  scrollbar and remains usable in both themes.
- Light theme, Black theme, and reduced transparency remain correct.
- A missing translation or format mismatch fails the app build.
- Corrupt-state backup and recovery behavior is preserved.
- Debug build, tests, and universal release packaging pass.
- README, developer documentation, and agent guidance describe the workflow.

## 10. Non-goals

- Changing the language used for dates and times independently of the system
  locale.
- Relaunch-free propagation of a macOS System Settings language change while
  System Default is active.
- Hong Kong Cantonese or `zh-HK`.
- Additional languages beyond the four listed here.
- Localizing README prose, release notes, GitHub metadata, or the Sparkle
  appcast.
- Customizing Sparkle's standard updater UI.
- Changing timer logic, persistence schema, notifications, sound, themes, or
  popover geometry.
- Adding a third-party localization, translation, or dependency-management
  service.

## 11. Implementation outline

1. Add both String Catalogs, the catalog validator, build-script integration,
   and `CFBundleLocalizations`.
2. Replace the core recovery string with `StateRecoveryIssue` and update
   persistence tests.
3. Migrate all runtime copy, accessibility copy, menus, notifications, update
   messages, and error presentation to semantic keys.
4. Add the persisted in-app language preference, locale-bundle lookup, and
   live menu/status/notification refresh behavior.
5. Add locale-aware typography and adjust copy/tracking to fit the existing
   layouts.
6. Draft and complete all Chinese and Japanese values, marking native review as
   pending.
7. Update README, DEVELOP, and repository agent guidance.
8. Run automated checks, app builds, packaged builds, and the full manual
   localization matrix.
