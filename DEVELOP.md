# Developing Pomodoro

## Requirements

- macOS 15 or later.
- Xcode 16 or later with the Swift 6 toolchain.

## Development

Run the tests:

```sh
swift test
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

The app bundle is written to `build/Pomodoro.app`; packaged disk images are
written to `dist/`.

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
version tag starts the release workflow, which builds a universal app,
packages `Pomodoro.dmg`, and publishes it with generated release notes and a
SHA-256 checksum.

```sh
./scripts/bump-version.sh patch
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)
git add Resources/Info.plist
git commit -m "Bump version to $VERSION"
git tag -a "v$VERSION" -m "Pomodoro $VERSION"
git push origin main "v$VERSION"
```

The tag must match `CFBundleShortVersionString` in `Resources/Info.plist`.

## Code signing and notarization

By default, the workflow creates an ad-hoc signed build. macOS may warn users
on first launch; they can allow it in **System Settings → Privacy & Security**.

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
