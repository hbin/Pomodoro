# Beta Update Channel

**Feature design specification**

- Status: Approved
- Date: 2026-11-24
- Platform: macOS 15+

## Summary

Pomodoro publishes stable releases today. This change adds a second Sparkle
channel, **beta**, so test builds can auto-update before a release without
changing what stable users see.

The channel is opt-in from the update panel. Stable releases keep their current
tag-driven pipeline; a `-beta.N` tag publishes a pre-release and refreshes a
rolling beta feed.

Alpha builds stay local (`./scripts/build-app.sh debug`). There is no TestFlight
or Mac App Store path because the app is distributed outside the store.

## Terminology

| Name | Meaning | Here |
| --- | --- | --- |
| Development build | Unsigned or ad-hoc local build | `build-app.sh debug`, no feed |
| Beta | Feature-complete external test build | `0.4.0-beta.1`, channel `beta` |
| Stable | Public release | `0.4.0`, default channel |
| RC | Optional final beta | `-beta.N` is used instead of a new suffix |

## Versioning

- `CFBundleShortVersionString` is `MAJOR.MINOR.PATCH` or
  `MAJOR.MINOR.PATCH-beta.N`.
- The tag is always `v` plus that string.
- `CFBundleVersion` increases with every build. Sparkle compares builds, so the
  final release must have a higher build number than every beta of the series.
- `scripts/bump-version.sh` gains `beta [patch|minor|major]` and `final`.

## Feeds and channels

- Stable feed: `releases/latest/download/appcast.xml`. GitHub skips
  pre-releases for `latest`, so beta items can never reach stable users.
- Beta feed: `releases/download/beta/appcast.xml`, served by a permanent
  pre-release whose tag is `beta`. Every beta replaces its `appcast.xml` and
  update ZIP, so the URL is stable.
- Beta appcast items carry `<sparkle:channel>beta</sparkle:channel>`.
- When a stable release ships, its appcast is also uploaded to the `beta`
  release, so beta testers move to the final build.
- The first stable release after this change creates the `beta` release with the
  stable appcast if it does not exist yet, so the switch never reads a missing
  feed.

## App behavior

- `SUBetaFeedURL` in `Info.plist` provides the beta feed. Debug bundles remove
  it together with `SUFeedURL` and `SUPublicEDKey`.
- The update panel shows a **Beta updates** switch only when the beta feed and
  the updater are available.
- The opt-in is stored in `UserDefaults` under `PomodoroBetaUpdates`.
- `UpdateController` implements `feedURLString(for:)` and
  `allowedChannels(for:)`: enabled returns the beta feed and `["beta"]`;
  disabled returns the default feed and the default channel.
- Toggling the switch persists the choice, resets the update cycle, and starts a
  check when automatic checks are enabled. Availability is cleared so the dot
  does not show stale state.
- Turning the switch off does not downgrade an installed beta. The app returns
  to the stable feed and waits for a higher stable build.
- Language changes and timer behavior are unaffected.

## Release flow

```sh
./scripts/bump-version.sh beta minor   # 0.3.1 -> 0.4.0-beta.1
# commit, tag v0.4.0-beta.1, push
./scripts/bump-version.sh beta         # 0.4.0-beta.1 -> 0.4.0-beta.2
./scripts/bump-version.sh final        # 0.4.0-beta.2 -> 0.4.0
# commit, tag v0.4.0, push
```

The release workflow:

1. Validates the tag against the plist, including the beta suffix.
2. Runs `swift test`, builds one universal app, and packages the DMG and ZIP.
3. Signs a channel-aware appcast for betas, or the default appcast for stable
   releases.
4. For betas: refreshes the rolling `beta` release and publishes the tag as a
   pre-release. For stable: publishes a normal release and points the beta feed
   at the new appcast.

## Acceptance criteria

- A `-beta.N` tag publishes a pre-release and keeps `releases/latest` unchanged.
- The beta appcast contains the `beta` channel marker and signed enclosure, and
  its enclosure URL resolves on the rolling release.
- A stable release reuses a higher build number and updates the beta feed.
- Debug builds show no beta switch and never contact a feed.
- Release builds with `SUBetaFeedURL` show the switch in every supported
  language and both themes without clipping the update panel.
- Enabling beta checks the beta feed without touching a running timer.
- Disabling beta returns to the stable feed without reinstalling a lower build.

## Non-goals

- A separate app name, bundle identifier, or Dock presence for betas.
- Automated nightly or alpha publishing.
- Phased rollout, delta updates, or critical-update behavior.
- A custom Sparkle user driver.
