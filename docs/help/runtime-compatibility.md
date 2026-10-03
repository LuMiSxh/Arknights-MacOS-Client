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

## Rendering

**Settings → General → Rendering** chooses how the game reaches a Retina display. Every mode applies on the next game launch, and all three look the same on non-Retina displays.

- **Retina** draws every pixel of the display. It is the sharpest mode and needs the most GPU time.
- **MetalFX** draws one pixel per macOS point and lets DXMT upscale each frame 2× with MetalFX spatial scaling. It uses noticeably less GPU time on 4K and larger displays, and text looks slightly softer. A runtime without MetalFX support uses Lightweight instead.
- **Lightweight** draws one pixel per macOS point and lets macOS stretch the window, which looks blurry on Retina displays.

**Window Size** is measured like the "Looks like" sizes in **System Settings → Displays**, so it keeps the same on-screen size in every mode. **Game Resolution** applies to fullscreen and is the resolution the game fills the display at, like the output resolution in other games; with MetalFX or Lightweight the game draws half the width and height and scales the picture up. Both settings' descriptions say what the game draws. **Native**, which setup picks, matches the display with the menu bar pixel for pixel and is read on every launch, so it follows display changes; the other resolutions are the official client's, plus sizes in the display's shape between 4K and a larger display's own resolution. They are scaled to fill the screen, which looks grainy when the display is larger or shaped differently, and sizes larger than the display are hidden. **Let the Launcher Size the Game** is on by default and recommended: the launcher converts the window size into the resolution the game draws, so the picture stays sharp. When it is off, Arknights' own display settings decide, and their resolution counts drawn pixels: with Retina rendering on a 2× display, 2560×1440 opens a 1280×720 window.

**Use Mac Pointer** in the same section shows the macOS pointer instead of the game's PRTS cursor, so the cursor follows the mouse without delay. It looks different from the game cursor, applies on the next game launch, and needs a runtime that supports it.

## Canary Features

**Settings → Installation → Canary Features** turns on experimental options. Turning it off again restores the normal behavior without deleting anything.

- **Allow Taiwan client** and **Allow China clients** show the Taiwan, China, and China — Bilibili regions.
- **Frame Latency** (0–3, default 3) can make the cursor feel more responsive at lower values when the runtime supports it. At 0, DXMT waits for the current GPU frame before queuing another; this may significantly reduce FPS or make frame pacing less smooth.

These preferences are saved, but the launcher passes each override only when the packaged runtime advertises that capability. If a capability is absent or unsupported, the runtime keeps its default behavior.

If a Canary option causes a problem, turn it off and mention it in your [report](README.md#report-a-problem).

## Anti-cheat

The Taiwan, China, and China — Bilibili clients use ACE Anti-Cheat. Running them through Wine is unofficial, and the launcher asks you to confirm this before their first start. Your publisher alone decides how it treats accounts that use a third-party launcher.
