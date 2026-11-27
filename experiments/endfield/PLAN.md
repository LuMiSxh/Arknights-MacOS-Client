# Endfield integration plan

This plan adds Arknights: Endfield to the existing client.
Each phase merges into `main` and ships in a normal release.
Endfield stays unreachable in release builds until 1.1.0.

## Decisions

- One app. Setup asks which game the player wants: Arknights, Endfield, or both.
- With both games set up, Home shows a game switcher.
- Players choose an update channel, **Stable** or **Canary**, in setup and in **Settings** (1.0.3).
- Canary gets prereleases: release candidates, and builds that soak 2-3 days before promotion to Stable.
- Endfield is opt-in and reachable only on the Canary channel.
- Endfield changes ship with normal client releases. There is no Endfield-only build.
- Endfield runs only on the ARM runtime lane, so it needs Apple Silicon and macOS 26.5 or later.
- On other Macs, setup shows Endfield greyed out with the note "Requires macOS 26.5 or later".
- Endfield uses DXMT with D3D11 (`-force-d3d11`). Never ship the Vulkan path.
- FSR3 is the upscaler. DLSS waits until a runtime's NGX reports support.
- `stepministrator` starts the game. The official launcher chain does not ship.
- The repositories stay under the current user account. There is no organization move.
- The Sparkle feed moves to GitHub Pages at the `github.io` URL. There is no custom domain.
- Existing Arknights paths stay unchanged. Endfield gets its own environment and game keys.

## Release 1.0.3

Goal: move the feed, add update channels, ship video backgrounds, and start the game-neutral API.

### Update channels

- The canonical feed is the `appcast.xml` asset on the fixed `appcast-feed` release. Pages serves a copy.
- Canary releases are GitHub prereleases whose appcast item carries `sparkle:channel` `canary`.
- `promote.yml` turns a prerelease into the latest release and moves its item to Stable.
- Pages deploys only when a release is published, so the feed never points at draft assets.
- The client stores an `UpdateChannel` preference under a new key, and answers Sparkle's `allowedChannels(for:)`.
- Every existing user runs onboarding once more, with a new update channel step. Existing answers are prefilled, and nothing installed is redone.

### Feed on GitHub Pages

- Set `SUFeedURL` in `Resources/Info.plist` to `https://lumisxh.github.io/Arknights-MacOS-Client/appcast.xml`.
- `release.yml` reads the previous appcast from the Pages URL instead of `releases/latest/download/appcast.xml`.
- Fall back to the GitHub release URL for the first run only.
- `release.yml` passes the generated `appcast.xml` to the `pages.yml` call. The Pages build serves it from the site root.
- Keep attaching `appcast.xml` to every GitHub release. Clients on 1.0.2 or older read it and update to the release that points at Pages.
- Update `docs/development/releases-and-updates.md`. Check that the privacy page names `lumisxh.github.io` as the update host.

### Video backgrounds

- Extend the home artwork from an image to image or video. `LauncherArtworkView` currently takes an `NSImage?`.
- A custom background can be an image or a video. Accept H.264 or HEVC in MP4 or MOV. Copy it into `AppPaths` like `customArtwork`.
- Loop with `AVPlayerLooper`. Play and pause under the same rules as `ContinuousMotion`: hidden window, covered window, sheets, running game, Low Power Mode, and Reduce Motion.
- Show the still image while paused or loading.
- Official Arknights artwork stays an image. The Endfield launcher serves a 15-second H.264 loop (see `README.md#background-media`).
- Update `docs/help`, `docs/development/design.md`, and `CHANGELOG.md`.

### First API changes, without behavior change

- `LauncherAPIProviding.branding(region:)` returns background media (image, optional video) instead of an image only.
- Add a `LaunchProfile` to `ArknightsGameRuntime`. It holds the executable, `WINEPRELOADERAPPNAME`, log name, crash-report prefix, screenshot name, and an optional launch helper.
- Arknights builds its profile from `GameConfiguration`. This replaces these hard-coded values:
  - `GameSessionController+Launch.swift` (`Arknights.exe`)
  - `WineRuntime+Environment.swift` (`AppConstants.Runtime.applicationName`)
  - `GameRegion.swift` log names
  - `ScreenshotFileWriter.swift`
  - `DiagnosticsArchive.swift`

## Releases 1.0.4 and later 1.0.x

Goal: build the Endfield path dormant, one reviewable change per release.

### Game dimension

- Add a game type in `ArknightsCore` (Arknights, Endfield). `GameRegion` stays the Arknights server list.
- Endfield gets its own server type with Global only.
- `AppPaths` gains Endfield keys: `Environments/endfield-gryphline-arm` and `Games/endfield-global`.
- Arknights keys and preference names stay unchanged, so no migration is needed.
- Scope the per-game settings: display, MetalFX, compatibility components, and Bilibili.
- Keep the global settings shared.

### Runtime repository

- Build `stepministrator` in the runtime CI with MinGW. Publish it with the runtime release and pin its SHA-256.
- Pin the ARM lane to a runtime with the alpha-3 line (`arm-1.0.2` or later). The client still pins `arm-1.0.1`.
- Leave the loader bundle named `Arknights.app` for now.

### Endfield installer

- Port `installer.py` to Swift as an Endfield provider in `ArknightsGameInstallation`.
- Reuse the `.part`, manifest-path, hash, and install-lease code.
- Request the Gryphline `batch_proxy` manifest. Download and extract the 59 split ZIP parts one at a time, and delete each part after extraction.
- Install the encrypted `game_files` and VFS resources.
- Add the Endfield hosts to the download host policy: `launcher.gryphline.com`, `beyond.hg-cdn.com`, and `gl-utils-public.hg-cdn.com`.
- Show the space needed before install: about 62 GB download and 68 GB installed.
- Add an import for an existing Endfield install. Move the lab game instead of downloading it again. Never delete it.

### Endfield launch and session

- Build the Endfield `LaunchProfile`: the `stepministrator` helper, `Games.exe` started suspended as the parent, and `Endfield.exe -force-d3d11`.
- Use the DXMT environment.
- `PlatformProcess.exe` outlives the game and holds the prefix. End it during prefix shutdown.
- Do not treat game exit as Idle until the prefix-wide shutdown finishes.
- Add Endfield log and crash-report names. Add support codes for the Endfield installer and launch failures.
- Fetch Endfield background media with `get_main_bg_image` (see `media.py`).

### Gating before 1.1.0

- Gate on the `UpdateChannel` preference from 1.0.3. The old `canaryFeaturesEnabled` key stays unused.
- Until 1.1.0, Endfield entry points are reachable only in DEBUG builds.
- From 1.1.0, the Canary channel gates entry points only: the setup choice, the switcher, and the Endfield install. Action bodies never check it.

## Release 1.1.0

Goal: cut off old updates, and open Endfield as canary.

### Update cutoff

- Remove the 0.6 and 0.7 migration path, and raise the migration gate to 1.0.
- Stop adding new builds to the `appcast.xml` attached to GitHub releases.
- Clients older than 1.0.3 then stop receiving updates.

Recommendation: attach a frozen `appcast.xml` to every later release that lists only the last 1.0.x build. Old clients then update to that build, read Pages, and reach 1.1.0. This costs one file per release and strands nobody.

### Endfield canary

- Show Endfield to players on the Canary channel.
- Add the game choice to setup and the game switcher to Home.
- Enable Endfield install, launch, and background video.
- Update `docs/help`, `docs/development/design.md`, `web/src/routes/privacy/+page.svelte` (Gryphline Endfield hosts), and `CHANGELOG.md` together.

## After 1.1.0

- Endfield fixes ride the 1.1.x releases.
- Add an `Endfield.app` loader variant, built and signed in the runtime CI.
- Revisit DLSS when a runtime's NGX reports D3D11 support.
- Fix the small jump at the loop point of the Endfield video, if it shows.

## Findings from Yaagl Endfield OS

Read-only analysis of Yaagl Endfield OS 1.0.0 on 2026-11-27. It runs x86_64 CrossOver Wine 11.0-1 under Rosetta, with Vulkan as its default renderer.

- Game updates are incremental: `GET /api/game/get_latest` with the installed `version` and `patch_encrypt=true` returns `patch` with `v2_patch_info`, `v2_verify_files`, and `cd_key`. It applies per-file diffs with `hpatchz` (MIT) and honors `delete_files.txt`. Confirm with a live request first.
- Repair decrypts `game_files` (AES), checks each file's MD5, and downloads only bad files from `${file_path}/<path>`.
- The installed version is read from the game's encrypted `config.ini` (`version`, `entry`, `entry_md5`).
- Install work runs in a staging folder with an `operation.json` phase record, so it can resume.
- More artwork: `get_single_ent` and `get_banner` beside `get_main_bg_image`.
- DXMT tuning goes through `DXMT_CONFIG`: `d3d11.preferredMaxFrameRate`, `d3d11.metalSpatialUpscaleFactor` with `DXMT_METALFX_SPATIAL_SWAPCHAIN=1`, `dxgi.forceSDR`, `dxgi.handleAltTab`, `dxmt.shaderMetalVersion`.
- DLSS candidate: `DXMT_ENABLE_NVEXT=1`, `WINE_NGX_SIGNER=1`, `dxgi.customVendorId=10de`, `dxgi.customDeviceId=2684`, NGX registry keys, plus `nvapi64.dll` and `nvngx.dll`. Test this in the lab on alpha-4.
- Graphics DLL swaps keep a backup and are restored after a crash.
- Registry: `winebus` `DisableHidraw` and `Enable SDL` for controllers, `LeftCommandIsCtrl`.
- No intro video fix: it ships a dynamic GStreamer 1.26.8 framework, but no Media Foundation install for Endfield.
- It does not end `PlatformProcess.exe`.
- Licenses: `gryphlink-start` and `hpatchz` are MIT; `aria2` is GPL-2.0. The app bundle has no license file, so check upstream before reusing its JavaScript.

### Candidates for Arknights too

Arknights already runs on DXMT, so several findings apply to both games. Check each against the current client before adopting.

- `DXMT_CONFIG` frame-rate cap (`d3d11.preferredMaxFrameRate`) as an alternative to the current limiter.
- MetalFX spatial upscaling through DXMT, compared with the current MetalFX path.
- `dxgi.handleAltTab` for fullscreen switching.
- `WINE_DARWIN_SPARSE_READ=1` for file reads.
- A Metal HUD toggle (`MTL_HUD_ENABLED`) as a diagnostics option.
- Controller registry keys (`winebus` `DisableHidraw`, `Enable SDL`) for gamepad support.
- Crash-safe graphics DLL swaps with a backup during prefix refresh.
- Staging folder plus a phase record, so an interrupted install or repair resumes.

## Branches

- `feat/endfield` holds the lab and is 11 commits behind `main`.
- Merge the lab into `main`, because `experiments/` is outside CI.
- Start each client phase as its own branch from `main`, named `<type>/<outcome>`.

## Open risks

- No `AVPlayer` test of the Endfield video yet. Only `ffprobe` was run.
- ACE has not been tested in a production prefix.
- Peak memory, about 7.7 GB for Wine plus 5 GB GPU, is close to the limit on 16 GB Macs.
- The Endfield video has no hash in the API response.
