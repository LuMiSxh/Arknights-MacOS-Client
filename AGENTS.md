# Agent Instructions

## Scope

- Target Apple Silicon and macOS 15+. Guard macOS-26-only Liquid Glass APIs through `AdaptiveGlass.swift` fallbacks.
- Treat Yostar's Global, Japan, and Korea PC clients and Hypergryph's China and China (Bilibili) clients as stable; keep Gryphline Taiwan behind Canary Features.
- Keep source, docs, tests, UI copy, and commits in English. The app ships English-only.
- Write docs in ASD-STE100 Simplified Technical English: short sentences, active voice, one instruction per step, one term per concept, no filler.
- Use SwiftPM as the source of truth; do not add an Xcode project.
- Keep the static SvelteKit site in `web/`; follow `docs/development/README.md#documentation-website` and do not add Vitest.
- Never commit game/runtime binaries, downloaded artwork, or `dist/`; regenerate tracked shipping icons only with `just icon`. The only artwork exception is the website hero wallpaper in `web/static/artwork/`.

## Commands

| Task                  | Command                                                  |
| --------------------- | -------------------------------------------------------- |
| Focused native checks | `just check`                                             |
| Focused unit tests    | `just test FILTER`                                       |
| Native CI             | `just ci`                                                |
| Integration tests     | `just integration`                                       |
| Website checks        | `just check web`                                         |
| Production website    | `cd web && BASE_PATH=/Arknights-MacOS-Client pnpm build` |
| Other tasks           | `just --list`                                            |

## Architecture

- Use Swift 6.4. Follow the target table in `docs/development/architecture/README.md#targets`.
- Keep app composition in `Sources/ArknightsClient/Application` (the only code in the executable), feature work in its feature target, cross-feature primitives and configuration in `ArknightsCore`, and feature-independent I/O in `ArknightsInfrastructure`.
- Give a symbol that another target uses `package` access (with an explicit `package init` when another target constructs the type); keep the rest `internal`. Do not add `public`.
- Map infrastructure errors at the owning feature boundary. Each feature owns its error type; support codes and messages are a stable contract pinned by `SupportCodeStabilityTests`.
- Only `ArknightsLauncherUI` links Sparkle. Only `ArknightsAudio` links YouTubePlayerKit.
- `Core` holds cross-feature lifecycle state and names no feature type.
- Use `@Observable`; keep `LauncherViewModel` at composition and inject narrow dependencies into features and views.
- Define persisted locations through `AppPaths`; preserve paths, keys, and serialized formats unless a migration is explicit.
- Centralize application-owned fixed keys, limits, retries, and timeouts in `Shared/Configuration/AppConstants.swift`; keep upstream literals beside their protocol.
- Keep handwritten production Swift and Swift tests below 450 lines. Native C/Objective-C shims and scripts are exempt.
- Use tabs with width four and follow `.swift-format`.
- Avoid silent `try?` for filesystem, process, and network work. Preserve MPL-2.0 SPDX headers in handwritten Swift, C, and Python.
- Write expressive code. Comment only non-obvious WHYs, workarounds, and security/concurrency invariants; add concise DocC for `package` APIs and complex domain models.
- Keep developer simulation in `SimulatedLauncherActions` (`#if DEBUG`); production action bodies never branch on developer mode.
- Treat installation as exclusive, preserve resumable `.part` files, and validate every manifest path before writing.

## Concurrency

- Set default isolation per target: `.defaultIsolation(MainActor.self)` only for UI and composition targets; Infrastructure, installation, hashing, and runtime stay nonisolated. Keep observable/UI/AppKit state on `@MainActor`.
- Mark offloads `@concurrent`; do not add `Task.detached`. Enable `NonisolatedNonsendingByDefault` per target only after every function that must leave the caller's actor is `@concurrent`.
- Use `Mutex` for small synchronous leaf state; use an actor for multi-step state machines. Never `await` while holding a lock.
- Capture an identity (session ID, lease, epoch) before `await` and compare it after. Cancellation alone is not ownership.
- Increment an epoch or end the lease before clearing or replacing state, so suspended work cannot republish stale results.
- Change launcher activity only through `LauncherLifecycleStore` lease `begin`, `update`, and `end`; a stale lease must not set idle. Launch work rechecks the session ID and lease after every suspension.
- Keep the shared Wine prefix owned until prefix-wide shutdown completes; direct game-process exit alone never means Idle.
- Bound parallel work with a windowed task group (seed N, add one per completion) and an `AppConstants` limit. Never call `addTask` in an unbounded loop.
- Give every `AsyncStream` an explicit buffering policy: `.bufferingNewest(1)` for progress and state, a stated bound for lossless streams. Set `onTermination` and call `finish()` once.
- Prefer event sources (`terminationHandler`, `DispatchSource`, notifications) to polling. A timer that remains uses `Task.sleep(for:tolerance:)` with at least 10% leeway.
- Release locks deterministically: use a `~Copyable` install lease with `consuming func release()` or the scoped `withInstallLease(at:)`. Never rely on `deinit` order. Acquire and release leases explicitly in tests.
- Swift 6.4: cleanup that must outlive cancellation (rollback, prefix shutdown, wineserver wait) runs in `withTaskCancellationShield` once the deployment target allows it, or in an `await` inside `defer`. Never skip prefix shutdown on cancel. Do not use detached cleanup tasks.

## Performance and Energy

- Keep hot loops (MD5, CRC64, extraction) inside one target; do not cross a module boundary per chunk. Hash from the read buffer with raw buffer pointers; no per-block `Data` copies.
- Only a small leaf view reads per-tick progress. Throttle high-frequency values to about 10 Hz.
- Run continuous animation through `ContinuousMotion` only. It pauses when hidden or covered, under sheets and overlays, while the game runs, and in Low Power Mode. Use one shared clock per loop type.

## UI

- Follow `docs/development/design.md`; reuse controls only when semantics, spacing, accessibility, and state match.
- Keep components feature-local unless multiple features share the same presentation contract. Declare reusable identical controls, surfaces, and design tokens centrally in `Shared/UI`; do not duplicate local button or panel styles.
- Dynamic artwork or theme accents are allowed for the current primary operation, progress, selection, and interaction highlights. Preserve them instead of replacing them with hardcoded neutrals.
- Secondary controls use quiet filled neutral surfaces with restrained borders. Collapsed HUD surfaces stay compact capsules; expanded HUD surfaces use a fixed-radius rounded rectangle.
- Never use a fixed cyan value in UI styling. `LauncherVisuals.cyan` is reserved for the fallback when no dynamic theme or artwork tint is available.
- `LauncherMotion` (curves and `Cycle`) is the only motion source; no raw `.easeInOut`, `.spring`, or durations in views.
- The primary action shows at most one ambient effect: a static halo with one arrival pulse.

## Testing

- Keep unit and integration tests offline and fixture-backed; live contracts run only through `just live-contracts`.
- Put shared test helpers in `Tests/ArknightsTestSupport`; do not copy them between test targets.
- Timed code takes an injected `Clock`; tests use a manual clock and never sleep for real.
- Give each test its own UUID temp directory, cleaned in `defer`. Use `.serialized` only as a last resort.
- Test behavior by regression impact; share fixtures and parameterize equivalent cases without deleting path, persistence, migration, isolation, cancellation, or concurrency contracts.

## Verification and Safety

- Run focused checks while iterating, `just check web` plus the production build for website changes, and `just ci` before completion.
- Do not launch previews or the app for UI work unless the user authorizes it.
- Do not install, launch, download, uninstall, or alter the user's game/runtime unless explicitly requested.
- Run Python through the root `pyproject.toml`/`uv.lock` with `uv run --locked`; reuse `scripts/lib` and test changed behavior.
- Derive product/package metadata and per-target resources (icons, bundles, and other multi-target assets) through `scripts/lib/project_config.py`, and runtime layout through `runtime.json`.
- Scripts never hard-code source paths; read them from `project_config`.
- Record user-visible changes in `CHANGELOG.md`; follow `docs/development/releases-and-updates.md` for releases.
- Follow existing commit style, never mention agent/model vendors, and push only with explicit consent.

## References

| Need              | File                                                                             |
| ----------------- | -------------------------------------------------------------------------------- |
| Architecture      | `docs/development/architecture/README.md`                                        |
| Design            | `docs/development/design.md`                                                     |
| Testing           | `docs/development/testing.md`                                                    |
| Storage/runtime   | `docs/help/storage.md`, `docs/help/runtime-compatibility.md`                     |
| Recovery/releases | `docs/development/error-recovery.md`, `docs/development/releases-and-updates.md` |
| Legal             | `docs/legal/third-party-notices.md`                                              |
