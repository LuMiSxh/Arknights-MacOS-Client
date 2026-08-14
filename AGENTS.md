# Agent Instructions

## Scope

- Build only for Apple Silicon and macOS 26 or newer.
- Support only the official Global PC client; do not add CN behavior without a verified API and an explicit decision.
- Keep source code, UI copy, documentation, commits, and tests in English.
- Use SwiftPM as the source of truth; do not add an Xcode project.
- Do not commit Arknights binaries, game files, downloaded artwork, Wine runtimes, or files from `dist/`.

## Commands

| Task          | Command                                                                              |
| ------------- | ------------------------------------------------------------------------------------ |
| Format check  | `swift format lint --configuration .swift-format --recursive --strict Sources Tests` |
| Tests         | `swift test --arch arm64`                                                            |
| Release build | `swift build --configuration release --arch arm64`                                   |
| App bundle    | `./scripts/build-app.sh`                                                             |
| DMG           | `ARKNIGHTS_RUNTIME_DIR="/path/to/Wine-DXMT" ./scripts/build-dmg.sh`                  |

## Key Conventions

- Use tabs with a width of four in Swift files; follow `.swift-format`.
- Keep SwiftUI views in `UI`, state and user actions in `ViewModels`, external work in `Services` or `Runtime`, and persisted paths in `Storage`.
- Keep UI state changes on `@MainActor`; move long synchronous network, hashing, extraction, and file work off it.
- Treat game installation as an exclusive operation. A refresh, Settings action, or repeated click must never start another installer or overwrite active progress.
- Preserve resumable `.part` downloads and validate every manifest path before writing it.
- Use standard macOS storage locations through `AppPaths`; do not introduce repository-local or legacy migration paths without an explicit requirement.
- Keep the interface native to macOS while following `docs/design.md`; branding may be angular, but primary actions use native controls.
- Add focused tests for changed installer, updater, storage, parsing, or concurrency behavior.
- Record user-visible changes under `Unreleased` in `CHANGELOG.md`.
- Preserve MPL-2.0 SPDX headers in Swift and shell source files.
- Regenerate `Resources/AppIcon.icns` with `scripts/generate-icon.sh`; do not edit it directly.
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
- Never replace a published tag or release asset; issue a higher version for fixes.
- Keep runtime URLs and SHA-256 values external to the repository and verify them during packaging.
- Do not claim Developer ID signing, notarization, or silent self-updates without an Apple Developer account.
