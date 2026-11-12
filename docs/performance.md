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

## Summary

- The ARM64 runtime uses about 43 % less CPU and about half the GPU of the x86_64 runtime in LS-5.
- ARM64 still uses about 1.7 times the CPU and 1.3 times the GPU of PlayCover in LS-5.
- In the main menu, ARM64 CPU use is close to PlayCover. Its GPU use is lower.
- ARM64 uses more memory: about 2.2 GB in the menu and 2.5 GB in LS-5.
- Your numbers will differ.

| | CPU, LS-5 | GPU, LS-5 | CPU, menu | GPU, menu |
|---|---|---|---|---|
| Arknights Client, ARM64 | 85 % | 38 % | 74 % | 38 % |
| Arknights Client, x86_64 | 150 % | 74 % | 113 % | 70 % |
| PlayCover | 49 % | 28 % | 67 % | 42 % |

The table shows mean values from the measured runs. CPU 100 % means one CPU core.
A 10-core Mac can show up to 1000 %. Lower is better for CPU and GPU.

## Comparison

Measured on an Apple M4 with 16 GB of memory. The x86_64 and PlayCover runs are from 23 October
2026 on macOS 27.0.1. The ARM64 run is from 12 November 2026 on macOS 27.2.1.
Every client played LS-5 with auto-deploy in a 1280 × 800 window.
Each LS-5 run lasted about 60 seconds. Every run used 60 FPS, except the MetalFX run, which used a 120 FPS cap.

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

With the ARM64 runtime, Arknights Client used about 1.7 times the CPU and 1.3 times the GPU of
PlayCover. Compared with the x86_64 runtime, ARM64 used about 43 % less CPU.
ARM64 used about half the GPU time.

With the x86_64 runtime, Arknights Client used about three times the CPU and 2.6 times the GPU of
PlayCover. **MetalFX** rendering cut the GPU load to 45 % by drawing a quarter of the pixels.
The CPU cost stayed at about 2.7 times, because the translation happens on every frame.

The clients are different builds.
PlayCover runs the mobile build natively.
Arknights Client runs the PC build through Wine and DXMT.
The x86_64 runtime translates the whole game and Wine with Rosetta 2.
The ARM64 runtime runs Wine natively and translates only the game code with FEX.

> [!NOTE]
> The x86_64 runs are a few weeks older and used an older DXMT. Part of the gap may come from that
> update, not only from the runtime.

## Main menu

A menu draws less than a stage.
The x86_64 gap stays in the menu, so most of it does not come from the scene.
With ARM64, CPU use is close to PlayCover, and GPU use is lower.
Measured on the same Mac, each client stood in the main menu for 30 seconds.

```chart
{
  "src": "/benchmarks/main-menu.json",
  "mode": "stats",
  "title": "Main menu at a glance"
}
```

```chart
{
  "src": "/benchmarks/main-menu.json",
  "metric": "cpu_percent",
  "title": "Main menu CPU use",
  "unit": "% of one core",
  "caption": "Lower is better. 100 % is one CPU core."
}
```

> [!NOTE]
> These numbers come from one controlled setup. The 1280 × 800 window is one fixed size.
> Most players use fullscreen or a different size. The test Mac also drives a 6K display.
> macOS composites that desktop while the game runs in a window. Part of the measured load is
> therefore not the game. Your own numbers will differ.

## Why the PC client needs more

The PC client is a desktop build. It costs more CPU, GPU, memory, and disk than the mobile build.
It also gives more in return. Not all of the extra cost comes from translation.

### What you get

- **Higher-resolution assets.** The PC version ships with higher-resolution artwork. The game
  looks sharper overall.
- **A larger screen with your own settings.** You choose the resolution, the window mode, and the
  frame rate. The mobile build follows the device screen.
- **Native keyboard and mouse.** The PC client reads the mouse and keyboard directly. It has
  shortcuts for common actions. PlayCover emulates touch from the mouse instead.

### What it costs

- **The build itself.** The PC install is 30 GB, against 3.3 GB for the iOS app.
  It also keeps the larger artwork in memory: about 1.9 GB, against 1.5 GB in the test.
  This cost exists on Windows too, without Rosetta, Wine, or DXMT.
  The ARM64 runtime uses more on top: about 2.2 GB in the menu and 2.5 GB in LS-5.
- **CPU.** Rosetta 2 or FEX translates every game instruction. Wine handles every Windows call.
  Neither step exists for the mobile build.
  That is why the CPU gap appears in the menu too, where the scene draws almost nothing.
  The ARM64 runtime runs Wine itself natively. So less of the work is translated.
- **GPU.** The game sends Direct3D 11 calls. DXMT translates them to Metal.
  The larger PC assets fill more pixels for the same scene.
  **MetalFX** reduces this part. It draws fewer pixels and upscales each frame.

Apart from the MetalFX run, all clients ran at 60 FPS and drew about the same number of pixels.
The measured difference therefore comes from the build and the translation.
It does not come from a higher frame rate or a larger render target.

## What affects performance

These settings and habits change the load on your Mac.

- **Rendering**: **Retina** draws every display pixel. **MetalFX** draws one pixel per macOS point
  and upscales. **Standard** draws one pixel per point and lets macOS stretch the window.
- **Resolution**: A higher resolution increases GPU load.
- **Window size**: A window that covers one third of the screen draws fewer pixels than fullscreen.
- **Frame limit**: A higher limit increases CPU and GPU load.
- **Thermals**: A hot Mac reduces clock speed. Keep the power adapter connected. Keep **Low Power
  Mode** off. The MacBook Neo has no fan, so a long session gets warm.
- **Memory**: The game lists 8 GB of RAM. On an 8 GB Mac such as the MacBook Neo, macOS and the game
  share that memory. Close other apps.
- **Other apps**: Messages, Safari, and other apps compete for CPU, GPU, and memory. Close them
  before you compare.
- **Scene**: A busy stage uses more CPU and GPU than a menu.

## Ongoing work

These numbers are a snapshot. Arknights Client, its runtime, Wine, and DXMT are all under active
development. Performance work continues in all four projects. Expect the numbers to change with
future releases.

The measurement method and the full metric list are in
[Performance comparison with PlayCover](development/performance-comparison.md).

## Report a performance problem

If the game stutters, overheats, or uses too much memory, open **Settings → Help → Report a Problem…**. Add
the scene, display settings, macOS version, chip, and memory size. See [Help](help/README.md).
