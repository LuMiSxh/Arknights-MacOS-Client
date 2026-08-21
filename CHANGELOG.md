# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.4.0]

### Added

- A resumable setup assistant for first installs and 0.3.x upgrades, with update preflight, background installation, and guided settings.
- Dedicated support actions for GitHub launcher reports and Yostar account, payment, or game-service issues.
- Free-space validation before game installation or updates.
- Functional Rosetta 2 preflight during setup and launch, including macOS 27 upgrade and Legacy Game Test Mode diagnostics.
- An optional Metal Performance HUD for native FPS and GPU diagnostics.
- An experimental Game Mode integration that requires the full Xcode app.
- A Settings Danger Zone for resets, Wine-prefix maintenance, migration, and game removal.
- Custom launcher icons with normalized Dock sizing (Thanks to @RadioNoiseE, #24).
- Drag-and-drop selection for launcher artwork and icons.
- Optional game-version, server-time, and daily-reset indicators above the Play controls.
- Cache cleanup for DXMT shaders, the embedded browser, and downloaded gallery assets.
- Optional YouTube background music with playlists, volume controls, and now-playing links (Thanks to @darkwebdev, #27).
- Expandable now-playing controls for pausing, resuming, and navigating playlists (#27).
- Expandable game-version details with a manual update check.
- Dynamic Theme colors for controls, HUD elements, and compatible launcher icons.
- Floating HUD pills for region, game version, reset time, and background music.
- Native macOS 15–25 fallbacks while preserving Liquid Glass on macOS 26 (Thanks to @Mickhasinsomnia, #29).
- Dedicated galleries for official wallpapers and paired Launcher/Game operators, with bounded downloads and caching (Thanks to @darkwebdev, #30; @RadioNoiseE, #24).
- Linked operator presets with a framed Launcher treatment and a simple character Game icon.
- Custom game icons and a normalized "Use Default" option that preserves the original Arknights icon.
- Version-range and display-window options for announcement management.
- Recipe-download tracking in release statistics.

### Changed

- Declared the launcher as a game in its macOS application metadata.
- Reduced DXMT logging to error-only output outside diagnostics.
- Reorganized Settings and moved music controls into a dedicated Audio section.
- Polished Settings with right-aligned actions, clearer descriptions, and better-positioned scrollbars.
- Attached destructive confirmations directly to their initiating Settings controls.
- Unified popups and bundled-document sheets with the Settings visual language.
- Made prominent button text adapt to the sampled accent's luminance.
- Enlarged the main Settings control.
- Hardened installer paths, temporary-file handling, and manifest conflict detection.
- Replaced silent filesystem and process failures with contextual logging or visible errors.
- Split large UI and service types, centralized limits, and expanded runtime documentation.
- Consolidated development commands, preview scenarios, formatting, and script output.

### Fixed

- Kept the Notices window above fullscreen gameplay and synchronized while dragging (Thanks to u/Fukksaks5th, #19).
- Prevented the first Notices click from briefly flashing the game during focus handoff (#26).
- Loaded cached artwork immediately, kept it visible while switching regions, and avoided transitions when the server artwork is unchanged.
- Reapplied normalized Wine scrolling on every launch to prevent excessive trackpad speed (Thanks to @darkwebdev, #28).
- Matched launcher and game icon Dock footprints to native macOS apps (#24).
- Corrected the launcher update status shown in Settings.

## [0.3.0]

### Added

- Support for the Japan and Korea Arknights PC clients alongside Global, each installed, updated, and launched independently. Switch regions from Settings → Installation, or from the region switcher in the main window once more than one region is installed.
- A "Report a Problem" button in Settings and on launch failures that opens a pre-filled GitHub bug report with your launcher version, macOS and chip details, and a recent log excerpt.
- New troubleshooting instructions for development to locate logs faster.
- Separate `unity.log` and `chromium.log` files for the game and its embedded browser, kept apart from `wine.log` and reachable from the same Logs button in Settings.

### Changed

- Expanded launcher and Wine diagnostic logging with clearer detail for troubleshooting, including why a Wine prefix migration ran or was skipped.
- Redesigned Settings with clearer grouping, consistent glass and cyan-accented controls, and working hover feedback throughout.
- Restored PayPal browser-challenge compatibility by disabling WebGL, GPU rasterization, and accelerated 2D canvas in the embedded browser, while keeping GPU compositing enabled for rendering speed; credit card and PayPal payments have now both been observed to work (Thanks to @darkwebdev).
- Centralized scattered timeouts, buffer sizes, and retry counts into a single constants file.
- Consolidated the Vuplex and PlatformProcess compatibility shims onto one shared file-swap engine, without changing their install or restore behavior.

### Fixed

- Slowed touchpad scrolling in-game to match Windows mouse-wheel speed (Thanks to u/herr-tibalt).
- Integrated the separate Notices helper with macOS windowing so it remains interactive, stays out of the Dock, and follows the game across window moves and Spaces (Thanks to u/No_Entrepreneur_6542).
- Mapped Command to Control in Wine so standard macOS copy and paste shortcuts work in the in-game browser, and fixed a separate copy-paste sync timeout under Wine.
- Fixed a Chromium sandbox crash in the embedded browser by stubbing the full set of Windows AppContainer APIs it requires, instead of only the one used for OAuth popups (Thanks to @darkwebdev).
- Fixed launcher background artwork and branding decoding failing when regional APIs (such as Japan or Korea) return empty URLs for privacy policies or user agreements.

## [0.2.0]

### Added

- Native release-note popups
- Repository hosted one-time announcements
- Isolated (development) UI-state simulator
- High-resolution rendering for sharper game and login-browser output on HiDPI displays.

### Changed

- Replaced the mixed shell and Python build scripts with uv-managed Python tooling and clearer command output.
- Made Wine prefix updates and game compatibility components resumable, idempotent, and removable across launcher versions.
- Kept DXMT shader data in the isolated persistent cache and added detailed runtime-stage timings to diagnostics.
- Enabled Chromium GPU compositing while retaining Vuplex's stable CPU texture transfer.
- Filled draft GitHub Release notes from the matching changelog section.
- Required releases to be built from merged `main` with matching changelog and app-bundle versions.
- Replaced per-byte game downloads with buffered streaming and loaded independent launcher metadata in parallel.
- Restored paused downloads as a Resume state and counted existing partial files in progress.
- Used Arknights cyan consistently for active Settings switches and text links.

### Removed

- Repeated Wine registry processes and no-op prefix writes from normal game launches.

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

[Unreleased]: https://github.com/LuMiSxh/Arknights-MacOS-Client/compare/v0.4.0...HEAD
[0.4.0]: https://github.com/LuMiSxh/Arknights-MacOS-Client/releases/tag/v0.4.0
[0.3.0]: https://github.com/LuMiSxh/Arknights-MacOS-Client/releases/tag/v0.3.0
[0.2.0]: https://github.com/LuMiSxh/Arknights-MacOS-Client/releases/tag/v0.2.0
[0.1.0]: https://github.com/LuMiSxh/Arknights-MacOS-Client/releases/tag/v0.1.0
