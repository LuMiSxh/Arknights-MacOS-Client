# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.4.0]

### Added

- A free-disk-space check before installing or updating the game, using Yostar's own reported install size so it stays accurate as the game grows; installation now fails fast with a clear message instead of running out of space mid-download.
- Detection of a missing Rosetta 2 runtime before launching the game, with an informative message instead of a silent 90-second window-readiness timeout.
- A Metal Performance HUD toggle in Settings → General that shows Apple's native FPS and GPU overlay during gameplay.
- An experimental Game Mode toggle in a new Danger Zone in Settings → Installation, requesting elevated macOS scheduling priority for the game while it runs; only takes effect if the full Xcode app is installed; disabled by default and off with a clear message otherwise.
- A Danger Zone panel in Settings → Installation that groups Uninstall Game and Force Migration together with a distinct visual style, since both undo real setup work.
- A custom app icon option in Settings → General; choose an image to replace the Dock and Finder icon, or reset to the default (Thanks to @RadioNoiseE, #24).
- A toggleable server time and daily reset countdown next to the version label in Settings → General.
- A "Clear Cache" action in Settings → Installation → Maintenance that shows and frees the space used by the DXMT shader and embedded browser caches; both rebuild automatically.
- Drag-and-drop image support on the Artwork and App Icon panels in Settings → General, alongside the existing file pickers.
- A "Show Game Version" toggle in Settings → General, on by default, for the version label next to the region indicator.
- A "Delete Wine Prefix" action in the Danger Zone that fully rebuilds the Wine environment on the next launch, including saved Yostar/Google/Apple/Facebook browser logins, without touching game files — a stronger reset than Force Migration.
- A "Reset All Settings" action in the Danger Zone that restores every launcher toggle and option to default, leaving the install location and selected region untouched.
- Optional YouTube-based launcher background music, off by default, with URL validation, playlist shuffling, and an optional now-playing title (Thanks to @darkwebdev, #27).
- A Settings → General → Input toggle for precise trackpad scrolling, enabled by default, so two-finger horizontal swipes work as expected (Thanks to @darkwebdev, #28).
- A "Dynamic Theme" option in Settings → General → Personalization that harmonizes launcher controls, HUD pills, and the app icon with colors sampled from the active artwork.
- Dynamic Theme now also updates the app icon: the default icon is hue-rotated in YIQ space to match sampled artwork colors, then normalized to a 512×512 point icon with Apple's 80.5% grid padding so the Dock tile no longer appears oversized.
- Small floating HUD pills above the main control bar for the now-playing track, region, reset countdown, and game version, each shown only when relevant.
- Support for macOS 15 (Sequoia) and newer, down from macOS 26; Liquid Glass stays full-featured on macOS 26, with native Material and bordered-button fallbacks on macOS 15–25 (Thanks to @Mickhasinsomnia, #29).
- Optional launcher background music now opens the currently playing track when tapping the now-playing HUD pill, and the pill now keeps to one-line text with truncation.

### Changed

- Declared the app as a game (macOS application category) so the system can offer native game-related features.
- Quieted DXMT's Metal translation logging by default; it previously ran at its noisiest level on every launch instead of only under diagnostics.
- Reorganized Settings → General into "Display & Controls", "Launcher", and "Personalization" panels, and split Music out into its own "Audio" section.
- Moved the Uninstall Game and Force Migration confirmation dialogs to attach directly to their buttons instead of the Settings window, so their animations originate from the right place.
- Reordered the Danger Zone from least to most destructive: Game Mode, Reset All Settings, Force Migration, Delete Wine Prefix, Uninstall Game.
- Reworked the Settings sheet to a single, cohesive dark glass surface: floating Done button, shared warm modal background, adjusted sidebar tint, and inset scrollbar indicators for full-page consistency.
- Code hardening pass: split every Swift file back under the 350-line convention, centralized a scattered timeout into `AppConstants`, added `///` documentation to protocols and coordinator types across the Swift sources, and documented every function in the `RuntimeSupport` C and Objective-C compatibility shims. No behavior change.
- Consolidated the `justfile`'s check, format, and dev commands, and added clang-format for the C/Objective-C compatibility shims.
- Reworked the Developer settings picker to cover every simulated launcher state, including live custom popups, and simplified the preview commands.
- Made prominent CTA button label contrast adapt to sampled accent luminance so bright accents render dark text and darker accents render light text for better legibility.
- Normalized user-provided custom app icons to Apple's default icon grid padding before assigning them to the Dock/Finder icon so the launcher icon keeps the same 80.5% visual bounds as system apps.
- Unified script CLI output with color, spinners, and progress bars, and fixed the progress bar's width calculation.
- Added recipe-download tracking to release statistics.
- Simplified the announcement management commands, and added optional version-range and display-window flags to `just announcement set`.

### Fixed

- Fixed the Notices companion window rendering behind the game window in fullscreen, and made it track the game window smoothly while dragging instead of lagging behind (Thanks to u/Fukksaks5th).
- Matched the Notices/announcement popup's styling (glass tint, hairlines, background) to the rest of the app.
- Fixed the now-playing title sometimes showing the wrong track right after the background music playlist shuffles to a new one.
- Updated launcher version row in Settings → Updates to mirror game status behavior (`vX.Y.Z` when current, “Update available” only when needed), and made popup/About buttons use the same icon+text button treatment as other prominent actions.

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
