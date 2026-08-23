# Testing architecture

The repository separates tests by dependency boundary. Unit and integration tests are deterministic and may run for every pull request. Live contracts are read-only probes of public services and run only through their dedicated scheduled or manually requested workflow.

## Test levels

| Level         | Command               | Scope                                                                                                                             | Public network |
| ------------- | --------------------- | --------------------------------------------------------------------------------------------------------------------------------- | -------------- |
| Unit          | `just check`          | Swift components, Python scripts, parsing, persistence, safety rules, and static checks                                           | Denied         |
| Integration   | `just integration`    | Fresh onboarding, real launcher API decoding, installer downloads, checksums, state persistence, and repeat runs against fixtures | Denied         |
| Live contract | `just live-contracts` | Current Yostar configuration, CDN, and manifest shapes for Global, Japan, and Korea                                               | Required       |

`just ci` runs unit checks, deterministic integration tests, and the release Swift build. It never downloads the Wine runtime or game files and never launches the app or Wine. On a fresh checkout, uv and SwiftPM may resolve pinned development dependencies before test execution; the test processes themselves remain network-denied.

Python tests use `pytest` from the uv-locked development dependency group. Swift levels are separate SwiftPM test targets:

- `ArknightsClientTests`
- `ArknightsClientIntegrationTests`
- `ArknightsClientLiveContractTests`

Integration and live-contract suites have explicit environment gates in addition to target filters. A plain `swift test` therefore cannot accidentally contact public services.

## Isolation contract

Swift unit and integration test execution runs inside the macOS sandbox with network access denied. SwiftPM builds test targets before entering that sandbox so a fresh runner may resolve the package's pinned source dependencies without granting network access to test code. Python unit tests use `pytest-socket` to reject socket and DNS access.

Each Swift test process receives temporary `HOME`, `CFFIXED_USER_HOME`, and `TMPDIR` directories. Workflow fixtures additionally inject temporary `AppPaths` roots and a unique `UserDefaults` suite. Tests must never use the user's application support directory, Wine prefix, game directories, runtime cache, or `dist/`.

HTTP behavior uses an ephemeral `URLSession` whose `URLProtocol` accepts only recorded fixture routes. An unknown URL fails the test instead of falling through to the internet. Fixtures must be small, deterministic, reviewable, and generated locally; downloaded game, runtime, and artwork files remain forbidden.

Static `URLProtocol` handlers require serialized suites and must be reset during cleanup. Equivalent behavior for Global, Japan, and Korea should be parameterized when the region changes the contract.

## Deterministic workflows

The initial workflow creates empty paths and preferences, presents onboarding, advances to Region & Install, and drives the real `LauncherViewModel`, `LauncherAPI`, and `GameInstaller` against fixture responses. It verifies the downloaded bytes, CRC64, installed-state file, progress, completed onboarding, persisted region/path, and a second no-op installation.

Future integration scenarios belong in the same level when they can use fixture runtimes or process doubles. Priorities include resumable and cancelled downloads across the launcher state model, compatibility reconciliation, prefix migration, region remapping, launch environment construction, process timeout and cancellation, and app-bundle packaging inspection.

The main-branch CI packaging smoke builds an app without a runtime. Complete runtime/DMG packaging remains in the release workflow because it downloads the pinned runtime and has a substantially larger time and disk budget.

## Live contracts

Live contracts perform safe read-only requests and make no local installation changes. They are separate from deterministic CI because service outages, rate limits, and upstream deployments must not make unrelated pull requests flaky. The dedicated workflow runs every Monday at 04:23 UTC; `workflow_dispatch` and `just live-contracts` provide deliberate manual execution.

Each run checks branding, game configuration, CDN configuration, manifest location, and the complete manifest for Global, Japan, and Korea through the production request signing and decoders. It requires credential-free HTTPS URLs, bounded response time and manifest size, safe non-conflicting paths, parseable CRC64 values, and nonnegative file sizes. Network and HTTP failures are retried three times; deterministic decoding and validation failures are not.

The probe writes a schema-versioned report containing only contract names, health states, ordinary version or file-count observations, and sanitized failure categories. Reports are retained as Actions artifacts for 30 days and rendered into the workflow summary. Authorization values and response bodies are never persisted.

Scheduled alert reconciliation is isolated in a second job with `issues: write`; the probe itself has read-only repository access. A contract must fail in two consecutive scheduled reports before the workflow creates or reopens its single `automated-monitor` issue. An unchanged failure updates the issue timestamp without comment spam, a changed failure adds a comment, and two consecutive healthy reports add a recovery comment and close only the issue carrying that contract's private monitor marker. Manual runs never mutate issues.

Failures indicate that an external schema or endpoint may have changed. They do not automatically rewrite fixtures or production code. Review the sanitized report and upstream change, then update production decoding and recorded fixtures together.

## Manual compatibility matrix

Real Wine and game behavior remains manual: fresh and upgraded prefixes, full install/update/repair, every login provider, Notices and payment pages, media playback, DXMT/Metal rendering, HiDPI, fullscreen and borderless modes, input, companion-window tracking, game exit, launcher termination, and Command-Q. Record the macOS version, chip, runtime revision, prefix history, scenario result, and sanitized logs for each release candidate.
