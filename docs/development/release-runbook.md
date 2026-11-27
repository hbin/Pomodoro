# AI Release Runbook

Use this runbook for every Pomodoro release, version bump, tag, publication, or
release-repair request. It is the operating procedure for an AI agent.

[`testing.md`](testing.md) owns the manual behavior checklist.
[`DEVELOP.md`](../../DEVELOP.md) owns the release tooling reference. This file
owns the order of operations, gates, and recovery decisions. Do not duplicate
those documents here.

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

Read [`testing.md`](testing.md), including the release record and after-publishing
section. Read the release sections of [`DEVELOP.md`](../../DEVELOP.md). Execute
every applicable pre-tag item in [`testing.md`](testing.md); record exceptions
instead of silently skipping them.

Done when:

- `main` matches `origin/main` and the worktree is clean.
- The next semantic version and build number are known.
- The repository is public.
- `SPARKLE_PRIVATE_KEY` exists. A stable release also requires
  `MACOS_CERTIFICATE`, `MACOS_CERTIFICATE_PASSWORD`, `APPLE_ID`,
  `APPLE_TEAM_ID`, and `APPLE_APP_PASSWORD`. A beta release may omit the five
  Developer ID/notary values only as a complete set; partial configuration is
  rejected.
- The latest `CI` run on `main` is green, or its failure is understood and does
  not affect the candidate.
- Every applicable pre-tag item in [`testing.md`](testing.md) is checked or
  recorded as an exception with its reason.
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
themes and all six languages. Refresh `docs/assets/readme` only during release
preparation, following [`DEVELOP.md`](../../DEVELOP.md).

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
git add Resources/Info.plist docs/assets/readme
git commit -m "Bump version to X.Y.Z"
```

Do not include `.build/`, `build/`, or `dist/`.

Done when the commit contains the intended version, build number, and release
assets, and the worktree is clean.

### 4. Tag and start the protected build

```sh
git tag -a vX.Y.Z -m "<one-sentence user-facing summary>"
git push origin main
git push origin vX.Y.Z
```

The tag must be annotated. Its peeled commit must be reachable from
`origin/main`. The tag push runs read-only `preflight` and `build` jobs; neither
uses the protected environment, so the build can complete and expose the exact
artifact digest. Do not create a GitHub release manually.

Stable builds fail before producing an artifact when any Developer ID or notary
secret is missing. Beta builds are ad-hoc only when all five Developer
ID/notary secrets are absent; if they are present they use the same signed path.
Partial beta configuration fails.

Done when the annotated tag exists remotely, its peeled commit is on `main`, and
the `preflight` and `build` jobs pass.

### 5. Approve the exact stable digest

For a stable release:

1. Open the successful `Release` run and read `DMG SHA-256` from the `build`
   job's **Release artifacts ready** summary.
2. Set the repository variable to that exact value:

   ```sh
   DIGEST="<paste the 64-character DMG SHA-256>"
   gh variable set RELEASE_APPROVED_DIGEST --body "$DIGEST"
   ```

3. In GitHub, approve the `release` environment deployment for the `publish`
   job.

The `publish` job downloads the same recorded Actions artifact, recomputes every
digest, verifies the signatures and notarization, and only then creates,
uploads, and publishes a draft release. A missing or mismatched
`RELEASE_APPROVED_DIGEST` stops before any release mutation. Do not rebuild
between digest approval and publication.

Beta releases do not use `RELEASE_APPROVED_DIGEST`, but their `publish` job still
requires the protected `release` environment approval.

Done when the stable variable equals the build summary digest and the `publish`
deployment is approved. If the build was rerun, copy the new digest and set the
variable again.

### 6. Monitor the publish gate

```sh
gh run list --workflow Release --limit 3
gh run watch <RUN_ID> --exit-status --interval 15
gh run view <RUN_ID> --log-failed
```

If the run is waiting for the `release` environment, ask the product owner to
approve it only after the stable digest has been set. Do not rerun the workflow
to skip the gate.

Done when `publish` succeeds through artifact verification, draft upload, and
publication without rebuilding.

### 7. Verify publication

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
- The stable DMG SHA-256 equals `RELEASE_APPROVED_DIGEST`.
- The appcast contains the expected version, build, download URL, length, and
  signatures.
- The beta feed serves the same stable appcast after a stable release.
- The GitHub body starts with the tag summary and includes the Full Changelog.
- A stable release identifies Developer ID signing and stapled notarization. A
  beta ad-hoc release says `Signing: ad-hoc` in both the body and the workflow
  summary.
- The public unauthenticated API resolves
  `repos/hbin/Pomodoro/releases/latest`.

Done when every public URL returns `200`, both SHA-256 checks pass, both EdDSA
signatures verify, and the beta feed points at the published build.

### 8. Install and launch check

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
| Stable preflight reports missing signing/notary secrets | Stop before build. Add the missing repository secrets through the separately authorized credential process, then rerun the tag workflow. Never substitute an ad-hoc stable build. |
| Tag is lightweight, off `main`, malformed, or mismatches the plist | Stop. Do not bypass preflight or create a release manually. If nothing was published, correct the tag only through an explicitly authorized tag-repair action. |
| Build or tests fail before any GitHub release exists | Fix the root cause on `main`; after review, tag the corrected commit through the normal authorized flow. Do not rewrite a pushed tag without explicit CEO approval. |
| Build or tests fail after a GitHub release exists | Never rewrite the published tag. Land the fix and publish the next patch version. |
| Stable publish is blocked by `RELEASE_APPROVED_DIGEST` | Copy the DMG SHA-256 from the same successful build summary, update `RELEASE_APPROVED_DIGEST`, and rerun only the failed `publish` job. Do not rerun `build`; a rerun creates a new artifact and digest. |
| Public downloads return `404` | Check repository visibility first. A private repository makes every release and appcast URL inaccessible. Recheck after changing visibility. |
| Workflow is queued with no runner or steps | This is infrastructure, not a code failure. Rerun the same workflow. macOS runner queues can exceed 15 minutes. |
| Publish fails after uploading some assets | The release is still a draft. Rerun only `publish` against the same artifact; it updates draft assets with `--clobber` before publishing. If the whole workflow is rerun, set `RELEASE_APPROVED_DIGEST` to the new build digest first. |
| Stable signing or notarization is missing | Stable is fail-closed: do not publish and do not claim notarization. Beta may produce an ad-hoc artifact only when all five Developer ID/notary secrets are absent, and both notes and summary must say `Signing: ad-hoc`. |
| Publish reports a digest, signature, staple, `spctl`, ZIP, or DMG verification failure | Stop before release mutation. Rebuild only after fixing the cause, then approve the new digest. Never replace the artifact in place. |
| Local build passes but CI fails to compile | Use the CI error as authoritative. Prefer Swift syntax supported by the package's Swift 6.0 toolchain. For `Animatable` conformances, `@preconcurrency` is compatible when `@MainActor` on the conformance is not. |
| The tag or release summary is wrong and nothing was published | Stop and obtain explicit approval for tag repair; then verify a fresh preflight/build. Never rewrite a published release. |

## Final report

Report these facts:

- Version, build, release URL, and whether it is latest.
- Tests and local packaging result.
- Public URL, checksum, and signature verification result.
- The approved `RELEASE_APPROVED_DIGEST` and whether it matched the published
  DMG.
- Whether the beta feed was updated.
- Installed version and launch result, if installation was requested.
- Repository visibility.
- Signing/notarization status, including app and DMG stapling, and any missing
  secrets.
- Any release exception, including the team cross-review limitation and the
  absence of external native-speaker certification.

Do not claim a check passed unless the command output or UI inspection showed
it passing.
