# Agent Instructions

## Scope and Commands

- Target Apple Silicon and macOS 15+. Guard macOS-26-only Liquid Glass APIs with `AdaptiveGlass.swift` fallbacks.
- Treat Yostar Global, Japan, and Korea PC, Gryphline Taiwan, and Hypergryph China and China (Bilibili) as stable. Canary Features currently has no features.
- Keep source, docs, tests, UI copy, and commits in English; the app ships English-only. Write docs in plain technical English: one idea per sentence, about 25 words or fewer, active voice, imperative steps, UI labels in **bold** exactly as shown, and glossary terms (`docs/development/README.md#terms`). `docs/help/**` and `docs/installation.md` are strict; architecture docs may use precise technical terms.
- Use SwiftPM as the source of truth; do not add an Xcode project.
- Keep the static SvelteKit site in `web/` (see `docs/development/README.md#documentation-website`); do not add Vitest.
- Never commit game/runtime binaries, downloaded artwork, or `dist/`. Regenerate shipping icons only with `just icon`; the hero wallpaper in `web/static/artwork/` is the only artwork exception.
- Do not install, launch, download, uninstall, or alter the user's game/runtime unless explicitly requested. Run `just preview`, `just dev app run`, and Xcode/SwiftUI previews only with user approval.
- `just test FILTER`: unit tests whose name matches FILTER (regex, case-sensitive).
- `just check swift`, `just check scripts`, `just check web`: focused lint and tests for one area.
- `just integration`: offline integration tests. `just ci`: full native CI; run it before handoff.
- `cd web && BASE_PATH=/Arknights-MacOS-Client pnpm build`: production website build. `just --list`: all other tasks.

## Architecture

- Follow the target table in `docs/development/architecture/README.md#targets`.
- The executable (`ArknightsClient`) holds only the app entry point, AppDelegate, menus, and scenes. `LauncherViewModel` in `ArknightsLauncherUI` is the composition root; inject narrow dependencies from it.
- Feature work goes in its feature target. Cross-feature primitives and configuration go in `ArknightsCore`, which names no feature type and holds cross-feature lifecycle state. Feature-independent I/O goes in `ArknightsInfrastructure`.
- Give a symbol `package` access only when another production target uses it (with an explicit `package init` when that target constructs it); keep the rest `internal`. Tests use `@testable import`; do not widen access for tests. Do not add `public`.
- Only `ArknightsLauncherUI` links Sparkle and only `ArknightsAudio` links YouTubePlayerKit. Use `@Observable`; add a presentation or policy type only when it holds real branching.
- Write UI copy as literals at the view. Do not add `*Strings` files. Extract a constant only when two or more sites share it.
- Map infrastructure errors at the owning feature boundary; each feature owns its error type. Support codes are pinned by `SupportCodeStabilityTests`; user-facing messages are copy.
- Define persisted locations through `AppPaths`; preserve paths, keys, and formats unless a migration is explicit. Centralize application-owned keys, limits, retries, and timeouts in `Shared/Configuration/AppConstants.swift`; keep upstream literals beside their protocol.
- Keep production Swift under 800 lines and tests under 450. Split a type by responsibility (`Type+Download.swift`), never by line count. C/Objective-C shims and scripts are exempt.
- Avoid silent `try?` for filesystem, process, and network work; for best-effort cleanup, use `log.attempt("context") { try … }`. Preserve MPL-2.0 SPDX headers in handwritten Swift, C, and Python.
- Comment only non-obvious WHYs, workarounds, and security/concurrency invariants. Add DocC only to `package` APIs whose behavior the name does not state.
- Keep developer simulation in `SimulatedLauncherActions` (`#if DEBUG`), driven by `CaseIterable` state and generic pickers. Production action bodies never branch on developer mode.
- Installation is exclusive and keeps resumable `.part` files. Validate every manifest path before writing: check it lexically, reject symlinks per component, write `.part`, hash, then rename atomically. Do not add inode-identity rechecks.

## Concurrency

- Set default isolation per target: `.defaultIsolation(MainActor.self)` only for UI and composition targets. Infrastructure, installation, hashing, and runtime stay nonisolated. Keep UI and AppKit state on `@MainActor`. Mark offloads `@concurrent`; do not add `Task.detached`.
- Use `Mutex` for small synchronous leaf state and an actor for multi-step state machines. Never `await` while holding a lock.
- Capture an identity (session ID, lease, token) before `await` and compare it after. Cancellation alone is not ownership. Hand-write identities only for leases and game sessions.
- Guard stale async results with `TaskSlot` (cancel on replace, `owns(token)`, `invalidate()`), not epoch counters. Call `invalidate()` or end the lease before clearing or replacing state.
- Change launcher activity only through `LauncherLifecycleStore` lease `begin`, `update`, and `end`. A stale lease must not set idle. Launch work rechecks the session ID and lease after every suspension. Keep the shared Wine prefix owned until prefix-wide shutdown completes; direct game-process exit alone never means Idle.
- Cleanup that must outlive cancellation (rollback, prefix shutdown, wineserver wait) runs in an unstructured `Task { … }` whose `.value` is awaited. An `await` inside `defer` does not shield it. Never skip prefix shutdown on cancel. Pattern: `Sources/ArknightsGameRuntime/Runtime/GameSessionController+Monitoring.swift`.
- Bound parallel work with a windowed task group (seed N, add one per completion) and an `AppConstants` limit. Never call `addTask` in an unbounded loop.
- Give every `AsyncStream` an explicit buffering policy: `.bufferingNewest(1)` for progress and state, a stated bound for lossless streams. Set `onTermination` when the producer owns a resource (task, socket, observer). Call `finish()` once.
- Prefer event sources (`terminationHandler`, `DispatchSource`, notifications) to polling. Repeating timers and testable timed logic take an injected `Clock`; tests use a manual clock and never sleep for real. A repeating timer uses `Task.sleep(for:tolerance:)` with at least 10% leeway; one-shot view delays may use `Task.sleep(for:)`.
- Release locks deterministically with a `~Copyable` install lease (`consuming func release()`) or the scoped `withInstallLease(at:)`. Never rely on `deinit` order. Acquire and release leases explicitly in tests.

## Performance and Energy

- Keep hot loops (MD5, CRC64, extraction) inside one target. Hash from the read buffer with raw buffer pointers; no per-block `Data` copies.
- Only a small leaf view reads per-tick progress. Throttle high-frequency values to about 10 Hz.
- Run continuous animation through `ContinuousMotion` only. It pauses when hidden or covered, under sheets, while the game runs, and in Low Power Mode. Use one shared clock per loop type.

## UI

- Follow `docs/development/design.md`. Reuse controls only when semantics, spacing, accessibility, and state match. Declare shared controls and tokens in `Shared/UI`; keep feature-only components in their feature.
- Get colors from `LauncherTheme` roles, read through `\.launcherTheme`. Never write a fixed cyan. `LauncherVisuals.cyan` is the fallback accent only, for when no artwork accent exists.
- Keep dynamic artwork or theme accents on the primary operation, progress, selection, and interaction highlights. Do not replace them with hardcoded neutrals.
- `LauncherMotion` is the only motion source: no raw `.easeInOut`, `.spring`, or durations in views.
- Use `AdaptiveGlass` fallbacks for macOS 26 APIs. The primary action shows at most one ambient effect: a static halo with one arrival pulse.

## Testing

- See `docs/development/testing.md`. Keep unit and integration tests offline and fixture-backed. Live contracts run only through `just live-contracts`.
- Put shared helpers in `Tests/ArknightsTestSupport`. Give each test its own UUID temp directory, cleaned in `defer`. Use `.serialized` only as a last resort.
- Write one test per contract. Parameterize equivalent cases. Test each contract at the cheapest layer that fails; do not repeat it in view-model or composition tests.
- Add a regression test only when users would notice the bug and no type, compiler check, or existing test catches it. Prefer a type change (enum, exhaustive `switch`).
- Test external contracts only: support codes, diagnostic prefixes, persisted keys, and URLs. Do not test constants, user-facing strings, log text, mappings, getters, presentation, or framework behavior.
- Keep at least one test for each critical contract: install exclusivity, activity lease, prefix ownership, launch cancellation, `.part` resume, manifest paths, download hosts, migrations, support codes, privacy, stale-result checks, and update safety.

## CI and Workflows

- Pin actions by SHA. Give each job only the permissions it needs. Never put `${{ }}` event data inside `run:`; pass it through `env:`.
- Release secrets live only in the `release` environment, limited to `main`, `release/*`, and `version-*`.
- `main` requires the "Source and integration tests" check.
- Pull requests opened by automation dispatch CI themselves (`gh workflow run ci.yml --ref`).

## Verification and Safety

- Run focused checks while iterating; run `just check web` and the production build for website changes, and `just ci` before handoff. Run Python through the root `pyproject.toml`/`uv.lock` with `uv run --locked`; reuse `scripts/lib` and test changed behavior.
- Define each repository path once: in the module that owns it, or in `project_config` when two or more scripts or workflows share it. Derive product and package metadata only through `project_config`, and runtime layout through `runtime.json`. Scripts never hard-code source paths.
- Same change: when a UI label, setting, menu item, or network host changes, update `docs/help`, `docs/development/design.md`, `web/src/routes/privacy/+page.svelte`, and `CHANGELOG.md` together. When a doc contradicts code, the code wins; fix the doc.
- User help uses glossary terms (server, game environment). CHANGELOG entries use exact UI labels and describe the shipped change, not intermediate builds. Record user-visible changes in `CHANGELOG.md`; follow `docs/development/releases-and-updates.md` for releases.
- Follow existing commit style. Never mention agent or model vendors. Push only with explicit consent.

## Known Debt

- Do not copy these patterns; fix a site only when you touch its code.
- Silent `try?` in `Sources/ArknightsGameInstallation/Compatibility/` (`GameShimIO`, `PlatformProcessCompatibility`, `BilibiliPlatformCompatibility`).
- `StorageOverviewCopy` in `Sources/ArknightsGameRuntime/Storage/StorageOverviewPage.swift`.
