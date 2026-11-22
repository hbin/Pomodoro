# Developing Pomodoro

## Requirements

- macOS 15 or later.
- Xcode 16 or later with the Swift 6 toolchain.

## Development

Run the tests:

```sh
swift test
```

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

The EdDSA public key is stored as `SUPublicEDKey` in `Resources/Info.plist`.
Debug bundles remove both `SUFeedURL` and `SUPublicEDKey`, so local debug builds
show updates as unavailable.

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

## Versioning

The public version and internal build live in `Resources/Info.plist`.
Bump them before packaging a release:

```sh
./scripts/bump-version.sh patch  # bug fixes and small adjustments
./scripts/bump-version.sh minor  # new features
./scripts/bump-version.sh major  # stable or breaking releases
./scripts/bump-version.sh build  # build number only
```

## Automated releases

Releases are built and published automatically by GitHub Actions. Pushing a
version tag starts the release workflow, which builds a universal app once,
generates release notes, packages the DMG and Sparkle ZIP, signs the appcast,
and publishes all five assets with a generated summary and changelog.

The annotated tag subject becomes the release summary. Keep it to one concise,
user-facing sentence. If the tag uses the default `Pomodoro X.Y.Z` message, the
workflow falls back to a capped list of commit subjects.

```sh
./scripts/bump-version.sh patch
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)
git add Resources/Info.plist
git commit -m "Bump version to $VERSION"
git tag -a "v$VERSION" -m "Describe this release in one concise sentence."
git push origin main "v$VERSION"
```

The tag must match `CFBundleShortVersionString` in `Resources/Info.plist`.
The release must retain the asset name `appcast.xml` so the
`releases/latest/download/appcast.xml` URL resolves.

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
