# In-App Language Picker

**Feature design specification**

- Status: Approved for implementation
- Date: 2026-11-23
- Platform: macOS 15+
- Languages: System Default, English, 简体中文, 繁體中文, 日本語

## 1. Summary

Pomodoro already ships complete runtime localization for English, Simplified
Chinese, Traditional Chinese, and Japanese. Language currently follows the
macOS app-language setting and is resolved at launch.

This feature adds a compact language picker to Settings. It lets people choose
an app-only language override, applies the change immediately, and restores
that choice on the next launch. **System Default** remains the default and
preserves the existing macOS app-language behavior.

## 2. Goals

1. Make language discoverable without leaving Pomodoro.
2. Apply copy, typography, menus, status-item text, accessibility copy, and
   pending notification content immediately.
3. Preserve timer state and the current interval's absolute end time.
4. Fit inside the 380-point-wide Settings surface without a persistent
   scrollbar.
5. Keep the existing four-language String Catalog as the single source of copy.

## 3. Non-goals

- Adding more languages.
- Changing the locale used for dates, times, and number formatting.
- Live-updating the AppKit standard About panel after launch.
- Live-updating an already delivered notification.
- Relaunch-free pickup of a macOS System Settings language change.

## 4. Placement and design

The picker lives inside the **Appearance** section, directly below the three
theme choices and separated from them by a hairline.

The row contains:

- Localized **Language** title.
- Detail text: **Changes apply immediately.** for an explicit language, or
  **Follows the macOS app language.** for System Default.
- A compact native menu button on the trailing side.

Menu-button treatment:

- 28-point height and 9-point continuous corner radius.
- `plaque` fill with the shared brass border.
- 11.5-point medium interface font.
- Leading globe symbol, current-language label, and trailing chevron.
- The menu opens with **System Default**, a divider, and the four autonyms:
  `English`, `简体中文`, `繁體中文`, `日本語`.
- The active choice uses native menu checkmark behavior.
- Accessibility label is the localized **Language** title; the value is the
  current choice; the hint is the localized detail text.

The added row needs roughly 43 points of vertical space. Settings grows from
460 to 520 points so normal content fits without a visible scrollbar. The
hidden-indicator ScrollView remains for rare overflow such as an additional
error or notification detail.

## 5. Persistence and resolution

- Store an explicit choice in `UserDefaults` under
  `PomodoroLanguagePreference` as one of `en`, `zh-Hans`, `zh-Hant`, or `ja`.
- Remove the key when **System Default** is selected.
- Absence of the key means System Default.
- Capture the macOS app language when the process launches and resolve it to
  one of the four supported `AppLanguage` values.
- Do not add language state to `PersistedState` or the state JSON.
- `L10n` resolves strings from the matching `.lproj` bundle; unavailable
  bundles fall back to the main bundle.
- `Typo` resolves fonts from the same active language.

Language names are autonyms and are identical in every interface language.
System Default and all descriptive copy are localized through the String
Catalog.

## 6. Live-change behavior

On an in-app change:

1. Persist the preference.
2. Update `L10n` and invalidate observing SwiftUI views.
3. Rebuild the app menu with localized titles.
4. Refresh status-item title, tooltip, and accessibility copy.
5. Reschedule the pending notification at the existing interval `endDate`
   without restarting the timer.
6. Post a localized accessibility announcement naming the new language.

Computed error messages use semantic error values so recovery and save errors
re-localize with the interface.

## 7. New copy keys

- `settings.language.title`
- `settings.language.detail`
- `settings.language.system_detail`
- `settings.language.system`
- `announcements.language_changed`

All five keys include English, Simplified Chinese, Traditional Chinese, and
Japanese values in `Resources/Localization/Localizable.xcstrings`.

## 8. Validation

Automated:

- `swift test`
- `swift scripts/check-localizations.swift .`
- `./scripts/build-app.sh debug`
- `UNIVERSAL=1 ./scripts/package-dmg.sh`

Manual:

- Switch through all five choices without relaunching.
- Verify Settings, timer states, completion states, updates, app menu,
  status-item menu, menu-bar title, tooltip, accessibility copy, and recovery
  or save errors.
- Verify an active timer keeps the same end time and pending notification is
  replaced with the new language.
- Verify explicit choice and System Default both persist correctly.
- Verify Light, Black, and reduced-transparency presentation.
- Verify Chinese and Japanese labels fit without clipping or truncation.
- Confirm the standard About panel remains launch-localized, which is an
  accepted limitation.

## 9. Documentation

Update `README.md` with the in-app path and System Default relaunch behavior.
Update `DEVELOP.md` with the preference key, live-refresh responsibilities,
QA launch-argument caveat, and About-panel limitation. Update `AGENTS.md` to
require `L10n` rather than bare SwiftUI localization literals for runtime copy.
