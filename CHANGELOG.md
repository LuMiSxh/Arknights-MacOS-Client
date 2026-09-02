---
title: Changelog
description: Release history for Arknights Client
---

# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- An opt-in Canary Features gate in Settings for containing unfinished functionality without changing the default launcher experience.
- The China client behind Canary Features, with the same native install, update, repair, storage, playtime, and launch flow as other regions.
- Resumable, size-bounded runtime archive downloads that retain partial files only while a strong ETag still matches.
- Local playtime statistics with all-time and per-region totals, seven- and thirty-day summaries, a latest-session view, and confirmed local reset (#50).
- A static project website built from the repository documentation, with safe Markdown rendering, base-path-aware navigation, canonical and social metadata, and GitHub Pages release deployment (#56).
- Stable word-based error codes with bundled troubleshooting guides, direct website links, safe report context, and guarded Retry and Repair actions (#57).
- Network-isolated Swift unit and integration levels, a fixture-backed onboarding-to-install workflow, uv-locked pytest coverage for repository scripts (#42).
- Weekly live-contract monitoring for every supported Yostar region (#39).
- Weekly runtime update and provenance monitoring with candidate summaries, pinned-source availability checks, archive verification (#47).
- Language switchers to onboarding and Settings for the system default, English, and German.
- A reviewed German translation for the native launcher, with English fallback and automatic support for macOS per-app language preferences (#38).
- A SwiftPM-compatible String Catalog workflow that validates shipping translations and generated localization resources without requiring an Xcode project (#38).
- Region-specific official Global, Japan, and Korea wordmarks with isolated runtime caches, startup restoration, and localized text fallbacks (#37).
- Sparkle launcher updates with signed appcast and ZIP release artifacts, while retaining ad-hoc macOS signing (#53).
- Storage overview in Settings with independent regional installations, shared runtime data, recreatable caches, and diagnostic logs, plus targeted cleanup actions (#43).
- Donate button for people who want to support the project.
- Dock shortcuts for starting an installed regional client or opening Settings (#46).
- Typo-tolerant preset gallery search with compact suggestions and searchable operator and official-wallpaper metadata.

### Changed

- Refactored the root launcher model into feature controllers with explicit, narrow dependencies and shared game-domain and configuration contracts (#52).
- Moved expensive artwork processing and installation-state inspection behind bounded background operations with explicit request ownership.
- Hardened game configuration and manifest parsing, runtime metadata, compatibility markers, symlink handling, executable names, byte totals, disk-capacity checks, HTTP redirects, and Wine's executable search path without changing supported regions or persisted formats.
- Unified launcher presentations through one sheet and overlay arbiter, improved Reduce Transparency and Dynamic Type behavior, and kept new native UI copy translated in English and German.
- Limited the main activity status to game and runtime operations instead of replacing it with customization, cache, or Settings success messages.
- Indented subprocess output under its owning repository-script status line.
- Made launcher modals adapt to the current window size and announcement popups fit their content, while preserving outer padding and scrolling for long messages.
- Improved keyboard dismissal, VoiceOver labels, reduced-transparency surfaces, reduced-motion feedback, and German text wrapping (#40).
- Hardened GitHub Actions with per-job timeouts and permissions, stale-run cancellation, dependency caching, workflow linting, and provenance attestations for release artifacts.
- Centralized product, package, localization, and release metadata in `Info.plist` and the evaluated SwiftPM manifest, and promoted `runtime.json` to schema v2.
- Consolidated repository scripts into one locked uv project, isolated packaging-only tools in their own dependency group, and removed single-use helpers and low-value wrapper tests.

### Fixed

- Matched the clickable areas of themed text fields and compact version and music HUD pills to their visible surfaces (Thanks to @darkwebdev, #60).
- Prevented stale artwork, logo, icon, preset-cache, metadata, and theme work from overwriting a newer region or user selection.
- Kept the shared Wine prefix owned until prefix-wide shutdown, preserved the originating region and failure across retries, and made stop, cancellation, and early process-exit cleanup deterministic.
- Kept music and Now Playing state isolated from stale player callbacks and private MediaPlayer queues.
- Prevented Settings, onboarding, popup, failure, and Rosetta presentations from masking one another.
- Rejected incomplete wallpaper downloads instead of displaying partially decoded images.
- Restored older official wallpapers whose Fankit entries wrap image URLs in single-element arrays (Thanks to @darkwebdev, #54).
- Kept music Play and Pause controls synchronized when the embedded player reports a delayed state from an earlier action (Thanks to @darkwebdev, #51).
- Refreshed the main window's Play control, Settings sidebar, and status pill immediately when the app language changes instead of waiting for an unrelated state change to redraw them.
- Removed the decorative three-part line below the regional wordmark and kept late branding responses from replacing the selected region's logo (#37).

## [0.4.1]

### Changed

- Scrolled the current song title only when it is too wide for the music HUD, while preserving a static truncated title when Reduce Motion is enabled.
- Locked launch-only display, Metal HUD, Game Mode, and Wine synchronization settings while a game session is starting or running, and recorded the selected launch configuration in diagnostics.
- Added the Yostar API operation, region, endpoint, HTTP status, and decoding phase to launcher logs without exposing request authorization or response bodies.

### Fixed

- Accepted the official leading-slash convention in game manifests while preserving installer path-containment protections, restoring installs, updates, and repairs for every region (Thanks to @NemesisHoshiko, #36).
- Rejected manifest collisions with installer-owned files and stopped oversized download responses before they can grow temporary files beyond their declared size (Thanks to @NemesisHoshiko, #36).
- Kept installation progress accurate when a checksum failure removes a partial download before retrying.

## [0.4.0]

### Added

- A resumable setup assistant for first installs and 0.3.x upgrades, with update preflight, background installation, and guided settings.
- Dedicated support actions for GitHub launcher reports and Yostar account, payment, or game-service issues.
- Free-space validation before game installation or updates.
- Functional Rosetta 2 preflight and guided installation during setup and launch, including macOS 27 upgrade and Legacy Game Test Mode diagnostics (Thanks to @Sorula2079, #33).
- An optional Metal Performance HUD for native FPS and GPU diagnostics.
- An experimental Game Mode integration that requires the full Xcode app.
- An experimental Danger Zone control for switching new game launches between MSYNC and ESYNC.
- A Settings Danger Zone for resets, Wine-prefix maintenance, migration, and game removal.
- Custom launcher icons with normalized Dock sizing (Thanks to @RadioNoiseE, #24).
- Drag-and-drop selection for launcher artwork and icons.
- Optional game-version, server-time, and daily-reset indicators above the Play controls.
- Cache cleanup for DXMT shaders, the embedded browser, and downloaded gallery assets.
- Optional YouTube background music with shuffled playlists, synchronized track titles, volume controls, and now-playing links (Thanks to @darkwebdev, #27).
- Expandable now-playing controls with deterministic playlist navigation and compact mute or volume adjustment (#27).
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

- Updated the bundled WineCX 11.15 and DXMT 0.80 runtime to the maintained dappermint build `4.5.118`.
- Matched the launcher's resolution choices to the options offered by the official PC client.
- Made segmented controls consistently honor dynamic and Danger Zone tint colors across supported macOS versions.
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
- Reworked launcher and music lifecycle handling around explicit hierarchical state machines.
- Kept potentially private log excerpts out of pre-filled GitHub issue URLs.

### Fixed

- Kept the Notices window above fullscreen gameplay and synchronized while dragging (Thanks to u/Fukksaks5th, #19).
- Prevented the first Notices click from briefly flashing the game during focus handoff (#26).
- Loaded cached artwork immediately, kept it visible while switching regions, and avoided transitions when the server artwork is unchanged.
- Reapplied normalized Wine scrolling on every launch to prevent excessive trackpad speed (Thanks to @darkwebdev, #28).
- Matched launcher and game icon Dock footprints to native macOS apps (#24).
- Corrected the launcher update status shown in Settings.
- Applied custom launcher icons consistently in the Dock, Finder, Spotlight, and macOS Now Playing surfaces.
- Prevented repair, relocation, cache maintenance, and uninstall operations from modifying game files while Arknights is active.
- Kept running games stoppable when a background refresh or unrelated Settings action reports an error.
- Made concurrent downloads, Wine helper cancellation, and music player replacement resilient to stale asynchronous work.
- Prevented a launch-time crash when macOS requests Now Playing artwork from its MediaPlayer queue.
- Left-aligned the expanded version text consistently with the music HUD.

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

[Unreleased]: https://github.com/LuMiSxh/Arknights-MacOS-Client/compare/v0.4.1...HEAD
[0.4.1]: https://github.com/LuMiSxh/Arknights-MacOS-Client/compare/v0.4.0...v0.4.1
[0.4.0]: https://github.com/LuMiSxh/Arknights-MacOS-Client/releases/tag/v0.4.0
[0.3.0]: https://github.com/LuMiSxh/Arknights-MacOS-Client/releases/tag/v0.3.0
[0.2.0]: https://github.com/LuMiSxh/Arknights-MacOS-Client/releases/tag/v0.2.0
[0.1.0]: https://github.com/LuMiSxh/Arknights-MacOS-Client/releases/tag/v0.1.0
