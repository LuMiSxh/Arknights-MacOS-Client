---
title: Performance
description: What affects CPU, GPU, memory, and power, and how the client compares with PlayCover
order: 15
---

# Performance

Arknights Client runs the official Windows game on Apple silicon Macs. This page explains what
affects CPU, GPU, memory, and power, and how the client compares with PlayCover.

How the launcher runs the game is described in
[Launch and process lifecycle](development/architecture/launch-and-process-lifecycle.md#launch-process).

## What affects performance

- **Rendering**: **Retina** draws every display pixel. **MetalFX** draws one pixel per macOS point
  and upscales. **Standard** draws one pixel per point and lets macOS stretch the window.
- **Resolution**: A higher resolution increases GPU load.
- **Window size**: A window that covers one third of the screen draws fewer pixels than fullscreen.
- **Frame limit**: A higher limit increases CPU and GPU load.
- **Thermals**: A hot Mac reduces clock speed. Keep the power adapter connected and Low Power Mode
  off. The MacBook Neo has no fan, so a long session gets warm.
- **Memory**: The game lists 8 GB of RAM. On an 8 GB Mac such as the MacBook Neo, macOS and the game
  share it. Close other apps.
- **Other apps**: Messages, Safari, and other apps compete for CPU, GPU, and memory. Close them before
  you compare.
- **Scene**: A busy stage uses more CPU and GPU than a menu.

## Comparison

Measured on an Apple M4 with 16 GB of memory and macOS 27. Both clients played LS-5 with
auto-deploy at 60 FPS in a 1280 × 800 window. Each line is one run of 60 seconds. 100 % is one CPU
core, so a 10-core Mac can show up to 1000 %.

```chart
{
  "src": "/benchmarks/comparison.json",
  "mode": "stats",
  "title": "At a glance"
}
```

```chart
{
  "src": "/benchmarks/comparison.json",
  "metric": "cpu_percent",
  "title": "CPU use",
  "unit": "% of one core",
  "caption": "Lower is better. 100 % is one CPU core."
}
```

```chart
{
  "src": "/benchmarks/comparison.json",
  "metric": "gpu_device_percent",
  "title": "GPU use",
  "unit": "%",
  "caption": "Lower is better. MetalFX trades sharpness for GPU time."
}
```

In this run, Arknights Client used about three times the CPU and 2.6 times the GPU of PlayCover.
**MetalFX** rendering cut the GPU load to 45 % by drawing a quarter of the pixels. The CPU cost
stayed at about 2.7 times, because the translation happens on every frame.

The two clients are different builds: PlayCover runs the mobile build natively, Arknights Client
runs the PC build through Wine, Rosetta 2, and DXMT.

> [!NOTE]
> These numbers come from one controlled setup. The 1280 × 800 window is one fixed size, and most
> players use fullscreen or a different size. The test Mac also drives a 6K display, and macOS
> composites that desktop while the game runs in a window. Part of the measured load is therefore
> not the game. Your own numbers will differ.

## Why the PC client needs more

The PC client is a desktop build. It costs more CPU and GPU than the mobile build, and it gives more
in return.

### What you get

- **Higher-resolution assets.** The PC version ships with higher-resolution artwork, so the game
  looks sharper overall.
- **A larger screen with your own settings.** You choose the resolution, the window mode, and the
  frame rate. The mobile build follows the device screen.
- **Native keyboard and mouse.** The PC client reads the mouse and keyboard directly, and it has
  shortcuts for common actions. PlayCover emulates touch from the mouse instead.

### What it costs

- **Disk space.** The PC install is 30 GB. The iOS app is 3.3 GB.
- **Memory.** The larger assets stay in memory. In the test, the PC client held about 1.9 GB against
  1.5 GB for PlayCover.
- **Translation.** The PC build is x86-64 and uses Direct3D 11. Rosetta 2 translates the
  instructions to arm64, and DXMT translates the graphics calls to Metal. PlayCover runs the mobile
  build natively and skips both steps.

Both clients ran at 60 FPS and drew about the same number of pixels, so the measured difference
comes from the assets and the translation, not from a higher frame rate or a larger render target.

## Ongoing work

These numbers are a snapshot. Arknights Client, its bundled runtime, Wine, and DXMT are all under
active development. Performance work continues in all four projects, so expect the numbers to change
with future releases.

The measurement method and the full metric list are in
[Performance comparison with PlayCover](development/performance-comparison.md).

## Report a performance problem

If the game stutters, overheats, or uses too much memory, open **Settings → About → Report…**. Add
the scene, display settings, macOS version, chip, and memory size. See [Help](help/README.md).
