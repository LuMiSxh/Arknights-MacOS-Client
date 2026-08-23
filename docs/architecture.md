# Architecture

Arknights Client has a native SwiftUI launcher and a bundled Windows compatibility runtime. The launcher owns downloads, updates, settings, and process state. Wine is used only after **Play** is selected.

## Source layout

| Folder           | Responsibility                                                                                  |
| ---------------- | ----------------------------------------------------------------------------------------------- |
| `Application`    | App entry point, dependency composition, and macOS lifecycle                                    |
| `Core`           | Small application-wide declarations such as fixed limits and keys                              |
| `Features`       | Feature-owned UI, state, domain models, services, and external work                             |
| `Infrastructure` | Feature-independent network and system I/O primitives                                           |
| `Shared`         | Persisted paths and preferences, diagnostics, support utilities, and cross-feature UI contracts |
| `Resources`      | SwiftPM resources copied into the application bundle                                            |

`Features` is organized around behavior rather than technical layers:

- `Launcher` owns the root observable state, home, Settings, documents, popups, and launcher updates.
- `Game` owns installation, Wine runtime behavior, Intel translation, and game-file compatibility components.
- `Customization` owns artwork, icons, and the preset gallery.
- `Audio` owns background playback, Now Playing integration, settings, and HUD controls.
- `Onboarding` owns its resumable flow, progress persistence, and step views.

Feature-specific components remain with their feature. `Shared/UI/Components` contains only presentation contracts used by multiple features, such as action buttons, modal chrome, and Settings panels.

User-facing launcher copy lives in Apple String Catalogs with stable, feature-namespaced keys. Generated Foundation symbols make catalog references type-safe, while small feature-local `…Strings` namespaces keep ownership with the UI that uses the copy. English is the source language and deterministic fallback; the launcher follows macOS language preferences without persisting a separate language setting. The catalog workflow is documented in [Localization](localization.md).

Repository scripts derive shipping product metadata from `Resources/Info.plist`, target and resource layout from SwiftPM's evaluated `Package.swift`, and runtime layout from `runtime.json`. `scripts/lib/project_config.py` cross-validates the first two before builds and checks. Scripts must not maintain separate app-name, executable, platform, architecture, language, or package-resource lists.

`LauncherViewModel` is the main UI orchestrator around one hierarchical `LauncherState`. Its orthogonal sub-states own mutually exclusive game activity, metadata refreshes, launch readiness, and presentation. A background refresh or non-fatal settings error therefore cannot overwrite an active game session. Views derive permissions and labels from this tree; `LauncherPhase` is only a compact compatibility projection for views that do not need the complete state.

Installation, maintenance, and the Wine-backed game lifecycle share the exclusive `LauncherActivity` sub-machine because they may touch the same game files or runtime. Refresh and presentation remain separate so safe metadata checks and actionable errors can coexist with a running game.

First-run setup is a separate `Onboarding` feature with its own `@Observable` coordinator and `UserDefaults` progress store. It never downloads files or persists launcher settings itself: each step calls the same region, installer, display, artwork, icon, update, and audio actions used by the main interface. A mandatory launcher-update preflight runs before setup; an available launcher release blocks the remaining steps until the newer app is installed and reopened. Interrupted setup resumes at its saved step, but an absent game always routes back through Region & Install before later steps.

## Installation

`LauncherAPI` obtains the current version, manifest, and CDN URLs for a `GameRegion` (Global, Japan, or Korea — same Yostar API shape and signature algorithm, different base URL and `game_tag`). `GameInstaller` validates every manifest path before writing, streams buffered network chunks into resumable `.part` files, verifies size and CRC64, and records the installed manifest.

A normal update compares the installed and current manifests so unchanged files can be reused. **Repair** deliberately skips that shortcut: it checks every installed file and downloads missing or damaged files again. Installation is exclusive; refreshes, Settings actions, and repeated clicks cannot start a second installer.

Each region has its own install directory and installed-state file, so regions install and update independently. They share one Wine prefix: `WinePrefixConfigurator` re-points the `G:` drive to the active region's directory on every launch, so a second prefix per region isn't needed.

```mermaid
flowchart LR
	API[Yostar launcher API] --> Manifest[Version and manifest]
	CDN[Yostar CDN] --> Installer[GameInstaller]
	Manifest --> Installer
	State[Installed manifest] --> Installer
	Installer --> Files[Game directory]
	Installer --> State
```

## Launch process

The packaged runtime is x86_64 and runs through Rosetta 2. The launcher gives Wine an isolated prefix and an allowlisted environment, mounts the game directory as `G:`, installs the pinned DXMT libraries, and starts `G:\Arknights.exe`. The main game uses DXMT for Direct3D-to-Metal translation. The exact runtime contract and compatibility components are documented in [Runtime compatibility](runtime-compatibility.md).

Arknights starts its Chromium-based Vuplex helper for account and in-game web pages. Before launch, the launcher moves the official helper beside a small wrapper. The wrapper preserves the game's arguments and starts the untouched helper with the system DNS resolver. A process-local `userenv.dll` supplies the one AppContainer SID function missing from the tested Wine build.

Notices use a different Qt WebEngine helper named `PlatformProcess.exe`. It runs as a separate Wine and macOS process, so this implementation deliberately keeps it as a top-level companion instead of modifying the game process. A wrapper launches the untouched helper, clears its Win32 frame and `WS_EX_NOACTIVATE` style, and follows the game in Wine's coordinate system. An AppKit bridge keeps the helper's `NSPanel` non-activating while preserving Wine's first-click input path, removes the separate Dock presence, and applies companion-window presentation while Arknights is active. The compatibility components do not inspect page data; the bridge changes only native window presentation.

A separate signed Objective-C bridge runs in the main Wine process. It waits for Wine to initialize AppKit, then normalizes Wine's original executable icon or substitutes a launcher-owned custom game icon through AppKit's public application-icon setter. Game files remain untouched, and removing the custom icon returns the next launch to the normalized original Arknights icon.

```mermaid
flowchart LR
	subgraph macOS
		Launcher[SwiftUI launcher]
		Rosetta[Rosetta 2]
		Metal[Metal]
		Prefix[Isolated Wine prefix]
		WindowSystem[Window system]
	end

	subgraph Windows client through Wine
		Wine[Wine runtime]
		Game[Arknights.exe]
		DXMT[DXMT]
		Shim[Vuplex wrapper]
		CEF[Official Vuplex / CEF]
		Userenv[userenv compatibility DLL]
		PlatformShim[PlatformProcess wrapper]
		Platform[Official PlatformProcess / Qt WebEngine]
	end
	Bridge[Process-local AppKit bridge]

	Launcher -->|allowlisted environment| Rosetta
	Rosetta --> Wine
	Wine --> Prefix
	Wine --> Game
	Game -->|Direct3D 11| DXMT
	DXMT --> Metal
	Game -->|starts web helper| Shim
	Shim --> CEF
	Userenv -. process-local override .-> CEF
	CEF -->|HTTPS login and game pages| Web[Official web services]
	Game -->|opens Notices| PlatformShim
	PlatformShim --> Platform
	PlatformShim -. injects .-> Bridge
	PlatformShim -->|Win32 position tracking| WindowSystem
	Bridge -->|Dock, activation, and Spaces policy| WindowSystem
	Platform -->|HTTPS notices| Web
```

Vuplex can share its accelerated off-screen surface through D3D11, but Chromium and Vuplex cannot coordinate write access to that surface through the tested DXMT path. The wrapper therefore uses Vuplex's CPU `OnPaint` transfer while leaving Chromium's internal GPU compositor enabled. CEF's asynchronous DNS path calls `SIO_ADDRESS_LIST_SORT`, which Wine does not implement; the wrapper disables that path so CEF uses Wine's normal system resolver. Social login starts a separate Chromium process and may take several seconds on first use.

The Notices helper remains a separate application process even though its Dock entry is hidden. Its wrapper tracks the game's absolute position and the bridge keeps it above the game while Arknights is active. Rapid window dragging can show a small visual delay, and clicking between the game and the helper can briefly expose the normal macOS focus transition. The launcher accepts these effects to keep coordination code out of the main game process.

Install, update, and repair restore the official Vuplex and PlatformProcess executables before modifying game files. Their wrappers are installed again at the next launch only when each official helper still carries its expected signature. Unknown helpers, unrelated `userenv.dll` files, and unknown native bridges are left untouched.

## Process lifecycle

The launcher remains in **Starting** until Wine exposes a visible game window. It monitors both the direct Wine process and the prefix-wide `wineserver`. Closing the game triggers prefix-scoped cleanup so browser and Yostar helpers do not keep the launcher in **Running**. **Stop** and launcher termination use the same prefix-scoped shutdown.

The `Arknights` runtime alias and `WINEPRELOADERAPPNAME` give the main macOS process a readable name. Packaging applies one reviewed patch to the staged Wine macOS driver so the standard `Command-Q` shortcut is available.

Prefix changes run through an ordered migration plan: Wine initialization, DXMT installation, and registry overrides. The prefix stores completed migration IDs with the runtime archive checksum and `prefixRevision` in `.arknights-runtime-migrations.json`. Each successful step is recorded atomically, so an interrupted launch resumes at the first incomplete step. A checksum or prefix-revision change replays the complete plan; adding a migration ID runs only that new step for an otherwise current prefix. Version 0.1 markers are imported once and removed.

```mermaid
flowchart TD
	Launch[Launch starts] --> Read["Read .arknights-runtime-migrations.json"]
	Read --> Changed{"Checksum or<br/>prefixRevision changed?"}
	Changed -->|yes| ReplayAll[Replay every migration step]
	Changed -->|no| NewSteps{"New migration IDs<br/>since last launch?"}
	NewSteps -->|yes| ReplayNew[Run only the new steps]
	NewSteps -->|no| Skip[Skip migrations, verify state only]
	ReplayAll --> Record[Record each completed step atomically]
	ReplayNew --> Record
	Record --> Ready[Prefix ready]
	Skip --> Ready
```

Normal launches inspect migration, registry, drive, and private-home state without rewriting unchanged files. Runtime diagnostics record cumulative timings for filesystem setup, compatibility reconciliation, prefix preparation, display configuration, and process creation before the launcher records time to the first visible game window.

Game-directory shims implement `GameCompatibilityComponent` and are registered with `GameCompatibilityManager`. Active components are reconciled before every launch; all active and retired components are restored before install, update, or repair. Removing a shim means moving its component from the active list to the retired list for a supported upgrade cycle, allowing launcher-owned files to be cleaned up even when replacement assets are no longer bundled.

Vuplex and PlatformProcess use this reconciliation path rather than one-time migration state because the official updater can replace either helper at any time. Their wrappers, `userenv.dll`, and AppKit bridge carry stable ownership markers, so upgrades and retirement never rely only on the current bundled bytes. Unknown files remain untouched.

## Launcher communication

Three read-only sources feed the launcher; no separate application server exists. Each fires independently at launch, on its own precondition, with no ordering or dependency between them. Any of the three can enqueue a popup.

- **GitHub Releases** (`https://api.github.com/repos/.../releases/latest`), checked by `checkLauncherUpdates()` when automatic launcher-update checks are on. GitHub's `latest` endpoint already excludes drafts and pre-releases; the launcher re-checks both client-side anyway and compares the tag against the running version with an embedded SemVer parser tolerant of a leading `v` and of Yostar-style version strings. A newer, non-draft, non-prerelease version becomes a Markdown popup built from the release body, and its release page stays reachable afterward from Settings and the status capsule.
- **GitHub Contents API** (`https://api.github.com/repos/.../contents/announcements.json?ref=main`), checked by `checkAnnouncements()` when announcements are enabled. The request sends `Accept: application/vnd.github.raw+json` so GitHub returns the raw file instead of a base64-wrapped JSON blob. The feed is capped at 20 entries and 128 KB and must declare schema version 1; the first entry that is enabled, not already seen, within its optional date window and version bounds, under the field-length limits, and using only an HTTPS action becomes the shown announcement.
- **Yostar's own branding response** — not a dedicated notice endpoint. It rides along on the same `api.branding(region:)` call the launcher already makes for hero artwork, as part of `refresh()`'s concurrent branding fetch. If that response's `noticePopOpen` is true and its `noticeContent` differs from the last notice shown, the HTML is converted to native attributed text and queued. This channel has no persistent "seen" state: the in-memory guard resets on every region switch and on every fresh launch, so an active Yostar notice reappears each session, unlike the two GitHub-sourced popups.

All three funnel into the same queue (`enqueuePopup`): if nothing is showing, the new popup is shown immediately and recorded as seen right away; otherwise it is appended to `pendingPopups` and only recorded as seen once `dismissPopup` actually promotes it into view. Entries are deduplicated by id — a duplicate of the currently-shown or an already-queued id is dropped silently. "Seen" persistence differs per source: announcements keep a set of seen ids, launcher updates keep the last version presented, and Yostar notices keep nothing beyond the current session (their id also embeds a fresh UUID each time, so the queue's own id-based dedup never catches a repeat there — only the upstream content comparison does). Dismissing a popup by its action button removes it from the queue before opening the URL, not after.

```mermaid
sequenceDiagram
	participant App as SwiftUI launcher
	participant Releases as GitHub Releases API
	participant Contents as GitHub Contents API
	participant Yostar as Yostar branding API
	participant Queue as Popup queue

	par Launcher update check
		App->>Releases: GET releases/latest
		Releases-->>App: Version, URL, Markdown body
		alt Newer, non-draft, non-prerelease version
			App->>Queue: enqueue launcher-update popup
		end
	and Announcement check
		App->>Contents: GET contents/announcements.json (raw)
		Contents-->>App: Validated feed
		alt First enabled, unseen, eligible entry
			App->>Queue: enqueue announcement popup
		end
	and Branding fetch (shared with artwork)
		App->>Yostar: GET branding/config
		Yostar-->>App: noticePopOpen, noticeContent
		alt New notice content this session
			App->>Queue: enqueue notice popup
		end
	end
	Queue->>Queue: Show now, or append to pendingPopups and dedup by id
```

## Boundaries

- Only the official Yostar-published PC distributions (Global, Japan, Korea) are supported; CN is excluded because it runs on separate Hypergryph infrastructure and bundles a kernel-mode anti-cheat with no Wine support.
- Game files come from first-party HTTPS endpoints and are never included in a release.
- Manifest paths cannot escape the selected game directory.
- Wine receives private home, cache, configuration, runtime, and temporary directories.
- Wine exposes only its private `C:` drive and the selected game directory as `G:`; the default `Z:` mapping to the macOS root is removed.
- The prefix limits accidental file access but is not a macOS security sandbox.
- The launcher never handles credentials or intercepts Vuplex pages.
- Runtime versions and source revisions are pinned in [`runtime.json`](../runtime.json).
