---
title: Frequently asked questions
description: Answers about compatibility, permissions, files, updates, cleanup, and support
order: 10
---

# Frequently asked questions

## Which Arknights clients are supported?

> [!NOTE]
> The launcher supports Yostar's Global, Japan, and Korea PC clients. The China and China — Bilibili
> clients are available when Canary Features are enabled and are operated by Hypergryph.

Choose the region that matches the service and account you already use. Regional installations, versions, and installed states are kept separate.

## Is this an official Yostar or Hypergryph launcher?

> [!IMPORTANT]
> No. Arknights Client is a community-maintained macOS launcher. It is not affiliated with, endorsed by, or supported by Hypergryph, Yostar, or Bilibili. It downloads the selected publisher's official PC-client files; it does not ship the game in the DMG.

The project cannot guarantee how a publisher will treat any third-party launcher or compatibility environment. The selected service alone defines its account and enforcement policies. Do not rely on the project for assurances about account standing.

## Does the download include Arknights game files?

No. The DMG contains the launcher, the tested Wine + DXMT runtime, required licenses, and an Applications shortcut. After you choose a region, the launcher fetches that region's official PC client directly from its publisher.

## Which Macs and macOS versions can run it?

Apple silicon Macs (M1 or newer) running macOS 15 through macOS 27 are in scope. Rosetta 2 is required because the bundled Wine runtime currently contains x86-64 macOS binaries.

The launcher tests whether an Intel process can actually start instead of trusting an installed-file marker. The current runtime supports macOS 15 through macOS 27; macOS 27 requires Legacy Game Test Mode to be disabled, and macOS 28 is blocked. See [Runtime compatibility](runtime-compatibility.md#macos-support) before upgrading macOS.

The Arknights Client app itself is native Apple silicon software. Rosetta is needed for the x86-64 parts of Wine that run the selected publisher's Windows game; it does not turn the SwiftUI launcher into an Intel app.

## Why does macOS ask for Local Network access?

The Windows game uses local networking while it runs through Wine. The permission belongs to that game-runtime traffic; the launcher does not automatically upload logs. If you denied it and the game cannot connect, allow **Arknights Client** under **System Settings → Privacy & Security → Local Network**, then start the game again.

## How much storage do I need?

The launcher reads the current install size from the selected region's service and checks the destination's available capacity before starting. Keep additional free space for temporary download files, future updates, repair operations, and caches. The server-provided value can change over time.

See [Storage](storage.md) for the locations measured by **Settings → Storage** and the cleanup actions that are safe to use.

## Do I need an internet connection?

Yes for setup, installation, updates, sign-in, and normal access to the selected game service. The launcher downloads configuration and official client files rather than bundling them. It does not promise offline gameplay; server availability and account access remain controlled by the service operator.

## Can I install more than one region?

Yes. Each supported region has its own game directory and manifest state. Global, Japan, and Korea
are Yostar clients and share one Wine prefix; China and China — Bilibili are Hypergryph clients and
share another. The selected region is mapped as Wine's `G:` drive for a launch. Switching regions
does not move or convert the other region's files.

## Can I use an existing installation?

Use **Settings → Installation → Installation Location → Locate Existing Installation…** and select the actual game folder. The launcher considers it installed only when it can find the configured `Arknights.exe` and `.arknights-client-state.json` state file. A folder copied from another launcher may therefore need to be installed or repaired before it is recognized.

**Choose New Location…** changes where the selected region will be installed. It does not move an existing game folder or delete files from the previous location. Use **Locate Existing Installation…** when the files already exist at the destination.

## Does the launcher update the game automatically?

No. **Check for Game Updates** compares the selected installation with its publisher's current configuration and marks an update when the version differs. It does not download game data by itself; you start the update from the main action.

Launcher updates use Sparkle and are also controlled separately. Both automatic checks can be disabled in **Settings → Updates**. Enabling a check may trigger a check immediately; it still does not silently install the result.

A launcher update waits for an active game, download, update, or repair to finish. Cancelling a launcher-update download does not cancel or remove a game installation.

## What is the difference between update, resume, and repair?

- **Update** reuses files that still match the stored manifest and downloads missing or changed files
- **Resume** continues a paused download from safe `.part` files beside their final destinations
- **Repair** verifies every manifest file and downloads missing or damaged files again

The installer verifies the size and CRC64 checksum of each downloaded file before moving it into place. If a download is interrupted, closing the launcher is safe; reopen it and choose **Resume Download**.

## Does the launcher modify the official game files?

The launcher applies its own compatibility components to the selected game directory for launch. Before an update or repair, it restores the official files, and it tracks the files it owns so they can be removed or upgraded safely. Do not replace or delete those files manually while a launch, update, or repair is in progress.

## Why can the first game start take longer?

The first **Play** after installing the launcher or changing its runtime may need to initialize the shared Wine prefix, install DXMT, apply registry settings, and prepare compatibility helpers before the game window appears. Later warm starts should be faster. If no window appears after the launcher reports a failure, use [Game will not launch](troubleshooting.md#game-will-not-launch).

## Can I quit the launcher while Arknights is running?

No. Quitting Arknights Client stops its shared Wine server and the running game. Closing the launcher window is not the same as choosing **Quit** on macOS; the app can be reopened from the Dock while it remains running.

## Why is sign-in or the Notices window blank or slow?

Global, Japan, Korea, and China clients use browser helpers inside Wine for their official sign-in
window and separate Notices window. China — Bilibili uses its own client login flow; the embedded
login-window guidance in this answer does not apply to that client.

> [!NOTE]
> After the first launch or an update, a cold start of either helper can take up to about one minute while the runtime initializes and its caches warm up. Later starts should be noticeably faster. Wait for that first minute before treating a blank window as a failure.

If the page remains blank after that, try the steps in [Sign-in, Notices, and embedded browser problems](troubleshooting.md#sign-in-notices-and-embedded-browser-problems), including clearing the recreatable browser cache. Clearing caches makes the following start cold again, so allow the helper time to rebuild them.

## Why can a notice still appear when announcements are disabled?

The setting controls project announcements such as launcher news and maintenance information.
Official publisher notices use a separate game-service feed and may still appear. For Yostar
regions, branding notices come from Yostar's game-service feed; disabling project announcements
does not disable those notices.

## Who handles accounts, payments, and game-service problems?

> [!WARNING]
> Contact [Yostar Support](https://account.yo-star.com/contact) for Global, Japan, and Korea account access, login ownership, payment, billing, server availability, or in-game service issues.
> Contact [Hypergryph Support](https://user.hypergryph.com/support) for the same issues with China or China — Bilibili.
> Contact the launcher project for installation, runtime, graphics, window, or launcher-owned embedded-browser failures.

Payment pages run inside the compatibility environment when the selected client provides them.
Transactions remain official publisher/payment-provider matters: verify every charge with the
payment provider, then route the publisher question by region using the [support routing](README.md#publisher-support-routing) table. A successful browser flow does not make the launcher a payment-support channel.

## Where are files and logs stored?

Game files are separate per region. The Wine prefix, compatibility runtime, browser data, caches, and central logs have different lifetimes. Standard game and prefix folders are grouped by publisher; after an update that introduces this layout, the launcher migrates exact old default paths before normal startup. See [Storage](storage.md) for the complete path table and the consequences of each cleanup action.

## What do the cleanup, reset, and uninstall actions remove?

- **Clear Caches** removes recreatable DXMT and embedded-browser caches. It keeps game files, saved sign-ins, and launcher settings; the next start may be slower.
- **Force Migration…** removes nothing. It forces Wine, DXMT, and registry setup to run again on the next launch while keeping game files, the Wine prefix, and saved sign-ins.
- **Delete Wine Prefix…** removes the selected publisher family's shared Windows environment, including browser sessions, registry state, DXMT cache, and migration data. It keeps every regional game installation and launcher setting.
- **Reset All Settings…** resets launcher preferences and launch options. It keeps the selected region, installation locations, and game files.
- **Uninstall Game…** moves the selected region's game directory to the Trash. It keeps other regions, the launcher, the selected publisher family's shared Wine prefix, and custom art.
- Moving **Arknights Client.app** to the Trash removes only the app bundle. Game files, the Wine prefix, caches, logs, preferences, and artwork remain.

Deleting a Wine prefix signs embedded-browser providers out across that client family when those
providers are used. For a complete uninstall, use the targeted removal steps in [Storage](storage.md#remove-or-reset-data) before moving the app itself to the Trash.

## Does “Report a Problem…” upload my logs?

No. The action opens a pre-filled public GitHub issue with the launcher version, macOS version, chip name, and memory size. For a coded failure, it also includes the code, operation, and selected region. Log files are not needed for the initial report. If a maintainer later asks for a specific file, open **Settings → Storage → Show Logs** and attach only the file they name.

## Can I control the game window from the launcher?

By default, Arknights controls its own display settings. In **Settings → General**, you can let the launcher provide window mode and resolution on every start. Windowed, borderless, and fullscreen modes are available, and High-Resolution Mode can be disabled when a Retina display causes uneven performance. See [Graphics, window, and performance problems](troubleshooting.md#graphics-window-and-performance-problems).

## Is Game Mode required?

No. Game Mode is an experimental optional setting. It asks macOS to prioritize the game and requires the full Xcode application because the required Apple tool is not included in Command Line Tools. It is off by default and has no effect on the Wine runtime when disabled.
