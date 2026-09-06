---
title: Troubleshooting
description: Steps for launcher, runtime, sign-in, graphics, and game-start problems
order: 20
---

# Troubleshooting

Use the symptom that matches what you see. Keep the recovery order conservative: most problems can be retried or repaired from the launcher without deleting game files or the shared Wine prefix.

## Start here

1. Quit Arknights and wait for the launcher to return to an idle state.
2. Confirm the intended region is selected in **Settings → Installation**.
3. Check the available storage for the selected game and the shared Wine prefix.
4. Retry once. If the same symptom returns, follow the matching section below before removing anything.

> [!IMPORTANT]
> Do not delete the Wine prefix or game directory as a first response. Deleting the prefix signs you out of embedded-browser accounts for clients that use them and removes runtime caches; deleting a game directory removes the regional installation. See [Storage](storage.md) before using either destructive action.

## If the launcher shows an error code

A short uppercase word such as `PEBBLE` identifies a documented failure path. Choose **Troubleshooting** beside the message to open the matching page, or find the word in [Error codes](errors/README.md).

- **Retry** repeats the failed operation for the same region only while that failure is still current.
- **Repair** appears only when verifying installed game files is a relevant next step and always asks for confirmation.
- **Report Problem** pre-fills the code, operation, region, launcher version, and coarse Mac environment. It does not include the displayed message, paths, URLs, or logs.

> [!NOTE]
> A code is a starting point, not a complete diagnosis. Keep the word with the report, then add what you did and what happened in your own words.

## Log locations

You do not need log files for an initial report. This reference is for follow-up when a maintainer asks for a specific file. **Settings → Storage → Show Logs** prepares the central log directory and selects the available launcher, Wine, Unity, and Chromium files in Finder. macOS crash reports live separately; if a maintainer needs one, they will provide separate steps for the named report.

| File                  | Path                                                                | Useful for                                                                                        |
| --------------------- | ------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| Launcher log          | `~/Library/Logs/com.lumisxh.arknights-client/launcher.log`          | Setup, region refresh, downloads, update checks, prefix migrations, and launcher errors           |
| Previous launcher log | `~/Library/Logs/com.lumisxh.arknights-client/launcher.previous.log` | The previous rotated launcher log after `launcher.log` reaches 4 MB                               |
| Wine and game log     | `~/Library/Logs/com.lumisxh.arknights-client/wine.log`              | Wine startup, DXMT, display setup, compatibility components, process output, and runtime failures |
| Unity log             | `~/Library/Logs/com.lumisxh.arknights-client/unity.log`             | Unity exceptions, asset loading, and game-side diagnostics                                        |
| Chromium log          | `~/Library/Logs/com.lumisxh.arknights-client/chromium.log`          | Embedded sign-in browser and CEF frame or JavaScript diagnostics                                  |
| macOS crash reports   | `~/Library/Logs/DiagnosticReports/`                                 | Native `.crash` or `.ips` reports when the launcher, Wine, or Rosetta terminates unexpectedly     |

The selected region's game folder also contains `.arknights-client-state.json`, which records the verified manifest state. The shared prefix contains `.arknights-runtime-migrations.json`, which records completed Wine and DXMT setup steps. These are state files, not replacement logs.

> [!TIP]
> Attach only the file a maintainer names. Logs may contain private paths, URLs, or account-related data, and you can decline to share one publicly.

## Diagnostic launch options

These options are for a documented recovery step or maintainer-guided follow-up. They are temporary command-line options; close the app and launch it normally again when finished.

For an installed release:

```sh
open "/Applications/Arknights Client.app" --args --graphics-diagnostics
```

For a local app bundle, replace the path with the actual location of `Arknights Client.app`.

- `--graphics-diagnostics` increases Wine Mac-driver and DXMT logging. Use it for display, Metal, window, or rendering failures; details are written to `wine.log`.
- `--no-retina` forces a 1× Wine display configuration for that launch. Use it when a Retina or scaled display produces an incorrectly sized window.

To keep the 1× setting across launches:

```sh
defaults write com.lumisxh.arknights-client forceDisableRetina -bool YES
```

Restore the normal display behavior with:

```sh
defaults write com.lumisxh.arknights-client forceDisableRetina -bool NO
```

## Launcher will not open

> [!WARNING]
> **“Arknights Client is damaged and can't be opened.”** Release builds are ad-hoc signed and not notarized. Download the DMG again from [GitHub Releases](https://github.com/LuMiSxh/Arknights-MacOS-Client/releases/latest), copy the app to **Applications**, then right-click it in Finder and choose **Open**. Do not use a random re-signed copy or bypass Gatekeeper without understanding what it changes.

If the app still does not open, report where the app came from, what macOS displayed, and whether right-clicking **Open** changed the result. A maintainer may ask for a specific macOS crash report as a follow-up and will explain how to find it. A missing runtime inside a manually copied or incomplete app bundle is a packaging problem; use a complete release DMG.

## Setup or installation will not start

### Rosetta 2 is missing

The bundled Wine runtime is x86-64 and cannot start without Rosetta 2. Choose **Install Rosetta 2…** in the setup assistant, or run:

```sh
softwareupdate --install-rosetta --agree-to-license
```

Return to the launcher and choose **Check Again**. The launcher tests an actual Intel process, so simply finding an on-disk Rosetta marker is not sufficient.

### Rosetta appears installed but the check fails

Restart the Mac and choose **Check Again**. If the result remains unavailable, report the macOS version and what the compatibility check displays. Do not delete the game directory for this symptom.

### Legacy Game Test Mode is active

On macOS 27, Legacy Game Test Mode can leave Rosetta installed while disabling the general translation environment Wine requires:

```sh
sudo game-test-tool disable
```

Restart the Mac, then choose **Check Again**. If the command is unavailable, consult Apple's current macOS documentation for the installed OS version; the launcher cannot enable general Rosetta while that test mode is active.

### macOS no longer supports the required translation

The current runtime is blocked when macOS does not provide general Intel translation. See [macOS support](runtime-compatibility.md#macos-support) before upgrading or downgrading the operating system.

### Setup update check failed

Check that the Mac can reach GitHub and the selected region's publisher services, then use **Try Again**. The assistant can continue after an unavailable launcher update check, but install the newer launcher before starting setup when an update is reported.

## Launcher update waits or fails

A launcher update waits while the game, an installation, an update, or a repair is active. Let the current operation finish or stop the game normally; Sparkle continues the launcher update when the launcher returns to idle.

If the download itself fails, confirm that the Mac can reach GitHub Releases, then use **Settings → Updates → Launcher → Check** to try again. Cancelling or retrying a launcher update does not remove regional game files or cancel a separate game download.

### The launcher is updating storage locations

After an update that changes the standard folder layout, the launcher may block its normal controls
while it moves existing default game and prefix folders into publisher-based locations. Allow the
startup migration to finish; it is a same-volume rename and does not redownload game files. Custom
game locations are not included.

If the launcher reports a collision or an unsafe folder, do not delete or merge either location. Check
which folder contains the installation or prefix state, then resolve the conflict or [report the
problem](https://github.com/LuMiSxh/Arknights-MacOS-Client/issues) with the displayed details. See
[Storage](storage.md#after-a-launcher-update) for the complete move list and recovery rules.

## Download is paused, stuck, or fails

The installer downloads several manifest files concurrently, retries a failed file against a backup CDN, and writes incomplete data to a `.part` file. A pause or closed launcher does not invalidate completed files.

1. Wait briefly if the status says **Preparing download** or **Waiting for network…**.
2. Check the selected region and available storage.
3. Close and reopen the launcher, then choose **Resume Download**.
4. If one file repeatedly fails, wait and retry later; the failure may be a temporary publisher/CDN response.
5. If the files exist but the launcher still cannot finish, use **Repair…** after the download is idle.

> [!NOTE]
> After some terminal download failures, the main action may return to **Install** instead of **Resume Download**. Starting the installation again still validates completed files and reuses valid `.part` data. Do not delete the partial files first.

> [!CAUTION]
> Do not rename, move, or manually replace `.part` files. Do not change the installation location while an install, update, or repair is active. The launcher validates paths and checksums and may discard a partial file that no longer matches the manifest.

If the launcher reports insufficient disk space, free space on the volume containing the selected installation. The conservative preflight compares available capacity with the current full server-reported install requirement, not only the bytes that appear to remain after an existing or partial download. It does not guarantee room for unrelated macOS or user files.

## A region is shown as “Not installed”

Select the region in **Settings → Installation**, then use **Installation Location → Locate Existing Installation…**. Choose the folder that directly contains the configured game executable, normally `Arknights.exe`.

The launcher also requires `.arknights-client-state.json`, its own verified manifest state. A folder copied from another launcher or from a partial backup may contain `Arknights.exe` but still be reported as **Not installed**. In that case, start the launcher's install or repair flow so it can verify the files and write fresh state.

**Choose New Location…** points the selected region at a new destination; it does not move files from the previous location. If the game already exists elsewhere, use **Locate Existing Installation…** and select the folder that contains those files.

## Update or repair does not finish

Automatic checks only identify a changed game version. Start the update from the main action when the launcher reports one. For a damaged installation, wait until no other install operation is running and choose **Settings → Installation → Repair…**.

Repair verifies every manifest file, restores launcher-owned compatibility files before downloading, and downloads only missing or mismatched files. It does not delete the shared Wine prefix or other region's game directory.

If the launcher shows `ANEMONE`, the failure belongs to the Vuplex or Notices compatibility helpers rather than the Wine prefix. Use **Repair** first, then retry the failed install, update, repair, or launch. Do not manually replace helper backups or launcher-owned DLL and bridge files.

> [!TIP]
> If the game was moved outside the launcher, use **Locate Existing Installation…** first. If it was copied without its state file, repair or reinstall is more reliable than manually recreating `.arknights-client-state.json`.

## Game will not launch

### Play is disabled

Check the status shown for the selected region:

- **Not installed** or **Paused**: finish or resume the regional download
- **Update available**: update the region before launching
- Rosetta or Intel compatibility warning: follow [the Rosetta steps](#rosetta-2-is-missing)
- runtime error: use a complete release app bundle and follow [Runtime compatibility](runtime-compatibility.md)

### No game window appears

The launcher waits up to 90 seconds for the Wine game window. If it times out:

1. Confirm that Rosetta passes the launcher's Intel compatibility check.
2. Retry once after quitting any leftover Arknights or Wine process.
3. If the launcher shows `SEPIA`, follow its recovery page before trying **Force Migration…**.
4. If the same error returns, choose **Report Problem** and say whether any game window appeared.

> [!IMPORTANT]
> **Delete Wine Prefix** is a last-resort recovery step, not the same as Force Migration. It removes the selected publisher family's shared Wine environment and saved sign-ins; game files remain untouched and the environment is rebuilt on the next launch. Use it only after reviewing [Storage](storage.md#remove-or-reset-data).

### The game exits immediately

If the failure follows a runtime update, let the next launch complete its migration before retrying. If only one region fails, select another installed region to determine whether the problem follows the shared runtime or that region's files. If it still exits immediately, choose **Report Problem** and say whether a window appeared first.

## Game cannot connect after Local Network access was denied

Quit the game, open **System Settings → Privacy & Security → Local Network**, and allow **Arknights Client**. Start the game again after changing the permission. The launcher cannot repair an account restriction, publisher outage, or other service-side failure; use the [publisher support routing](README.md#publisher-support-routing) table when the same account or service also fails outside the launcher.

## Sign-in, Notices, and embedded browser problems

Global, Japan, Korea, and China clients use browser helpers launched through Wine for their
official sign-in window and separate Notices window. China — Bilibili uses its own client login
flow; the embedded login-window guidance in this section does not apply to that client. For the
clients that use these helpers, their first start or first start after an update, runtime change,
or cache cleanup is a cold start. It can take up to about one minute; later warm starts should be
faster.

1. Allow up to one minute for the helper to finish starting; do not repeatedly press the provider button or reopen Notices.
2. Check the network and system date/time, then retry the provider once.
3. If the page is blank or stale, close the game and choose **Settings → Storage → Clear Caches**. This clears DXMT and embedded-browser caches, not game files or saved settings.
4. Start the game again and allow another cold-start minute while the caches rebuild.
5. If the helper window remains blank, stale, or fails to render after these steps, report the
   launcher problem and name the affected provider or window. If the window renders but
   authentication is rejected, the account is locked, or a provider policy blocks sign-in, use the
   [publisher support routing](README.md#publisher-support-routing) table instead.

> [!WARNING]
> Never post passwords, session cookies, access tokens, or payment details to a GitHub issue. Log files are not needed for the initial report.

For account ownership, a locked account, provider policy, or a missing in-game entitlement, use the
[publisher support routing](README.md#publisher-support-routing) table.

## Graphics, window, and performance problems

The launcher can either leave display settings to Arknights or provide them on every start. Try changes in this order:

1. If **Use In-Game Display Settings** is enabled, adjust the game's own display settings first.
2. On a Retina or scaled display, turn off **High-Resolution Mode** in **Settings → General** and launch again.
3. If the window is too large, incorrectly proportioned, or expensive to render, use a lower resolution or switch between Windowed and Borderless.
4. Use `--no-retina` for one diagnostic launch if the window still has the wrong backing size.
5. If the issue remains, report the display setup and what the window looks like. A maintainer may ask you to use `--graphics-diagnostics` for a follow-up launch.

Higher resolution increases work for both Wine and DXMT. Arknights draws its own cursor inside the game frame; with VSync enabled, the software cursor can trail the macOS pointer on some systems. Disabling VSync in the game can reduce the delay but may introduce tearing.

> [!NOTE]
> **Game Mode (Experimental)** is optional and off by default. It requires the full Xcode application because Apple's required `gamepolicyctl` tool is not shipped with Command Line Tools. It is not a prerequisite for launching the game.

## Payment or service error

Payment pages and notices run inside the game's embedded browser when the selected client provides
them, but transactions remain official publisher/payment-provider matters. Verify every charge with
the payment provider, then use the [publisher support routing](README.md#publisher-support-routing)
table for account or transaction review. Do not repeatedly retry a blocked payment challenge.

## Reporting a launcher problem

Use **Report a Problem…** in the setup assistant or **Settings → About → Report…** for launcher-owned failures. Include:

- launcher version, Mac model, and macOS version
- selected region and whether the game is installed, updating, or repairing
- the exact action that failed and approximate time

The launcher pre-fills the error code, failed operation, selected region, and environment metadata (version, macOS release, chip name, and memory size) when available. Log files are not needed for the initial report. If a maintainer later asks for one, open **Settings → Storage → Show Logs** and attach only the file they name. GitHub issues are public, and you can decline to share a file that contains private information.

> [!IMPORTANT]
> If the problem concerns account access, payment, billing, server availability, or in-game data, use the [publisher support routing](README.md#publisher-support-routing) table instead of opening a launcher issue.
