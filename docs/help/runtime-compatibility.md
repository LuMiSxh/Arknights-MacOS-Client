---
title: macOS compatibility
description: Supported macOS versions, display settings, and Canary Features
order: 40
---

# macOS compatibility

The launcher runs the Windows game through a bundled Wine. You need no Wine, virtual machine, or Windows.

## macOS support

| macOS       | Status                                                                                                |
| ----------- | ----------------------------------------------------------------------------------------------------- |
| macOS 15–26 | Supported with Rosetta 2                                                                              |
| macOS 27    | Supported with Rosetta 2                                                                              |
| macOS 28    | Blocked by current launcher policy; compatibility with Apple's limited Rosetta support is unconfirmed |

Only Apple silicon Macs work. The launcher runs natively; the Windows part needs Rosetta 2.

Apple says macOS 27 is the last release with general Rosetta support. From macOS 28, Rosetta stays only for some older games that use Intel frameworks. Apple has not said if this runtime qualifies. The launcher blocks macOS 28 by policy, not because of a verified failure. See Apple's [Rosetta details](https://support.apple.com/en-au/102527) and [developer notice](https://developer.apple.com/news/?id=w5ngl9k2).

If the check reports Rosetta as unavailable but it is installed, restart the Mac and choose **Check Again**.

## Legacy Game Test Mode on macOS 27 beta

Legacy Game Test Mode exists only in the macOS 27 beta. It disables Rosetta and can crash non-game processes. The launcher detects it through Apple's `game-test-tool` and blocks the launch.

Turn it off in Terminal:

```sh
sudo game-test-tool disable
```

Restart the Mac, then choose **Check Again**. See Apple's [macOS 27 release notes](https://developer.apple.com/documentation/macos-release-notes/macos-27-release-notes?changes=l_2).

## Display

**Settings → Game → Display** changes apply at the next launch.

**Picture** sets how the game reaches a Retina display. It has no effect on other displays.

| Choice                         | Mode        | Behavior                                                                                                                                                                                                        |
| ------------------------------ | ----------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **The sharpest picture**       | Retina      | Draws every display pixel. Sharpest. Needs the most GPU time.                                                                                                                                                   |
| **Smooth play on big screens** | MetalFX     | Draws one pixel per macOS point. DXMT upscales each frame 2× with MetalFX spatial scaling. Needs much less GPU time on 4K and larger displays. Softer text. A runtime without MetalFX uses Longer battery life. |
| **Longer battery life**        | Lightweight | Draws one pixel per macOS point. macOS stretches the window. Blurry on Retina displays.                                                                                                                         |

**Window size** uses the "Looks like" sizes of **System Settings → Displays**. **Fill my screen** fills the usable screen area with the title bar visible. **Leave room for other apps** picks a smaller 16:9 window. The menu also lists exact sizes.

**Detail** sets the fullscreen resolution. With Smooth play or Longer battery life, the game draws half the width and height, then scales up.

- **Full detail** matches the display pixel for pixel, with the menu bar. Setup picks it. It follows display changes.
- **Balanced** and **Lighter** use up to 1440p and 1080p.
- **Exact resolution** lists the sizes of the official client and sizes in the display shape between 4K and the native resolution.

Lower resolutions scale to fill the screen and look grainy on larger or differently shaped displays. Sizes larger than the display are hidden.

**Pointer** set to **Your Mac's pointer** shows the macOS pointer instead of the PRTS cursor, so the cursor follows the mouse without delay. It needs runtime support.

**Settings → Game → Advanced** shows the exact size the game draws. **Let the launcher size the game** is on by default. Keep it on: the launcher converts the window size into the game resolution, so the picture stays sharp. When it is off, the display settings of Arknights decide and count drawn pixels. Example: with the sharpest picture on a 2× display, 2560×1440 opens a 1280×720 window.

## Canary Features

**Settings → Installation → Canary Features** turns on experimental options. Turning it off restores normal behavior and deletes nothing.

- **Allow Taiwan region** shows the Taiwan region.

If a Canary option causes a problem, turn it off and mention it in your [report](README.md#report-a-problem).

## Anti-cheat

The Taiwan, China, and China (Bilibili) clients use ACE Anti-Cheat. Running them through Wine is unofficial. The launcher asks you to confirm this before the first start. Your publisher alone decides how it treats accounts that use a third-party launcher.
