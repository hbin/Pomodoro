# Six-Language Localization (Vietnamese and Korean)

**Feature design specification**

- Status: Approved — Tech Lead and product owner, 2026-11-25; design complete
- Date: 2026-11-25
- Revision: 2026-11-25 — copy corrections from the in-context implementation
  review (Vietnamese break/timer terminology and subtitle), synced with the
  final implemented Korean notification copy
- Target version: `0.5.0`
- Platform: macOS 15+
- Locales: English, Simplified Chinese, Traditional Chinese, Japanese, Vietnamese, Korean
- Extends: `2026-11-23-four-language-localization.md`, `2026-11-23-in-app-language-picker.md`

## 1. Summary

Add Vietnamese (`vi`) and Korean (`ko`) to the runtime interface, the in-app
language picker, and macOS per-app language settings. Switching either language
at runtime must apply immediately, without a relaunch, for copy, typography,
menus, status-item text, pending notifications, and accessibility.

This is a localization and typography change. It adds no screens, no controls,
and no new layout. The timer card stays 340×510 points; Settings stays 340
points wide with a content-measured height and no scrollbar; the update panel
stays within the existing content width.

Where this document and `2026-11-23-four-language-localization.md` disagree on
geometry, this document wins: the earlier spec's 380×544/520 dimensions were
already superseded by the 340×510 timer and the content-measured Settings card.

## 2. Goals and non-goals

### Goals

1. Present every user-facing surface in six languages with no untranslated
   runtime copy.
2. Offer `Tiếng Việt` and `한국어` in the in-app picker and in macOS per-app
   language settings.
3. Apply runtime language changes immediately, including fonts.
4. Preserve the existing English, Simplified Chinese, Traditional Chinese, and
   Japanese copy, fonts, and layout exactly.
5. Keep Vietnamese and Korean copy inside the existing fixed geometry without
   shrinking type, resizing the card, or introducing scrolling.
6. Keep the build-time localization validator and release checklist authoritative
   for six locales.

### Non-goals

- No visual redesign, new components, or new information hierarchy.
- No change to timer behavior, persistence, notification scheduling, Sparkle, or
  sound.
- No per-language window sizes, font sizes, line heights, or tracking exceptions.
- No translation-name labels in the picker: autonyms remain the label.
- No change to the `POMODORO` wordmark, bundle name, identifiers, or `MM:SS`
  readouts.
- No localization of Sparkle's own UI beyond what Sparkle ships.

## 3. Locale model

### 3.1 Locales

| Locale | Meaning | Convention |
| --- | --- | --- |
| `en` | English | Development language and fallback |
| `zh-Hans` | Simplified Chinese | Mainland China |
| `zh-Hant` | Traditional Chinese | Taiwan |
| `ja` | Japanese | Standard Japanese |
| `vi` | Vietnamese | Standard Vietnamese, full diacritics |
| `ko` | Korean | Standard Korean, Hangul |

`CFBundleDevelopmentRegion` stays `en`.

### 3.2 Picker order and autonyms

`AppLanguage.allCases` order is the picker order. Append the new cases after
Japanese so existing users' menu positions do not move:

| Position | Value | Autonym |
| --- | --- | --- |
| 0 | System Default | localized `settings.language.system` |
| 1 | `en` | `English` |
| 2 | `zh-Hans` | `简体中文` |
| 3 | `zh-Hant` | `繁體中文` |
| 4 | `ja` | `日本語` |
| 5 | `vi` | `Tiếng Việt` |
| 6 | `ko` | `한국어` |

The menu label and the picker rows keep showing autonyms. Do not translate
language names; the label is not allowed to change with the active language.

### 3.3 Resolution

- `AppLanguage(identifier:)` normalizes `_` to `-`, lowercases, and then
  **exactly matches the primary language subtag** — the text before the first
  `-`. `vi-VN` resolves to `vi`; `ko-KR` resolves to `ko`; `ja-JP` resolves to
  `ja`.
- Prefix matching is not allowed for the primary subtag. `vai` (Vai) must not
  resolve to Vietnamese, `kok` (Konkani) must not resolve to Korean, and `jam`
  (Jamaican Creole) must not resolve to Japanese. `zh` keeps its existing
  script/region handling because `zh-Hans` and `zh-Hant` differ by subtag.
- Unknown primary subtags fall back to English.
- `System Default` continues to resolve from `Bundle.main.preferredLocalizations`
  at launch.
- An explicit in-app selection persists and wins over the system preference.
- A macOS per-app language change is picked up on the next launch while
  `System Default` is active. No live observation of system settings is added.

### 3.4 Bundle metadata

`CFBundleLocalizations` must list exactly, in order:

```
en
zh-Hans
zh-Hant
ja
vi
ko
```

`Localizable.xcstrings` and `InfoPlist.xcstrings` must carry `vi` and `ko`
localizations for every key. `NSHumanReadableCopyright` candidates:

| Locale | Value |
| --- | --- |
| `vi` | `Bản dựng cá nhân` |
| `ko` | `개인 빌드` |

## 4. Typography

### 4.1 Font mapping

Typography follows the active `L10n` language, not the region. Changing the
in-app language must switch fonts immediately.

| Locale | Interface sans | Display serif |
| --- | --- | --- |
| `en` | `AvenirNext-Regular/Medium/DemiBold/Bold` (unchanged) | `IowanOldStyle-Roman` |
| `zh-Hans` | `PingFangSC-*` (unchanged) | `STSongti-SC-Regular` |
| `zh-Hant` | `PingFangTC-*` (unchanged) | `STSongti-TC-Regular` |
| `ja` | `HiraginoSans-W3/W5/W6` (unchanged) | `HiraMinProN-W3` |
| `vi` | `AvenirNext-Regular/Medium/DemiBold/Bold` | **`Palatino-Roman`** |
| `ko` | **`AppleSDGothicNeo-Regular/Medium/SemiBold/Bold`** | **`AppleMyungjo`** |

Weight mapping for Korean: `Medium` → `AppleSDGothicNeo-Medium`,
`DemiBold`/`Bold` → `AppleSDGothicNeo-SemiBold`/`-Bold`, default → `-Regular`.
Countdown digits stay `AvenirNext-Medium` with monospaced digits in all locales.

### 4.2 Why these fonts

Measured on macOS 27.2.1 (26B131) with CoreText glyph coverage:

- `IowanOldStyle-Roman` is missing 11 Vietnamese glyphs — `ữ ơ ở ỡ ợ ứ ừ ử ự ư Ư`.
  Keeping Iowan for `vi` would fall back per glyph and mix typefaces inside the
  largest text on the card. Iowan has no Hangul at all.
- `AvenirNext` fully covers Vietnamese but has no Hangul.
- `Palatino-Roman` fully covers Vietnamese. At 34 pt its cap height is 23.62
  against Iowan's 23.96 (−1.4%) and x-height 16.02 against 16.52 (−3.0%), so the
  title keeps the same optical size. Baskerville is rejected: x-height 13.60
  (−17.6%) makes the Vietnamese title look a size smaller. `Typo.serif` is only
  used at regular weight, so Baskerville's extra weight is not a requirement.
- `AppleMyungjo` fully covers Hangul and is the system Myeongjo serif, matching
  the light-serif display voice used by Mincho and Songti. `Apple SD Gothic Neo`
  fully covers Hangul and provides the four interface weights.
- No single installed family covers both Vietnamese and Hangul. Per-language
  family selection is required; a Unicode fallback font is explicitly rejected.

### 4.3 Tracking, case, and line height

- Korean is CJK: `Typo.tracking` returns 0, matching Chinese and Japanese.
- Vietnamese is Latin: keep the existing Latin tracking values (1.9 pt section
  labels, 0.12 pt mode labels, dial caption tracking). Do not add a
  Vietnamese-specific exception.
- Uppercase stays as designed. Vietnamese uppercase with diacritics
  (`NGHỈ NGẮN`) measures 53.8 pt at 9 pt with 1.9 pt of extra width available —
  it fits without adjustment. Korean uppercase is a no-op.
- `Typo.lineHeight(size) = ceil(size × 1.4)` stays unchanged in every locale.
  Changing it would move text blocks and change the measured Settings height.

### 4.4 Vertical clearance

The 34 pt title sits in a 48 pt frame. Palatino's line box is 37.4 pt, leaving
5.3 pt above and below. The worst measured Vietnamese sample (`Nghỉ ngắn`) has
ink 2.6 pt above the font ascent and still keeps 2.7 pt to the frame edge: no
clipping, no overlap with the header. At 9.7 pt, Vietnamese ink height is
10.4 pt inside a 14 pt row, so two-line descriptions do not collide.
Korean display ink is 31.9 pt inside a 40.4 pt line box.

The Vietnamese title baseline sits about 2.7 pt higher than English because
Palatino has a smaller ascent than Iowan. That is text-internal positioning; no
non-text element may move because of it.

### 4.5 Fallback

Keep the existing `NSFont(name:size:)` availability check and system fallback.
Adding an `AppLanguage` case must force an explicit font decision in the
exhaustive switches; silent fallback per language is a bug.

## 5. Copy and length budgets

### 5.1 Budgets

Point budgets are authoritative; character counts are guidance for translators.
Overflow is fixed by shortening copy, never by changing type size, card size, or
scrolling.

| Surface | Font | Hard limit | Target |
| --- | --- | --- | --- |
| Timer title | serif 34 | 300 pt, one line | ≤290 pt (≤19 VI chars / ≤9 KO syllables) |
| Timer status | sans 10.7 | 300 pt, one line | ≤200 pt to avoid the 0.9 scale factor |
| Timer footer tip | sans 9.7 | 300 pt, must stay one line | ≤260 pt |
| Primary button | sans 13.5 | 140 pt of text inside the 190 pt button | ≤120 pt |
| Mode selector | sans 9 demi-bold, uppercase | 300 pt | ≤120 pt |
| Settings row title | sans 12 medium | 252 pt, one line | ≤200 pt |
| Settings row detail | sans 9.7 | 252 pt, `lineLimit(2)` | one line ≤250 pt |
| Language detail | sans 9.7 | ~204 pt when `vi` is selected, `lineLimit(2)` | one line ≤200 pt |
| Section label | sans 8.7 demi-bold, 1.9 tracking | 300 pt | ≤100 pt |
| Update modes row | sans 9.5 per tab | section label + 3 tabs ≤292 pt | VI ≤180 pt of tabs |
| Update beta detail | sans 8.6 | 300 pt | one line ≤280 pt |

### 5.2 Measured high-risk anchors

All values are string widths in points at the stated font and size.

| Key | Limit | Vietnamese | Korean |
| --- | --- | --- | --- |
| `timer.title.idle` | 300 | `Sẵn sàng tập trung` 282.2 (94.1%) | `집중할 준비` 183.4 |
| `timer.title.running` | 300 | `Đang tập trung` 231.0 | `집중 중` 115.5 |
| `timer.title.paused` | 300 | `Tạm dừng` 157.6 | `일시 정지` 149.5 |
| `timer.title.short_break` | 300 | `Nghỉ ngắn` 160.7 | `짧은 휴식` 149.5 |
| `timer.title.long_break` | 300 | `Nghỉ dài` 132.9 | `긴 휴식` 115.5 |
| `timer.status.ends_at` | 300 | `Kết thúc lúc %@` 87.8 | `%@에 종료` 54.5 |
| `timer.status.paused_remaining` | 300 | `Tạm dừng · còn %@` 107.0 | `일시 정지 · %@ 남음` 94.3 |
| `timer.tip.keeps_running` | 300 | `Đóng cửa sổ này, đồng hồ vẫn chạy.` 159.0 | `이 창을 닫아도 타이머는 계속 실행됩니다.` 157.6 |
| `timer.action.start` | 140 | `Bắt đầu` 48.0 | `시작` 23.4 |
| `timer.action.pause` | 140 | `Tạm dừng` 63.6 | `일시 정지` 50.3 |
| `settings.focus.auto_break.detail` | 252 | `Bắt đầu giờ nghỉ đề xuất sau chuông tập trung.` 207.7 | `집중 알림음 후 추천 휴식을 시작합니다.` 149.2 |
| `settings.focus.auto_pomodoro.detail` | 252 | `Bắt đầu phiên tiếp theo khi nghỉ kết thúc.` 181.8 | `휴식이 끝나면 다음 집중을 시작합니다.` 146.6 |
| `settings.sound.tick.detail` | 252 | `Tiếng tích tắc nhẹ mỗi giây khi tập trung.` 179.8 | `집중 중에만 1초마다 작게 울립니다.` 133.3 |
| `settings.language.detail` | 204 | `Thay đổi áp dụng ngay.` 103.9 | `변경 사항은 즉시 적용됩니다.` 110.5 |
| `settings.quit` | footer | `Thoát Pomodoro` 92.3 | `Pomodoro 종료` 75.9 |
| `updates.mode.never.title` | row total 292 | `Không bao giờ` 65.2 (row total 238) | `안 함` (row total 150) |
| `updates.beta.detail` | 300 | `Bản thử nghiệm sẽ xuất hiện ở đây.` 136.8 | `정식 출시 전 테스트 버전이 여기에 표시됩니다.` 156.9 |

`settings.durations.value` (`%lld min`) is only an accessibility value. The
visible duration control shows the number alone; do not add a unit to the
visible label.

### 5.3 Candidate copy

Drafts for the high-risk surfaces. The team copy review described in 7.4 is
required before release; review must not lengthen a string past its budget.

| Key | Vietnamese | Korean |
| --- | --- | --- |
| `timer.title.idle` | `Sẵn sàng tập trung` | `집중할 준비` |
| `timer.title.running` | `Đang tập trung` | `집중 중` |
| `timer.title.paused` | `Tạm dừng` | `일시 정지` |
| `timer.title.short_break` | `Nghỉ ngắn` | `짧은 휴식` |
| `timer.title.long_break` | `Nghỉ dài` | `긴 휴식` |
| `timer.status.ends_at` | `Kết thúc lúc %@` | `%@에 종료` |
| `timer.status.paused_remaining` | `Tạm dừng · còn %@` | `일시 정지 · %@ 남음` |
| `timer.tip.keeps_running` | `Đóng cửa sổ này, đồng hồ vẫn chạy.` | `이 창을 닫아도 타이머는 계속 실행됩니다.` |
| `timer.tip.paused` | `Đóng cửa sổ này, phiên vẫn tạm dừng.` | `이 창을 닫아도 일시 정지는 유지됩니다.` |
| `timer.tip.rhythm` | `Tận hưởng nhịp tập trung.` | `집중의 리듬을 즐겨 보세요.` |
| `timer.mode.focus` | `Tập trung` | `집중` |
| `timer.mode.short_break` | `Nghỉ ngắn` | `짧은 휴식` |
| `timer.mode.long_break` | `Nghỉ dài` | `긴 휴식` |
| `timer.action.start` | `Bắt đầu` | `시작` |
| `timer.action.pause` | `Tạm dừng` | `일시 정지` |
| `settings.title` | `Cài đặt` | `설정` |
| `settings.subtitle` | `Một chiếc đồng hồ tĩnh lặng, không cần quản lý.` | `관리할 것 없는 조용한 타이머.` |
| `settings.focus.auto_break.title` | `Tự động bắt đầu nghỉ` | `휴식 자동 시작` |
| `settings.focus.auto_break.detail` | `Bắt đầu giờ nghỉ đề xuất sau chuông tập trung.` | `집중 알림음 후 추천 휴식을 시작합니다.` |
| `settings.focus.auto_pomodoro.title` | `Tự động bắt đầu tập trung` | `집중 자동 시작` |
| `settings.focus.auto_pomodoro.detail` | `Bắt đầu phiên tiếp theo khi giờ nghỉ kết thúc.` | `휴식이 끝나면 다음 집중을 시작합니다.` |
| `settings.sound.chime.title` | `Âm báo hoàn thành` | `완료 알림음` |
| `settings.sound.chime.detail` | `Hai nốt nhẹ khi kết thúc mỗi phiên.` | `구간이 끝나면 부드러운 두 음이 울립니다.` |
| `settings.sound.tick.title` | `Tiếng tích tắc` | `시계 소리` |
| `settings.sound.tick.detail` | `Tiếng tích tắc nhẹ mỗi giây khi tập trung.` | `집중 중에만 1초마다 작게 울립니다.` |
| `settings.menu_bar.minutes.title` | `Hiện số phút còn lại` | `남은 시간 표시` |
| `settings.menu_bar.minutes.detail` | `Ẩn giờ trên thanh menu khi tắt.` | `끄면 시계 시간이 숨겨집니다.` |
| `settings.language.title` | `Ngôn ngữ` | `언어` |
| `settings.language.detail` | `Thay đổi áp dụng ngay.` | `변경 사항은 즉시 적용됩니다.` |
| `settings.notifications.open` | `Mở Cài đặt` | `시스템 설정 열기` |
| `completion.action.done` | `Tạm xong` | `지금은 여기까지` |
| `settings.quit` | `Thoát Pomodoro` | `Pomodoro 종료` |
| `updates.panel.title` | `Cập nhật` | `업데이트` |
| `updates.dot.label` | `Tùy chọn cập nhật` | `업데이트 설정` |
| `updates.action.check_now` | `Kiểm tra ngay` | `지금 확인` |
| `updates.action.install` | `Cài đặt bản cập nhật` | `업데이트 설치` |
| `updates.action.later` | `Để sau` | `나중에` |
| `updates.section.automatic` | `TỰ ĐỘNG` | `자동` |
| `updates.mode.notify.title` | `Thông báo` | `알림` |
| `updates.mode.download.title` | `Tải xuống` | `다운로드` |
| `updates.mode.never.title` | `Không bao giờ` | `안 함` |
| `updates.beta.title` | `Bản beta` | `베타 업데이트` |
| `updates.beta.detail` | `Bản thử nghiệm sẽ xuất hiện ở đây.` | `정식 출시 전 테스트 버전이 여기에 표시됩니다.` |
| `notifications.focus.title` | `Đã xong phiên tập trung` | `집중 완료` |
| `notifications.focus.body` | `Đến giờ nghỉ.` | `휴식할 시간입니다.` |
| `notifications.break.title` | `Đã nghỉ xong` | `휴식 완료` |
| `notifications.break.body` | `Sẵn sàng tập trung tiếp?` | `집중할 시간입니다.` |
| `completion.action.take_break` | `Nghỉ %lld phút` | `%lld분 휴식하기` |
| `common.minutes_compact` | `%lld phút` | `%lld분` |

### 5.4 Terminology

| English | Vietnamese | Korean |
| --- | --- | --- |
| Focus | Tập trung | 집중 |
| Break | Nghỉ | 휴식 |
| Timer (the app object) | Đồng hồ | 타이머 |
| Settings | Cài đặt | 설정 |
| Appearance | Giao diện | 화면 스타일 |
| Sound | Âm thanh | 사운드 |
| Menu bar | Thanh menu | 메뉴 막대 |
| Notifications | Thông báo | 알림 |
| Updates | Cập nhật | 업데이트 |
| System | Hệ thống | 시스템 |
| Light | Sáng | 라이트 |
| Black | Đen | 블랙 |

Keep `Pomodoro` in Latin script inside translated sentences. Keep the existing
quiet, non-judgmental voice; no exclamation marks and no motivational slogans.
Use `…` for continuation. Vietnamese uses standard Vietnamese punctuation with
full diacritics; Korean does not insert a space between a number and its unit.

Vietnamese terminology rules:

- Use `đồng hồ` for the timer object everywhere. Do not introduce `hẹn giờ` as
  a competing noun.
- `kỳ nghỉ` means a vacation or leave period. Never use it for a Pomodoro break;
  use `giờ nghỉ` or the verb `nghỉ`.
- `Cài đặt` means both “settings” and “to install”. For an affordance that opens
  update settings, prefer `Tùy chọn cập nhật`; reserve `Cài đặt` + `bản cập nhật`
  for installing an update.

## 6. Layout and visual acceptance

### 6.1 Fixed geometry

- Timer card: 340×510 pt in every language, with 20 pt horizontal padding.
- Settings: 340 pt wide, content-measured height, minimum 592 pt, maximum 760 pt.
- Update panel: at most the existing 300 pt content width.
- No per-language size, scale, or spacing changes.

### 6.2 Slot preservation

Switching languages may change text width and wrap. It must not move:

- the dial, mode arrows, or mode dots;
- the 190×49 primary button and the 48 pt trailing end control;
- section hairlines, toggles, the language picker, or footer controls;
- the horizontal slot each Settings row reserves for its toggle and menu.

The language menu label is `.fixedSize()`. `Tiếng Việt` is about 7 pt wider than
`繁體中文`; the `Spacer(minLength: 8)` absorbs it by shrinking the text column
from about 215 pt to about 205 pt. The language detail still measures 103.9 pt
in Vietnamese and 110.5 pt in Korean, so it stays on one line and the row height
does not change.

### 6.3 No scrollbar in Settings

The Settings card must show its footer without a scroll indicator in every
locale, both themes, reduced transparency, and both notification states.
Vietnamese and Korean descriptions stay at or below the current maximum line
count — the English `settings.focus.auto_break.detail` already needs two lines,
while the Vietnamese draft is one line — so the measured height does not
increase. Any draft that would add a line must be shortened before merge.

### 6.4 Appearance

Light and Black, plus reduced transparency, must be checked in all six
languages. Colors, opacity, and surfaces do not change; only glyphs and metrics
do. Vietnamese diacritics must not collide with adjacent lines or the header;
Hangul must not fall back to a non-Myeongjo / non-SD-Gothic face.

## 7. Validation

### 7.1 Automated

- `swift test`.
- `./scripts/build-app.sh debug`, which must validate six locales and produce
  `vi.lproj` and `ko.lproj` for both tables.
- `UNIVERSAL=1 ./scripts/package-dmg.sh` for release packaging.
- The catalog validator must fail on a missing `vi` or `ko` value, an empty
  value, or a placeholder mismatch.

### 7.2 Manual language matrix

For each of the six languages, verify:

1. Idle (Focus, Short break, Long break), running, paused, completion, and end
   confirmation.
2. Settings with notifications allowed and denied, all theme choices, and the
   update panel open.
3. Light and Black, plus one reduced-transparency pass.
4. App menu, status-item menu, tooltip, menu-bar minutes, About copyright.
5. VoiceOver labels, values, hints, and the language-change announcement.
6. Switching language while a timer is running: interval unchanged, pending
   notification rescheduled in the new language.
7. Relaunch with an explicit selection: the selection persists.
8. macOS per-app language set to `vi` and `ko` with `System Default` active:
   applied on the next launch.

### 7.3 Picker and layout checks

- Order is System Default, English, 简体中文, 繁體中文, 日本語, Tiếng Việt,
  한국어.
- Autonyms are never translated.
- Timer geometry and Settings slots are unchanged across all six languages.
- Settings footer visible, no scrollbar, in all six languages and both
  notification states.

### 7.4 Copy review

All 146 runtime keys require an independent team cross-review for `vi` and
`ko`. There is no external professional native-speaker review for this release,
and the team must not claim native-speaker or professional certification.

Review rules:

- At least two team members review the `vi` and `ko` copy independently, in
  separate passes, before reconciling differences.
- Reviewers check translation accuracy, terminology consistency against 5.4,
  tone, punctuation, placeholders, and the point budgets in 5.1.
- Review each string in context at the real size in the built app, not only as
  an isolated catalog value. String-level checks do not catch a wrong noun or a
  misleading object (for example, a break called a vacation).
- An author may join the reconciliation but does not self-certify: at least one
  approver per locale must not have authored that copy.
- The release record and release notes must retain the limitation
  "no external native-speaker review" so the review depth is never overstated.

The review is still a release gate: the drafts in section 5.3 are design
placeholders for layout validation, not final copy. After review, re-run the
point budgets in 5.1.

## 8. Implementation touchpoints (informative)

For the implementer, the design requires changes in exactly these areas:

- `Sources/Pomodoro/Localization.swift`: two enum cases, autonyms, identifier
  primary-subtag matching.
- `Sources/Pomodoro/Views/Theme.swift`: exhaustive language switches for the
  sans and serif families, and the CJK tracking branch.
- `Resources/Info.plist`: `CFBundleLocalizations`.
- `Resources/Localization/Localizable.xcstrings` and `InfoPlist.xcstrings`.
- `scripts/check-localizations.swift` and `scripts/build-app.sh`: six supported
  locales and the `.lproj` verification loop.
- `TESTING.md`: six-language checklist entries.

No changes to `PomodoroCore`, timer math, persistence, notification scheduling
logic, or update logic are implied by the design. The existing runtime
re-localization path (menus, status item, pending notification) already covers
the new cases once the enum and catalog are complete.

## 9. Risks and open questions

1. **Palatino acceptance.** Using Palatino for Vietnamese is a visual decision.
   The alternative — keeping Iowan — produces mixed-typeface titles on the most
   common horned vowels and is rejected. Baskerville would shrink the title
   optically by about 18%.
2. **Copy review.** Vietnamese and Korean copy in this document is a layout
   draft. The release relies on independent team cross-review (7.4), not
   external native-speaker review. Final wording may change length; it must be
   re-measured against 5.1, and the release record must keep the
   "no external native-speaker review" limitation.
3. **Pixel evidence.** No `vi`/`ko` screenshots exist before implementation.
   The measurements here use the real fonts, sizes, and widths, but final visual
   acceptance happens on the built app.
4. **Visibility of units.** Do not surface `%lld min` in the visible duration
   control; it is accessibility-only.
5. **Sparkle.** Sparkle's own UI localization is out of scope; it follows the
   framework's shipped languages.

## 10. Design evidence

Measurements were taken with CoreText/AppKit on macOS 27.2.1 (26B131) using the
actual PostScript font names, point sizes, and available widths from the
current source. The full table, per-key verdicts, and candidate copy are in the
read-only assessment `VI-KO-UX-IMPACT.md` held with the design deliverable.
