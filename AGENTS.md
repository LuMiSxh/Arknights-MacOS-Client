# Agent Instructions

## Scope

- Build only for Apple Silicon and macOS 15+. Guard macOS-26-only Liquid Glass APIs through `AdaptiveGlass.swift` fallbacks.
- Support only Yostar's official Global, Japan, and Korea PC clients. Do not add CN behavior; its Hypergryph infrastructure and Tencent ACE anti-cheat are incompatible.
- Keep source code, documentation, commits, tests, localization keys, and translator comments in English. Maintain reviewed English and German UI copy through the String Catalogs.
- Use SwiftPM as the source of truth; do not add an Xcode project.
- Do not commit game/runtime binaries, downloaded artwork, or files from `dist/`. Commit the tracked shipping icon assets only when regenerated with `just icon`.

## Commands

| Task                     | Command                    |
| ------------------------ | -------------------------- |
| Source checks            | `just check`               |
| Integration tests        | `just integration`         |
| Live service contracts   | `just live-contracts`      |
| Runtime source monitor   | `just runtime-monitor`     |
| Format sources           | `just format`              |
| Regenerate localizations | `just format localization` |
| Full CI                  | `just ci`                  |
| UI preview               | `just preview`             |
| App bundle               | `just app`                 |
| Dev runtime              | `just runtime`             |
| App + runtime            | `just dev`                 |
| App + runtime, run       | `just dev app run`         |
| DMG + runtime            | `just dev dmg`             |
| App icon                 | `just icon`                |

## Architecture and Swift

- Organize production code by feature. Keep app composition in `Application`, cross-feature primitives in `Shared`, and feature-independent I/O helpers in `Infrastructure`.
- Keep views, state/actions, models, and external work together inside their owning feature; do not recreate top-level technical layer folders.
- Keep components feature-local by default. Promote them to `Shared/UI/Components` only when multiple features use the same presentation contract.
- Consolidate identical chrome and controls; do not merge controls that only look similar but differ in semantics, spacing, accessibility, or state.
- Keep handwritten Swift files below 350 lines. Split by cohesive responsibility, not merely into extensions that preserve the same oversized dependency surface. Exceed the limit only for declarations Swift cannot move into an extension, such as an `@Observable` type's stored properties; flag that exception instead of forcing an artificial split.
- Use tabs with width four in Swift and follow `.swift-format`.
- Keep UI state on `@MainActor`; move long synchronous network, hashing, extraction, and file work off it.
- Use Swift 5.9+ `@Observable`. Keep the root launcher model as composition state, while feature controllers use narrow dependencies rather than implicit singletons or the whole root model.
- Treat installation as exclusive; preserve resumable `.part` files and validate every manifest path before writing.
- Keep every region's installation/state independent while sharing one Wine prefix whose `G:` drive is repointed on launch.
- Define persisted locations only through `AppPaths`; preserve existing paths, keys, and serialized formats unless migration is explicitly required.
- Follow `docs/design.md`; use the existing shared action/control families instead of per-call styling.
- Follow `docs/localization.md`; do not edit generated localization symbols or `.strings` files directly.
- Write expressive code. Comment only non-obvious WHYs, workarounds, and security/concurrency invariants; add concise DocC for public APIs and complex domain models.
- Centralize fixed keys, limits, retries, and timeouts in `AppConstants.swift`; avoid silent `try?` for filesystem, process, and network work.
- Test behavior according to regression impact. Preserve installer safety, persistence, parsing, migration, runtime isolation, and concurrency coverage; do not require tests for file moves, view composition, trivial accessors, or wrappers.
- Share test fixtures and parameterize equivalent cases. Apply the 350-line limit to test files too.
- Preserve MPL-2.0 SPDX headers in handwritten Swift, C, and Python files.

## Verification and Safety

- Run focused checks while iterating and `just ci` before completion.
- Keep unit and integration tests fixture-backed and offline; follow `docs/testing.md` for level ownership and live-contract gates.
- For UI refactors, compare the affected isolated developer scenarios; do not launch previews or apps unless the user authorizes it.
- Unless explicitly requested, do not install, launch, download, uninstall, or alter the user's local game or runtime.
- Regenerate `Resources/AppIcon.icns` and `Resources/Assets.car` only with `just icon`.
- Run scripts from the root `pyproject.toml` and `uv.lock` with `uv run --locked`; keep packaging-only dependencies in the `packaging` group, reuse `scripts/lib`, and cover changed behavior in `scripts/tests/test_*.py`.
- Derive script product and package metadata through `scripts/lib/project_config.py`; keep runtime layout in `runtime.json` instead of duplicating either contract in Python.
- Record user-visible changes in `CHANGELOG.md`; follow `docs/releases-and-updates.md` for releases.

## Commit Rules

- Follow the existing commit style. Do not mention agent/model vendors; push only with explicit user consent.

## References

| Need                    | File                                |
| ----------------------- | ----------------------------------- |
| Setup and contribution  | `README.md`                         |
| Architecture            | `docs/architecture.md`              |
| Testing                 | `docs/testing.md`                   |
| Interface               | `docs/design.md`                    |
| Localization            | `docs/localization.md`              |
| Storage                 | `docs/storage.md`                   |
| Runtime contract        | `docs/runtime-compatibility.md`     |
| Troubleshooting         | `docs/troubleshooting.md`           |
| Releases                | `docs/releases-and-updates.md`      |
| Third-party obligations | `docs/legal/third-party-notices.md` |
