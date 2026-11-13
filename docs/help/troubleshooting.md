---
title: Troubleshooting
description: Fixes for launcher, sign-in, graphics, and start problems
order: 20
---

# Troubleshooting

> [!IMPORTANT]
> Do not delete the game environment (Wine prefix) or the game folder first. Deleting the game environment signs you out. Deleting the game folder forces a new download.

## The launcher shows an error code

See [Error codes](errors/README.md) for codes such as `IN-DLD`.

## The launcher will not open

- **Cannot verify the developer, or cannot check for malicious software:** Confirm you downloaded the app from [the official GitHub release](https://github.com/LuMiSxh/Arknights-MacOS-Client/releases/latest). Then follow [Apple’s Open Anyway steps](https://support.apple.com/en-au/102445): in **System Settings → Privacy & Security**, choose **Open Anyway**, then **Open**.
- **App is damaged:** Download a fresh DMG from the official release. If the warning stays, report it.
- **App will damage your computer:** Do not open or override it. Report the warning and the download source.

## Setup says Rosetta is missing or unavailable

Follow [Rosetta 2](runtime.md#rosetta-2). On a macOS 27 beta, also turn off [Legacy Game Test Mode](runtime.md#legacy-game-test-mode-on-macos-27-beta). On macOS 28 or later, choose [ARM64](runtime.md#macos-support).

## The download is stuck or fails

1. Wait while the launcher shows **Preparing download** or **Waiting for network…**.
2. Check your connection and the free space on the destination drive.
3. Reopen the launcher and choose **Resume**.
4. If one file keeps failing, try later.

Do not move or rename partly downloaded files or change the installation location during a download.

## A server shows “Not installed”

1. Select the server in **Settings → Installation**.
2. Choose **Settings → Installation → Location → Change… → Locate Existing Installation…** and select the folder that directly contains `Arknights.exe`.
3. If the server still shows **Not installed**, run **Repair**.

## An update or repair does not finish

When no other download runs, choose **Settings → Installation → Repair**.

## The game will not start

- **Play is disabled:** Finish the download or pending update.
- **No game window appears:** Quit any leftover Arknights process and try again. If the launcher shows an error code, follow its page.
- **The game closes right away:** After an update, start it once more. If it keeps closing, try another installed server. Then [report the problem](README.md#report-a-problem).

## Sign-in or Notices stay blank

Sign-in opens in a different place by server:

- **Global, Japan, Korea, and China:** a sign-in window inside the game.
- **China (Bilibili):** the login window of Bilibili.
- **Taiwan:** the default browser of your Mac. Look for a new window or tab.

An in-game window can take up to one minute after first start, an update, or cache clearing.

1. Wait one minute. Do not press sign-in again.
2. Check your connection and the Mac date and time.
3. For Global, Japan, Korea, or China, quit the game. Choose **Settings → Storage → Clear Caches**, then restart.
4. If the window stays blank, [report the problem](README.md#report-a-problem) with the server.

If the window works but your sign-in is rejected or the account is locked, contact your [publisher](README.md#publisher-support-routing).

## The game cannot connect

Allow **Arknights Client** in **System Settings → Privacy & Security → Local Network**, then restart the game. If the account or game service also fails outside the launcher, contact your [publisher](README.md#publisher-support-routing).

## Graphics, window, or performance problems

1. If **Override in-game display settings** (**Settings → Game → Display**) is off, turn it on. You can also change the display settings in the game.
2. Set **Rendering** to **MetalFX** in **Settings → Game → Display**. See [Display](display.md#display).
3. Pick **Compact**, a smaller **Window size**, a lower fullscreen **Resolution**, or **Fullscreen**. Fullscreen can skip a macOS compositing pass.
4. If fullscreen looks grainy, set **Resolution** to **Native**.

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

## Runtime patches

Use **Runtime patches** only when a maintainer asks, or when a problem started after a runtime update. Each switch turns off one fix that the runtime applies to Wine.

1. Quit the game. The switches stay locked while the game runs.
2. Open **Settings → Runtime → Runtime patches**.
3. Turn off one switch and confirm the warning.
4. Start the game and check whether the problem is gone.

The game may break or behave differently with a patch off. To undo a change, turn the switch back on. **Restore Defaults** turns every patch back on. The list shows only the patches that your runtime contains.

## Debug logging

Use **Debug logging** when a maintainer asks for detailed logs. Turn it on in **Settings → Help → Troubleshooting**.

The next game start writes detailed Wine and graphics logs. Logs grow quickly. Turn **Debug logging** off when you are done.
