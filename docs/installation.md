---
title: Installation
description: Requirements, installation, and first launch
order: 10
---

# Installation

The launcher downloads the official PC game from its publisher. It contains no game files.

## Quick start

1. Download `Arknights.Client.dmg` from [GitHub Releases](https://github.com/LuMiSxh/Arknights-MacOS-Client/releases/latest).
2. Open the DMG. Drag **Arknights Client** to **Applications**.
3. Open **Arknights Client**. If macOS blocks it, follow the [steps below](#if-macos-blocks-the-app).
4. Follow the setup assistant. Choose your server.
5. Choose the runtime. Choose **ARM64 (Apple Silicon)** on macOS 26 or later, or **x86_64** on macOS 15.
6. Choose **Play** and sign in.

Read on for details on each step.

## Requirements

- An Apple silicon Mac: an M-series Mac, or the MacBook Neo (A18 Pro)
- macOS 15 or later (see [Game runtime](help/runtime.md#macos-support))
- The **x86_64** runtime needs Rosetta 2.
- The **ARM64 (Apple Silicon)** runtime needs macOS 26 or later. It does not need Rosetta 2.
- An account for your region
- An internet connection and free space for the game and its updates

> [!NOTE]
> The MacBook Neo has 8 GB of memory and no fan.
> The game lists 8 GB of RAM, so macOS and the game share that memory.
> Close other apps before you play.

## Install the launcher

1. Download `Arknights.Client.dmg` from [GitHub Releases](https://github.com/LuMiSxh/Arknights-MacOS-Client/releases/latest).
2. Open the DMG and drag **Arknights Client** to **Applications**.
3. Open the app.

### If macOS blocks the app

Releases are ad-hoc signed and not notarized. macOS can block the app. Continue only if the app came from the official release.

1. Open **Arknights Client** once. macOS shows an alert.
2. Open **System Settings → Privacy & Security**.
3. Scroll down and choose **Open Anyway**.
4. Confirm with **Open**.

See [Apple’s steps](https://support.apple.com/en-au/102445). Never override an alert that the app is damaged or will damage your computer.

## Set up the game

The setup assistant opens on the first start. Change any choice later in **Settings**.

1. **System Check** — The assistant checks for a launcher update.
2. **Server** — Choose the server for your account:

   | Server               | Publisher  | Availability |
   | -------------------- | ---------- | ------------ |
   | **Global**           | Yostar     | Always       |
   | **Japan**            | Yostar     | Always       |
   | **Korea**            | Yostar     | Always       |
   | **Taiwan**           | Gryphline  | Always       |
   | **China**            | Hypergryph | Always       |
   | **China (Bilibili)** | Hypergryph | Always       |

   Nothing downloads on this step.

3. **Install** — The step names your server and its publisher. Then choose the runtime, the game files location, and Rosetta 2 if needed.
   - Choose **ARM64 (Apple Silicon)** on macOS 26 or later. This is the recommended runtime.
   - On macOS 15, choose **x86_64**. It is the only runtime. On macOS 26 and 27, **x86_64** is a fallback.
   - Choose **Change…** to pick another location for the game files.
   - **x86_64** needs Rosetta 2. If it is missing, choose **Install Rosetta 2…**, then **Check Again**.
   - On macOS 28 or later, see [macOS support](help/runtime.md#macos-support).
   - Choose **Download and Continue** to download what is missing, or **Continue** if everything is installed. The game download continues in the background while you finish setup. The setup rail shows its progress on every step. Choose **Pause** to stop it and **Resume** to continue. The runtime download pauses and resumes the same way. **Back** never stops a download.
   - If a download fails, the step shows what happened and a support code under the failed item. Choose **Download and Continue** to try again.
   - If the game download fails on a later step, the setup rail shows **Download failed** and its support code. Choose **Retry** to start the download again.
   - See [Game runtime](help/runtime.md).
4. **Display** — Choose the display mode and window size. Open **More options** for rendering, frame rate limit, and cursor. Pick an exact size later in **Settings → Game**.
5. **Look** — Choose artwork and Dynamic Theme. Open **More options** for Home controls, branding colors, appearance, launcher information, and the Dock operator.
6. **Updates and Integrations** — Choose update behavior and the daily reset reminder. Choose whether to play launcher music. Open **More options** for Discord presence, music volume, and **Now playing**.

After the launcher verifies the download, **Play** becomes available.

### Anti-cheat

Taiwan, China, and China (Bilibili) use ACE Anti-Cheat. Before the first start, the launcher asks you to confirm that running them through Wine is unofficial. Use these servers at your own risk.

## First launch

1. Choose **Play**.
2. Sign in through the official game.
   - Taiwan signs in through your default browser.
   - Other servers sign in inside the game.

The first start is slower. The window can stay blank for up to one minute the first time.

> [!TIP]
> Quitting Arknights Client also quits the game. Closing the launcher window does not.

## More servers and existing installations

- **Add a server:** Select it in **Settings → Installation** and start its download.
- **Use existing files:** Choose **Settings → Installation → Location → Change… → Locate Existing Installation…**. Select the game folder. If it shows **Not installed**, run **Repair**.
- **Use another location:** Choose **Choose New Location…** before the download. Use a folder that contains only the game. The game can see its contents.

## Update the launcher

When a launcher update is available, the main window shows **Install Update**. Choose **Install Update**. The launcher installs the update and restarts.

To change automatic checks:

1. Choose **Settings → Updates**.
2. Turn **Launcher updates** on or off under **Automatic checks**.

If the launcher needs a newer runtime, Home shows **Runtime update required**. Choose **Update Runtime**.

## Update the game

The launcher never downloads game updates without your choice. To update the game, choose **Update** in the main window.

If the game is damaged, choose **Settings → Installation → Repair**. Repair downloads only missing or broken files. If something fails, see [Troubleshooting](help/troubleshooting.md).
