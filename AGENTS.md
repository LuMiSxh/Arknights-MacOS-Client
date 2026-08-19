# Agent Instructions

## Scope

- Build only for Apple Silicon; support macOS 15 (Sequoia) and newer. Guard macOS-26-only APIs (Liquid Glass) with `#available(macOS 26, *)` via `adaptiveGlassEffect`/`adaptiveGlassButton` in `AdaptiveGlass.swift` — macOS 15–25 fall back to native Material/bordered styles.
- Support the official Global, Japan, and Korea PC clients (all published by Yostar on `yo-star.com`, same launcher API shape and signature algorithm, verified 2026-08-16). Do not add CN behavior: it runs on separate Hypergryph infrastructure (its own launcher, its own account system) and its PC client bundles Tencent ACE, a kernel-mode anti-cheat with no Wine/Linux support — a verified technical blocker, not just unverified scope.
- Keep source code, UI copy, documentation, commits, and tests in English.
- Use SwiftPM as the source of truth; do not add an Xcode project.
- Do not commit Arknights binaries, game files, downloaded artwork, Wine runtimes, or files from `dist/`.

## Commands

| Task               | Command            |
| ------------------ | ------------------ |
| Source checks      | `just check`       |
| Format sources     | `just format`      |
| Full CI            | `just ci`          |
| UI preview         | `just preview`     |
| App bundle         | `just app`         |
| Dev runtime        | `just runtime`     |
| App + runtime      | `just dev`         |
| App + runtime, run | `just dev app run` |
| DMG + runtime      | `just dev dmg`     |
| App icon           | `just icon`        |

## Key Conventions

- Use tabs with a width of four in Swift files; follow `.swift-format`.
- Keep SwiftUI views in `UI`, state and user actions in `ViewModels`, external work in `Services` or `Runtime`, and persisted paths in `Storage`.
- Keep handwritten Swift files below 350 lines; split cohesive behavior into focused types or extensions. Exceed it only when the excess is stored-property/declaration code Swift can't move into an extension (e.g. an `@Observable` class's properties); flag the overage instead of forcing an artificial split.
- Keep UI state changes on `@MainActor`; move long synchronous network, hashing, extraction, and file work off it.
- Use Swift 5.9+ `@Observable` for fine-grained, property-level view invalidation; avoid legacy `ObservableObject` and `@Published` God-objects.
- Treat game installation as an exclusive operation. A refresh, Settings action, or repeated click must never start another installer or overwrite active progress.
- Preserve resumable `.part` downloads and validate every manifest path before writing it.
- Use standard macOS storage locations through `AppPaths`; do not introduce repository-local or legacy migration paths without an explicit requirement.
- Each `GameRegion` gets its own install directory and installed-state file so regions install and update independently; they share one Wine prefix, since `WinePrefixConfigurator` already re-points the `G:` drive to the active region's directory on every launch.
- Keep the interface native to macOS while following `docs/design.md`; branding may be angular, but primary actions use native controls.
- Add focused tests for changed installer, updater, storage, parsing, or concurrency behavior.
- Record user-visible changes in the next release section in `CHANGELOG.md`.
- Verify changes with `just ci` and `just dev run` before considering work done.
- Preserve MPL-2.0 SPDX headers in handwritten Swift, C, and Python source files.
- Regenerate `Resources/AppIcon.icns` and `Resources/Assets.car` with `just icon`; do not edit them directly.
- Unless explicitly requested, do not install, launch, download, uninstall, or alter a user's local game while verifying changes.
- Write scripts as `uv run --script` entry points with inline PEP 723 metadata; share process/output helpers via `scripts/lib/common.py` and `scripts/lib/console.py` instead of duplicating them.
- Add or update `scripts/tests/test_*.py` (`unittest`, run via `just check scripts`) for changed script behavior.

## Code Style & Commenting Philosophy

- Write expressive Swift and C so code explains _what_ it does without line-by-line commentary.
- Comment only the "WHY": non-obvious workarounds (Wine/Windows/macOS quirks, IPC constraints, API bugs) and security/memory invariants. No comments that restate the code.
- Give public APIs, protocols, and complex domain models concise `///` DocC comments covering preconditions, side effects, and thrown errors.
- Centralize magic numbers and strings (timeouts, buffer sizes, retry counts, fixed keys) into `AppConstants.swift`; never scatter them through implementation logic.
- Avoid silent `try?` in filesystem, process, or network operations; use `do-catch` and log unexpected failures with context.

## External References

| Need                                  | File                                |
| ------------------------------------- | ----------------------------------- |
| Project setup and contribution rules  | `README.md`                         |
| Architecture and source boundaries    | `docs/architecture.md`              |
| Interface direction                   | `docs/design.md`                    |
| Persistent files and removal behavior | `docs/storage.md`                   |
| Wine/DXMT runtime contract            | `docs/runtime-compatibility.md`     |
| Announcement feed format              | `docs/announcements.md`             |
| Troubleshooting and log locations     | `docs/troubleshooting.md`           |
| Versioning and release workflow       | `docs/releases-and-updates.md`      |
| Third-party obligations               | `docs/legal/third-party-notices.md` |

## Release Rules

- Releases are manual draft releases triggered with an `X.Y.Z` version.
- Trigger releases only from clean, pushed `main`; the version must match `CHANGELOG.md` and `Resources/Info.plist`.
- Never replace a published tag or release asset; issue a higher version for fixes.
- Keep the prefix revision, tested runtime versions, provenance, URLs, and SHA-256 values in `runtime.json`. Increase `prefixRevision` when existing prefixes must reapply runtime configuration. Release automation must not replace these values with hidden repository configuration.
- Do not claim Developer ID signing, notarization, or silent self-updates without an Apple Developer account.

## Commit Rules

- Do not mention your AI model or company in commit messages or code.
- Follow the established commit scheme by inspecting past git log history.
- Only push commits when the user gives explicit consent.
