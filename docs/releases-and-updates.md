# Releases and updates

## User experience

Each release contains a complete Apple Silicon DMG with the launcher, Wine, DXMT, licenses, and an Applications shortcut. Arknights game files are never part of the DMG.

The launcher checks GitHub for a newer launcher version when it opens. If one exists, it links to the release page. Installation remains manual because the app is not Developer-ID signed or notarized. The check can be disabled in Settings.

Game updates are checked separately against Yostar. The check can also be disabled. A check never downloads game data by itself; the user starts the update.

## Creating a release

Run **Draft release** from the GitHub Actions page and enter a version in `X.Y.Z` form. The workflow rejects malformed versions, versions missing from `CHANGELOG.md`, and versions whose tag or release already exists.

It then:

1. formats and tests the source on an Apple Silicon macOS 26 runner;
2. downloads the pinned Wine + DXMT runtime and verifies its SHA-256;
3. downloads and verifies the matching source archive;
4. builds an arm64 app and DMG;
5. writes `SHA256SUMS`; and
6. creates a draft `vX.Y.Z` GitHub Release for review.

Required repository variables:

| Variable                | Contents                              |
| ----------------------- | ------------------------------------- |
| `RUNTIME_URL`           | Immutable HTTPS runtime archive URL   |
| `RUNTIME_SHA256`        | Runtime archive SHA-256               |
| `RUNTIME_SOURCE_URL`    | Matching Wine/DXMT source archive URL |
| `RUNTIME_SOURCE_SHA256` | Source archive SHA-256                |

Publish the draft only after installing its DMG on a clean Mac and testing Install, Update, Repair, and Play. Published assets and version tags are never replaced. A broken release is fixed with a higher version.

## Versioning and changelog

Versions follow Semantic Versioning. Before 1.0, minor versions may contain deliberate compatibility changes; patch versions contain compatible fixes. User-visible work is added to `Unreleased` during development and moved into a dated `X.Y.Z` section before running the release workflow.

## Signing limitation

The app is ad-hoc signed so its bundle is internally consistent, but it is not notarized. Users must confirm the first launch with right-click → **Open**. Developer ID and silent self-updates are intentionally outside the current plan.
