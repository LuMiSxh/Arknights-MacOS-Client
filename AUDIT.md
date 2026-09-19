# AUDIT Runtime

> **Runtime work only.** The client-side sections of the original audit are resolved — implemented,
> or rejected with a reason — and have been removed; the changes they produced are in `CHANGELOG.md`
> under 0.5.3 and in `docs/development/architecture/`. What remains below belongs to the runtime
> repository (WineCX `e1b410a` / 11.16, DXMT `4ddb20e` / 0.80-213). Each section keeps the original
> text followed by an **Opus-Note** with what to do, what not to do, and what the research found.
>
> The display-profile cache experiment (formerly `0001-winemetal-cache-display-profiles.patch`) is now
> **rejected and removed**. Its A/B result is retained below as historical evidence, but there is no
> active `ARKNIGHTS_RUNTIME_PERFORMANCE` switch or cache candidate to enable. The independent
> `0001-dxmt-initialize-device-before-command-helpers.patch` remains a correctness fix and is kept
> in the runtime. The release-statistics/HUD gate is active as
> `0002-dxmt-skip-release-present-statistics.patch`; the Wine/AppKit request-batching candidate was
> rejected and removed after its screening run. Two of the original ideas turn out not to need a
> patch at all: 1.5 and 1.6 are DXMT configuration that already exists upstream. **Start with
> measurement, not with a patch** — the runtime repository now has a
> frametime recorder (`just frametime-record CASE SECONDS`,
> `docs/testing.md#frametime-capture`) that captures `metalperftrace` `.atrc` traces and JSON
> overviews. Test matrices still have to be run explicitly; the harness does not ship predefined
> pacing or MetalFX cases.

Arknights ist ein x86_64 Unity-Spiel (Direct3D 11). Jeder Frame durchläuft die Kette: `Unity -> Rosetta 2 -> WineCX -> DXMT -> Metal API`. Die folgenden Architektur-Änderungen greifen genau an den Flaschenhälsen dieser Kette an, um Frametimes zu stabilisieren und die maximale Hardware-Leistung aus Apple Silicon herauszuholen.

## Measurement status: Tactical Drill stage 4 (19 September 2026)

The first repeatable gameplay capture is now available under
`Arknights-MacOS-Runtime/.build/frametimes/`; the derived comparison is
`.build/frametimes/tactical-drill-4-comparison.json`. It aligns the first 70 complete,
approximately one-second aggregate bins from the same Tactical Drill stage and Auto-Deploy, at
maximum frame latency 3. The underlying windows span 69.5 to 70.3 seconds and FPS uses each run's
actual duration. The presented WineMetal layer was 2560 x 1440 BGRA8Unorm in every run. That is
the presentation size, not proof that every internal Unity render target used the same resolution.

**Measured baseline (A1/A2, `ARKNIGHTS_RUNTIME_PERFORMANCE` disabled):**

- A1 and A2 averaged 78.072 and 78.297 FPS; the group mean was 78.184 FPS.
- Group means were 12.789 ms frame-on-glass, 13.794 ms on-GPU, 12.964 ms CPU end-to-end,
  and 8.744 ms waiting for the next drawable.
- Both runs reported zero skipped frames. The slowest five one-second windows averaged
  70.799 FPS, and the first and second halves averaged 81.255 and 75.142 FPS.
- Frame-on-glass intervals followed the 120 Hz display's 8.33 ms cadence and reached 41.67 ms.
  Zero Metal `Skipped Frame Stats` therefore does not mean that no visible long frame occurred.
- The compared A windows created no pipeline states and performed no shader compilation. Shader
  cache work is not motivated by this warmed combat case; cold-start stutter would be a separate test.
- The one-second FPS series was strongly inversely correlated with both GPU time
  (about -0.93) and CPU end-to-end time (about -0.96). This shows that the slow windows
  carry both signals; it does not identify which side caused them.

**Clean-removal control (cache patch removed, 19 September 2026):** run
`tactical-drill-4-clean-removal-20260919T110604Z` used the same Tactical Drill stage and
Auto-Deploy. The comparable 70-second window was timeline 10..79 at 2560 x 1440 and contained
5,356 frames: 76.513958 FPS, 13.069511 ms frame-on-glass, 14.071160 ms on-GPU,
13.186565 ms CPU end-to-end, and 8.875558 ms waiting for the next drawable. The slowest-five
window average was 64.989255 FPS and the minimum one-second window was 55.911034 FPS.
Against the earlier A1/A2 means, this was -2.1366% FPS, +2.1895% frame-on-glass, +2.0078%
on-GPU, +1.7201% CPU end-to-end, +1.5071% next-drawable wait, and -8.2064% for the slowest
five windows. The slowdown therefore reproduces after removing the cache patch; the earlier A/B
difference cannot be assigned causally to that patch. Individual manual runs remain screening
evidence only. The cache patch stays removed because it provides no demonstrated advantage. This
clean-removal run is now the immediate comparator for the next isolated DXMT release-statistics
gate run.

**Candidate 1 result (DXMT release-statistics/HUD gate, 19 September 2026):** run
`tactical-drill-4-dxmt-stats-gate-20260919T111838Z` used the same warmed Tactical Drill and
Auto-Deploy path. Its aligned window was timeline 7..76 (70 seconds) at 2560 x 1440 and
contained 5,397 frames: 77.099852 FPS, 12.971744 ms frame-on-glass, 13.944139 ms on-GPU,
13.145567 ms CPU end-to-end, and 8.869328 ms waiting for the next drawable. It reported zero
skipped frames; the slowest-five window average was 70.398952 FPS and the minimum one-second
window was 69.998865 FPS.

Against the immediate clean-removal control, this was +0.7657% FPS, -0.7481% frame-on-glass,
-0.9027% on-GPU, -0.3109% CPU end-to-end, and -0.0702% next-drawable wait. The slowest-five
average was +8.3240% and the minimum window +25.1969%. This is one screening run only; the
low-window improvement is not causal evidence because the clean-control low was an outlier.
The release-dead statistics/HUD work can therefore be kept provisionally: no regression was
observed, the run was stable, and debug HUD behavior remains unchanged. The performance gain is
inconclusive until repeated paired runs confirm it. At that point, Wine/AppKit per-drawable request
measurement was the next candidate.

**Candidate 2 result (Wine/AppKit per-drawable request batching, 19 September 2026):** run
`tactical-drill-4-winemac-batch-20260919T113855Z` used the same warmed Tactical Drill and
Auto-Deploy path. Its aligned window was timeline 8..77 (70 seconds) at 2560 x 1440 and contained
5,246 frames: 74.835601 FPS, 13.361040 ms frame-on-glass, 14.367926 ms on-GPU, 13.553031 ms
CPU end-to-end, and 9.110337 ms waiting for the next drawable. It reported zero skipped frames;
the slowest-five window average was 64.600295 FPS and the minimum one-second window was
62.999474 FPS.

Against candidate 1's active DXMT release-statistics gate, this was -2.9368% FPS, +3.0011%
frame-on-glass, +3.0392% on-GPU, +3.0996% CPU end-to-end, +2.7173% next-drawable wait,
-8.2369% for the slowest five windows, and -9.9993% for the minimum window. Fullscreen/windowed
switching, resize/move, minimize/restore, input, and rendering all passed the functional smoke
check, but performance was consistently worse. This is one screening run only; the candidate is
nevertheless rejected and removed because every aggregate performance signal moved in the wrong
direction. Keep Wine/AppKit as an instrumentation target: first aggregate request counts, actual
frame/z-order changes, and request durations, then design caching or batching with complete
invalidation coverage.

**Metal HUD observation and spike interpretation:** every tested path shows a red graph with many
small spikes and intermittent larger spikes. Apple's
[Metal Performance HUD Tech Talk](https://developer.apple.com/videos/play/tech-talks/110339/)
explains that unusually high frame intervals and GPU times are highlighted in red. Red therefore
means an outlier relative to the recent average; the color alone does not identify a CPU, GPU,
drawable, or compositor cause. The documented `frameintervalgraph` covers the last 120 on-glass
intervals, while `gputime` and `presentdelay` are separate metrics
([metric definitions](https://developer.apple.com/documentation/xcode/understanding-metal-performance-hud-metrics)).
At roughly 77 FPS on a 120 Hz display, ordinary presentation already has to alternate between
8.33 and 16.67 ms refresh steps; those small oscillations alone do not prove a runtime bug.
Intervals of 25/33.33 ms and above miss additional refresh opportunities and remain the larger
spikes that need per-frame diagnosis.

In the one-second aggregates, each run's maximum frame-on-glass interval correlates moderately
with CPU and GPU maxima, but only weakly with the maximum next-drawable wait: `r ~= 0.12` for the
clean-removal control, `0.19` for the statistics gate, and `0.03` for the rejected WineMac batch.
This argues against `nextDrawable` as the sole source of the red spikes. The current aggregation
cannot assign an individual red frame causally. Every trace also contains Zed rendering its own
3008 x 3128 Metal layer at about 26 FPS. Zed is the non-removable host IDE, so it remains a fixed
background condition: keep its window/content/activity stable during each run and filter analysis
explicitly to the `wine` process rather than treating Zed as a removable test variable.

**Online Wine/DXMT patch review (19 September 2026):** broad research of upstream issues, pull
requests, current commits, forks, and community reports produced three conditional candidates:

1. [DXMT issue #204](https://github.com/3Shain/dxmt/issues/204) is the strongest new throughput
   candidate. Full `UpdateSubresource` writes to `D3D11_USAGE_DEFAULT` constant buffers enter the
   rename path, but the rename pool in `src/d3d11/d3d11_buffer.cpp` inherits flags without
   `BufferAllocationFlag::SuballocateFromOnePage`. A workload with many pixel-shader constant-buffer
   updates can therefore create many small `MTLBuffer` objects and `useResource` entries. The issue's
   synthetic M3 Max reproducer reports 87.29 ms at 24,000 draws before the change and 4.80 ms after
   it, including Metal kernel time falling from 86.10 to 0.78 ms. Those numbers prove the synthetic
   mechanism, not an Arknights benefit. Before porting it, the diagnostic trace must show that
   Arknights frequently uses this exact update path and spends material time in the corresponding
   Metal driver/resource work. A candidate must change only the rename-pool flags, not the initial
   allocation. Review `ExecuteCommandList` cursor restoration and deferred contexts first; for
   2-4 KiB buffers the current integer division may reserve a full page without gaining multiple
   slots.
2. Upstream Wine commit
   [`5f67373a`](https://github.com/wine-mirror/wine/commit/5f67373a139f2f1c91d4f6668bb745446348f84a)
   removes the old `WineDisplayLink` GDI redraw workaround and its deprecated `CVDisplayLink`
   callback. It is absent from WineCX `e1b410a` and can be rebased with one local context adjustment.
   It is not DXMT's Metal frame pacer: without continuing `viewsNeedDisplay` invalidations the link
   stops after about two seconds, and `WineMetalLayer::nextDrawable` does not itself set that flag.
   Promote this candidate only if a warmed trace shows recurring `WineDisplayLinkCallback`,
   `-[WineDisplayLink fire]`, main-queue `displayIfNeeded`, and temporal overlap with late frames.
3. Community-fork shader-IR release/reconstruction can reduce retained memory, but it changes
   compiler-object lifetimes and concurrency. It remains a later memory-pressure candidate only if
   `vmmap`, faults, swap, or the trace show a real memory problem; current runs do not.

Do not port [DXMT PR #175](https://github.com/3Shain/dxmt/pull/175): its per-map nested binding
scan was explicitly rejected by the maintainer as too expensive for the hot `WRITE_DISCARD` path.
The multi-second GS/TS stall fix discussed in
[DXMT issue #200](https://github.com/3Shain/dxmt/issues/200), worker-thread priority work, and the
large fence/encoder reorder are already present at this pin. The post-pin macOS 27 custom-HUD metric
fix changes diagnostics, not rendering performance. The open
[ProMotion issue #26](https://github.com/3Shain/dxmt/issues/26) reinforces testing
`d3d11.preferredMaxFrameRate` as configuration; it does not supply a safe general refresh-rate patch.

**Inference from A/A:** the scene has useful preliminary _within-session_ repeatability: A1 and A2
differ by 0.29% in mean FPS. They share one Wine process, so they do not establish restart-to-restart
variance or a general two-percent significance threshold. CPU end-to-end includes pipeline waits
and cannot be compared with on-GPU time as if both were busy-time counters; these traces do not
identify a CPU or GPU bottleneck. The next-drawable wait is substantial, but zero skipped frames
does not establish a swapchain or `CAMetalLayer` defect. No 4K presentation occurred, so the
Retina/high-resolution case remains untested.

**Rejected cache experiment (B1/B2, old performance canary enabled):** the group mean fell from 78.184 to
76.391 FPS (-2.29%). Frame-on-glass rose 2.35%, on-GPU time 2.08%, and CPU end-to-end time
2.27%. The slowest-five-window mean fell 5.82% and the second-half mean fell 3.82%.

Treat this as a **failed experiment**, not as proven causality. There were only two independent
game sessions in total: A1/A2 shared one process and B1/B2 shared another. Variant, restart, order,
and process warm-up are therefore confounded. B1 also shows pipeline-cache activity that is absent
from B2. B2 remains slower, so that activity is not a sufficient explanation, but the design still
cannot isolate the display-profile cache from session variance.
The candidate remains rejected and removed because it shows no demonstrated advantage. The
clean-removal control below reproduces a similar slowdown after removal, so the earlier A/B delta
cannot be assigned causally to the cache. A properly paired rerun would still be required for a
causal performance claim; the individual manual runs are screening evidence only.

The failed cache and the Wine/AppKit batching candidate are removed, while candidate 1 remains
provisionally retained. The next action is a diagnostic run on that retained build, not another
optimization patch:

1. Record one 90-second `Game Performance` Instruments trace for all processes while repeating the
   same warmed Tactical Drill and align the same 70-second battle window. Keep 2560 x 1440, 120 Hz,
   latency 3, HUD configuration, Zed state, and gameplay fixed. The local Xcode installation
   provides this template:

   ```sh
   xcrun xctrace record --template 'Game Performance' --all-processes --time-limit 90s \
     --output .build/frametimes/tactical-drill-4-diagnostic.trace
   ```

   Instruments adds material overhead, so do not score its FPS directly against the earlier
   low-overhead `metalperftrace` runs. Use it to classify several frames at or above 25 ms: GPU
   work, missing CPU submissions, runnable delay on `dxmt-encode-thread`, Metal driver/resource
   work, drawable/fence waiting, or Wine/AppKit main-queue work.
2. Enable Metal's per-frame signposts for the `wine` PID when possible, then export the full
   timeline. This provides a lower-overhead frame-level companion to the Instruments trace:

   ```sh
   metalperftrace setup --enable per-frame-metrics --pid <wine-pid>
   metalperftrace overview --json --json-include-timeline <trace.atrc>
   ```

3. If the trace confirms frequent DEFAULT constant-buffer renames and material Metal driver work,
   build the narrow DXMT #204 suballocation candidate and give it exactly one identical screening
   gameplay run. If instead warmed combat shows recurring `WineDisplayLink` callbacks overlapping
   late frames, test the upstream Wine removal as its own candidate. Do not combine them. Retain a
   patch only if its specific mechanism improves and rendering/UI remain correct; a single randomly
   higher average FPS is insufficient.

Wine/AppKit request counts and the per-present EDR query remain instrumentation targets if the
diagnostic points there. Any future caching must still cover frame/superview/visibility or
screen/HDR/EDR/reconnect/sleep-wake invalidation respectively; the rejected candidates provide no
support for an unconditional cache.

The A/A result still supports testing a lower source resolution first, then
`preferredMaxFrameRate` 0 versus 60 with latency fixed at 3, and then frame latency 3/2/1 with the
cap fixed. These are configuration experiments and should stay separate from the runtime patch
sequence. Test MetalFX only after establishing a lower source resolution and matched final output;
judge text/UI sharpness together with frametime. QoS and DXMT-only LTO remain later hypotheses
because the traces contain no scheduler or compiler evidence.

**Untested hypotheses:** the current captures do not establish E-core migration, an expensive
AppKit lock or WindowServer round trip, thermal throttling, a benefit from LTO, or a benefit from
MetalFX. The source does establish a per-present AppKit/EDR query; its cost remains unmeasured.
The captures also do not measure high-resolution mode, so none of these claims should be promoted
from a test target to an optimization decision yet.

---

### 1.1 CPU-Scheduling & Thread QoS (Rosetta 2 vs. E-Cores)

> **Opus-Note (researched).** Nothing the client can do here — thread QoS is set inside Wine's own
> thread creation. Do this only with measurements, and expect it to be harder than the
> snippet suggests. Two facts work against it:
>
> - QoS is documented as affecting "scheduling, CPU and I/O throughput, and timer latency". Apple
>   does not document it as pinning a thread to P-cores, and `QOS_CLASS_USER_INTERACTIVE` is a
>   hint, not an affinity. Writing "zwingst du den macOS-Scheduler" overstates the guarantee.
> - The exact WineCX pin already maps Win32 priorities to Mach latency/throughput QoS tiers and
>   applies precedence/time-constraint policies in `server/thread.c`. DXMT sets both its encode and
>   finish threads to `THREAD_PRIORITY_TIME_CRITICAL`. A blanket interactive-QoS patch would replace
>   existing policy rather than fill a missing mapping and could reduce responsiveness elsewhere.
>
> Also note this is CrossOver's WineCX (`dappermint/winecx` @ `e1b410a`, 11.16), not upstream Wine —
> CrossOver already has its own macOS thread handling that any patch has to reconcile with.
> Verdict: **low priority, high effort, unproven.** Do not change the mapping before a System Trace
> shows runnable delay, harmful core placement, or starvation caused by the current policy.

**Ursprüngliche, unbestätigte Hypothese:**
Apple Silicon nutzt P- und E-Cores. Ob Rosetta-/Wine-Threads hier eine unpassende QoS-Klasse
erhalten, auf E-Cores migrieren oder dadurch Frametime-Spikes erzeugen, zeigen die vorhandenen
Traces nicht. Dafür ist ein System Trace mit Thread-, Core- und Runnable-Latency-Daten nötig.

**Möglicher Versuch nach einem positiven Profiling-Befund:**
Eine WineCX- oder DXMT-Änderung dürfte nur die nachweislich problematische bestehende Zuordnung
anpassen, etwa einen zu aggressiven Hilfsthread herabstufen oder eine konkrete kritische
Wake-up-Kette korrigieren. Ein pauschales `pthread_set_qos_class_self_np` zusätzlich zur vorhandenen
Mach-Policy ist kein sinnvoller Test und garantiert ebenfalls keine P-Core-Bindung.

### 1.3 Link-Time Optimization (LTO) im Runtime-Build

> **Opus-Note (researched).** Do **not** apply this to Wine. Wine failing to build with `-flto` is
> a long-standing, repeatedly reported problem: undefined references to `relay_trace_entry`,
> `relay_trace_exit`, `call_thread_func`, `wld_start`, `thread_ldt` — i.e. exactly the hand-written
> assembly, relay thunks and special sections that LTO's whole-program view breaks. Debian filed it
> as an FTBFS bug; Gentoo carries the same failure. WineCX has _more_ of that code than upstream,
> not less.
>
> DXMT is a different story: ordinary C++ with no relay assembly, so target-toolchain-compatible
> LTO is technically plausible there. If you try it, scope it to DXMT and treat the audit's
> "3 bis 8 %" as unsourced — it cites nothing.
>
> The current DXMT release build already uses `-O3`; Wine remains at `-O2`. The DXMT cross build
> uses MinGW GCC, so the Clang-specific `-flto=thin` prescription below is not directly applicable.
> Do not open this experiment until a CPU profile identifies meaningful DXMT work that whole-program
> optimization could plausibly reduce. The baseline contains no such evidence.

**Ursprüngliche Hypothese:**
Wine wird mit `-O2` gebaut; DXMT wird im aktuellen Release-Build bereits mit `-O3` gebaut. Ob
Modulgrenzen in einem relevanten CPU-Hotpath verbleiben, ist noch nicht profiliert.

**Nicht ungeprüft anwenden:**
Die folgende ursprüngliche Clang-Skizze passt nicht ohne Weiteres zum verwendeten Cross-Toolchain
und die behaupteten **3 bis 8 %** sind nicht belegt:

```bash
export CFLAGS="-O3 -flto=thin -fno-stack-protector -Wno-error=implicit-function-declaration $include_flags"
export LDFLAGS="-flto=thin $link_flags"
```

### 4.4 AppKit-Locking im Render-Loop (`winemetal_unix.c`)

> **Opus-Note.** Synchronous AppKit work on a present path deserves profiling, but an AppKit getter
> alone is not evidence of an expensive lock or WindowServer round trip. The removed
> former `0001-winemetal-cache-display-profiles.patch` cached ColorSync chromaticities behind
> `ARKNIGHTS_RUNTIME_PERFORMANCE`; its own commit message correctly says that _"a frame-rate
> improvement remains unproven"_. The cache is no longer in the runtime or client, and it targeted
> a different call path from the live EDR query.
>
> The remaining AppKit path is source-confirmed:
> `d3d11_swapchain.cpp` calls `Presenter::synchronizeLayerProperties`, which reaches
> `_WMTQueryDisplaySettingForLayer` in `winemetal_unix.c` and reads `NSView`, `NSWindow`,
> `NSScreen`, and live EDR properties. Presence on the present path does not prove that the getter
> performs an expensive lock or WindowServer IPC. Profile its duration and stacks before changing
> it. Any eventual cache must preserve live screen, HDR, and EDR changes.
>
> **Measured outcome (19 September 2026).** The removed display-profile cache candidate was enabled
> for B1/B2. Against A1/A2 it increased average frame-on-glass, GPU, and CPU times by about two
> percent and reduced average FPS by 2.29%. This is a failed experiment and the runtime/client
> switch has been removed; do not re-enable it or treat it as an active optimization candidate. It
> is not causal proof because the comparison has only two independent sessions total, one for each
> variant, plus different warm-up state; do not infer from it that the ColorSync query is itself a
> per-frame cost.
> `_WMTGetDisplayDescription`, the existing cache's target, is a separate DXGI-output/NVAPI path;
> it is not the confirmed per-present EDR query. The next experiment should count/profile both paths
> and should not add another mutex or dictionary cache until that evidence exists. The EDR query is
> the next runtime patch target after the active release-statistics/HUD gate; the rejected Wine/AppKit
> batching candidate does not establish that caching or batching is safe or beneficial.

**Bestätigter Pfad, unbestätigte Kosten:**
Der Present-Pfad fragt AppKit-Objekte und EDR/HDR-Metadaten ab. Ob diese Getter dabei messbare
Locks oder WindowServer-IPC auslösen, ist noch nicht profiliert.

**Nur nach Profiling ändern:**
Falls der Pfad messbar teuer ist, sollte WineMetal unveränderte Screen-Daten nicht pro Present
erneut ermitteln.

- Vermeide nur die redundant nachgewiesenen Abfragen und erhalte den aktuellen Screen-, HDR- und
  EDR-Zustand sowie die bestehenden Present-Semantiken.
- Weise vor einem Cache nach, dass alle relevanten Display-/Window-Wechsel und dynamischer
  EDR-Headroom korrekt invalidiert oder weiterhin live abgefragt werden.

### 1.5 ProMotion (120 Hz) & CAMetalLayer Swapchain

> **Opus-Note (verified against the pin `4ddb20e`).** Correction to an earlier draft of this note,
> which claimed the limiter "defaults to 60" and concluded the section was mostly obsolete. That was
> wrong, and the error is worth recording: the `60` lives on line 36 of the shipped `dxmt.conf` as
> `# d3d11.preferredMaxFrameRate = 60` — a **commented-out example**, not an active default. The
> code default is **0** (`src/d3d11/d3d11_swapchain.cpp:169`).
>
> What actually happens at 0 (`d3d11_swapchain.cpp:762-766`): DXMT still derives a vsync duration,
> but from `init_refresh_rate_`, the display's own mode — it imposes no `1/rate` floor of its own.
> So pacing is CoreAnimation-coordinated by default, keyed to the display mode, not to 60. The
> measured external 120 Hz display reached about 120 FPS in menu bins and combat presents fell on
> 8.33 ms multiples. There is no blanket 60 FPS ceiling. This was a fixed-refresh external display,
> not a ProMotion/variable-refresh test.
>
> A 60 FPS stream on fixed 120 Hz has an exact 2:1 cadence; it is not intrinsically mismatched.
> A 60 FPS cap remains worth testing as a smoothness, power, and thermal tradeoff because combat
> throughput exceeds 60 but stays below 120. Mean FPS alone does not prove that every frame can
> meet the 16.67 ms budget.
>
> At this pin the implementation calls `presentDrawable:afterMinimumDuration:`. Patching
> `CAMetalLayer` properties or adding a separate `CAMetalDisplayLink` would compete with DXMT's own
> pacing. Use the existing limiter first.
>
> **Recommended:** compare `d3d11.preferredMaxFrameRate` 0 and 60 while keeping in-game settings
> and maximum frame latency at 3. Only after choosing a cap should latency 3/2/1 be compared. The
> baseline's roughly 49 ms Metal end-to-end total, 21 ms GPU-done-to-completion interval, and
> 8.74 ms next-drawable wait make queue depth a useful latency/pacing experiment, not proof of
> input latency or wasted CPU time.

**Ursprüngliche Hypothese:**
Variable Bildwiederholraten und mehrere gleichzeitig aktive Limiter können das Frame-Pacing
beeinflussen. Die Behauptung, 60 FPS auf 120 Hz verursachten allein bereits Micro-Stutter, ist für
einen festen 120-Hz-Modus falsch und wurde in diesem Lauf nicht beobachtet.

**Nicht als ersten Schritt patchen:**
Die ursprüngliche Skizze verändert Layer-Eigenschaften, ohne DXMTs bestehenden Present-Pfad zu
berücksichtigen:

```objc
metalLayer.maximumDrawableCount = 3; // Erlaubt Triple-Buffering, verhindert CPU-Stalls
if (@available(macOS 14.0, *)) {
    metalLayer.presentWithTransaction = NO;
}
metalLayer.displaySyncEnabled = YES; // Koppelt Presents hart an den VBlank des Displays
```

### 1.6 Die Retina 4K-GPU-Falle & MetalFX Upscaling

> **Opus-Note (researched) — right feature, wrong lever.** Correction to an earlier draft of this
> note: `DXMT_ENABLE_NVEXT=1` does exist. It unlocks the NVIDIA vendor extensions (`nvapi64.dll`,
> `nvngx.dll`) and maps DLSS SuperResolution onto MetalFX **Temporal**. It is simply useless here,
> because Arknights' Unity build never calls DLSS — so there is nothing for it to translate.
>
> The lever that does work is opt-in, game-agnostic **MetalFX Spatial** on the output swapchain:
>
> - `DXMT_METALFX_SPATIAL_SWAPCHAIN=1` enables it.
> - `d3d11.metalSpatialUpscaleFactor` sets the factor (multiplied by source output width).
>
> This needs **no runtime patch** and does not depend on Arknights supporting DLSS. It does not,
> however, lower the source resolution by itself: enabling a factor on the current 2560 x 1440
> source enlarges the output. A valid test must first select a lower source resolution, then choose
> a factor that produces the intended final output.
>
> **Measured status:** the presented Metal layer was 2560 x 1440; there was no 4K presentation in
> these captures. That makes the title's "4K trap" unobserved in this setup. Resolution sensitivity
> is still the strongest cheap throughput test because on-GPU time is material relative to an
> 8.33 ms 120 Hz budget, but the trace does not identify fill rate, bandwidth, shaders, or CPU
> submission as the cause.
>
> Two things to settle before any UI, both specific to this game rather than to DXMT:
>
> - **Spatial upscalers are built for 3D content, and Arknights is mostly crisp 2D.** The base UI,
>   operator art and text are exactly what a spatial scaler softens most visibly. Judge the manual
>   test on text sharpness first and frametimes second; a faster blurry launcher is not a win.
> - **"The player picks 1080p" needs a mechanism.** The game's backing-store resolution follows the
>   Wine window and `RetinaMode`, which the launcher already drives through
>   `WineDisplayConfiguration`. That is the lever, and it is the same one the section's point 1
>   wants to decouple from the browser/notice windows — for which there is still no mechanism.
>   Treat point 1 as unspecified.
>
> **Resolved (verified at the pin):** DXMT reads a DXVK-style `DXMT_CONFIG` environment variable —
> `src/util/config/config.cpp:355`, split on `;`, logged as "Found config env: " — alongside
> `DXMT_CONFIG_FILE` and a `dxmt.conf` in the working directory. The client can therefore inject
> everything through `WineRuntime+Environment.swift` and never write a file into the game folder.
>
> Two details for whoever runs the manual test (`d3d11_swapchain.cpp:142`, `:1116`):
>
> - `d3d11.metalSpatialUpscaleFactor` defaults to **2** with a floor of 1.0, so setting only
>   `DXMT_METALFX_SPATIAL_SWAPCHAIN=1` gives 2x, not 1.33x. Pass the factor explicitly.
> - The swapchain is only created when `supportsFXSpatialScaler()` is true; otherwise DXMT warns
>   and silently falls back. Check the log before concluding the feature did nothing.

**Zu testende Hypothese:**
`High-Resolution Mode` kann die präsentierte Auflösung und damit GPU-Arbeit erhöhen. Die bisherigen
Traces belegen weder eine 4K-Ausgabe noch Thermal Throttling. Sie erlauben auch keine Aussage dazu,
ob jedes interne Unity-Target der präsentierten Layer-Auflösung entspricht.

**Mögliche Konfiguration nach einem Auflösungstest:**

1. **Entkopplung:** Die UI des Browsers/Notices kann in Retina auflösen, der 3D-View von Unity sollte idealerweise auf 1080p/1440p fixiert sein.
2. **MetalFX Spatial:** Eine niedrigere Quellauflösung kann mit
   `DXMT_METALFX_SPATIAL_SWAPCHAIN=1` und einem expliziten
   `d3d11.metalSpatialUpscaleFactor` auf eine festgelegte Ausgabegröße skaliert werden.
   `DXMT_ENABLE_NVEXT=1` ist für Arknights irrelevant, solange das Spiel keine DLSS-Aufrufe macht.

---

## Opus-Note: runtime points the audit does not raise

1. **Measure before patching.** The removed display-profile cache patch was
   honest that _"a frame-rate improvement remains unproven"_. It is a rejected experiment, not an
   active runtime candidate, and `ARKNIGHTS_RUNTIME_PERFORMANCE` is no longer an active switch.
   The active correctness patch is
   `0001-dxmt-initialize-device-before-command-helpers.patch`, and the active release-statistics/HUD
   gate is `0002-dxmt-skip-release-present-statistics.patch`. The former is an independent
   initialization fix active in both A and B; the failed cache experiment and rejected Wine/AppKit
   batching candidate are not evidence against it. Every performance item above remains a
   hypothesis until there is a repeatable capture for one Arknights scene, and it is the only way
   to tell 1.1, 1.3 and 4.4 apart from noise. This is now built: `scripts/frametime.py` in the runtime
   repository records `/usr/bin/metalperftrace`
   `.atrc` traces and JSON overviews with approximately one-second aggregate bins. The A/A capture
   prioritizes resolution and pacing experiments, but it contains no evidence for E-core migration,
   LTO benefit, thermal throttling, or expensive AppKit work. The per-present AppKit path is known
   from source, not from the trace. Do not label slowest-second metrics as p99, one-percent-low, or
   per-frame stutter share. Run a matched baseline before every candidate. The next step is the
   combined Game Performance trace described above; it determines whether DXMT #204, the upstream
   WineDisplayLink removal, or neither deserves the next isolated build.

2. **Prefer DXMT configuration over Wine patches.** Two of the five runtime sections (1.5, 1.6)
   turn out to be `dxmt.conf` keys or environment variables that already exist upstream. Config
   survives a runtime bump; a patch has to be rebased against `winecx` 11.16 and DXMT 0.80 every
   time. Check `dxmt.conf` before writing a patch.

3. **Two frame-pacing knobs already exist, and they pull on different things.**
   `ARKNIGHTS_RUNTIME_DXMT_MAX_FRAME_LATENCY` (yours, 1–3, default 3) is queue depth: how many
   frames the CPU may run ahead of the GPU. `d3d11.preferredMaxFrameRate` (DXMT's, code default 0;
   the `60` in `dxmt.conf` is a commented example) is target cadence. Reducing queue depth reduces
   overlapping CPU/GPU work and may expose stalls or lower throughput; measure that tradeoff at the
   chosen cap. It does not imply that all downstream presentation buffering disappears or prescribe
   a particular frame-drop behavior.

   Arknights' own in-game frame cap and VSync setting add another control. Do not move several
   controls in one comparison. Use two separate matrices:

   | Pacing test | In-game settings | `preferredMaxFrameRate` | `MAX_FRAME_LATENCY` |
   | ----------- | ---------------- | ----------------------- | ------------------- |
   | P0 baseline | unchanged        | 0                       | 3                   |
   | P1 cap      | unchanged        | 60                      | 3                   |

   | Queue test | In-game settings | Chosen cap | `MAX_FRAME_LATENCY` |
   | ---------- | ---------------- | ---------- | ------------------- |
   | Q3         | unchanged        | fixed      | 3                   |
   | Q2         | unchanged        | fixed      | 2                   |
   | Q1         | unchanged        | fixed      | 1                   |

   P0 is a valid baseline: `0` is both
   the code default and the "no explicit cap" path, confirmed at the pin
   (`d3d11_swapchain.cpp:169`, `:762-766`).

   These runs need the game launched and played; that is yours to do, not something to automate
   from the launcher's test suite.

4. **Pin awareness, and read the source rather than the sample config.** DXMT is pinned at
   `4ddb20e` (0.80-213) and WineCX at `e1b410a` (11.16). A checkout of both already exists under
   `.build/pins-20260912/sources/` in the runtime repo. The similarly named
   `.build/sources/dxmt-combined` is stale and must not be used for pin-level conclusions.
   `git show 4ddb20e:<path>` answers these questions directly — which is how the
   `preferredMaxFrameRate` default above was caught. The shipped
   `dxmt.conf` is documentation with **commented-out examples**; its values are not the defaults the
   code uses. Every capability cited in this file was checked that way, not against DXMT `main`.
