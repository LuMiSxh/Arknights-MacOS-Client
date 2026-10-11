---
title: Testing architecture
description: Test levels, isolation boundaries, deterministic workflows, and release verification
order: 40
---

# Testing architecture

> [!IMPORTANT]
> Unit and integration tests are deterministic and run for every pull request. Live contracts are read-only probes of public services. They run only through their scheduled or manual workflow.

## Test levels

| Level         | Command               | Scope                                                                                       | Public network |
| ------------- | --------------------- | ------------------------------------------------------------------------------------------- | -------------- |
| Unit          | `just check`          | Swift components, Python scripts, parsing, persistence, safety rules, and static checks     | Denied         |
| Integration   | `just integration`    | Onboarding, API decoding, installer downloads, checksums, and state persistence on fixtures | Denied         |
| Live contract | `just live-contracts` | Current Yostar configuration, CDN, and manifest shapes; Gryphline Taiwan metadata and CDN   | Required       |

`just ci` runs unit checks, integration tests, and the release Swift build. It never downloads the Wine runtime or game files. It never launches the app or Wine. uv and SwiftPM can resolve pinned dependencies on a fresh checkout. Test processes stay network-denied.

Swift suites use Swift Testing (`import Testing`), not XCTest. Each unit test target sits beside its source target. `ArknightsClientIntegrationTests` and `ArknightsClientLiveContractTests` also have environment gates, so a plain `swift test` cannot contact public services. Python tests use `pytest` from the default group.

Use the smallest level that proves the changed contract:

| Change                                                                      | Test, if a test is necessary                                                                                                                                        |
| --------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Parser, state transition, path rule, persistence value, or controller logic | A focused test in the unit test target of the owning source target, using local values and fixtures. Add it only when no type or existing test covers the contract. |
| Flow across onboarding, API decoding, installation, or persisted state      | `ArknightsClientIntegrationTests` with `IntegrationTestEnvironment` and `LocalFixtureNetwork`                                                                       |
| Yostar or Gryphline endpoint, response shape, manifest, or signing          | A live probe, plus a fixture test when the decoder changes                                                                                                          |
| `runtime.json` or a new packaged runtime release                            | `just check`, `just runtime`, and the manual compatibility matrix                                                                                                   |
| Website Markdown, Svelte UI, routes, or Mermaid                             | The website checks in [Development](README.md#documentation-website)                                                                                                |

## What to test

Write one test per contract. Put equivalent cases into one parameterized test. Test each contract at the cheapest layer that fails. Do not test it again in view-model or composition tests.

Add a regression test only when users would notice the bug and no type, compiler check, or existing test catches it. Prefer a type change (enum, value type, exhaustive `switch`) to a new test.

Do not test constants, strings, mappings, getters, log text, presentation details, or framework behavior.

These contracts always keep at least one test: install exclusivity, activity lease, prefix ownership, launch cancellation, `.part` resume, manifest paths, download hosts, migrations, support codes, privacy, stale-epoch checks, and update safety.

## Focused tests

Run `just test FILTER` to run a group of Swift unit tests. `FILTER` is a case-sensitive regular expression. It matches the test identifier, which contains the suite or type name. A pattern that matches no test fails the recipe.

```bash
just test GameInstaller
just test 'InstallerDirectory|GameInstallerRollback'
```

- `just test gameinstaller` matches nothing, because the match is case-sensitive.
- A free-function `@Test` runs under `just test` only when a `@Suite` type wraps it.
- `just test` does not run integration or live-contract tests. Run `just ci` before you finish.

## Isolation contract

Swift unit and integration tests run in the macOS sandbox with network denied. SwiftPM builds test targets before it enters the sandbox. Python unit tests use `pytest-socket` to reject socket and DNS access.

> [!WARNING]
> Each Swift test process gets temporary `HOME`, `CFFIXED_USER_HOME`, and `TMPDIR` directories. Workflow fixtures also inject temporary `AppPaths` roots and a unique `UserDefaults` suite. Tests must never use the user's application support directory, Wine prefix, game directories, runtime cache, or `dist/`.

HTTP tests use an ephemeral `URLSession` whose `URLProtocol` accepts only recorded fixture routes. An unknown URL fails the test. Fixtures must be small, deterministic, reviewable, and generated locally. Do not commit downloaded game, runtime, or artwork files. Static `URLProtocol` handlers need serialized suites and a cleanup reset.

## Shared helpers, clocks, and leases

Helpers that more than one test target uses live in the `ArknightsTestSupport` library target. Do not copy a helper into another test target.

Timed code takes an injected `Clock` (`any Clock<Duration>`). Tests pass a manual clock and advance it explicitly. A test never sleeps for real time.

Each test owns its state:

- Create a temporary directory with a unique UUID name. Remove it in `defer`.
- Acquire the install lease explicitly. Release it explicitly before the test returns. Never rely on deallocation to unlock it.
- Use `.serialized` only as a last resort, when shared static state cannot be isolated per test.

## Failure triage

Start with the narrowest failing command. Keep its first error in the report.

- Unit test: fix it at the owning feature boundary. Do not weaken an assertion to pass a fixture.
- Fixture network: check the recorded URL, method, headers, response bytes, and `URLProtocol` cleanup before you change production code.
- Live contract: inspect the sanitized report and compare the upstream response shape before you update fixtures.

Move a test that needs a real runtime, game download, or public network to the manual matrix or a gated workflow.

## Live contracts

> [!NOTE]
> Live contracts send read-only requests and change nothing locally. They stay out of CI so outages and rate limits cannot make unrelated pull requests flaky. The workflow runs every Monday at 04:23 UTC. `workflow_dispatch` and `just live-contracts` run it manually.

Each run checks branding, game configuration, CDN configuration, manifest location, and the complete manifest for Global, Japan, and Korea through the production request signing and decoders. For Taiwan it checks only Gryphline branding, metadata, and CDN hosts. It never reads the encrypted game manifest or a game package. It requires credential-free HTTPS URLs, bounded response time and manifest size, safe non-conflicting paths, parseable CRC64 or MD5 values, and nonnegative file sizes. It retries network and HTTP failures three times, not decoding or validation failures.

A failed scheduled run emails the repository owner. If no issue titled "Live contract failure" is open, the workflow opens one. Manual runs never open issues. The owner closes the issue by hand.

A failure means an upstream schema or endpoint may have changed. Nothing rewrites fixtures or code automatically. Update decoding and fixtures together.

## Runtime ownership

The Arknights macOS Runtime repository owns runtime source monitoring and release construction. This repository validates the selected release through `runtime.json`. See [Runtime updates](runtime-updates.md).

## Manual compatibility matrix

> [!IMPORTANT]
> Unit and integration tests never launch Wine or the game, so they do not establish platform compatibility. Real game and macOS checks stay pending until someone runs them on the release candidate. Record the client commit, runtime revision or archive hash, macOS version, chip, prefix history, result, and sanitized logs. Change a result from **Pending** only after you observe that exact case.

Use this checklist for each release candidate.

| Check                             | Procedure                                                                                                                                                                                                                                                        | Result  |
| --------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------- |
| Fresh prefix                      | New Wine prefix: install a stable client, launch, sign in, open and close Notices, exit the game and launcher.                                                                                                                                                   | Pending |
| Existing prefix                   | Launch from an initialized prefix after you update or repair the game. Repeat for Global, Japan, and Korea, including sign-in, Notices, and focus switches between game and helper windows.                                                                      | Pending |
| Mac pointer                       | Play with **Pointer** set to **Your Mac's pointer** and to **Arknights' cursor**. Record cursor behavior, region, and runtime.                                                                                                                                   | Pending |
| Picture modes and sizes           | On a Retina display, play one fight with each **Picture** choice at one **Window size**, windowed and fullscreen at **Full detail**. Confirm the window keeps its size and fullscreen fills the display.                                                         | Pending |
| Window size choices               | On a 16:10 and a 16:9 display, use **Fill my screen** and **Leave room for other apps**. Confirm the window fits above the Dock with its title bar visible.                                                                                                      | Pending |
| Audio route changes               | Change the macOS output device before launch, during game and music, and after exit. Record whether game audio and launcher music recover.                                                                                                                       | Pending |
| Other installation and game paths | Full install, update, and repair. Sign-in helpers, Notices and payment pages, media playback, DXMT/Metal rendering, HiDPI, fullscreen and borderless modes, input, companion-window tracking, Command-Q.                                                         | Pending |
| macOS and Rosetta preflight       | On macOS 15, 26, and 27 stable, check Rosetta preflight and complete a launch and shutdown. On stable macOS 27, confirm an unavailable beta-only `game-test-tool` does not block the Rosetta check. Test Legacy Game Test Mode recovery only on a macOS 27 beta. | Pending |

For the launcher UI, use the debug preview controls to compose lifecycle, installation, failure, region, HUD, popup, and accessibility states.

- VoiceOver: Settings navigation, the music and version HUD controls, gallery items, document links, and modal Done actions expose meaningful labels and stay keyboard reachable.
- Full Keyboard Access: Tab shows a visible focus ring. Space activates the focused control. Return never triggers Play or Install globally. The primary action stays focused as it changes. Settings scrolls the focused row into view.
- Repeat with Reduce Motion, Reduce Transparency, Differentiate Without Color, and the largest practical text size. English copy must wrap without clipping.
- With one and with several regions installed, the Dock menu lists only those regions, disables Play during active operations, opens Settings once, and brings the launcher forward when a launch needs attention.
