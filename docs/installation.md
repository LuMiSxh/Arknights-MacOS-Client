---
title: Installation
description: Requirements, installation, and first launch
order: 10
---

# Installation

The launcher downloads the official PC game from its publisher. It contains no game files.

## Requirements

- An Apple silicon Mac (M1 or newer)
- macOS 15 through macOS 27 (see [macOS compatibility](help/runtime-compatibility.md))
- Rosetta 2
- An account for your region
- An internet connection and free space for the game and its updates

## Install the launcher

1. Download `Arknights.Client.dmg` from [GitHub Releases](https://github.com/LuMiSxh/Arknights-MacOS-Client/releases/latest).
2. Open the DMG and drag **Arknights Client** to **Applications**.
3. Open the app.

> [!WARNING]
> Releases are ad-hoc signed and not notarized. macOS can block the app. Continue only if the app came from the official release. Choose **System Settings → Privacy & Security → Open Anyway** and **Open**. See [Apple’s steps](https://support.apple.com/en-au/102445). Never override an alert that the app is damaged or will damage your computer.

## Set up the game

The setup assistant opens on the first start. Change any choice later in **Settings**.

1. **Rosetta 2** — If missing (the assistant installs it), choose **Install Rosetta 2…**, then **Check Again**.
2. **Region** — Choose the service of your account:

   | Region               | Publisher  | Availability                       |
   | -------------------- | ---------- | ---------------------------------- |
   | **Global**           | Yostar     | Always                             |
   | **Japan**            | Yostar     | Always                             |
   | **Korea**            | Yostar     | Always                             |
   | **Taiwan**           | Gryphline  | [Canary Features](#canary-regions) |
   | **China**            | Hypergryph | Always                             |
   | **China (Bilibili)** | Hypergryph | Always                             |

3. **Download** — Choose **Install & Continue**. The download continues in the background. Closing the launcher pauses it.
4. **Display** — Choose window or fullscreen, window size, picture priority, and pointer. Pick an exact size later in **Settings → Game**.
5. **Look** — Choose artwork, colors, the Dock operator, and launcher display options.
6. **Updates & Audio** — Choose update behavior and music.

After the launcher verifies the download, **Play** becomes available.

### Canary regions

To show experimental Taiwan, turn on **Settings → Installation → Canary Features**, then **Allow Taiwan region**. Taiwan uses ACE Anti-Cheat. Before the first start, the launcher asks you to confirm that running it through Wine is unofficial and at your own risk.

## First launch

Choose **Play** and sign in through the official game. The first start is slower. Taiwan signs in through your default browser. Other regions sign in inside the game. The window can stay blank for up to one minute the first time.

> [!TIP]
> Quitting Arknights Client also quits the game. Closing the launcher window does not.

## More regions and existing installations

- **Add a region:** Select it in **Settings → Installation** and start its download.
- **Use existing files:** Choose **Settings → Installation → Installation Location → Locate Existing Installation…** and select the game folder. If it shows **Not installed**, run **Repair…**.
- **Use another location:** Choose **Choose New Location…** before the download. Use a folder that contains only the game. The game can see its contents.

## Keep the game up to date

The launcher never downloads updates without your choice. Choose **Update** in the main window. If the game is damaged, choose **Settings → Installation → Repair…**. Repair downloads only missing or broken files.

If something fails, see [Troubleshooting](help/troubleshooting.md).
