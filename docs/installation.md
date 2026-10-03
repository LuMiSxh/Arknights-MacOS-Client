---
title: Installation
description: Requirements, installation, and first launch on Apple Silicon Macs
order: 10
---

# Installation

Arknights Client downloads the official PC version of Arknights from its publisher and runs it on your Mac. The launcher download does not contain any game files.

## Requirements

- an Apple silicon Mac (M1 or newer)
- macOS 15 through macOS 27 (see [macOS compatibility](help/runtime-compatibility.md) before upgrading)
- Rosetta 2, which the setup assistant can install for you
- an account for the region you want to play
- an internet connection and enough free space for the game and its updates

The launcher shows the current download size before it starts and checks that the destination has room for it.

## Install the launcher

1. Download `Arknights.Client.dmg` from [GitHub Releases](https://github.com/LuMiSxh/Arknights-MacOS-Client/releases/latest).
2. Open it and drag **Arknights Client** to **Applications**.
3. Open the app from **Applications** once.

> [!WARNING]
> Releases are ad-hoc signed and not notarized. If macOS says the developer cannot be verified or Apple cannot check the app, continue only if you downloaded it from the official GitHub release. After trying to open the app, go to **System Settings → Privacy & Security → Open Anyway**, then review the warning and choose **Open**. This saves an exception for this app only. See [Apple’s steps for opening an app that has not been notarized](https://support.apple.com/en-au/102445). If macOS says the app is damaged or will damage your computer, do not override that alert.

## Set up the game

The setup assistant opens on the first start. It saves each choice right away, and you can change everything later in **Settings**.

1. **Rosetta 2** — if it is missing, choose **Install Rosetta 2…**, then **Check Again**.
2. **Region** — choose the service your account belongs to:

   | Region               | Publisher  | Availability                       |
   | -------------------- | ---------- | ---------------------------------- |
   | **Global**           | Yostar     | Always                             |
   | **Japan**            | Yostar     | Always                             |
   | **Korea**            | Yostar     | Always                             |
   | **Taiwan**           | Gryphline  | [Canary Features](#canary-regions) |
   | **China**            | Hypergryph | [Canary Features](#canary-regions) |
   | **China — Bilibili** | Hypergryph | [Canary Features](#canary-regions) |

3. **Download** — choose **Install & Continue**. The download keeps running while you finish the remaining pages, and closing the launcher only pauses it.
4. **Display** — answer two questions: whether the game opens in a window or fullscreen, and whether the sharpest picture, smooth play on large screens, or lower battery use matters most. The launcher then picks a window size that fits your screen, or fullscreen at your display's native resolution.
5. **Launcher, updates, and audio** — pick artwork and Dock icons, then answer whether the launcher should check for updates and play music.

When the download has finished and been verified, the launcher enables **Play**.

### Canary regions

Taiwan, China, and China — Bilibili are experimental. To show them, turn on **Settings → Installation → Canary Features**, then **Allow Taiwan client** or **Allow China clients**. These regions use ACE Anti-Cheat, and the launcher asks you to confirm before their first start that running them through Wine is unofficial and at your own risk.

## First launch

Choose **Play** and sign in through the official game. The first start after installing takes longer while the launcher prepares its Windows environment; later starts are faster. Taiwan opens sign-in in your default browser; the other regions sign in inside the game, where the window can stay blank for up to a minute the first time.

> [!TIP]
> Quitting Arknights Client also quits the game. Closing the launcher window does not.

## More regions and existing installations

- **Add a region:** select it in **Settings → Installation** and start its download. Each region keeps its own files and version.
- **Use files already on disk:** choose **Settings → Installation → Installation Location → Locate Existing Installation…** and select the game folder. Folders copied from another launcher may still show **Not installed**; run **Repair…** to verify them.
- **Install somewhere else:** choose **Choose New Location…** before the download starts. Use a folder that holds only the game, because the game can see its contents.

## Keep the game up to date

The launcher checks for game updates but never downloads without asking. Choose **Update** in the main window when one is available. If the game is damaged, **Settings → Installation → Repair…** checks every file and downloads only what is missing or broken.

If something does not work, start with [Troubleshooting](help/troubleshooting.md).
