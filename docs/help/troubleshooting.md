---
title: Troubleshooting
description: Fixes for launcher, sign-in, graphics, and start problems
order: 20
---

# Troubleshooting

> [!IMPORTANT]
> Do not delete the Wine prefix or the game folder first. Deleting the prefix signs you out. Deleting the game folder forces a new download.

## The launcher shows an error code

See [Error codes](errors/README.md) for words such as `PEBBLE`.

## The launcher will not open

- **Cannot verify the developer, or cannot check for malicious software:** Confirm that you downloaded the app from [the official GitHub release](https://github.com/LuMiSxh/Arknights-MacOS-Client/releases/latest). Then follow [Apple’s Open Anyway steps](https://support.apple.com/en-au/102445): in **System Settings → Privacy & Security**, choose **Open Anyway**, then **Open**.
- **App is damaged:** Download a fresh DMG from the official release. If the warning stays, report it.
- **App will damage your computer:** Do not open or override it. Report the warning and the download source.

## Setup says Rosetta is missing or unavailable

1. Choose **Install Rosetta 2…**, or run this in Terminal:

   ```sh
   softwareupdate --install-rosetta --agree-to-license
   ```

2. Restart the Mac and choose **Check Again**.
3. On a macOS 27 beta, turn off Legacy Game Test Mode. See [macOS compatibility](runtime-compatibility.md#legacy-game-test-mode-on-macos-27-beta).

## The download is stuck or fails

1. Wait while the launcher shows **Preparing download** or **Waiting for network…**.
2. Check your connection and the free space on the destination drive.
3. Reopen the launcher and choose **Resume Download**.
4. If one file keeps failing, try later.

Do not move or rename `.part` files or change the installation location during a download.

## A region shows “Not installed”

1. Select the region in **Settings → Installation**.
2. Choose **Installation Location → Locate Existing Installation…** and select the folder that directly contains `Arknights.exe`.
3. If the region still shows **Not installed**, run **Repair…**.

## An update or repair does not finish

When no other download runs, choose **Settings → Installation → Repair…**.

## The game will not start

- **Play is disabled:** Finish the download or pending update.
- **No game window appears:** Quit any leftover Arknights process and try again. If the launcher shows an error code, follow its page.
- **The game closes right away:** After an update, start it once more. If it keeps closing, try another installed region. Then [report the problem](README.md#report-a-problem).

## Sign-in or Notices stay blank

Sign-in by region:

- **Global, Japan, Korea, and China:** a sign-in window inside the game.
- **China (Bilibili):** the login window of Bilibili.
- **Taiwan:** the default browser of your Mac. Look for a new window or tab.

An in-game window can take up to one minute after first start, an update, or cache clearing.

1. Wait one minute. Do not press sign-in again.
2. Check your connection and the Mac date and time.
3. For Global, Japan, Korea, or China: quit the game, choose **Settings → Storage → Clear Caches**, restart.
4. If the window stays blank, [report the problem](README.md#report-a-problem) with the region.

If the window works but your sign-in is rejected or the account is locked, contact your [publisher](README.md#publisher-support-routing).

## The game cannot connect

Allow **Arknights Client** in **System Settings → Privacy & Security → Local Network**, then restart the game. If the account or game service also fails outside the launcher, contact your [publisher](README.md#publisher-support-routing).

## Graphics, window, or performance problems

1. If **Let the launcher size the game** (**Settings → Game → Advanced**) is off, turn it on or change the display settings in the game.
2. Set **Picture** to **Smooth play on big screens** in **Settings → Game**. See [Display](runtime-compatibility.md#display).
3. Pick **Leave room for other apps**, a smaller **Window size**, a lower fullscreen **Detail**, or **Fullscreen** (it can skip a macOS compositing pass).
4. If fullscreen looks grainy, set **Detail** to **Full detail**.

If the cursor lags, turn off VSync in the game. Tearing can occur.

## A launcher update is waiting

Launcher updates wait until the game, a download, or a repair finishes. They never remove game files. After some updates, the first start moves game folders to a new layout. If it reports a conflict, do not delete either folder. See [Storage](storage.md#after-a-launcher-update).

## Advanced diagnostics

Use these only when a maintainer asks. Each applies to one start.

```sh
open "/Applications/Arknights Client.app" --args --graphics-diagnostics
open "/Applications/Arknights Client.app" --args --no-retina
```

- `--graphics-diagnostics` writes detailed graphics logs.
- `--no-retina` starts the game at 1× scaling. It fixes a wrong window size on a Retina display.

To keep 1× scaling:

```sh
defaults write com.lumisxh.arknights-client forceDisableRetina -bool YES
```

Replace `YES` with `NO` to restore the default. Log files are in [Storage](storage.md#logs).
