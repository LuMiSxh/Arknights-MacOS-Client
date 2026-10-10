---
title: Testing architecture
description: Test levels, isolation boundaries, deterministic workflows, and release verification
order: 40
---

# Testing architecture

> [!IMPORTANT]
> Unit and integration tests are deterministic and can run for every pull request. Live contracts are read-only probes of public services and run only through their scheduled or manual workflow.

## Test levels

| Level         | Command               | Scope                                                                                                                  | Public network |
| ------------- | --------------------- | ---------------------------------------------------------------------------------------------------------------------- | -------------- |
| Unit          | `just check`          | Swift components, Python scripts, parsing, persistence, safety rules, and static checks                                | Denied         |
| Integration   | `just integration`    | Onboarding, launcher API decoding, installer downloads, checksums, state persistence, and repeat runs against fixtures | Denied         |
| Live contract | `just live-contracts` | Current Yostar configuration, CDN, and manifest shapes; Gryphline Taiwan metadata and CDN contract                     | Required       |

> [!IMPORTANT]
> `just ci` runs unit checks, deterministic integration tests, and the release Swift build. It never downloads the Wine runtime or game files and never launches the app or Wine. On a fresh checkout, uv and SwiftPM can resolve pinned dependencies before tests run; test processes stay network-denied.

Scripts resolve from the root `pyproject.toml` and `uv.lock`. Python tests use `pytest` from the default group. DMG and compatibility builds use the `packaging` group. Swift levels are SwiftPM test targets: `ArknightsClientTests`, `ArknightsClientIntegrationTests`, and `ArknightsClientLiveContractTests`. Integration and live-contract suites also have environment gates, so a plain `swift test` cannot contact public services.

Use the smallest level that proves the changed contract:

| Change                                                                                   | Add or update                                                                                             |
| ---------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| Parser, state transition, path rule, persistence value, renderer, or controller decision | A focused test in `ArknightsClientTests` using local values and fixtures                                  |
| Flow across onboarding, API decoding, installation, progress, or persisted state         | `ArknightsClientIntegrationTests` with an isolated `IntegrationTestEnvironment` and `LocalFixtureNetwork` |
| Yostar or Gryphline endpoint, response shape, manifest, or signing contract              | A live probe, plus a fixture regression test when the decoder changes                                     |
| `runtime.json` or a new packaged runtime release                                         | `just check`, `just runtime`, and the manual compatibility matrix                                         |
| Website Markdown, Svelte UI, routes, or Mermaid                                          | `just check web`, a production build, and a browser smoke check for visible behavior                      |

Swift suites use Swift Testing (`import Testing`), not XCTest. Keep tests offline and fixture-backed unless they are in the live-contract target. Do not add a test runner for the website; it has no Vitest suite.

## Focused tests

Run `just test FILTER` to run a group of Swift unit tests. `FILTER` is a regular expression. The recipe runs only the unit tests whose names match `FILTER`.

```bash
just test GameInstaller
just test 'InstallerDirectory|GameInstallerRollback'
```

- Use `just test` while you change code.
- Run `just ci` before you finish.
- `just test` does not run integration or live-contract tests.

## Isolation contract

Swift unit and integration tests run in the macOS sandbox with network denied. SwiftPM builds test targets before it enters the sandbox. Python unit tests use `pytest-socket` to reject socket and DNS access.

> [!WARNING]
> Each Swift test process gets temporary `HOME`, `CFFIXED_USER_HOME`, and `TMPDIR` directories. Workflow fixtures also inject temporary `AppPaths` roots and a unique `UserDefaults` suite. Tests must never use the user's application support directory, Wine prefix, game directories, runtime cache, or `dist/`.

HTTP tests use an ephemeral `URLSession` whose `URLProtocol` accepts only recorded fixture routes. An unknown URL fails the test. Fixtures must be small, deterministic, reviewable, and generated locally. Downloaded game, runtime, and artwork files stay forbidden.

Static `URLProtocol` handlers need serialized suites and a cleanup reset. Parameterize equivalent Global, Japan, Korea, and Taiwan behavior when the region changes the contract.

## Deterministic workflows

The initial workflow starts with empty paths and preferences, presents onboarding, advances to Region & Install, and drives the real `LauncherViewModel`, `LauncherAPI`, and `GameInstaller` against fixtures. It verifies downloaded bytes, provider checksum, installed-state file, progress, completed onboarding, persisted region and path, and a second no-op installation.

Add scenarios to this level when they can use fixture runtimes or process doubles. Priorities: resumable and cancelled downloads, compatibility reconciliation, prefix migration, region remapping, launch environment construction, process timeout and cancellation, and app-bundle packaging inspection. App and DMG packaging run only in the release workflow.

## Website validation

Website checks are separate from `just ci`. The Pages workflow runs them only when dispatched manually or called by the release workflow, so documentation edits need a local check.

```sh
just format web
just check web
```

Run `just format web` only to accept Prettier's changes. Validate content and prerendering with the Pages base path:

```sh
cd web
BASE_PATH=/Arknights-MacOS-Client pnpm build
```

The build reads `docs/` and `CHANGELOG.md` and checks frontmatter, duplicate routes or error codes, links and fragments, exact canonical and social URLs, hidden navigation, active-page accessibility metadata, external-link safety, and every prerendered route under the deployment base path. For a UI or Mermaid change, open light, dark, desktop, and mobile pages with `just dev web`. Check navigation, active table-of-contents state, diagram fallback, and horizontal overflow.

> [!NOTE]
> The website has no Vitest requirement. Validation is type checking, Prettier, the static build, and targeted browser checks.

## Failure triage

Start with the narrowest failing command and keep its first error in the report.

- Unit test: fix it at the owning feature boundary. Do not weaken an assertion to pass a fixture.
- Fixture network: check the recorded URL, method, headers, response bytes, and `URLProtocol` cleanup before you change production code.
- Live contract: inspect the sanitized report and compare the upstream response shape before you update fixtures.

A test that needs a real runtime, game download, user preference directory, or public network does not belong in the deterministic path. Move it to the manual matrix or a gated workflow and document the setup.

The release workflow checks that the bundle contains Sparkle.framework with symlinks and nested XPC/helper code intact, an `@executable_path/../Frameworks` rpath, inside-out ad-hoc signatures, and a final outer-bundle verification. `SUPublicEDKey` comes from the tracked `Resources/Info.plist` and must decode to exactly 32 bytes. The workflow derives that key from the protected `SPARKLE_ED25519_PRIVATE_KEY` seed, compares the two, and signs `appcast.xml` through standard input. For a release candidate, install the DMG, start a newer signed update from the launcher, and confirm the themed update UI and the download and restart flow. Repeat during an active game or installation to verify that replacement is deferred.

## Live contracts

> [!NOTE]
> Live contracts send read-only requests and change nothing locally. They stay out of CI so outages, rate limits, and upstream deployments cannot make unrelated pull requests flaky. The workflow runs every Monday at 04:23 UTC; `workflow_dispatch` and `just live-contracts` run it manually.

Each run checks branding, game configuration, CDN configuration, manifest location, and the complete manifest for Global, Japan, and Korea through the production request signing and decoders. For Taiwan it checks only Gryphline branding, metadata, and CDN hosts, never the encrypted game manifest or a game package. It requires credential-free HTTPS URLs, bounded response time and manifest size, safe non-conflicting paths, parseable CRC64 or MD5 values, and nonnegative file sizes. It retries network and HTTP failures three times, not decoding or validation failures.

The probe writes a schema-versioned report with only contract names, health states, version or file-count observations, and sanitized failure categories. Actions keeps it as an artifact for 30 days and in the summary. It never persists authorization values or response bodies.

> [!IMPORTANT]
> A second job with `issues: write` reconciles scheduled alerts. The probe itself has read-only repository access.
>
> - A contract must fail in two consecutive scheduled reports before the workflow creates or reopens its single `automated` issue.
> - An unchanged failure updates the issue timestamp without a comment. A changed failure adds a comment.
> - Two consecutive healthy reports add a recovery comment and close only the issue with that contract's private monitor marker.
> - Manual runs never change issues.

A failure means an external schema or endpoint may have changed. Nothing rewrites fixtures or code automatically. Review the report and the upstream change, then update decoding and fixtures together.

## Runtime ownership

> [!IMPORTANT]
> The Arknights macOS Runtime repository owns upstream source monitoring, source pins, patch application, and runtime release construction. This repository owns the client-selected runtime release and validates its archive contract through `runtime.json`.

Runtime source checks do not run in client CI and never rewrite `runtime.json`. When you promote a runtime release, update the URL, checksum, versions, source provenance, required layout, and prefix revision as one reviewed change. `just runtime update TAG` rewrites the release-derived fields; see [Runtime updates](runtime-updates.md). `just runtime` then downloads and hashes the archive, extracts it safely, and validates its executable and DXMT layout. The release workflow packages only that runtime. It never chooses among channels or combines independently updated Wine and DXMT components.

## Manual compatibility matrix

> [!IMPORTANT]
> Unit and integration tests use fixtures and never launch Wine or the game, so they do not establish platform compatibility. Real game and macOS checks stay pending until someone runs them on the release candidate. Record the client commit, runtime revision or archive hash, macOS version, chip, prefix history, result, and sanitized logs. Change a result from **Pending** only after you observe that exact case.

Use this checklist for each release candidate. Keep separate notes per region, macOS version, and Canary setting combination.

| Check                             | Procedure                                                                                                                                                                                                                                                                                             | Result  |
| --------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------- |
| Fresh prefix                      | New Wine prefix: install a stable client, launch, sign in, open and close Notices, exit the game and launcher.                                                                                                                                                                                        | Pending |
| Existing prefix                   | Launch from an initialized prefix after you update or repair the game. Repeat for Global, Japan, and Korea, including sign-in, Notices, and focus switches between game and helper windows.                                                                                                           | Pending |
| Mac pointer                       | Play with **Pointer** set to **Your Mac's pointer** and to **Arknights' cursor**. Record cursor behavior, region, and runtime.                                                                                                                                                                        | Pending |
| Picture modes and sizes           | On a Retina display, play one fight with each **Picture** choice at one **Window size**, windowed and fullscreen at **Full detail**. Confirm the window keeps its size, fullscreen fills the display with the menu bar. Record FPS, frame pacing, text sharpness, and runtime.                        | Pending |
| Window size choices               | On a 16:10 and a 16:9 display, use **Fill my screen** and **Leave room for other apps**. Confirm the window fits above the Dock with its title bar visible and no letterboxing artifacts.                                                                                                             | Pending |
| Audio route changes               | Change the macOS output device before launch, during game and music, and after exit. Record whether game audio and launcher music recover.                                                                                                                                                            | Pending |
| Other installation and game paths | Full install, update, and repair. Sign-in helpers (including embedded), Notices and payment pages where available, media playback, DXMT/Metal rendering, HiDPI, fullscreen and borderless modes, input, companion-window tracking, Command-Q.                                                         | Pending |
| macOS and Rosetta preflight       | On macOS 15, 26, and 27 stable, check Rosetta preflight and complete a launch and shutdown. On stable macOS 27, confirm an unavailable beta-only `game-test-tool` does not block the normal Rosetta check. Test Legacy Game Test Mode recovery only on a macOS 27 beta where Apple provides the tool. | Pending |

Rosetta unit fixtures cover the missing-tool path, the macOS 28 policy rejection, and simulated Intel-probe outcomes. They do not prove behavior on macOS 15, 26, or 27; those checks stay manual.

For the launcher UI, use the debug preview controls to compose lifecycle, installation, progress, failure, region, HUD, popup, and accessibility states.

- VoiceOver: Settings navigation, the music and version HUD controls, gallery items, document links, and modal Done actions expose meaningful labels and stay keyboard reachable.
- Full Keyboard Access: Tab shows a visible focus ring and moves through controls. Space activates the focused control. Return activates a focused or native control only where macOS provides that and never triggers Play or Install globally. The primary action stays focused as it changes between Play/Install, Pause, and Resume. Settings scrolls the focused row into view.
- Repeat with Reduce Motion, Reduce Transparency, Differentiate Without Color, and the largest practical text size. English copy must wrap without clipping in onboarding, Settings rows, gallery titles, documents, and popup actions.
- Escape dismisses Settings, galleries, and bundled documents.
- With one and with several regions installed, the Dock menu lists only those regions, disables Play during active operations, opens Settings once, and brings the launcher forward when a launch needs attention.
