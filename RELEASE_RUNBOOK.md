# AI Release Runbook

Use this runbook for every Pomodoro release, version bump, tag, publication, or
release-repair request. It is the operating procedure for an AI agent.

`TESTING.md` owns the manual behavior checklist. `DEVELOP.md` owns the release
tooling reference. This file owns the order of operations, gates, and recovery
decisions. Do not duplicate those documents here.

## Start conditions

Start only when the user explicitly requests a release, version bump, tag, or
publication.

Stop and ask before proceeding when any of these is true:

- The worktree has unrelated changes that should not ship.
- The requested version conflicts with the next semantic version.
- The repository is private and the user has not authorized making it public.
- The release needs a new Sparkle key or a change to the public signing key.
- A GitHub release already exists for the version and the request implies
  replacing its tag.

## Release decisions

- Bug fixes only: patch, for example `0.4.0` to `0.4.1`.
- A completed feature cycle without breaking changes: minor, for example
  `1.2.3` to `1.3.0`.
- Breaking product or data changes: major. Ask before choosing this.
- A final build after beta builds must have a higher `CFBundleVersion` than
  every beta. Use `scripts/bump-version.sh final`.
- Use `scripts/bump-version.sh`; never edit the version fields by hand.
- The tag is exactly `v` plus `CFBundleShortVersionString`.
- The annotated tag subject is one concise, user-facing release summary. The
  workflow copies it into the GitHub release.

## Procedure

### 1. Preflight

Run:

```sh
git status --short --branch
git log --oneline -10
git tag --sort=-v:refname | head
./scripts/bump-version.sh --help
gh repo view --json visibility,isPrivate
gh secret list --json name
gh run list --workflow CI --branch main --limit 1
```

Read `TESTING.md`, including the release record and after-publishing section.
Read the release sections of `DEVELOP.md`. Execute every applicable pre-tag
item in `TESTING.md`; record exceptions instead of silently skipping them.

Done when:

- `main` matches `origin/main` and the worktree is clean.
- The next semantic version and build number are known.
- The repository is public.
- Required secrets are known. At minimum, `SPARKLE_PRIVATE_KEY` must exist.
- The latest `CI` run on `main` is green, or its failure is understood and does
  not affect the candidate.
- Every applicable pre-tag item in `TESTING.md` is checked or recorded as an
  exception with its reason.
- The team localization cross-review state is recorded. Do not claim external
  native-speaker certification that did not happen.

### 2. Validate the candidate

Run:

```sh
swift test
./scripts/build-app.sh debug
UNIVERSAL=1 CONFIG=release ./scripts/package-dmg.sh
```

Then verify:

```sh
plutil -extract CFBundleShortVersionString raw build/Pomodoro.app/Contents/Info.plist
plutil -extract CFBundleVersion raw build/Pomodoro.app/Contents/Info.plist
lipo -archs build/Pomodoro.app/Contents/MacOS/Pomodoro
codesign --verify --deep --strict --verbose=2 build/Pomodoro.app
cd dist
shasum -a 256 -c Pomodoro.dmg.sha256
shasum -a 256 -c "Pomodoro-$VERSION.zip.sha256"
unzip -t "Pomodoro-$VERSION.zip"
hdiutil verify Pomodoro.dmg
```

For UI changes, launch the built app and inspect the affected states in both
themes and all six languages. Refresh `docs/screenshots` only during release
preparation, following `DEVELOP.md`.

Done when:

- All tests pass, including the CI toolchain. A newer local Xcode does not
  prove compatibility with the macOS runner.
- The app bundle validates, is universal, and has the expected version, build,
  entitlements, and architecture.
- The DMG and ZIP pass checksum and archive validation.
- Release screenshots and release-only documentation are current.

### 3. Create the release commit

Run the semantic bump:

```sh
./scripts/bump-version.sh minor   # or patch/major/final
./scripts/build-app.sh debug
```

Review the diff and commit only release-owned changes:

```sh
git diff --check
git status --short
git add Resources/Info.plist docs/screenshots
git commit -m "Bump version to X.Y.Z"
```

Do not include `.build/`, `build/`, or `dist/`.

Done when the commit contains the intended version, build number, and release
assets, and the worktree is clean.

### 4. Tag and trigger the workflow

```sh
git tag -a vX.Y.Z -m "<one-sentence user-facing summary>"
git push origin main
git push origin vX.Y.Z
```

The tag push is the publication trigger. Do not create a GitHub release
manually.

The `release` job targets the protected `release` environment. After the tag
push, the run pauses at `Waiting for review`; the product owner must approve
the deployment in GitHub before tests, packaging, or publication can start. An
agent must not try to bypass this gate.

Done when the tag exists remotely, a new `Release` workflow run starts for that
tag, and it is waiting for environment approval.

### 5. Monitor CI

```sh
gh run list --workflow Release --limit 3
gh run watch <RUN_ID> --exit-status --interval 15
gh run view <RUN_ID> --log-failed
```

If the run is waiting for the `release` environment, ask the product owner to
approve it. Do not rerun the workflow to skip the gate.

Done when the workflow succeeds through tests, packaging, appcast signing,
checksum refresh, and publication.

### 6. Verify publication

Set the release variables from the tagged commit, then run:

```sh
VERSION="$(plutil -extract CFBundleShortVersionString raw Resources/Info.plist)"
TAG="v$VERSION"
gh release view "$TAG" --json name,tagName,isDraft,isPrerelease,body,assets
gh release list --limit 5

for url in \
  "https://github.com/hbin/Pomodoro/releases/latest/download/appcast.xml" \
  "https://github.com/hbin/Pomodoro/releases/download/$TAG/Pomodoro-$VERSION.zip" \
  "https://github.com/hbin/Pomodoro/releases/download/$TAG/Pomodoro-$VERSION.zip.sha256" \
  "https://github.com/hbin/Pomodoro/releases/download/$TAG/Pomodoro.dmg" \
  "https://github.com/hbin/Pomodoro/releases/download/$TAG/Pomodoro.dmg.sha256"; do
  curl -fsSL -o /dev/null -w "%{http_code} $url\n" "$url"
done
```

Download the public artifacts and verify them:

```sh
.build/artifacts/sparkle/Sparkle/bin/sign_update \
  --verify --account com.hb.pomodoro appcast.xml
shasum -a 256 -c "Pomodoro-$VERSION.zip.sha256"
shasum -a 256 -c Pomodoro.dmg.sha256
```

Extract `sparkle:edSignature` from the appcast enclosure and verify the ZIP
with the same `sign_update` command:

```sh
SIGNATURE="$(python3 - <<'PY'
import xml.etree.ElementTree as ET

namespace = "{http://www.andymatuschak.org/xml-namespaces/sparkle}edSignature"
item = ET.parse("appcast.xml").getroot().find("./channel/item")
print(item.find("enclosure").attrib[namespace])
PY
)"
.build/artifacts/sparkle/Sparkle/bin/sign_update \
  --verify --account com.hb.pomodoro "Pomodoro-$VERSION.zip" "$SIGNATURE"
```

Also verify:

- The stable release is the latest non-prerelease.
- All five assets exist and are uploaded.
- The appcast contains the expected version, build, download URL, length, and
  signatures.
- The beta feed serves the same stable appcast after a stable release.
- The GitHub body starts with the tag summary and includes the Full Changelog.
- The public unauthenticated API resolves
  `repos/hbin/Pomodoro/releases/latest`.

Done when every public URL returns `200`, both SHA-256 checks pass, both EdDSA
signatures verify, and the beta feed points at the published build.

### 7. Install and launch check

Do this when the user requested installation or hands-on verification.

1. Quit every Pomodoro process and wait for exit.
2. Mount the downloaded DMG read-only.
3. Confirm the mounted app version, build, architecture, and signature.
4. Move the installed app to Trash with a versioned backup name.
5. Copy the mounted app to `/Applications/Pomodoro.app`.
6. Clear quarantine only on the local test install when the build is ad hoc.
7. Launch the installed app and confirm it stays running.
8. Confirm Settings shows the released version.

Preserve the user's app preferences. Replace the app bundle only; do not reset
the container.

Done when the installed app matches the release version and build, launches,
and exposes the expected update controls.

## Failure recovery

| Failure | Action |
| --- | --- |
| Tests fail before any GitHub release exists | Fix the root cause on `main`, rerun all gates, move the local tag to the final release commit, then force-push that tag. Confirm `gh release view` still returns not found before moving it. |
| Tests fail after a GitHub release exists | Never rewrite the published tag. Land the fix and publish the next patch version. |
| Public downloads return `404` | Check repository visibility first. A private repository makes every release and appcast URL inaccessible. Recheck after changing visibility. |
| Workflow is queued with no runner or steps | This is infrastructure, not a code failure. Rerun the same workflow. macOS runner queues can exceed 15 minutes. |
| Workflow fails after uploading some assets | Rerun the same tag workflow. The workflow uses `--clobber` and is designed to repair partial publication. |
| Signing and notarization steps are skipped | If `MACOS_CERTIFICATE`, `MACOS_CERTIFICATE_PASSWORD`, `APPLE_ID`, `APPLE_TEAM_ID`, or `APPLE_APP_PASSWORD` is absent, the build is ad hoc. Report that Gatekeeper may require Open Anyway; do not claim notarization. |
| Local build passes but CI fails to compile | Use the CI error as authoritative. Prefer Swift syntax supported by the package's Swift 6.0 toolchain. For `Animatable` conformances, `@preconcurrency` is compatible when `@MainActor` on the conformance is not. |
| The tag or release summary is wrong and nothing was published | Fix the tag locally, force-push it, and verify the new workflow run. |

## Final report

Report these facts:

- Version, build, release URL, and whether it is latest.
- Tests and local packaging result.
- Public URL, checksum, and signature verification result.
- Whether the beta feed was updated.
- Installed version and launch result, if installation was requested.
- Repository visibility.
- Signing/notarization status and any missing secrets.
- Any release exception, including the team cross-review limitation and the
  absence of external native-speaker certification.

Do not claim a check passed unless the command output or UI inspection showed
it passing.
