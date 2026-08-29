---
title: Runtime compatibility
description: How the pinned Wine, DXMT, and Rosetta runtime launches the game
order: 40
---

# Runtime compatibility

Arknights is a Windows PC client. On an Apple silicon Mac, Arknights Client connects the pieces required to run it:

```text
Apple silicon Mac → Rosetta 2 → x86-64 Wine → DXMT → Metal → official Yostar PC client
```

The launcher owns this chain as one tested runtime. It does not ask you to install Wine, DXMT, or a separate Windows copy.

> [!IMPORTANT]
> The DMG contains a pinned Wine + DXMT runtime, but it does not contain the game. The launcher downloads the selected official Yostar client and verifies its files against Yostar's manifest.

## macOS support

The current app supports Apple silicon Macs on macOS 15 through the general Intel-translation range supported by the runtime. The launcher performs a real x86-64 probe before allowing Wine to start:

- macOS 15–26: Rosetta 2 must be installed and executable
- macOS 27: Rosetta must be available and **Legacy Game Test Mode** must be disabled
- macOS 28 and later: the current x86-64 Wine runtime is blocked because general Intel translation is unavailable

The support check can show Rosetta as unavailable even when its files are present. Restart the Mac and choose **Check Again** before reinstalling anything.

### macOS 27 Legacy Game Test Mode

If the setup assistant reports that Legacy Game Test Mode is active, disable it in Terminal:

```sh
sudo game-test-tool disable
```

Restart the Mac and run the launcher check again. This mode disables the general Rosetta environment Wine needs; it is not a game setting that the launcher can work around.

> [!WARNING]
> Do not rely on the presence of `/Library/Apple/usr/share/rosetta/rosetta` alone. The launcher also executes `/usr/bin/arch -x86_64 /usr/bin/true` so it can detect a disabled or unusable translation layer.

## What happens when you choose Play

1. The launcher checks that the selected region contains its configured game executable.
2. The bundled runtime is discovered from the app bundle and the shared Wine prefix is created if needed.
3. Pending Wine initialization, DXMT installation, or registry migrations run. Completed steps are recorded so an interrupted launch can resume.
4. The launcher prepares the selected regional game directory and maps it to Wine's `G:` drive.
5. Wine starts the official executable through the DXMT Direct3D 11-to-Metal path.
6. The launcher waits up to 90 seconds for the game window, then monitors the game and Wine processes until exit.

The central `wine.log` records these stages. A first launch after a runtime change can take longer while the prefix migration completes.

## The shared Wine prefix

All supported regions use one prefix:

```text
~/Library/Application Support/com.lumisxh.arknights-client/Wine/Prefixes/Arknights-Global
```

The historical `Arknights-Global` name is kept for storage compatibility. The prefix contains Wine registry state, the embedded-browser profiles and sessions, DXMT shader data, and runtime migration state. Regional game files remain in separate directories; only the active region is mapped as `G:` for a launch.

The launcher also maps the central macOS log directory as `L:` so Unity and browser logs can be collected alongside `wine.log`. Wine's default `Z:` mapping to the macOS file-system root is removed before each start, and its shell folders are kept inside the prefix.

> [!CAUTION]
> **Delete Wine Prefix** removes this shared environment for every region, including saved Yostar, Google, Apple, and Facebook browser sessions. Game files are untouched, and the prefix is rebuilt on the next launch. Use [Force Migration](troubleshooting.md#no-game-window-appears) or targeted cache cleanup first.

## The pinned runtime

The release currently pins the following compatibility unit in [`runtime.json`](../../runtime.json):

| Component        | Pinned version           |
| ---------------- | ------------------------ |
| WineCX           | 11.15                    |
| DXMT             | 0.80                     |
| Runtime artifact | dappermint build 4.5.118 |
| Wine Gecko       | 2.47.4                   |
| GStreamer        | 1.26.3                   |
| FFmpeg           | 7.1.1                    |
| MoltenVK         | 1.4.2                    |

Wine, DXMT, Gecko, and the media libraries are selected and tested together. Installing another Wine distribution beside the launcher does not replace its bundled runtime and is not a supported way to change this compatibility unit.

> [!NOTE]
> `runtime.json` also records archive checksums, source revisions, the prefix revision, and the expected files and directories. This lets release builds verify that the runtime used for packaging is the runtime the launcher expects.

## Graphics and display behavior

DXMT translates the game's Direct3D 11 calls to Metal. The bundled runtime includes both x64 and x32 DXMT libraries because the Windows client and its helpers can use different architectures. Apple D3DMetal is not required by this launcher and is not redistributed.

The launcher configures Retina mode from the current display and **High-Resolution Mode** setting. It keeps Windows `LogPixels` at 96 and scales the embedded browser separately, so a global 192-DPI prefix setting is not required. If the window is incorrectly sized or performance is uneven:

1. turn off High-Resolution Mode in **Settings → General**
2. try a lower resolution or a different window mode
3. run one launch with `--no-retina`
4. use `--graphics-diagnostics` when the issue appears to involve Metal, DXMT, or the window backing size

See [Graphics, window, and performance problems](troubleshooting.md#graphics-window-and-performance-problems) for the commands and recovery order.

The default Wine synchronization mode is **MSYNC**. It uses macOS Mach synchronization and is the mode tested for the current runtime. **ESYNC** remains available as an experimental compatibility fallback in **Settings → Installation → Compatibility**. Changing this setting applies on the next launch and does not delete or migrate the prefix.

## Embedded browser and notices

Sign-in and some game notices use separate Windows browser helpers. The launcher keeps the official helpers and applies only the compatibility components required for the tested Wine environment:

- the sign-in helper uses a process-local configuration that disables the accelerated paint-sharing path that is unreliable under Wine while keeping Chromium's compositor available
- a launcher-owned `userenv.dll` supplies the Windows AppContainer calls Chromium expects during sandbox startup
- the separate Notices helper is presented as a native-looking companion window without merging it into the game process

These changes do not replace the official pages, inspect credentials, or bypass provider challenges. The browser and game logs are separate so a blank sign-in page can be diagnosed without treating it as a graphics failure.

> [!WARNING]
> Payment flows run in the same embedded browser compatibility environment. Verify every transaction with Yostar and your payment provider. The launcher cannot resolve account, billing, or provider-side restrictions.

## Runtime failures

Use [Troubleshooting](troubleshooting.md) when:

- the Intel compatibility check fails
- Play stays disabled or no game window appears within 90 seconds
- a runtime migration or DXMT setup fails
- the game exits before its window appears
- the browser or Notices helper is blank
- the window has incorrect Retina sizing or rendering artifacts

Collect `launcher.log` and `wine.log` around one reproduction. The launcher report form supplies basic environment metadata but never attaches logs automatically. GitHub issues are public; remove private paths, URLs, account information, and tokens before sharing excerpts.

## Runtime provenance

The pinned artifact is published by the maintained [dappermint/Whisky fork](https://github.com/dappermint/Whisky) and built from the pinned [winecx-gptk recipe](https://github.com/dappermint/winecx-gptk). Component repositories, exact commits, and checksums are kept in [`runtime.json`](../../runtime.json). The release process treats Wine and DXMT as one runtime unit; users should not mix independently downloaded component versions.
