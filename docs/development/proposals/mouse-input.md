---
title: Mouse responsiveness investigation
description: Evidence and diagnostic next steps for the in-game cursor report in issue 84
order: 30
hidden: true
audience: developers
---

# Mouse responsiveness investigation

Status: A local instrumented A/B run confirms that Frame Latency 1 reaches DXMT and actively
shortens the queue. Canary exposes values 0–3 with default 3. Value 0 waits for the current GPU
frame to complete before queuing more work; it does not mean zero input-to-display latency. The
client now has an off-by-default Hardware Cursor Canary option that asks the runtime to hide the
game-rendered PRTS cursor. A matching Wine patch is required for the option to take effect, and its
effect on cursor appearance and responsiveness remains unverified. No further diagnostic work is
requested from the original reporter, and no fix for #84 is confirmed.

Investigated on 2026-09-26 against client
`3d5417987d9f375a2105a4a7cd2e62659730c9cd`, the published `v0.6.0` tag.
Related reports: [#84](https://github.com/LuMiSxh/Arknights-MacOS-Client/issues/84),
[#88](https://github.com/LuMiSxh/Arknights-MacOS-Client/issues/88), and
[#34](https://github.com/LuMiSxh/Arknights-MacOS-Client/issues/34).

## Findings

The report initially did not distinguish reduced movement speed from delayed presentation of the
game cursor. These require different interventions. A sensitivity control changes the settled
distance travelled; a frame-latency control changes how long rendered feedback can remain queued.

At the time of the report, launcher v0.6.0 provided a Canary **Frame Latency** setting with values
1–3 and default 3. The reporter compared 1 with 3 and saw no visible difference. This rules out that
control as a useful workaround on the reported M1 configuration, but does not prove that the
runtime ignored it or that presentation contributes no latency.

The leading hypothesis is now the game's software cursor and presentation path. The client and
runtime contain no cursor-speed control, and the existing frame-latency experiment never changes
mouse input. The new Hardware Cursor option requests hiding the PRTS cursor so the Wine/macOS
hardware pointer can appear; it does not change mouse speed or coordinate handling. A separate
sensitivity or coordinate mismatch remains possible, but the report does not yet establish one: a
delayed software cursor also appears to travel less distance while the physical pointer is still
moving.

A local instrumented Global-client comparison on 2026-09-27 found a small subjective improvement
at Frame Latency 1. At value 3, 8,100 command-queue fence samples waited 6.816 ms in total, averaging
0.84 microseconds with a 64-microsecond maximum. At value 1, 6,300 samples waited 35.057 seconds in
total, averaging 5.56 ms with a 32.55-ms maximum. This confirms that the setting reaches the active
queue and that value 1 limits frames in flight on this machine. It does not measure input-to-display
latency or establish that the same change helps the reporter.

## Reporter follow-up

The reporter tested launcher v0.6.0 on an M1 Mac with macOS 26.6 and the built-in trackpad. They
described both apparently shorter travel and slower arrival, with no visible difference between
Frame Latency 1 and 3. They had not tested VSync because the request did not make clear that it is
an in-game option rather than a launcher option. A follow-up now asks for that single comparison
while stating that investigation of possible solutions continues independently.
[Follow-up](https://github.com/LuMiSxh/Arknights-MacOS-Client/issues/84#issuecomment-5847382326).

The later comment linking a Windows workaround came from a different user, not the original
reporter. It adds independent evidence but does not answer the requested VSync comparison.

Independent reports point in the same direction. The earlier project report #34 was reproduced
locally and said similar behavior occurs on Windows. A Linux/Wine player separately described the
PRTS cursor lagging behind the native cursor and reported that disabling in-game VSync made the
remaining lag difficult to notice. Windows players also describe the official PC client's software
cursor as sluggish and affected by VSync. These community observations are not controlled
measurements, but make a Mac-trackpad-only fault less likely.
Sources: [Linux/Wine report](https://www.reddit.com/r/arknights/comments/1w23wg6/tech_help_linux_user_here_is_there_a_way_to/),
[Windows discussion](https://www.reddit.com/r/arknights/comments/1vnlhfo/arknights_pc_version_has_completely_changed_how/).

A later Windows report identifies the cursor asset used by the game and says removing it exposes
the smooth hardware pointer while eliminating transition-time cursor freezes. Several replies
independently report the same result, including removal of apparent acceleration. This is stronger
evidence that the PRTS cursor presentation itself contributes to the symptom, but the workaround is
not suitable for the launcher: it deliberately modifies a game asset, makes the official launcher
report a corrupted installation, and requires bypassing that launcher.
Source: [Windows software-cursor workaround](https://www.reddit.com/r/arknights/comments/1vorlzp/pc_client_fix_for_the_annoying_mouse_stuttering/).

## Previous report and release history

In issue #34, the reporter attributed the duplicate cursor to the screen recorder and reported
that disabling in-game VSync reduced the remaining delay, with tearing as a tradeoff.
The maintainer subsequently described a game-rendered cursor and announced a Canary change
for v0.5. These observations concern the earlier report; they do not establish the cause on
the machine described in #84.
Sources: [reporter observations](https://github.com/LuMiSxh/Arknights-MacOS-Client/issues/34#issuecomment-5372200891),
[maintainer investigation](https://github.com/LuMiSxh/Arknights-MacOS-Client/issues/34#issuecomment-5373826181),
[Canary announcement](https://github.com/LuMiSxh/Arknights-MacOS-Client/issues/34#issuecomment-5517395053).

The [changelog](../../../CHANGELOG.md) records a one-to-three-frame DXMT latency control in
v0.5.0. It separately records an experimental runtime-performance toggle in v0.5.2 and its
removal in v0.6.0, explicitly preserving the frame-latency control. The
[compatibility guide](../../help/runtime-compatibility.md#canary-features) still describes
Frame Latency, while the [troubleshooting guide](../../help/troubleshooting.md#graphics-window-or-performance-problems)
documents the VSync workaround. The statement in #84 that an earlier change did not reach
production therefore needs to be reconciled with these two distinct controls.

## Client evidence

In released v0.6.0, open **Settings → Installation**, enable **Canary Features**, and use
**Frame Latency** in the same panel. Quit the game before changing it: the control is disabled
while a game is active, and its help text states that it applies on the next launch.
The setting is stored in `LauncherPreferencesStore.maximumFrameLatency`, defaults to `3`,
and clamps reads and writes to `1...3`.
Sources: [settings control](https://github.com/LuMiSxh/Arknights-MacOS-Client/blob/3d5417987d9f375a2105a4a7cd2e62659730c9cd/Sources/ArknightsClient/Features/Launcher/Settings/InstallationSettingsPage%2BCanary.swift#L31-L58),
[preferences](https://github.com/LuMiSxh/Arknights-MacOS-Client/blob/3d5417987d9f375a2105a4a7cd2e62659730c9cd/Sources/ArknightsClient/Shared/Persistence/LauncherPreferencesStore.swift#L238-L245).

`GameSessionController.runtimeEnvironmentOverrides` emits
`ARKNIGHTS_RUNTIME_DXMT_MAX_FRAME_LATENCY` only with Canary enabled. `WineRuntime.launch`
merges the override into the environment passed to the game process. This is not limited
to a Canary game region. The current client does not expose a pointer-speed or VSync control.
Sources: [override construction](https://github.com/LuMiSxh/Arknights-MacOS-Client/blob/3d5417987d9f375a2105a4a7cd2e62659730c9cd/Sources/ArknightsClient/Features/Game/Runtime/GameSessionController%2BLaunch.swift#L6-L20),
[environment propagation](https://github.com/LuMiSxh/Arknights-MacOS-Client/blob/3d5417987d9f375a2105a4a7cd2e62659730c9cd/Sources/ArknightsClient/Features/Game/Runtime/WineRuntime.swift#L223-L275).

Client commit [`d33556f`](https://github.com/LuMiSxh/Arknights-MacOS-Client/commit/d33556f9b27906a74e52ba95863abfee06a61310)
introduced the latency control. Commit
[`cc99138`](https://github.com/LuMiSxh/Arknights-MacOS-Client/commit/cc99138bcb0a7c0df59e06c1f7ea46c8f8d9d3eb)
removed the separate performance toggle while retaining it. An older precise-trackpad-scrolling
toggle from [issue #28](https://github.com/LuMiSxh/Arknights-MacOS-Client/issues/28)
was also removed. `UsePreciseScrolling=y` preserved Wine's horizontal wheel events but made
vertical scrolling excessively fast; the game's Unity input path then ignored the horizontal
component anyway. The fixed `UsePreciseScrolling=n` replacement normalizes wheel behavior. This
path concerns two-finger scrolling and horizontal/vertical wheel translation, not pointer movement
or rendered-cursor latency, so it is not a candidate fix for #84.

## Runtime evidence

The client manifest pins Runtime v0.6.0 at build commit
`8f4dcc3524e21b5baf98af2bfa6e9a86f611cad4`, WineCX
`e1b410a5fdd96a32722a5f2617b5068bd385b7db` (Wine 11.16), and DXMT
`4ddb20e54672c0cb56115ce80d6db1beef94ae28`. The matching runtime recipe contains
the [cursor frame-latency patch](https://github.com/LuMiSxh/Arknights-MacOS-Runtime/blob/8f4dcc3524e21b5baf98af2bfa6e9a86f611cad4/patches/dxmt/cursor/0001-dxmt-command-queue-configurable-frame-latency.patch#L25-L46).
It reads `ARKNIGHTS_RUNTIME_DXMT_MAX_FRAME_LATENCY` once when the first command queue is
constructed. Only the exact values `1`, `2`, and `3` are accepted; missing or invalid input
retains `3`. It changes the command queue's frame-latency limit, with no mouse sensitivity,
acceleration, raw-input, or cursor-rendering replacement in that patch.

This initialization is not necessarily authoritative for every game session. DXMT also implements
`IDXGIDevice1::SetMaximumFrameLatency` by writing the same command-queue value. If the game or Unity
calls that API after queue construction, it can replace the launcher-selected value. The local
diagnostic run logged queue initialization, every setter call, and aggregate fence-wait time. It
observed effective values matching the launcher setting and no later setter calls at either 3 or 1.
This weakens the overwrite hypothesis for the tested Global build, while leaving other clients and
future game versions unverified. The next diagnostic should record presentation sync interval,
swapchain flags, and drawable waits; command-queue fence time alone is not input-to-display latency.

Unity exposes `QualitySettings.maxQueuedFrames` for Direct3D 11 and documents a PC default of 2.
That establishes a supported engine path for changing the queued-frame limit; it does not establish
that this game invokes it or which value it selects.
Source: [Unity `maxQueuedFrames`](https://docs.unity3d.com/2022.3/Documentation/ScriptReference/QualitySettings-maxQueuedFrames.html).

The patch was introduced in runtime commit
[`745fca9`](https://github.com/LuMiSxh/Arknights-MacOS-Runtime/commit/745fca97486d27f4ae5d7f68b70487569079a54c)
and has the same hash in runtime tags v0.5.0, v0.5.2, and v0.6.0. The
[runtime lock](https://github.com/LuMiSxh/Arknights-MacOS-Runtime/blob/8f4dcc3524e21b5baf98af2bfa6e9a86f611cad4/runtime.lock.json#L79-L83)
includes it in the source recipe. This establishes recipe inclusion; the published binary
was not downloaded or inspected during this research.

## Upstream input alternatives

The pinned WineCX source does not justify adding a generic mouse-speed or raw-input toggle:

- `MouseWarpOverride` controls DirectInput recentering/warping. It is worth investigating only
  after establishing that the game uses that path; it does not adjust sensitivity.
  [DirectInput implementation](https://github.com/dappermint/winecx/blob/e1b410a5fdd96a32722a5f2617b5068bd385b7db/dlls/dinput/mouse.c#L42-L63).
- DirectInput v8 selects raw input internally. No `EnableRawInput` switch was found in the
  inspected DirectInput, win32u, and Mac-driver files. This is a scoped search result, not a
  claim about every possible downstream patch.
  [Raw-input selection](https://github.com/dappermint/winecx/blob/e1b410a5fdd96a32722a5f2617b5068bd385b7db/dlls/dinput/mouse.c#L506-L544).
- Windows-style mouse registry tweaks are not established controls for this symptom. Wine's
  relative `NtUserSendInput` path applies acceleration, while the normal Mac-driver path
  sends hardware input through a different entry point.
  [Injected-input handling](https://github.com/dappermint/winecx/blob/e1b410a5fdd96a32722a5f2617b5068bd385b7db/dlls/win32u/input.c#L628-L664),
  [Mac hardware-input handling](https://github.com/dappermint/winecx/blob/e1b410a5fdd96a32722a5f2617b5068bd385b7db/dlls/winemac.drv/mouse.c#L129-L143).
- Retina handling scales coordinates and movement deltas. It is relevant to a reproducible
  distance/coordinate mismatch, but does not itself establish the cause of temporal lag.
  [Retina movement conversion](https://github.com/dappermint/winecx/blob/e1b410a5fdd96a32722a5f2617b5068bd385b7db/dlls/winemac.drv/cocoa_app.m#L1445-L1585).

For ordinary unclipped movement, the Mac driver sends the absolute macOS cursor position through
Wine. It switches to relative deltas only when the cursor is pinned at a clipping boundary. Retina
mode scales both absolute coordinates and relative deltas by two, matching Wine's doubled Retina
desktop coordinates. That makes a general launcher-side sensitivity multiplier a poor fit without
evidence that the game actually consumes the relative DirectInput path or that settled coordinates
are wrong.

Upstream DXMT's internal swapchain latency constant, presentation timing, and this project's
patched command-queue limit are separate mechanisms. In particular, upstream
`kSwapchainLatency = 1` does not prove that the client setting is redundant. The game's
chosen input API, swapchain flags, and actual cursor rendering remain unverified.
Sources: [swapchain implementation](https://github.com/3Shain/dxmt/blob/4ddb20e54672c0cb56115ce80d6db1beef94ae28/src/d3d11/d3d11_swapchain.cpp#L721-L810),
[runtime patch](https://github.com/LuMiSxh/Arknights-MacOS-Runtime/blob/8f4dcc3524e21b5baf98af2bfa6e9a86f611cad4/patches/dxmt/cursor/0001-dxmt-command-queue-configurable-frame-latency.patch).

## Frame Latency 0

Canary Features still controls both experimental runtime settings and access to China regions. Do
not add a separate frame-latency override toggle: the runtime's normal limit of 3 is the same value
as the launcher's default. A separate toggle would only choose between explicitly sending 3 and
leaving the runtime at 3.

The new value 0 asks the patched command queue to wait for the current GPU frame to complete before
queuing more work, so no completed frames wait ahead in that queue. This is a runtime-specific
meaning. It is not the device-level `IDXGIDevice1::SetMaximumFrameLatency(0)` behavior, which resets
that API to its default. Source: [Microsoft `IDXGIDevice1::SetMaximumFrameLatency`](https://learn.microsoft.com/windows/win32/api/dxgi/nf-dxgi-idxgidevice1-setmaximumframelatency).
Value 0 can reduce queue latency, but may significantly reduce FPS or make frame pacing less
smooth. It does not guarantee zero input-to-display latency because presentation and display paths
still add delay. Keep 3 as the default.

## Diagnostic sequence

The first two local runs used the same Global-client main-menu scene, Windowed 2560×1440, High
Resolution Mode, MSYNC, and both in-game VSync states. Each run exercised VSync on and then off.
The only launcher variable changed between runs was Frame Latency 3 versus 1. The game ran for
83.10 seconds at 3 and 63.57 seconds at 1. The tester described value 1 as "a little snappier."
The local setting was restored to 3 after collection.

1. Record client and runtime version, game region, macOS version, input device, display refresh
   rate, resolution, display mode, High-Resolution Mode, VSync, observed frame rate, and the
   current Canary/Frame Latency settings.
2. Establish whether the complaint is a delayed response or a distance mismatch. Compare the
   cursor's settled endpoint after repeated equal physical movements, and separately compare
   how quickly it catches up when movement stops. Keep the input device and display geometry
   constant. Repeat slow and fast motions to distinguish gain from acceleration.
3. The reporter has completed the Frame Latency 3-versus-1 comparison without a visible change.
   The local instrumented comparison proved that both values were active and found a small
   subjective improvement at 1. Do not request another instrumented run from the reporter or treat
   either result as universal.
4. The reporter has been asked to compare in-game VSync on and off as the next separate variable,
   recording responsiveness and tearing while keeping the scene and other graphics settings fixed.
   Do not combine this comparison with a latency, resolution, or runtime change.
5. Only if the settled movement distance remains wrong, compare windowed/borderless mode and
   High-Resolution Mode separately. A result tied to display scaling warrants an input-coordinate
   investigation; a result tied to frame rate warrants a rendering-latency investigation.
6. Compare at least one unaffected machine with an affected machine before changing defaults.
   Disable cursor overlays in screen recordings so the recorder does not introduce a second
   pointer, as happened in #34.

## Implementation decision and regression coverage

Do not add a mouse-speed slider based only on this report. Windows-style mouse-speed registry values
do not apply to Wine's normal Mac hardware-input path. Keep 0–3 behind Canary Features, with 3 as
the default. The local run shows that lower values can reduce frames in flight while increasing
GPU wait time, so they may trade throughput and smooth pacing for responsiveness. Make no further
diagnostic requests of the reporter. Existing evidence continues to point toward the game's
software-cursor and presentation path, but does not confirm a fix for #84.

The current Canary Frame Latency control spans 0–3, with 3 as the default. The launcher passes the
saved value to DXMT only when Canary is enabled and the packaged runtime advertises
`dxmtMaximumFrameLatency`; the value is clamped to that advertised range. Otherwise the preference
remains saved and the runtime default applies. The Hardware Cursor preference defaults off and
resets off. The client emits `ARKNIGHTS_RUNTIME_HARDWARE_CURSOR=1` only when Canary Features and Use
Hardware Cursor are on and the packaged runtime advertises `hardwareCursor`. The runtime must
interpret this flag by suppressing the game's rendered cursor; the launcher does not modify game
assets. The setting applies on the next launch and may change cursor appearance. Preferences tests
cover the default, persistence, and reset; environment tests cover every region and all four
Canary/toggle combinations. These checks protect configuration propagation, while manual
comparisons with the matching runtime remain necessary to establish whether the hardware pointer
feels better.

## Limits

Issue #84 now identifies the client version, macOS version, M1 hardware, and trackpad input, but
still lacks the runtime version, game region, display configuration, settled-endpoint comparison,
frame measurements, logs, or reproduction video. The historical and community VSync results are
useful evidence for a hypothesis, not measurements of this reporter's machine. Offline launcher
tests cannot establish the game's input API or measure end-to-end cursor latency. The local A/B run
used one unaffected machine and subjective observation, combined both VSync states within each run,
and measured only the DXMT command-queue fence. It validates configuration propagation and queue
pressure, not the reporter's symptom or the full presentation path.
