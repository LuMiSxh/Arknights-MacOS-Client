# Agent Instructions

## Scope

- Build only for Apple Silicon and macOS 26 or newer.
- Support the official Global, Japan, and Korea PC clients (all published by Yostar on `yo-star.com`, same launcher API shape and signature algorithm, verified 2026-08-16). Do not add CN behavior: it runs on separate Hypergryph infrastructure (its own launcher, its own account system) and its PC client bundles Tencent ACE, a kernel-mode anti-cheat with no Wine/Linux support — a verified technical blocker, not just unverified scope.
- Keep source code, UI copy, documentation, commits, and tests in English.
- Use SwiftPM as the source of truth; do not add an Xcode project.
- Do not commit Arknights binaries, game files, downloaded artwork, Wine runtimes, or files from `dist/`.

## Commands

| Task          | Command        |
| ------------- | -------------- |
| Source checks | `just check`   |
| Full CI       | `just ci`      |
| Run launcher  | `just run`     |
| UI preview    | `just preview` |
| App bundle    | `just app`     |
| Dev runtime   | `just runtime` |
| App + runtime | `just dev`     |
| DMG + runtime | `just dev-dmg` |
| App icon      | `just icon`    |

## Key Conventions

- Use tabs with a width of four in Swift files; follow `.swift-format`.
- Keep SwiftUI views in `UI`, state and user actions in `ViewModels`, external work in `Services` or `Runtime`, and persisted paths in `Storage`.
- Keep handwritten Swift files below 350 lines; split cohesive behavior into focused types or extensions.
- Keep UI state changes on `@MainActor`; move long synchronous network, hashing, extraction, and file work off it.
- Treat game installation as an exclusive operation. A refresh, Settings action, or repeated click must never start another installer or overwrite active progress.
- Preserve resumable `.part` downloads and validate every manifest path before writing it.
- Use standard macOS storage locations through `AppPaths`; do not introduce repository-local or legacy migration paths without an explicit requirement.
- Each `GameRegion` gets its own install directory and installed-state file so regions install and update independently; they share one Wine prefix, since `WinePrefixConfigurator` already re-points the `G:` drive to the active region's directory on every launch.
- Keep the interface native to macOS while following `docs/design.md`; branding may be angular, but primary actions use native controls.
- Add focused tests for changed installer, updater, storage, parsing, or concurrency behavior.
- Record user-visible changes in the next release section in `CHANGELOG.md`.
- Preserve MPL-2.0 SPDX headers in handwritten Swift, C, and Python source files.
- Regenerate `Resources/AppIcon.icns` and `Resources/Assets.car` with `just icon`; do not edit them directly.
- Unless explicitly requested, do not install, launch, download, uninstall, or alter a user's local game while verifying changes.

## External References

| Need                                  | File                                |
| ------------------------------------- | ----------------------------------- |
| Project setup and contribution rules  | `README.md`                         |
| Architecture and source boundaries    | `docs/architecture.md`              |
| Interface direction                   | `docs/design.md`                    |
| Persistent files and removal behavior | `docs/storage.md`                   |
| Versioning and release workflow       | `docs/releases-and-updates.md`      |
| Third-party obligations               | `docs/legal/third-party-notices.md` |

## Release Rules

- Releases are manual draft releases triggered with an `X.Y.Z` version.
- Trigger releases only from clean, pushed `main`; the version must match `CHANGELOG.md` and `Resources/Info.plist`.
- Never replace a published tag or release asset; issue a higher version for fixes.
- Keep the prefix revision, tested runtime versions, provenance, URLs, and SHA-256 values in `runtime.json`. Increase `prefixRevision` when existing prefixes must reapply runtime configuration. Release automation must not replace these values with hidden repository configuration.
- Do not claim Developer ID signing, notarization, or silent self-updates without an Apple Developer account.
