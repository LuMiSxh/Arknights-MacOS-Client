---
title: Testing architecture
description: Test levels, isolation boundaries, deterministic workflows, and release verification
order: 40
---

# Testing architecture

> [!IMPORTANT]
> The repository separates tests by dependency boundary. Unit and integration tests are deterministic and may run for every pull request. Live contracts are read-only probes of public services and run only through their dedicated scheduled or manually requested workflow.

## Test levels

| Level         | Command               | Scope                                                                                                                             | Public network |
| ------------- | --------------------- | --------------------------------------------------------------------------------------------------------------------------------- | -------------- |
| Unit          | `just check`          | Swift components, Python scripts, parsing, persistence, safety rules, and static checks                                           | Denied         |
| Integration   | `just integration`    | Fresh onboarding, real launcher API decoding, installer downloads, checksums, state persistence, and repeat runs against fixtures | Denied         |
| Live contract | `just live-contracts` | Current Yostar configuration, CDN, and manifest shapes for Global, Japan, and Korea                                               | Required       |

> [!IMPORTANT]
> `just ci` runs unit checks, deterministic integration tests, and the release Swift build. It never downloads the Wine runtime or game files and never launches the app or Wine. On a fresh checkout, uv and SwiftPM may resolve pinned development dependencies before test execution; the test processes themselves remain network-denied.

Repository scripts resolve from the root `pyproject.toml` and `uv.lock`. Python tests use `pytest` from the default development group, while DMG and compatibility builds opt into the separate `packaging` group. Swift levels are separate SwiftPM test targets:

- `ArknightsClientTests`
- `ArknightsClientIntegrationTests`
- `ArknightsClientLiveContractTests`

Integration and live-contract suites have explicit environment gates in addition to target filters. A plain `swift test` therefore cannot accidentally contact public services.

Choose the smallest level that proves the changed contract:

| Change                                                                                     | Add or update                                                                                             |
| ------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------- |
| A parser, state transition, path rule, persistence value, renderer, or controller decision | A focused test in `ArknightsClientTests` using local values and fixtures                                  |
| A flow crossing onboarding, API decoding, installation, progress, or persisted state       | `ArknightsClientIntegrationTests` with an isolated `IntegrationTestEnvironment` and `LocalFixtureNetwork` |
| A current Yostar endpoint, response shape, manifest, or signing contract                   | A live probe plus a deterministic fixture/regression test when the decoder changes                        |
| `runtime.json`, runtime provenance, or a candidate upstream runtime                        | `just check`, `just runtime-monitor`, and the scheduled/manual runtime workflow as applicable             |
| Website Markdown, Svelte UI, routes, or Mermaid                                            | `just check web` plus a production build; use a browser smoke check for visible behavior                  |

The Swift suites use the Swift Testing API (`import Testing`) rather than XCTest. Keep tests offline and fixture-backed unless the test is explicitly in the live-contract target. Do not add a second test runner for the website; it currently has no Vitest suite.

## Isolation contract

Swift unit and integration test execution runs inside the macOS sandbox with network access denied. SwiftPM builds test targets before entering that sandbox so a fresh runner may resolve the package's pinned source dependencies without granting network access to test code. Python unit tests use `pytest-socket` to reject socket and DNS access.

> [!WARNING]
> Each Swift test process receives temporary `HOME`, `CFFIXED_USER_HOME`, and `TMPDIR` directories. Workflow fixtures additionally inject temporary `AppPaths` roots and a unique `UserDefaults` suite. Tests must never use the user's application support directory, Wine prefix, game directories, runtime cache, or `dist/`.

HTTP behavior uses an ephemeral `URLSession` whose `URLProtocol` accepts only recorded fixture routes. An unknown URL fails the test instead of falling through to the internet. Fixtures must be small, deterministic, reviewable, and generated locally; downloaded game, runtime, and artwork files remain forbidden.

Static `URLProtocol` handlers require serialized suites and must be reset during cleanup. Equivalent behavior for Global, Japan, and Korea should be parameterized when the region changes the contract.

## Deterministic workflows

The initial workflow creates empty paths and preferences, presents onboarding, advances to Region & Install, and drives the real `LauncherViewModel`, `LauncherAPI`, and `GameInstaller` against fixture responses. It verifies the downloaded bytes, CRC64, installed-state file, progress, completed onboarding, persisted region/path, and a second no-op installation.

Future integration scenarios belong in the same level when they can use fixture runtimes or process doubles. Priorities include resumable and cancelled downloads across the launcher state model, compatibility reconciliation, prefix migration, region remapping, launch environment construction, process timeout and cancellation, and app-bundle packaging inspection.

The main-branch CI packaging smoke builds an app without a runtime. Complete runtime/DMG packaging remains in the release workflow because it downloads the pinned runtime and has a substantially larger time and disk budget.

## Website validation

Website checks are intentionally separate from `just ci`: the normal CI workflow runs `just ci`, while the Pages workflow runs the website check and static build only when Pages is manually dispatched or called by the release workflow. Documentation edits therefore need a local website check even when the native source suite is unchanged.

Run the focused checks from the repository root:

```sh
just format web
just check web
```

Run `just format web` only when you intend to accept Prettier's changes, then run the check. Validate content and prerendering with the same base path used by GitHub Pages:

```sh
cd web
BASE_PATH=/Arknights-MacOS-Client pnpm build
```

The build discovers Markdown files from `docs/` and `CHANGELOG.md`, so it catches missing frontmatter, duplicate routes or error codes, invalid local links and heading fragments, rejected `index.md` files, and broken prerendered routes. For a UI or Mermaid change, open representative light, dark, desktop, and mobile pages with `just dev web`; check navigation, active table-of-contents state, diagram fallback, and no horizontal overflow.

> [!NOTE]
> The website has no Vitest requirement. Type checking, Prettier, the static production build, and targeted browser checks are the current validation boundary.

## Failure triage

Start with the narrowest failing command and keep its first error intact in the report. A failing unit test should be fixed at the owning feature boundary; do not weaken an assertion merely to make a fixture pass. For a fixture-network failure, check the recorded URL, method, headers, response bytes, and cleanup of the `URLProtocol` handler before changing production code. For a live-contract failure, inspect the sanitized report and compare the upstream response shape before updating fixtures.

If a test needs a real runtime, a game download, a user preference directory, or public network access, it does not belong in the deterministic unit/integration path. Move it to the manual compatibility matrix or the explicitly gated live/runtime workflow and document the required setup.

Sparkle packaging checks run as part of the app smoke and release workflow. The app bundle must contain Sparkle.framework with its symlinks and nested XPC/helper code intact, an `@executable_path/../Frameworks` rpath, inside-out ad-hoc signatures, and a final outer-bundle verification. `SUPublicEDKey` is always read from the tracked `Resources/Info.plist` and must decode to exactly 32 bytes. The release workflow derives and compares that key with the protected `SPARKLE_ED25519_PRIVATE_KEY` seed, then signs `appcast.xml` through standard input. Manual release-candidate testing must install the DMG, start a newer signed update from the launcher, confirm the themed update UI and Sparkle download/restart flow, then repeat while a game or installation operation is active to verify that replacement is deferred.

## Live contracts

> [!NOTE]
> Live contracts perform safe read-only requests and make no local installation changes. They are separate from deterministic CI because service outages, rate limits, and upstream deployments must not make unrelated pull requests flaky. The dedicated workflow runs every Monday at 04:23 UTC; `workflow_dispatch` and `just live-contracts` provide deliberate manual execution.

Each run checks branding, game configuration, CDN configuration, manifest location, and the complete manifest for Global, Japan, and Korea through the production request signing and decoders. It requires credential-free HTTPS URLs, bounded response time and manifest size, safe non-conflicting paths, parseable CRC64 values, and nonnegative file sizes. Network and HTTP failures are retried three times; deterministic decoding and validation failures are not.

The probe writes a schema-versioned report containing only contract names, health states, ordinary version or file-count observations, and sanitized failure categories. Reports are retained as Actions artifacts for 30 days and rendered into the workflow summary. Authorization values and response bodies are never persisted.

> [!IMPORTANT]
> Scheduled alert reconciliation is isolated in a second job with `issues: write`; the probe itself has read-only repository access. A contract must fail in two consecutive scheduled reports before the workflow creates or reopens its single `automated` issue. An unchanged failure updates the issue timestamp without comment spam, a changed failure adds a comment, and two consecutive healthy reports add a recovery comment and close only the issue carrying that contract's private monitor marker. Manual runs never mutate issues.

Failures indicate that an external schema or endpoint may have changed. They do not automatically rewrite fixtures or production code. Review the sanitized report and upstream change, then update production decoding and recorded fixtures together.

## Runtime monitoring

> [!IMPORTANT]
> Runtime monitoring reads `runtime.json` as the pinned source of truth and never changes it. The dedicated workflow performs a metadata and provenance check every Wednesday at 05:37 UTC. A second schedule on the first day of each month downloads and independently hashes the pinned runtime archive; manual dispatch can request the same full verification. `just runtime-monitor` runs the metadata check locally, while `just runtime-monitor true` also verifies the approximately 460 MB archive.

The monitor ignores dappermint application-preview releases and selects the newest numeric Whisky release that actually contains `Libraries.tar.gz`. It requires an exact matching winecx-gptk recipe release, equal GitHub asset and checksum-file digests, a matching recipe tag and build commit, an explicit mirror-to-recipe link, and available pinned recipe and component commits. The small pinned build-recipe archive is downloaded and checked every run. Candidate comparisons summarize changed recipe pins, commits, and files without downloading the candidate runtime.

Scheduled runs maintain at most one open runtime-candidate issue and one source-availability issue, both carrying the `automated` label and private ownership markers. A newer candidate updates and reopens the existing candidate issue; the workflow never closes it without a maintainer decision. Availability incidents update their existing issue and close only after two healthy scheduled reports. Manual runs never mutate issues.

The normal probe job has read-only repository access. Issue writes are isolated in the reconciliation job, and the monitor persists only bounded, validated release metadata and sanitized summaries. It never publishes a release, edits the runtime pin, or treats a higher version number as approved.

## Manual compatibility matrix

> [!IMPORTANT]
> Real Wine and game behavior remains manual: fresh and upgraded prefixes, full install/update/repair, every login provider, Notices and payment pages, media playback, DXMT/Metal rendering, HiDPI, fullscreen and borderless modes, input, companion-window tracking, game exit, launcher termination, and Command-Q. Record the macOS version, chip, runtime revision, prefix history, scenario result, and sanitized logs for each release candidate.

For the launcher UI, use the debug `accessibility` developer scenario before release. With VoiceOver enabled, verify that Settings navigation, the music and version HUD controls, gallery items, document links, and modal Done actions expose meaningful labels and remain keyboard reachable. With Full Keyboard Access enabled, Tab must show a visible focus ring and move through the controls; Space activates the focused control, while Return only activates the focused/native control when macOS provides that behavior and must not trigger Play or Install globally. The focused primary action must remain focused as it changes between Play/Install, Pause, and Resume. Settings must scroll the focused row into view. Repeat with Reduce Motion, Reduce Transparency, Differentiate Without Color, and the largest practical text size. Switch the app to German and confirm that onboarding, Settings rows, gallery titles, documents, and popup actions wrap without clipping. Escape must dismiss Settings, galleries, and bundled documents. With one and multiple regions installed, verify that the Dock menu lists only those regions, disables Play during active operations, opens Settings once, and brings the launcher forward when a launch needs attention.
