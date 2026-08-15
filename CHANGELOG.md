# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- Replaced the mixed shell and Python build scripts with uv-managed Python tooling and clearer command output.
- Made Wine prefix updates and game compatibility components resumable, idempotent, and removable across launcher versions.
- Kept DXMT shader data in the isolated persistent cache and added launch-phase timings to diagnostics.

## [0.1.0]

### Added

- Native Apple Silicon launcher for the official Global PC client on macOS 26 and newer.
- Resumable game installation, updates, repair, removal, and independent update checks.
- Self-contained DMG with a verified Wine 11.15 and DXMT 0.80 runtime.
- Windowed, borderless, and fullscreen launch options with resolution controls.
- Working in-game web login through a bundled Vuplex compatibility shim.
- Isolated Wine data, native game controls, `Command-Q` support, and launcher/Wine logs.
- Native Liquid Glass interface with official branding, notices, custom artwork, and settings.
- Reproducible local packaging and manually triggered GitHub draft releases.

[Unreleased]: https://github.com/LuMiSxh/Arknights-MacOS-Client/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/LuMiSxh/Arknights-MacOS-Client/releases/tag/v0.1.0
