# Runtime compatibility

Arknights Client packages a fixed Windows compatibility runtime. `runtime.json` is the source of truth for the artifact URL, checksum, component versions, source revisions, and prefix revision. Runtime changes must preserve the contract below or update the launcher and its migrations in the same release.

## Runtime baseline

The current artifact is produced by the maintained [`dappermint/winecx-gptk`](https://github.com/dappermint/winecx-gptk) recipe and published as runtime `4.5.118` by the maintained [`dappermint/Whisky`](https://github.com/dappermint/Whisky) fork. The recipe repository builds and tests the archive; the Whisky release mirrors that exact artifact after validating its checksum and embedded version. It is not sourced from the archived original Whisky project.

This build remains the baseline because it packages WineCX, DXMT, Wine Gecko, GStreamer, FFmpeg, and their relocatable dependencies together. Other free Wine distributions considered for macOS either omit DXMT, require a separately installed media stack, or do not publish a complete reproducible recipe. The launcher uses the generic Wine and DXMT component names; the host project is provenance, not part of the runtime interface.

The runtime's macOS executables are x86-64 and therefore depend on Rosetta 2. macOS 26 may show Apple's Intel-app compatibility notice on the first game launch. An upgrade to macOS 27 may remove an existing Rosetta installation, and macOS 27's Legacy Game Test Mode disables the general Rosetta environment Wine requires. The launcher therefore checks the mode when available and executes `/usr/bin/arch -x86_64 /usr/bin/true` before allowing Wine to launch; an on-disk Rosetta marker alone is not sufficient.

General-purpose Rosetta is supported through macOS 27. macOS 28's restricted old-game translation is not a compatible host for this x86-64 macOS Wine process, so the current runtime is blocked there. A future runtime should move to a native ARM64 Wine plus a suitable x86-64 Windows translation path once a free, reproducible build provides equivalent DXMT, media, Chromium, and child-window compatibility.

## Runtime and prefix lifecycle

The runtime and Wine prefix have separate lifecycles. `just runtime` stages the archive under `.build/runtime`, and packaging copies it into the app bundle at `Contents/Resources/Runtime`. This payload contains the Wine executables, libraries, and DXMT DLLs and is replaced when the pinned archive changes.

The persistent Wine prefix lives at `~/Library/Application Support/com.lumisxh.arknights-client/Wine/Prefixes/Arknights-Global`. The legacy directory name remains for storage compatibility, but the prefix is shared by all supported regions; the launcher repoints its `G:` drive to the selected game directory before launch. See [Storage](storage.md) for the complete path contract.

The prefix's `.arknights-runtime-migrations.json` records completed migrations against an effective revision of `<archive SHA-256>-prefix-<prefixRevision>`. A new archive checksum therefore replays runtime migrations automatically while preserving the prefix. Increase `prefixRevision` only when an unchanged archive needs a new prefix configuration migration. Users do not need to delete their prefix for a binary-only runtime update unless troubleshooting indicates that its persistent state is itself damaged.

## Required Wine interface

| Interface                         | Use                                                                        |
| --------------------------------- | -------------------------------------------------------------------------- |
| x86-64 macOS binaries             | Run Wine through Rosetta 2 on Apple Silicon.                               |
| `bin/wine64`                      | Initialize the prefix, edit its registry, and start `Arknights.exe`.       |
| `bin/wineserver`                  | Wait for prefix processes and stop the isolated runtime.                   |
| `wineboot.exe -u`                 | Create or update a prefix during the corresponding migration.              |
| `reg.exe`                         | Apply DLL overrides and disable Wine crash dialogs.                        |
| Wine macOS driver                 | Present game and browser windows and support the reviewed Command-Q patch. |
| Wine Gecko, GStreamer, and FFmpeg | Support web and media paths used by the client.                            |

Wine receives a private Unix home, XDG directories, temporary directory, and prefix. Only `C:` and the selected game directory as `G:` remain mapped. The runtime must honor `WINEPREFIX`, `WINEDLLOVERRIDES`, `WINEPRELOADERAPPNAME`, and the current synchronization variables.

MSYNC is the tested default for runtime `4.5.118`; it maps Windows thread waits onto macOS Mach synchronization and produced steadier frame pacing in current tests. ESYNC uses Wine's older event-based synchronization path and remains available as an experimental compatibility fallback in Settings → Installation → Danger Zone. The launcher injects only `WINEMSYNC=1` or `WINEESYNC=1`, never both, and ignores matching variables inherited from the host. Switching modes does not modify the Wine prefix and therefore requires neither a migration nor prefix deletion.

The launcher injects its signed x86-64 game-icon bridge into the main Wine process with `DYLD_INSERT_LIBRARIES`. The bridge waits for Wine to initialize AppKit before intercepting its normal `setApplicationIconImage` call, preserving Wine's application name and startup order. Without a custom selection it grid-normalizes the icon Wine extracts from `Arknights.exe`; with one it substitutes the launcher-owned PNG from Application Support. It does not patch the runtime or game executable.

## Required DXMT interface

DXMT translates the game's Direct3D 11 calls to Metal. The runtime archive must contain x64 and x32 copies of:

- `d3d10core.dll`
- `d3d11.dll`
- `dxgi.dll`
- `winemetal.dll`

The prefix migration installs these files into `system32` and `syswow64`, then selects them with Wine DLL overrides. DXMT's shader cache is enabled explicitly and stored under the prefix's private `home/.cache/dxmt` directory. It persists between game launches and is removed with the Wine prefix.

MoltenVK is included by the upstream runtime for Wine's Vulkan support. It is not part of the current Arknights Direct3D 11 rendering path. Apple D3DMetal is neither required nor redistributed.

## Compatibility components

Game-file workarounds conform to `GameCompatibilityComponent` and are registered by `GameCompatibilityManager`:

```mermaid
flowchart LR
	Manager[GameCompatibilityManager] --> Active[Active components]
	Manager --> Retired[Retired components]
	Active -->|reconcile before launch| Game[Game directory]
	Active -->|restore before update| Game
	Retired -->|remove owned files| Game
```

An active component must identify only files it owns, install idempotently, and restore the official files before game updates. To remove a workaround, move it to the retired list for at least one supported upgrade cycle. Retired components no longer install but can still clean up stable ownership markers without bundling their old payload.

The Vuplex component supplies two process-local workarounds:

- A wrapper preserves the official helper, selects Vuplex's CPU `OnPaint` transfer, disables WebGL, GPU rasterization, and accelerated 2D canvas, disables the CEF flags for Wine's working DNS path and clipboard sync, and adds high-resolution arguments when requested. Chromium's own GPU compositor stays enabled for rendering speed; only Vuplex's inter-process accelerated-paint texture sharing is disabled. These restrictions apply only to the browser helper; the game process keeps its independent DXMT renderer.
- `userenv.dll` stubs the full set of Windows AppContainer APIs (SID derivation, profile create/delete, registry location, folder path) that Chromium's sandbox resolves via `GetProcAddress` and asserts on if missing. The tested Wine build implements none of them; stubbing only the SID-derivation function left the sandbox's `CHECK(fn)` assertion failing on the others.

The wrapper does not render pages, inspect credentials, or replace Vuplex. It launches the untouched official helper and waits for its exit code. Both launcher-owned files carry stable markers so they can be upgraded or removed safely.

### Payment compatibility

Credit card and PayPal payments have been observed to complete in the game's embedded browser. Disabling WebGL, GPU rasterization, and accelerated 2D canvas is the config observed to let PayPal's browser challenge complete in the tested Vuplex/CEF environment under Wine; the launcher does not bypass or weaken the payment provider's challenge (#14).

The embedded browser previously crashed on Chromium sandbox initialization. Chromium's sandbox (`sandbox/win/src/app_container_base.cc`) dynamically loads several Windows AppContainer APIs and asserts `CHECK(fn)` if any are missing; Wine's `userenv.dll` implements none of them. The compatibility DLL originally stubbed only the one function needed for OAuth popups (`DeriveAppContainerSidFromAppContainerName`), which left the sandbox's other required functions unresolved. Stubbing the full set the sandbox expects avoids the assertion (#16). Still, verify every purchase or charge directly with the payment provider and Yostar, since this runs through an unofficial, community-patched Wine environment.

The PlatformProcess component handles the separate Qt WebEngine window used by Notices:

- A wrapper launches the untouched official `PlatformProcess.exe`, removes its border and Win32 `WS_EX_NOACTIVATE` style, follows the game's absolute position, and waits for the official process.
- An x86-64 AppKit bridge is injected into the helper process tree through WineCX's `__CX_UNIX_` environment passthrough. It keeps Wine's `NSPanel` non-activating while the Wine content view delivers first-click mouse input, hides the helper's separate Dock presence, and applies the companion window's Spaces, level, transparency, and clipping policy.

The compatibility component does not inspect input, Qt page data, network requests, or rendered content; the bridge changes only native window presentation. Chromium starts with the helper after Notices is selected. Collapsing Qt WebEngine into one process or disabling its sandbox is intentionally avoided.

The helper and game remain separate top-level processes under the current compatibility boundary. Fast game-window drags can show a small tracking delay. Mouse interaction with Notices remains in the non-activating helper panel so it does not transfer application focus away from the game; this relies on Wine's existing first-mouse delivery rather than injecting coordination code into the main game process.

When high-resolution mode is enabled, the launcher enables Wine's prefix-wide Retina mode when Play is pressed from a window on a HiDPI display. Windows `LogPixels` remains at 96 because a global 192 DPI setting makes Unity restore window dimensions inconsistently. Instead, the game process passes a 2x scale factor to the Vuplex wrapper, which adds Chromium-only HiDPI arguments. This gives the game and browser high-density output without changing Unity's coordinate system. On a 1x display or when the setting is disabled, the launcher disables Retina mode and uses a 1x browser scale. The current registry values are read directly from the prefix, and `reg.exe` runs only when a value must change.

On a scaled macOS desktop, maximizing a normal Retina window can create a backing surface larger than 4K. Borderless or fullscreen rendering at a deliberate 2560×1440 or 3840×2160 resolution avoids that extra pixel cost; DXMT-specific upscaling and frame-limit overrides remain disabled because the game already controls those tradeoffs.

Arknights renders its own cursor inside the game frame. With VSync enabled, that software cursor can visibly trail the native macOS pointer on some systems; disabling VSync reduces the delay but can introduce tearing (#34). Similar behavior has been observed on Windows, so cursor lag alone is not treated as evidence of a DXMT defect, and the launcher does not override the game's VSync setting.

Use `--no-retina` or `defaults write com.lumisxh.arknights-client forceDisableRetina -bool YES` as a troubleshooting fallback. `--graphics-diagnostics` temporarily enables Wine Mac-driver and DXMT info logging so the physical backing and swapchain dimensions can be verified in the Wine log.

## Updating the runtime

1. Verify the runtime and build-recipe checksums and record exact upstream revisions in `runtime.json`.
2. Confirm `wine64`, `wineserver`, DXMT payloads, Gecko, and media libraries are present in the extracted artifact.
3. Run the launcher tests and build an app with `just ci` and `just dev`.
4. Test a fresh prefix, an existing prefix, game launch, every login provider, media pages, game exit, and launcher termination.
5. Increase `prefixRevision` only when existing prefixes must replay configuration. A binary-only refresh uses the new archive checksum to invalidate all runtime migrations automatically.
6. Update third-party notices and corresponding-source material before publishing a DMG.

Launcher diagnostics record the time from **Play** to the Wine process and visible game window. The Wine log additionally records filesystem, compatibility, prefix, display, and process stages. Use these phases to distinguish launcher work from game, Metal, and browser startup before changing the recipe.
