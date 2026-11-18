---
title: Testing architecture
description: Which tests earn their place, how to prove it, and the isolation rules for each level
order: 40
---

# Testing architecture

> [!IMPORTANT]
> A test earns its place only when it fails for a behavior that users or callers depend on. Test count is not quality.

## Test value

Keep a test only when it fails for the behavior it names and stays green through a refactor that keeps that behavior.

| Smell            | How it looks                                                      | Action                                               |
| ---------------- | ----------------------------------------------------------------- | ---------------------------------------------------- |
| Tautology        | The test builds the expected value the way the code does          | Compare against a literal from the specification     |
| Tests the double | The test checks that a stub was called and nothing else           | Assert the returned state or the written file        |
| Change detector  | The test asserts call order or a private detail                   | Delete it, or rewrite through the public entry point |
| Trivial          | Constant, getter, plain `Codable` roundtrip, standard library use | Delete                                               |
| Weak assertion   | `#expect(value != nil)`, `#expect(!list.isEmpty)`                 | Assert the exact value or delete the test            |
| Duplicate        | The same rule has a test in the unit and the view-model target    | Keep the cheapest layer and delete the other         |
| Example pile     | Five tests of one rule with different literals                    | One `@Test(arguments:)` case list                    |
| Large setup      | Many doubles to reach one assertion                               | Test at the layer that owns the rule                 |

Prefer a type change over a test when the compiler can reject the bug. Use an enum instead of a boolean pair, an exhaustive `switch`, or an initializer that rejects an invalid value.

A test also stays when it pins a past bug that users noticed. Every contract in [What to test](#what-to-test) keeps at least one test.

## Test levels

| Level         | Command               | Scope                                                                                       | Public network |
| ------------- | --------------------- | ------------------------------------------------------------------------------------------- | -------------- |
| Unit          | `just check`          | Swift components, Python scripts, parsing, persistence, safety rules, and static checks     | Denied         |
| Integration   | `just integration`    | Onboarding, API decoding, installer downloads, checksums, and state persistence on fixtures | Denied         |
| Live contract | `just live-contracts` | Current Yostar configuration, CDN, and manifest shapes; Gryphline Taiwan metadata and CDN   | Required       |

`just ci` runs unit checks, integration tests, and the release Swift build. It never downloads the Wine runtime or game files, and it never launches the app or Wine. Test processes stay network-denied.

Swift suites use Swift Testing (`import Testing`), and each unit test target sits beside its source target. The integration and live-contract targets also have environment gates, so a plain `swift test` cannot contact public services. Python tests use `pytest` from the default group.

## What to test

Write one test per contract, parameterized for equivalent cases, at the cheapest layer that fails.

| Change                                                                      | Test, if a test is necessary                                                                                                                                        |
| --------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Parser, state transition, path rule, persistence value, or controller logic | A focused test in the unit test target of the owning source target, using local values and fixtures. Add it only when no type or existing test covers the contract. |
| Flow across onboarding, API decoding, installation, or persisted state      | `ArknightsClientIntegrationTests` with `IntegrationTestEnvironment` and `LocalFixtureNetwork`                                                                       |
| Yostar or Gryphline endpoint, response shape, manifest, or signing          | A live probe, plus a fixture test when the decoder changes                                                                                                          |
| `runtime.json` or a new runtime release                                     | `just check`, `just runtime`, and the manual compatibility matrix                                                                                                   |
| Website Markdown, Svelte UI, routes, or Mermaid                             | The website checks in [Development](README.md#documentation-website)                                                                                                |

Add a regression test only when users would notice the bug and no type, compiler check, or existing test catches it.

Do not test constants, strings, mappings, getters, log text, presentation details, framework behavior, or a double's calls.

These contracts always keep at least one test: install exclusivity, activity lease, prefix ownership, launch cancellation, `.part` resume, manifest paths, download hosts, migrations, support codes, privacy, stale-result checks, and update safety.

## Focused tests

`just test FILTER` runs the unit tests whose identifier matches the case-sensitive regular expression. A pattern that matches no test fails the recipe. It never runs integration or live-contract tests, so run `just ci` before you finish.

```bash
just test GameInstaller
just test 'InstallerDirectory|GameInstallerRollback'
```

A free-function `@Test` runs under `just test` only when a `@Suite` type wraps it.

## Isolation contract

Swift unit and integration tests run in the macOS sandbox with network denied. SwiftPM builds test targets before it enters the sandbox. Python unit tests use `pytest-socket` to reject socket and DNS access.

> [!WARNING]
> Each Swift test process gets temporary `HOME`, `CFFIXED_USER_HOME`, and `TMPDIR` directories. Workflow fixtures also inject temporary `AppPaths` roots and a unique `UserDefaults` suite. Tests must never use the user's application support directory, Wine prefix, game directories, runtime cache, or `dist/`.

HTTP tests use an ephemeral `URLSession` whose `URLProtocol` accepts only recorded fixture routes, and an unknown URL fails the test. Fixtures must be small, deterministic, reviewable, and generated locally. Do not commit downloaded game, runtime, or artwork files. Static `URLProtocol` handlers need serialized suites and a cleanup reset.

## Shared helpers, clocks, and leases

Helpers used by more than one test target live in the `ArknightsTestSupport` library target; do not copy one into another test target. Runtime fixtures live in `ArknightsRuntimeTestSupport`, which depends on `ArknightsGameRuntime`; add it only where fixtures are used. `ArknightsTestSupport` never depends on runtime targets.

Use `StubURLProtocol`, `makeIsolatedDefaults()`, `makeLifecycleStore()`, and `TemporaryDirectory` instead of a local copy.

Timed code takes an injected `Clock` (`any Clock<Duration>`), and tests advance a manual clock explicitly. Use `ParkedClock` when a deadline must never fire. No test sleeps for real time: `just check scripts` rejects `Task.sleep`, `Thread.sleep`, `usleep`, and `sleep` under `Tests/`, except the reasons and exact counts in `scripts/config/test-sleep-allowlist.txt`.

Each test owns its state:

- Create a temporary directory with a unique UUID name and remove it in `defer`.
- Acquire the install lease explicitly and release it before the test returns. Never rely on deallocation to unlock it.
- Use `.serialized` only when shared static state cannot be isolated per test.

## Failure triage

Start with the narrowest failing command and keep its first error in the report.

- Unit test: fix it at the owning feature boundary. Do not weaken an assertion to pass a fixture.
- Fixture network: check the recorded URL, method, headers, response bytes, and `URLProtocol` cleanup before you change production code.
- Live contract: inspect the sanitized report and compare the upstream response shape before you update fixtures.

Never delete or weaken a failing test to make the suite green. A red test is a finding: decide whether the behavior or the test is wrong first. Move a test that needs a real runtime, game download, or public network to the manual matrix or a gated workflow.

## Live contracts

> [!NOTE]
> Live contracts send read-only requests and change nothing locally. They stay out of CI so outages and rate limits cannot make unrelated pull requests flaky. The workflow runs every Monday at 04:23 UTC. `workflow_dispatch` and `just live-contracts` run it manually.

Each run checks branding, game configuration, CDN configuration, manifest location, and the complete manifest for Global, Japan, and Korea through the production request signing and decoders. For Taiwan it checks only Gryphline branding, metadata, and CDN hosts. It never reads the encrypted game manifest or a game package. It requires credential-free HTTPS URLs, bounded response time and manifest size, safe non-conflicting paths, parseable CRC64 or MD5 values, and nonnegative file sizes. It retries network and HTTP failures three times, not decoding or validation failures.

A failed scheduled run emails the repository owner, and the workflow opens one issue titled "Live contract failure" if none is open. Manual runs never open issues; the owner closes the issue by hand.

A failure means an upstream schema or endpoint may have changed. Nothing rewrites fixtures or code automatically; update decoding and fixtures together.

## Runtime ownership

The Arknights macOS Runtime repository owns runtime source monitoring and release construction. This repository validates the selected release through `runtime.json`. See [Runtime updates](releases-and-updates.md#runtime-updates).

> [!IMPORTANT]
> Unit and integration tests never launch Wine or the game, so they do not establish platform compatibility. Real game and macOS checks stay pending until someone runs them on the release candidate. Record the client commit, runtime revision or archive hash, macOS version, chip, prefix history, result, and sanitized logs. Change a result from **Pending** only after you observe that exact case.
