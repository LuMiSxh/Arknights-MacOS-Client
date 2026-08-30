# Agent Instructions

## Scope

- Target Apple Silicon and macOS 15+. Guard macOS-26-only Liquid Glass APIs through `AdaptiveGlass.swift` fallbacks.
- Support only Yostar's official Global, Japan, and Korea PC clients; never add CN behavior.
- Keep source, docs, tests, localization keys, translator comments, and commits in English. Ship complete reviewed English and German UI copy.
- Use SwiftPM as the source of truth; do not add an Xcode project.
- Keep the static SvelteKit site in `web/`; follow `docs/development/README.md#documentation-website` and do not add Vitest.
- Never commit game/runtime binaries, downloaded artwork, or `dist/`; regenerate tracked shipping icons only with `just icon`.

## Commands

| Task | Command |
| --- | --- |
| Focused native checks | `just check` |
| Native CI | `just ci` |
| Integration tests | `just integration` |
| Website checks | `just check web` |
| Production website | `cd web && BASE_PATH=/Arknights-MacOS-Client pnpm build` |
| Other tasks | `just --list` |

## Architecture and Swift

- Use Swift 6.2. Keep composition in `Application`, feature work in `Features/*`, cross-feature primitives/configuration in `Shared`, and feature-independent I/O in `Infrastructure`.
- Never import feature-owned types from `Shared` or `Infrastructure`; map infrastructure errors at the owning feature boundary.
- Keep components feature-local unless multiple features share the same presentation contract.
- Keep handwritten production Swift and Swift tests below 350 lines. Generated localization symbols, native C/Objective-C shims, and scripts are exempt.
- Use tabs with width four and follow `.swift-format`.
- Keep observable/UI/AppKit state on `@MainActor`; move synchronous network, hashing, extraction, and file work off it.
- Use `@Observable`; keep `LauncherViewModel` at composition and inject narrow dependencies into features and views.
- After suspension, revalidate request/session/generation ownership before publishing UI state or committing identity-sensitive file/process state.
- Increment a cache/request epoch before clearing or replacing state so suspended work cannot republish stale results.
- Keep the shared Wine prefix owned until prefix-wide shutdown completes; direct game-process exit alone never means Idle.
- Treat installation as exclusive, preserve resumable `.part` files, and validate every manifest path before writing.
- Define persisted locations through `AppPaths`; preserve paths, keys, and serialized formats unless a migration is explicit.
- Centralize application-owned fixed keys, limits, retries, and timeouts in `Shared/Configuration/AppConstants.swift`; keep upstream literals beside their protocol.
- Put every user-facing string in the owning String Catalog with a namespaced lower-camel key, translator comment, and complete English/German values; never edit generated symbols.
- Follow `docs/development/design.md`; reuse controls only when semantics, spacing, accessibility, and state match.
- Avoid silent `try?` for filesystem, process, and network work. Preserve MPL-2.0 SPDX headers in handwritten Swift, C, and Python.
- Test behavior by regression impact; share fixtures and parameterize equivalent cases without deleting path, persistence, migration, isolation, cancellation, or concurrency contracts.

## Verification and Safety

- Run focused checks while iterating, `just check web` plus the production build for website changes, and `just ci` before completion.
- Keep unit/integration tests offline and fixture-backed; live contracts run only through `just live-contracts`.
- Do not launch previews or the app for UI work unless the user authorizes it.
- Do not install, launch, download, uninstall, or alter the user's game/runtime unless explicitly requested.
- Run Python through the root `pyproject.toml`/`uv.lock` with `uv run --locked`; reuse `scripts/lib` and test changed behavior.
- Derive product/package metadata through `scripts/lib/project_config.py` and runtime layout through `runtime.json`.
- Record user-visible changes in `CHANGELOG.md`; follow `docs/development/releases-and-updates.md` for releases.
- Follow existing commit style, never mention agent/model vendors, and push only with explicit consent.

## References

| Need | File |
| --- | --- |
| Architecture | `docs/development/architecture/README.md` |
| Testing | `docs/development/testing.md` |
| Localization | `docs/development/localization.md` |
| Storage/runtime | `docs/help/storage.md`, `docs/help/runtime-compatibility.md` |
| Recovery/releases | `docs/development/error-recovery.md`, `docs/development/releases-and-updates.md` |
| Legal | `docs/legal/third-party-notices.md` |
