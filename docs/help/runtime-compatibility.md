---
title: macOS compatibility
description: Which Macs and macOS versions can run the game, and what Canary Features change
order: 40
---

# macOS compatibility

Arknights is a Windows game. The launcher runs it through a tested, bundled version of Wine, so you do not need to install Wine, a virtual machine, or Windows.

## macOS support

| macOS       | Status                                                                                  |
| ----------- | --------------------------------------------------------------------------------------- |
| macOS 15–26 | Supported with Rosetta 2                                                                |
| macOS 27    | Supported with Rosetta 2 and [Legacy Game Test Mode](#legacy-game-test-mode) turned off |
| macOS 28    | Blocked, because it no longer offers the Rosetta translation Wine needs                 |

Only Apple silicon Macs are supported. The launcher itself runs natively; Rosetta 2 is needed for the Windows part.

If the check reports Rosetta as unavailable even though it is installed, restart the Mac and choose **Check Again** before reinstalling anything.

## Legacy Game Test Mode

On macOS 27, this test mode turns off the Rosetta translation Wine needs, and the launcher keeps **Play** disabled while it is active. Turn it off in Terminal:

```sh
sudo game-test-tool disable
```

Restart the Mac, then choose **Check Again** in the launcher.

## Canary Features

**Settings → Installation → Canary Features** turns on experimental options. Turning it off again restores the normal behavior without deleting anything.

- **Allow Taiwan client** and **Allow China clients** show the Taiwan, China, and China — Bilibili regions.
- **Frame Latency** (1–3, default 3) can make the cursor feel more responsive at lower values, but may reduce the frame rate.

If a Canary option causes a problem, turn it off and mention it in your [report](README.md#report-a-problem).

## Anti-cheat

The Taiwan, China, and China — Bilibili clients use ACE Anti-Cheat. Running them through Wine is unofficial, and the launcher asks you to confirm this before their first start. Your publisher alone decides how it treats accounts that use a third-party launcher.
