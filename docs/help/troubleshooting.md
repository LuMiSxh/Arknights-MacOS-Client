---
title: Troubleshooting
description: Steps for launcher, runtime, sign-in, graphics, and game-start problems
order: 20
---

# Troubleshooting

Find the symptom below and work through the steps in order. Almost everything can be fixed without deleting game files.

> [!IMPORTANT]
> Do not delete the Wine prefix or the game folder as a first step. Deleting the prefix signs you out; deleting the game folder means downloading it again.

## The launcher shows an error code

A short uppercase word such as `PEBBLE` points to a specific fix. Choose **Troubleshooting** next to the message, or look it up in [Error codes](errors/README.md).

## The launcher will not open

If macOS says the app **is damaged and can't be opened**, download the DMG again from [GitHub Releases](https://github.com/LuMiSxh/Arknights-MacOS-Client/releases/latest), copy the app to **Applications**, then right-click it and choose **Open**. Only use the official release DMG.

## Setup says Rosetta is missing or unavailable

1. Choose **Install Rosetta 2…**, or run this in Terminal:

   ```sh
   softwareupdate --install-rosetta --agree-to-license
   ```

2. Restart the Mac and choose **Check Again**.
3. On macOS 27, also turn off [Legacy Game Test Mode](runtime-compatibility.md#legacy-game-test-mode).

If the check still fails, see [macOS compatibility](runtime-compatibility.md).

## The download is stuck or fails

1. Wait a moment if it says **Preparing download** or **Waiting for network…**.
2. Check your connection and the free space on the destination drive.
3. Close and reopen the launcher, then choose **Resume Download**.
4. If one file keeps failing, try again later; the publisher's servers may be busy.

Finished files are never lost. Do not move or rename the `.part` files next to the game, and do not change the installation location while a download runs.

## A region shows “Not installed”

Select the region in **Settings → Installation** and choose **Installation Location → Locate Existing Installation…**. Pick the folder that directly contains `Arknights.exe`. If it still shows **Not installed**, the files came from somewhere else; run **Repair…** so the launcher can verify them.

## An update or repair does not finish

Wait until no other download is running, then choose **Settings → Installation → Repair…**. Repair checks every file and downloads only what is missing or broken; your settings and sign-ins stay.

## The game will not start

- **Play is disabled:** finish the download or install the pending update first.
- **No game window appears:** quit any leftover Arknights process and try once more. If the launcher shows an error code, follow its page.
- **The game closes right away:** start it once more after an update, since the first start finishes setting things up. If it keeps closing, try another installed region to see whether only one is affected, then [report the problem](README.md#report-a-problem).

## Sign-in or Notices stay blank

Where you sign in depends on the region:

- **Global, Japan, Korea, and China** use a sign-in window inside the game.
- **China — Bilibili** uses Bilibili's own login window.
- **Taiwan** opens sign-in in your Mac's default browser. If nothing seems to happen, look for a new browser window or tab.

The first time, and after an update or clearing caches, an in-game window can take up to a minute.

1. Wait that minute without pressing the sign-in button again.
2. Check your connection and that the Mac's date and time are correct.
3. For Global, Japan, Korea, or China: quit the game, choose **Settings → Storage → Clear Caches**, and start again.
4. If the window still stays blank, [report the problem](README.md#report-a-problem) and name the region.

If the window works but your sign-in is rejected or the account is locked, contact your [publisher](README.md#publisher-support-routing).

## The game cannot connect

If you denied Local Network access, allow **Arknights Client** under **System Settings → Privacy & Security → Local Network**, then start the game again. If your account or the game service fails outside the launcher too, contact your [publisher](README.md#publisher-support-routing).

## Graphics, window, or performance problems

1. With **Use In-Game Display Settings** on, change the display settings inside the game first.
2. Turn off **High-Resolution Mode** in **Settings → General**.
3. Pick a lower resolution, or switch between **Windowed** and **Borderless**.

If the in-game cursor lags behind the mouse, turning off VSync in the game helps, at the cost of possible tearing.

## A launcher update is waiting

Launcher updates wait until the game, a download, or a repair has finished. They never remove game files.

After some updates, the first start moves existing game folders to a new layout. Let it finish; nothing is downloaded again. If it reports a conflict, do not delete either folder and see [Storage](storage.md#after-a-launcher-update).

## Advanced diagnostics

Use these only when a maintainer asks for them. They apply to one start; quit and open the app normally afterwards.

```sh
open "/Applications/Arknights Client.app" --args --graphics-diagnostics
open "/Applications/Arknights Client.app" --args --no-retina
```

`--graphics-diagnostics` writes detailed graphics logs. `--no-retina` starts the game at 1× scaling, which helps when the window has the wrong size on a Retina display. To keep 1× scaling:

```sh
defaults write com.lumisxh.arknights-client forceDisableRetina -bool YES
```

Replace `YES` with `NO` to restore the default. Log files are listed in [Storage](storage.md#logs).
