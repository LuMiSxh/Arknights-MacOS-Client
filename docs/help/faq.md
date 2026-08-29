---
title: Frequently asked questions
description: Answers about supported regions, compatibility, files, updates, and support
order: 10
---

# Frequently asked questions

## Which Arknights clients are supported?

> [!NOTE]
> The launcher supports Yostar's official Global, Japan, and Korea PC clients. CN is not supported: its separate Hypergryph infrastructure and Tencent ACE anti-cheat are incompatible with this Wine-based runtime.

Choose the region that matches the Yostar service and account you already use. Regional installations, versions, and installed states are kept separate.

## Is this an official Yostar or Hypergryph launcher?

> [!IMPORTANT]
> No. Arknights Client is a community-maintained macOS launcher. It is not affiliated with, endorsed by, or supported by Hypergryph or Yostar. It downloads the official PC-client files from Yostar after you select a region; it does not ship the game in the DMG.

## Does the download include Arknights game files?

No. The DMG contains the launcher, the tested Wine + DXMT runtime, required licenses, and an Applications shortcut. After you choose a region, the launcher fetches that region's official PC client directly from Yostar.

## Which Macs and macOS versions can run it?

Apple silicon Macs (M1 or newer) running macOS 15 through macOS 27 are in scope. Rosetta 2 is required because the bundled Wine runtime currently contains x86-64 macOS binaries.

The launcher tests whether an Intel process can actually start instead of trusting an installed-file marker. The current runtime supports macOS 15 through macOS 27; macOS 27 requires Legacy Game Test Mode to be disabled, and macOS 28 is blocked. See [Runtime compatibility](runtime-compatibility.md#macos-support) before upgrading macOS.

## How much storage do I need?

The launcher reads the current install size from Yostar for the selected region and checks the destination's available capacity before starting. Keep additional free space for temporary download files, future updates, repair operations, and caches. The value shown by the assistant is server-provided and can change over time.

See [Storage](storage.md) for the locations measured by **Settings → Storage** and the cleanup actions that are safe to use.

## Can I install more than one region?

Yes. Each supported region has its own game directory and manifest state. The Wine prefix and its embedded-browser data are shared, while the selected region is mapped as Wine's `G:` drive for a launch. Switching regions does not move or convert the other region's files.

## Can I use an existing installation?

Use **Settings → Installation → Installation Location → Locate Existing Installation…** and select the actual game folder. The launcher considers it installed only when it can find the configured `Arknights.exe` and `.arknights-client-state.json` state file. A folder copied from another launcher may therefore need to be installed or repaired before it is recognized.

## Does the launcher update the game automatically?

No. **Check for Game Updates** compares the selected installation with Yostar's current configuration and marks an update when the version differs. It does not download game data by itself; you start the update from the main action.

Launcher updates use Sparkle and are also controlled separately. Both automatic checks can be disabled in **Settings → Updates**. Enabling a check may trigger a check immediately; it still does not silently install the result.

## What is the difference between update, resume, and repair?

- **Update** reuses files that still match the stored manifest and downloads missing or changed files
- **Resume** continues a paused download from safe `.part` files beside their final destinations
- **Repair** verifies every manifest file and downloads missing or damaged files again

The installer verifies the size and CRC64 checksum of each downloaded file before moving it into place. If a download is interrupted, closing the launcher is safe; reopen it and choose **Resume Download**.

## Does the launcher modify the official game files?

The launcher applies its own compatibility components to the selected game directory for launch. Before an update or repair, it restores the official files, and it tracks the files it owns so they can be removed or upgraded safely. Do not replace or delete those files manually while a launch, update, or repair is in progress.

## Why is sign-in blank or slow?

Yostar, Google, Apple, and Facebook sign-in run in an embedded browser helper inside Wine. The first sign-in can take longer while that helper initializes. If the page remains blank, try the steps in [Sign-in and embedded browser problems](troubleshooting.md#sign-in-and-embedded-browser-problems), including clearing the recreatable browser cache.

## Who handles accounts, payments, and game-service problems?

> [!WARNING]
> Contact [Yostar Support](https://account.yo-star.com/contact) for account access, login ownership, payment, billing, server availability, or in-game service issues. Contact the launcher project for installation, runtime, graphics, window, or embedded-browser failures.

Payment pages run inside the compatibility environment. Verify every charge with the payment provider and Yostar; a successful browser flow does not make the launcher a payment-support channel.

## Where are files and logs stored?

Game files are separate per region. The Wine prefix, compatibility runtime, browser data, caches, and central logs have different lifetimes. See [Storage](storage.md) for the complete path table and the consequences of each cleanup action.

## Does “Report a Problem…” upload my logs?

No. The action opens a pre-filled public GitHub issue with the launcher version, macOS version, chip name, and memory size. It never attaches logs automatically. Review excerpts from `launcher.log`, `wine.log`, `unity.log`, or `chromium.log`, remove private paths and account-related data, and attach only what is relevant.

## Can I control the game window from the launcher?

By default, Arknights controls its own display settings. In **Settings → General**, you can let the launcher provide window mode and resolution on every start. Windowed, borderless, and fullscreen modes are available, and High-Resolution Mode can be disabled when a Retina display causes uneven performance. See [Graphics, window, and performance problems](troubleshooting.md#graphics-window-and-performance-problems).

## Is Game Mode required?

No. Game Mode is an experimental optional setting. It asks macOS to prioritize the game and requires the full Xcode application because the required Apple tool is not included in Command Line Tools. It is off by default and has no effect on the Wine runtime when disabled.
