---
title: Performance comparison with PlayCover
description: Measure CPU, GPU, memory, and frame time for the Windows client and an iOS client
order: 25
audience: developers
---

# Performance comparison with PlayCover

This page defines the measurement method. The user-facing summary is in
[Performance](../performance.md).

> [!IMPORTANT]
> Both sides must draw the same number of pixels and show the same frame rate. A run that breaks this
> rule is not comparable, whatever the numbers say.

## What to measure

| Metric             | Unit                   | Why it matters                         |
| ------------------ | ---------------------- | -------------------------------------- |
| CPU time           | percent of one core    | Shows translation and game logic cost  |
| System CPU         | percent of one core    | Shows total machine load               |
| Background CPU     | percent of one core    | Shows noise from other apps            |
| Display and window | pixels, points, bounds | Shows how many pixels the game draws   |
| GPU utilization    | percent                | Shows renderer load                    |
| Resident memory    | MiB                    | Shows memory pressure                  |
| Frame time         | milliseconds           | Shows smoothness, not only average FPS |
| 1% low             | milliseconds           | Shows stutter                          |
| Startup time       | seconds                | Shows launch and shader cost           |
| Disk use           | GiB                    | Shows install and cache size           |
| Energy             | watt or joule          | Shows battery and heat cost            |
| Thermal limit      | percent                | Shows throttling                       |
| Stability          | crashes per hour       | Shows practical quality                |

Use the same scene, resolution, display mode, and duration for both options. A stage with autodeploy
or the base screen is better than a menu.

## Fair test rules

1. Use one Mac. Record the model, chip, memory, macOS version, and power source.
2. Connect the power adapter. Disable Low Power Mode. Close other apps. The harness records system
   CPU and the top background processes, but it cannot remove their effect.
3. Set the same drawn pixel count and render scale. On a Retina display, record whether each option
   draws every pixel. Record the window bounds.
4. Set the same frame limit. If one option cannot limit frames, record the difference.
5. Restart the game before each run. Warm up for at least 60 seconds.
6. Record at least two runs for each option. Add a third when the A/A difference is close to the
   difference between the options.
7. Run an A/A control first. The difference between two runs of the same option is your noise floor.
8. Keep the scene identical. Do not move the camera or open menus during a run.
9. Record the client version, runtime version, PlayCover version, and PlayTools version.
10. Store raw samples. Do not report only a summary.

## Launcher settings to pin

Set these values before you measure and record them in the manifest note.

| Setting               | Baseline value | Why it changes the result                                                           |
| --------------------- | -------------- | ----------------------------------------------------------------------------------- |
| Display mode          | Windowed       | Both clients use the same window. There is no fullscreen or compositor difference.  |
| Window size           | 1280 × 800     | 16:10. The launcher and PlayCover both count window size in points.                 |
| Rendering             | Retina         | Draws every backing pixel. PlayCover uses resolution scaler 2 for the same result.  |
| Drawn pixels          | 2560 × 1600    | Read it in **Render resolution**. It is the number that makes two runs comparable.  |
| In-game override      | On             | Off leaves the size to the game's own settings. The iOS client has no equal option. |
| Wine sync             | MSYNC          | MSYNC and ESYNC take different wait paths. ESYNC can change frame pacing.           |
| Metal Performance HUD | Off            | The overlay adds work. Turn it on only to cross-check the frame rate by eye.        |

**Settings → Game → Advanced → Render resolution** shows the pixels the game draws. With Retina on
a 2× display it is twice the window size in each direction. Read the shown value and compare it with
PlayCover's window points × scaler. The window size alone does not make two runs comparable.

The launcher has no frame limit option. The in-game setting is the only control. Set the same value
in both clients and record it.

Three settings have no equal on the other side. Note them, but do not try to match them:

- **Cursor.** **macOS** uses a hardware cursor. **Game** keeps the game's own cursor. The hardware
  cursor needs runtime support, so record the runtime version.
- **Game Mode.** The launcher calls Apple's `gamepolicyctl`, which PlayCover does not use. macOS can
  still enable Game Mode for a fullscreen app on its own. Record the menu bar state.
- **MetalFX.** PlayCover renders natively and has no upscaling option.

### PlayCover equivalents

PlayCover has no **Rendering** menu. Its resolution scaler sets the backing scale that the game
sees, so it is the same control. PlayTools computes `nativeBounds = bounds × scaler`.

| Arknights Client | PlayCover             | Drawn pixels      |
| ---------------- | --------------------- | ----------------- |
| Retina           | Resolution scaler `2` | window points × 2 |
| Standard         | Resolution scaler `1` | window points × 1 |
| MetalFX          | No equivalent         | window points × 1 |

Set **Resolution** to **Custom**. **Auto** uses the whole display frame, so the scaler multiplies the
screen size and not the window. The window then shows a much larger render scaled down, and the run
is not comparable.

PlayCover scales the configured window by 0.77 on this Mac (`UINSLastUsedWindowScaleFactor`). The
**1080p** preset with **16:10** therefore opens at 1330 × 831 points and draws 2660 × 1662 pixels.
The client draws 2560 × 1600. The difference is 3.9 percent per axis. Record it. Do not compensate
with a custom size, because the factor is a saved value and can change.

## Variants worth measuring

After the baseline, these runs answer questions that users ask:

1. **Retina at native fullscreen.** This is the pixel ceiling. It shows where each renderer runs out
   of headroom.
2. **Retina, MetalFX, and Standard at one drawn size.** This shows the image quality and GPU cost
   trade-off inside Arknights Client alone.
3. **MSYNC and ESYNC on the same scene.** This shows whether frame pacing or CPU time changes.

## Harness

`just benchmark sample` samples the process tree once per second. It records CPU, GPU, memory,
thermal limit, power source, system CPU, background CPU, and the top background processes. It also
stores display pixels, display points, window bounds, and the foreground app in `manifest.json`.
It writes JSON and CSV files under `.build/benchmarks/`.

```sh
just benchmark sample client-menu-30s 30 arknights-client "Main menu, 1280x800 Retina, 2560x1600 drawn, 60 FPS"
just benchmark sample client-ls5-60s 60 arknights-client "LS-5 autodeploy 2x, 1280x800 Retina, 2560x1600 drawn, 60 FPS"
just benchmark sample playcover-menu-30s 30 playcover "Main menu, 1080p 16:10, 1330x831 scaler 2, 60 FPS"
just benchmark sample playcover-ls5-60s 60 playcover "LS-5 autodeploy 2x, 1080p 16:10, 1330x831 scaler 2, 60 FPS"
just benchmark compare .build/benchmarks/client-ls5-60s-... .build/benchmarks/playcover-ls5-60s-...
```

Wine reports Windows paths as process names, so the client patterns match a suffix such as
`Arknights.exe`. Check `process_count` in `summary.json`: a client run that reports 2 processes
measured the runtime wrapper only, not the game.

Limits:

- GPU utilization is system-wide. It is not per process.
- Resident memory counts shared pages. It is not a private footprint.
- CPU percent uses 100 percent for one core. A 10-core Mac can show up to 1000 percent.
- The harness does not record frame time.

## Frame time and energy

Use `metalperftrace` on macOS 27 or newer. The runtime repository has
`just frametime-record CASE SECONDS`. Record at least 60 seconds, three times. Report the median,
the 95th percentile, and the 1% low. Do not compare average FPS alone.

`powermetrics` gives CPU and GPU power. It needs root:

```sh
sudo powermetrics --samplers cpu_power,gpu_power -i 1000 -n 60
```

Run it for the same window as the harness. Record `pmset -g therm` before and after the run.

## Confounders

- Rosetta 2 translation cost changes with the instruction mix. A CPU-bound scene shows it more than
  a GPU-bound scene.
- DXMT is not a native Metal renderer. Shader translation, state changes, and synchronization add
  cost.
- PlayCover injects PlayTools into the game process. The injection has a cost, but it is small
  compared with translation.
- The iOS and Windows clients are different builds. They can differ in texture resolution, effects,
  and frame pacing.
- The iOS client can pause when it is not frontmost. The Windows client through Wine can keep
  running. Do not compare a paused app with a running app.
- Anti-cheat behavior differs. A bypass can change behavior and cost.
- Thermal throttling can hide a difference. Run the same order for both options, or randomize the
  order.
- Memory pressure can change results. Record free memory and swap.
- A Retina display multiplies the pixel count. Record the render scale, not only the window size.
- The baseline window is one fixed size. Most players use fullscreen or another size, so the result
  describes a controlled comparison, not a typical setup.
- The test display is 6016 × 3384. macOS composites that desktop while the game runs in a window, so
  system CPU, background CPU, and GPU include work that is not the game. Compare two clients on one
  display. Do not compare absolute values across displays.

## Report template

| Metric                               | Arknights Client | PlayCover | Delta |
| ------------------------------------ | ---------------: | --------: | ----: |
| CPU, mean (% of one core)            |                  |           |       |
| CPU, p95 (% of one core)             |                  |           |       |
| System CPU, mean (% of one core)     |                  |           |       |
| Background CPU, mean (% of one core) |                  |           |       |
| GPU, mean (%)                        |                  |           |       |
| Resident memory, mean (MiB)          |                  |           |       |
| Frame time, median (ms)              |                  |           |       |
| Frame time, 1% low (ms)              |                  |           |       |
| Startup time (s)                     |                  |           |       |
| Disk use (GiB)                       |                  |           |       |
| Package power, mean (W)              |                  |           |       |
| Crashes per hour                     |                  |           |       |
| Display (pixels, points)             |                  |           |       |
| Window bounds                        |                  |           |       |

Add the machine, macOS version, client versions, scene, resolution, render scale, frame limit,
window bounds, foreground app, top background processes, and run count below the table.

## Charts

`just benchmark export BASELINE CANDIDATE OUTPUT` writes a dataset for the website. Put the output
under `web/static/benchmarks/`. Add a `chart` block to [Performance](../performance.md) with the
dataset path. The chart plots the sample index, so both runs share one x axis.

The runtime, Wine, and DXMT change often. Re-run the baseline after an update. Do not compare a new
client build against an old dataset, because the runtime moves with it.

## References

- [Runtime compatibility](../help/runtime-compatibility.md)
- [Testing architecture](testing.md)
- [DXMT](https://github.com/3Shain/dxmt)
- [PlayCover](https://github.com/PlayCover/PlayCover)
- [PlayTools](https://github.com/PlayCover/PlayTools)
- [Apple Rosetta](https://support.apple.com/102527)
