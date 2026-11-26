# Developing Pomodoro

## Documentation map

- This file: local development, localization, updates, signing, and versioning.
- [`docs/development/testing.md`](docs/development/testing.md): release-only
  manual behavior checklist.
- [`docs/development/release-runbook.md`](docs/development/release-runbook.md):
  ordered release procedure, gates, and recovery.

## Requirements

- macOS 15 or later.
- Xcode 16 or later with the Swift 6 toolchain.

## Source layout

```
Sources/
  Pomodoro/
    App/           app lifecycle, menu-bar shell, popover hosting
    Features/      Timer, Settings, and Updates model/view code
    DesignSystem/  shared colors, typography, backgrounds, and components
    Services/      notifications and sound
    Localization/  language resolution and runtime string lookup
  PomodoroCore/    UI-independent timer domain and persistence
```

Place new app-layer files in the feature or shared area that owns them. Keep
`PomodoroCore` independent of AppKit, SwiftUI, notifications, sound, and
persistence side effects outside its own `Persistence/` area. Test files mirror
the production domain they cover.

## Development

Run the tests:

```sh
swift test
```

Before preparing a release, complete the release-only coverage checklist in
[`docs/development/testing.md`](docs/development/testing.md).

Resolve the exact Sparkle dependency after changing `Package.swift`:

```sh
swift package resolve
```

Build and launch a local app bundle:

```sh
./scripts/build-app.sh debug
open build/Pomodoro.app
```

Use `./scripts/build-app.sh release` for an optimized local build. To test
the release packaging step:

```sh
UNIVERSAL=1 ./scripts/package-dmg.sh
```

The app bundle is written to `build/Pomodoro.app`. Packaged disk images, update
archives, checksums, and appcasts are written to `dist/`.

## Localization

Supported locale identifiers are `en`, `zh-Hans`, `zh-Hant`, `ja`, `vi`, and
`ko`. English is the development language and fallback.
`CFBundleLocalizations` in `Resources/Info.plist` must list exactly those six
identifiers in that order.

Runtime strings live in `Resources/Localization/Localizable.xcstrings`.
Info.plist strings, currently `NSHumanReadableCopyright`, live in
`Resources/Localization/InfoPlist.xcstrings`. Both catalogs use English as
their source language and contain all six localizations.

Keys are semantic and grouped by surface: `common.*`, `menu.*`,
`status_bar.*`, `timer.*`, `completion.*`, `settings.*`,
`notification_status.*`, `notifications.*`, `updates.*`, `accessibility.*`,
`announcements.*`, and `errors.*`. `InfoPlist.xcstrings` uses the plist key
names directly, currently `NSHumanReadableCopyright`. Use whole sentences
rather than concatenating translated fragments. English count-bearing copy uses
String Catalog plural variations; Chinese, Japanese, Vietnamese, and Korean use
a single grammatical form.

Use `L10n.string`, `L10n.format`, or `L10n.count` from
`Sources/Pomodoro/Localization/Localization.swift` for all runtime copy,
including copy in SwiftUI views. Do not use a bare localized
`Text("semantic.key")` for runtime copy because SwiftUI literals keep the
language selected at launch and would not update with the in-app language
picker. Do not pass a localized fragment into an English sentence, and do not
use `Bundle.module`; the app bundle is assembled by `scripts/build-app.sh`.

The in-app picker stores an app-only override in `UserDefaults` under
`PomodoroLanguagePreference`. With no stored value, Pomodoro uses the macOS app
language captured at launch. `L10n` resolves strings from the matching
`.lproj` bundle, and `Typo` resolves the same active language so changing the
picker updates copy, typography, menus, and status-item accessibility without
a relaunch.

Vietnamese uses Avenir Next for interface text and Palatino for display
serifs. Korean uses Apple SD Gothic Neo for interface text and AppleMyungjo for
display serifs. Korean follows the CJK tracking rule (zero added tracking);
Vietnamese keeps the Latin tracking values. Do not change
`Typo.lineHeight`.

When changing language in `TimerModel`, rebuild the app menu, refresh the
status item, and reschedule the pending notification at the existing
`endDate`. Do not restart or alter the running timer. The standard About panel
is provided by AppKit and remains localized at launch; that limitation is
accepted.

`./scripts/build-app.sh` validates both catalogs before compiling, installs
compiled resources into each `.lproj` directory, and verifies the expected
`Localizable.strings` and `InfoPlist.strings` files before signing. Run the
validator directly with:

```sh
swift scripts/check-localizations.swift .
```

The validator fails on a missing locale, empty value, unsupported plural shape,
or format-placeholder mismatch. When adding or changing copy, update every
localized value and rerun the debug build.

The `zh-Hans`, `zh-Hant`, `ja`, `vi`, and `ko` catalogs are team-authored
drafts. For this release, at least two team members must review the Vietnamese
and Korean additions independently, and neither reviewer may approve copy they
authored. The Chinese and Japanese catalogs remain internal drafts. There is no
external native-speaker certification for any locale; do not claim
native-speaker or professional review. Record "team internal cross-review, no
external native-speaker certification" in the release record. Do not replace
unfinished translations with English placeholders.

Before a release:

- [ ] Independent team cross-review of the `vi` and `ko` catalogs is complete,
      and the release record states that no external native-speaker
      certification was performed.
- [ ] `swift scripts/check-localizations.swift .` passes.
- [ ] `./scripts/build-app.sh debug` installs all six localizations.
- [ ] The manual language matrix in the in-app language picker spec passes for
      all six languages, including Light, Black, and reduced-transparency
      appearances.

For normal QA, launch the app and change **Settings → Appearance → Language**
through all seven choices. Each change should apply immediately, preserve any
running timer, and survive a relaunch. To test the **System Default** path with
an explicit macOS language, first clear the app-only override, quit any running
instance, and launch the built app with:

```sh
defaults delete com.hb.pomodoro PomodoroLanguagePreference 2>/dev/null || true
pkill -x Pomodoro 2>/dev/null || true
while pgrep -x Pomodoro >/dev/null; do sleep 0.2; done
open build/Pomodoro.app --args --open-popover \
  -AppleLanguages '(zh-Hans)' -AppleLocale zh_CN
```

The `pkill` and wait lines are required. `open` activates an already-running
app and drops `--args`, so a stale instance keeps the previous language.

| Language | `-AppleLanguages` | `-AppleLocale` |
| --- | --- | --- |
| English | `(en)` | `en_US` |
| Simplified Chinese | `(zh-Hans)` | `zh_CN` |
| Traditional Chinese | `(zh-Hant)` | `zh_TW` |
| Japanese | `(ja)` | `ja_JP` |
| Vietnamese | `(vi)` | `vi_VN` |
| Korean | `(ko)` | `ko_KR` |

Replace `--open-popover` with `--open-settings` to open Settings directly.
These arguments use the same mechanism as the per-app language setting in
**System Settings → General → Language & Region → Applications**, which is the
system-language path described in the README. The macOS language is captured
at launch; external macOS language changes apply after reopening the app.

Use `--idle-mode=short` or `--idle-mode=long` with `--open-popover` to inspect
the idle break modes; the default is `focus`.

## Auto-updates

Pomodoro uses Sparkle 2.10.1 through SwiftPM. The exact dependency and
`Package.resolved` are committed together. The app uses Sparkle's standard
update UI. A small dot after the version in Settings signals that a release is
available and opens a compact update panel with three modes:

- **Notify** checks daily and asks before downloading an update.
- **Download** checks daily, downloads updates automatically, and installs
  them when Pomodoro quits.
- **Never** disables automatic checks. **Check Now** and **Check for Updates…**
  still work.

The dot stays neutral when updates are unavailable, no update is known, or
Pomodoro is current. It turns tomato when an update is available or ready to
install.

The feed URL is:

```text
https://github.com/hbin/Pomodoro/releases/latest/download/appcast.xml
```

Sparkle must be able to read this feed and the ZIP without authentication.
GitHub Releases on a private repository do not provide public download URLs, so
the repository must be public or the feed and update archive must be hosted at
a public URL.

### Beta channel

Pre-release builds ship through a second Sparkle channel named `beta`:

```text
https://github.com/hbin/Pomodoro/releases/download/beta/appcast.xml
```

That URL belongs to a rolling pre-release whose tag is `beta`. The release
workflow replaces its `appcast.xml` and update ZIP on every beta, so the URL
stays fixed. The stable and beta feeds never mix:

- `releases/latest` skips pre-releases, so stable users cannot see a beta item.
- Beta items carry `<sparkle:channel>beta</sparkle:channel>` and are only
  visible to an updater that allows the channel.
- When a stable release ships, the workflow also replaces the beta feed's
  appcast with the stable one, so beta testers roll onto the final build.

The first workflow run that publishes a release creates the `beta` release, so
the feed resolves even before the first beta exists. Local release bundles built
before that run have a switch that cannot check the channel.

**Settings → update dot → Beta updates** stores the opt-in in
`PomodoroBetaUpdates` and switches the feed through
`SPUUpdaterDelegate.feedURLString(for:)` and
`SPUUpdaterDelegate.allowedChannels(for:)`. The beta feed comes from
`SUBetaFeedURL`. Debug bundles remove `SUFeedURL`, `SUBetaFeedURL`, and
`SUPublicEDKey`, so the switch only appears in release builds and local debug
builds never check for updates.

Turning the switch off returns the stable feed but does not downgrade the
installed beta; the next stable release must use a higher `CFBundleVersion` to
replace it. The design record is
[`docs/superpowers/specs/2026-11-24-beta-channel.md`](docs/superpowers/specs/2026-11-24-beta-channel.md).

The EdDSA public key is stored as `SUPublicEDKey` in `Resources/Info.plist`.
Update metadata lives only in release bundles, so local debug builds show
updates as unavailable.

### Signing key and secret

The dedicated Sparkle key uses the keychain account `com.hb.pomodoro`. The
private key must never be committed or printed. The local backup is stored
outside the repository at:

```text
~/.config/pomodoro/sparkle-private-key
```

Keep that file at mode `600` in a directory at mode `700`, and keep a separate
off-machine backup. Losing this key means future releases cannot update
existing Sparkle installs. Do not rotate the key for routine releases.

The private key is also stored in the public repository's
`SPARKLE_PRIVATE_KEY` Actions secret. To restore the key on a new Mac:

```sh
.build/artifacts/sparkle/Sparkle/bin/generate_keys \
  --account com.hb.pomodoro \
  -f ~/.config/pomodoro/sparkle-private-key
.build/artifacts/sparkle/Sparkle/bin/generate_keys \
  --account com.hb.pomodoro \
  -p
```

The printed public key must match `SUPublicEDKey` in `Resources/Info.plist`.
The release workflow fails early when `SPARKLE_PRIVATE_KEY` is missing.

### Packaging an appcast

`scripts/package-dmg.sh` builds the app once and produces:

- `dist/Pomodoro.dmg` and `dist/Pomodoro.dmg.sha256` for manual installs.
- `dist/Pomodoro-VERSION.zip` and its `.sha256` for Sparkle.

After release notes are written, generate and verify the appcast:

```sh
./scripts/make-appcast.sh \
  --version 0.1.4 \
  --zip dist/Pomodoro-0.1.4.zip \
  --notes path/to/Pomodoro-0.1.4.md \
  --key-file ~/.config/pomodoro/sparkle-private-key \
  --output dist/appcast.xml
```

The script also accepts `VERSION`, `ZIP_PATH`, `NOTES_PATH`,
`SPARKLE_PRIVATE_KEY_FILE`, and `OUTPUT_PATH`. It signs the ZIP enclosure and
the feed, fails if either signature is missing, and verifies the feed with
`sign_update`.

### Verifying a published release

`scripts/verify-release.sh` compares a published release with its JSON release
manifest and prints one PASS/FAIL row per expectation:

```sh
./scripts/verify-release.sh --manifest path/to/<tag>.json
```

The manifest supplies every expected value, so the script never guesses: it
checks the release record, annotated tag, CI run, asset ids/sizes/SHA-256,
downloads, checksums, ZIP and DMG contents, bundle metadata, appcast fields,
both EdDSA signatures, the beta feed, `releases/latest`, and the rollback
anchor. All GitHub calls are GETs; nothing is written remotely. It needs `gh`
authentication and the Sparkle `sign_update` binary from `.build/artifacts`.

Exit codes are `0` pass, `1` usage/manifest error, `2` environment, network, or
unwritable report, `3` public URL failure, `4` asset mismatch, `5` artifact
failure, and `6` release/git/CI/feed mismatch. Useful flags:
`--check-manifest` validates the manifest offline, `--quiet` prints only
failures, and `--report FILE` keeps the table as TSV. `--grandfathered`
downgrades fields missing from the pre-freeze manifest to SKIP rows, but it is
accepted only for `v0.4.2` and marks the run as `GRANDFATHERED MODE` in the
table and TSV. When a newer release is already live, the live-feed checks
report SKIP because those URLs no longer describe the tag being audited.

For release evidence, write the report to
`outputs/verify-release/<tag>-verify.tsv` (team records) and record that file's
SHA-256 in the release manifest's `verification[]` or `note` field.

## Versioning

The public version and internal build live in `Resources/Info.plist`.
Bump them before packaging a release:

```sh
./scripts/bump-version.sh patch  # bug fixes and small adjustments
./scripts/bump-version.sh minor  # new features
./scripts/bump-version.sh major  # stable or breaking releases
./scripts/bump-version.sh build  # build number only
```

Beta builds use the same script:

```sh
./scripts/bump-version.sh beta minor  # 0.3.1 -> 0.4.0-beta.1
./scripts/bump-version.sh beta        # 0.4.0-beta.1 -> 0.4.0-beta.2
./scripts/bump-version.sh final       # 0.4.0-beta.2 -> 0.4.0
```

`beta` accepts `patch` (default), `minor`, or `major` to choose the base of a
new series. Every mode increments `CFBundleVersion`. Sparkle compares builds, so
the final release must keep a higher build number than every beta of the same
series; do not tag a final release that reuses a beta build number.

### README screenshots

`docs/assets/readme` is refreshed only when preparing a release, not with each UI
change. Rebuild the app, then quit Pomodoro and wait for the process to exit
before each launch; `open` drops the launch arguments when an instance is
already running:

```sh
./scripts/build-app.sh debug
pkill -x Pomodoro 2>/dev/null || true
while pgrep -x Pomodoro >/dev/null; do sleep 0.2; done
open build/Pomodoro.app --args --open-popover --force-light
# Capture docs/assets/readme/light-theme.png, then quit before the next launch.
pkill -x Pomodoro 2>/dev/null || true
while pgrep -x Pomodoro >/dev/null; do sleep 0.2; done
open build/Pomodoro.app --args --open-popover --force-dark
```

Capture the popover window with ⇧⌘4 then Space and replace
`docs/assets/readme/light-theme.png` and `docs/assets/readme/black-theme.png`. The
timer card is 340×510; downscale a Retina capture with `sips -z 510 340`
before replacing them. The committed screenshots are stale until the next
release.

## Automated releases

Releases are built and published automatically by GitHub Actions. Pushing a
version tag starts the release workflow, which builds a universal app once,
generates release notes, packages the DMG and Sparkle ZIP, signs the appcast,
and publishes all five assets with a generated summary and changelog.

The release job targets the protected `release` environment. A tag push
therefore pauses the workflow until the product owner approves the deployment
in GitHub; this is the machine-enforced GO gate. Pushes to `main` and pull
requests run the separate `CI` workflow, which runs `swift test`; a red CI run
blocks release preparation.

The annotated tag subject becomes the release summary. Keep it to one concise,
user-facing sentence. If the tag uses the default `Pomodoro X.Y.Z` message, the
workflow falls back to a capped list of commit subjects.

The tag must match `CFBundleShortVersionString` in `Resources/Info.plist`,
including a `-beta.N` suffix. The release must retain the asset name
`appcast.xml` so the `releases/latest/download/appcast.xml` URL resolves.

### Publishing a stable release

```sh
./scripts/bump-version.sh patch
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)
git add Resources/Info.plist
git commit -m "Bump version to $VERSION"
git tag -a "v$VERSION" -m "Describe this release in one concise sentence."
git push origin main "v$VERSION"
```

### Publishing a beta

```sh
./scripts/bump-version.sh beta minor
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)
git add Resources/Info.plist
git commit -m "Bump version to $VERSION"
git tag -a "v$VERSION" -m "Describe this beta in one concise sentence."
git push origin main "v$VERSION"
```

A `-beta.N` tag publishes a GitHub pre-release with the DMG, update ZIP,
checksums, and a channel-signed appcast. It also creates or refreshes the
rolling `beta` release that serves
`releases/download/beta/appcast.xml`; that feed is what the in-app switch reads.
The `beta` tag and release are permanent infrastructure for the channel: do not
delete them, because the download URL would stop resolving.

To promote a beta to a release, run `./scripts/bump-version.sh final`, commit,
and tag `vX.Y.Z` without the suffix. The workflow publishes a normal release and
points the beta feed at the new stable appcast.

## Code signing and notarization

By default, the workflow creates an ad-hoc signed build. macOS may warn users
on first launch; they can allow it in **System Settings → Privacy & Security**.
Sparkle verifies update archives and the appcast with EdDSA signatures, so
update authenticity does not depend on a paid Developer ID certificate.

For a warning-free download, add these repository secrets and re-run the
release from the Actions tab:

- `MACOS_CERTIFICATE`: base64-encoded Developer ID Application `.p12`.
- `MACOS_CERTIFICATE_PASSWORD`: password for the `.p12`.
- `APPLE_ID`: Apple Developer account email.
- `APPLE_TEAM_ID`: Apple Developer team ID.
- `APPLE_APP_PASSWORD`: an app-specific password for notarization.

To base64-encode the certificate for the `MACOS_CERTIFICATE` secret:

```sh
base64 -i DeveloperID.p12 | pbcopy
```

Bundled Sparkle code is signed innermost-first without `--deep`. The app also
has an `@executable_path/../Frameworks` runtime search path, and all temporary
absolute build paths are removed before signing.

## Migrating from 0.1.3

Pomodoro 0.1.3 and earlier do not contain Sparkle. Install the first
Sparkle-enabled release manually one time. Releases after that can update in
place through Sparkle, including when **Notify** or **Never** is selected via
manual checks.
