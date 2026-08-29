---
title: Troubleshooting
description: Steps for launcher, runtime, sign-in, graphics, and game-start problems
order: 20
---

# Troubleshooting

Use the symptom that matches what you see. Keep the recovery order conservative: most problems can be diagnosed from a log or repaired from the launcher without deleting game files or the shared Wine prefix.

## Start here

1. Quit Arknights and wait for the launcher to return to an idle state.
2. Confirm the intended region is selected in **Settings → Installation**.
3. Check the available storage for the selected game and the shared Wine prefix.
4. Open **Settings → Storage → Show Logs** and note the time of the failed action.
5. Retry once. If the same symptom returns, follow the matching section below before removing anything.

> [!IMPORTANT]
> Do not delete the Wine prefix or game directory as a first response. Deleting the prefix signs you out of every embedded-browser account and removes runtime caches; deleting a game directory removes the regional installation. See [Storage](storage.md) before using either destructive action.

## Log locations

The launcher writes its own diagnostics to one central macOS log directory. **Settings → Storage → Show Logs** prepares that directory and selects the available launcher, Wine, Unity, and Chromium files in Finder. macOS crash reports live separately and are not selected by this action.

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
> Capture the launcher log and Wine log immediately after reproducing a failure. Include a small time-adjacent excerpt rather than a complete log when possible; logs may contain private paths, URLs, or account-related data.

## Diagnostic launch options

These options are useful when a normal log is not enough. They are temporary command-line options; close the app and launch it normally again when finished.

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

If the app still does not open, check `~/Library/Logs/DiagnosticReports/` for a recent launcher crash report and use **Report…** in **Settings → About** from a working installation. A missing runtime inside a manually copied or incomplete app bundle is a packaging problem; use a complete release DMG.

## Setup or installation will not start

### Rosetta 2 is missing

The bundled Wine runtime is x86-64 and cannot start without Rosetta 2. Choose **Install Rosetta 2…** in the setup assistant, or run:

```sh
softwareupdate --install-rosetta --agree-to-license
```

Return to the launcher and choose **Check Again**. The launcher tests an actual Intel process, so simply finding an on-disk Rosetta marker is not sufficient.

### Rosetta appears installed but the check fails

Restart the Mac and choose **Check Again**. If the result remains unavailable, attach `launcher.log` and the macOS version to a launcher report. Do not delete the game directory for this symptom.

### Legacy Game Test Mode is active

On macOS 27, Legacy Game Test Mode can leave Rosetta installed while disabling the general translation environment Wine requires:

```sh
sudo game-test-tool disable
```

Restart the Mac, then choose **Check Again**. If the command is unavailable, consult Apple's current macOS documentation for the installed OS version; the launcher cannot enable general Rosetta while that test mode is active.

### macOS no longer supports the required translation

The current runtime is blocked when macOS does not provide general Intel translation. See [macOS support](runtime-compatibility.md#macos-support) before upgrading or downgrading the operating system.

### Setup update check failed

Check that the Mac can reach GitHub and Yostar services, then use **Try Again**. The assistant can continue after an unavailable launcher update check, but install the newer launcher before starting setup when an update is reported.

## Download is paused, stuck, or fails

The installer downloads several manifest files concurrently, retries a failed file against a backup CDN, and writes incomplete data to a `.part` file. A pause or closed launcher does not invalidate completed files.

1. Wait briefly if the status says **Preparing download** or **Waiting for network…**.
2. Check the selected region and available storage.
3. Close and reopen the launcher, then choose **Resume Download**.
4. If one file repeatedly fails, wait and retry later; the failure may be a temporary Yostar/CDN response.
5. If the files exist but the launcher still cannot finish, use **Repair…** after the download is idle.

> [!CAUTION]
> Do not rename, move, or manually replace `.part` files. Do not change the installation location while an install, update, or repair is active. The launcher validates paths and checksums and may discard a partial file that no longer matches the manifest.

If the launcher reports insufficient disk space, free space on the volume containing the selected installation. The check uses the current server-reported install requirement and does not guarantee room for unrelated macOS or user files.

## A region is shown as “Not installed”

Select the region in **Settings → Installation**, then use **Installation Location → Locate Existing Installation…**. Choose the folder that directly contains the configured game executable, normally `Arknights.exe`.

The launcher also requires `.arknights-client-state.json`, its own verified manifest state. A folder copied from another launcher or from a partial backup may contain `Arknights.exe` but still be reported as **Not installed**. In that case, start the launcher's install or repair flow so it can verify the files and write fresh state.

## Update or repair does not finish

Automatic checks only identify a changed game version. Start the update from the main action when the launcher reports one. For a damaged installation, wait until no other install operation is running and choose **Settings → Installation → Repair…**.

Repair verifies every manifest file, restores launcher-owned compatibility files before downloading, and downloads only missing or mismatched files. It does not delete the shared Wine prefix or other region's game directory.

> [!TIP]
> If the game was moved outside the launcher, use **Locate Existing Installation…** first. If it was copied without its state file, repair or reinstall is more reliable than manually recreating `.arknights-client-state.json`.

## Game will not launch

### Play is disabled

Check the status shown for the selected region:

- **Not installed** or **Paused**: finish or resume the regional download
- **Update available**: update the region before launching
- Rosetta or Intel compatibility warning: follow [the Rosetta steps](#rosetta-2-is-missing)
- runtime error: use a complete release app bundle and inspect `wine.log`

### No game window appears

The launcher waits up to 90 seconds for the Wine game window. If it times out:

1. Open `wine.log` and look around the most recent **Play** attempt for Rosetta, Metal, DXMT, or process errors.
2. Confirm that Rosetta passes the launcher's Intel compatibility check.
3. Retry once after quitting any leftover Arknights or Wine process.
4. If the log shows a pending or failed Wine setup, choose **Settings → Installation → Wine Setup → Force Migration…**, confirm it, and launch again. This reruns Wine initialization, DXMT installation, and registry setup without touching game files or saves.
5. If the same error returns, report the launcher and Wine logs.

> [!IMPORTANT]
> **Delete Wine Prefix** is a last-resort recovery step, not the same as Force Migration. It removes the shared Wine environment and saved sign-ins for every region; game files remain untouched and the environment is rebuilt on the next launch. Use it only after reviewing [Storage](storage.md#remove-or-reset-data).

### The game exits immediately

Check `wine.log`, `unity.log`, and `~/Library/Logs/DiagnosticReports/` for the same timestamp. If the failure follows a runtime update, let the next launch complete its migration before retrying. If only one region fails, select another installed region to determine whether the problem follows the shared runtime or that region's files.

## Sign-in and embedded browser problems

Yostar, Google, Apple, and Facebook sign-in use the embedded browser helper launched through Wine. The first browser start can take longer than the game window itself.

1. Wait for the browser helper to finish starting; do not repeatedly press the provider button.
2. Check the network and system date/time, then retry the provider once.
3. If the page is blank or stale, close the game and choose **Settings → Storage → Clear Caches**. This clears DXMT and embedded-browser caches, not game files or saved settings.
4. Retry the sign-in.
5. If OAuth still fails, collect `chromium.log` and `wine.log` and report the launcher problem.

> [!WARNING]
> Never attach passwords, session cookies, access tokens, payment details, or an unreviewed full browser log to a GitHub issue. The launcher report form does not upload logs for you; review every excerpt first.

For account ownership, a locked account, provider policy, or a missing in-game entitlement, contact [Yostar Support](https://account.yo-star.com/contact).

## Graphics, window, and performance problems

The launcher can either leave display settings to Arknights or provide them on every start. Try changes in this order:

1. If **Use In-Game Display Settings** is enabled, adjust the game's own display settings first.
2. On a Retina or scaled display, turn off **High-Resolution Mode** in **Settings → General** and launch again.
3. If the window is too large, incorrectly proportioned, or expensive to render, use a lower resolution or switch between Windowed and Borderless.
4. Use `--no-retina` for one diagnostic launch if the window still has the wrong backing size.
5. Use `--graphics-diagnostics` and inspect `wine.log` when the issue involves a blank window, Metal, DXMT, or a rendering failure.

Higher resolution increases work for both Wine and DXMT. Arknights draws its own cursor inside the game frame; with VSync enabled, the software cursor can trail the macOS pointer on some systems. Disabling VSync in the game can reduce the delay but may introduce tearing.

> [!NOTE]
> **Game Mode (Experimental)** is optional and off by default. It requires the full Xcode application because Apple's required `gamepolicyctl` tool is not shipped with Command Line Tools. It is not a prerequisite for launching the game.

## Payment or service error

Payment pages and notices run inside the game's embedded browser, but the transaction and service remain Yostar-controlled. Verify every charge with the payment provider and Yostar. Do not repeatedly retry a blocked payment challenge; contact [Yostar Support](https://account.yo-star.com/contact) if the account or transaction needs review.

## Reporting a launcher problem

Use **Report a Problem…** in the setup assistant or **Settings → About → Report…** for launcher-owned failures. Include:

- launcher version, Mac model, and macOS version
- selected region and whether the game is installed, updating, or repairing
- the exact action that failed and approximate time
- relevant excerpts from `launcher.log`, `wine.log`, `unity.log`, or `chromium.log`
- a recent crash report when the process terminated unexpectedly

The launcher pre-fills environment metadata (version, macOS release, chip name, and memory size) but never attaches logs automatically. GitHub issues are public: review that metadata and remove private paths, URLs, account data, tokens, cookies, passwords, payment details, and unrelated log lines before attaching anything.

> [!IMPORTANT]
> If the problem concerns account access, payment, billing, server availability, or in-game data, contact [Yostar Support](https://account.yo-star.com/contact) instead of opening a launcher issue.
