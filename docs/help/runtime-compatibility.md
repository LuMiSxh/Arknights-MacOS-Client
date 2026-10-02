---
title: macOS compatibility
description: Which Macs and macOS versions can run the game, and what Canary Features change
order: 40
---

# macOS compatibility

Arknights is a Windows game. The launcher runs it through a tested, bundled version of Wine, so you do not need to install Wine, a virtual machine, or Windows.

## macOS support

| macOS       | Status                                                                                                |
| ----------- | ----------------------------------------------------------------------------------------------------- |
| macOS 15–26 | Supported with Rosetta 2                                                                              |
| macOS 27    | Supported with Rosetta 2                                                                              |
| macOS 28    | Blocked by current launcher policy; compatibility with Apple's limited Rosetta support is unconfirmed |

Only Apple silicon Macs are supported. The launcher itself runs natively; Rosetta 2 is needed for the Windows part.

Apple says macOS 27 is the last release with general Rosetta support. Starting with macOS 28, Rosetta remains only for certain older, unmaintained games that rely on Intel frameworks. Apple has not established whether this Wine runtime and game qualify. The launcher currently blocks macOS 28, so this is a policy limit rather than a verified Wine failure. See [Apple's Rosetta support details](https://support.apple.com/en-au/102527) and [developer notice](https://developer.apple.com/news/?id=w5ngl9k2).

If the check reports Rosetta as unavailable even though it is installed, restart the Mac and choose **Check Again** before reinstalling anything.

## Legacy Game Test Mode on macOS 27 beta

Apple documented Legacy Game Test Mode as a beta-only macOS 27 feature. It disables Rosetta and may make non-game processes crash or behave unexpectedly; Apple says the feature is unavailable outside macOS beta releases. The launcher detects the mode when Apple's beta-only `game-test-tool` is available and reports it as a launch blocker.

If you are running a macOS 27 beta with Legacy Game Test Mode enabled, turn it off in Terminal:

```sh
sudo game-test-tool disable
```

Restart the Mac, then choose **Check Again** in the launcher. This command is not a stable macOS troubleshooting step; the tool is unavailable outside beta releases. See Apple's [macOS 27 release notes](https://developer.apple.com/documentation/macos-release-notes/macos-27-release-notes?changes=l_2).

## Canary Features

**Settings → Installation → Canary Features** turns on experimental options. Turning it off again restores the normal behavior without deleting anything.

- **Allow Taiwan client** and **Allow China clients** show the Taiwan, China, and China — Bilibili regions.
- **Frame Latency** (0–3, default 3) can make the cursor feel more responsive at lower values when the runtime supports it. At 0, DXMT waits for the current GPU frame before queuing another; this may significantly reduce FPS or make frame pacing less smooth.
- **Use Hardware Cursor** asks a supporting runtime to hide the game's PRTS cursor so the macOS hardware cursor can appear. The cursor may look different, and the setting applies on the next game launch when supported.

These preferences are saved, but the launcher passes each override only when the packaged runtime advertises that capability. If a capability is absent or unsupported, the runtime keeps its default behavior.

If a Canary option causes a problem, turn it off and mention it in your [report](README.md#report-a-problem).

## Anti-cheat

The Taiwan, China, and China — Bilibili clients use ACE Anti-Cheat. Running them through Wine is unofficial, and the launcher asks you to confirm this before their first start. Your publisher alone decides how it treats accounts that use a third-party launcher.
