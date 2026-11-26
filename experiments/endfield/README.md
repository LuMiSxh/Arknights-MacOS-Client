# Arknights: Endfield lab

## Purpose and status

This lab tests Arknights: Endfield on the app's ARM Wine runtime.

- Status: experiment. The lab is not part of the app, SwiftPM, or CI.
- The lab moves into the client only if the exit criteria pass.
- Files: `lab.py` (CLI), `installer.py` and `zipstream.py` (streaming installer), `test_installer.py`, `test_lab.py` (recorder parsers), `fixtures/`, and this README.

## Current state

- **Runtime changed.** The lab runs the app's installed ARM runtime, `Runtimes/arm-1.0.2`: Wine 11.22, DXMT 0.80, a builtin `winemetal`, and a KosmicKrisp build newer than the catalog runtime's. Pass it with `--runtime`.
- **DXMT works.** A `dxmt-d3d11` run on that runtime starts the game and renders (device utilization 20–52%, `recoveryCount` 0). The run ended after 116 s. The same backend failed on the catalog runtime because that runtime has no DXMT or `winemetal`.
- **Vulkan stalls after the first in-game frame.** On the newer KosmicKrisp the game starts, plays music and dialogue, and the window stays on the first in-game frame. The log ends with `AGX: exceeded compiled variants footprint limit`, the render thread is stuck in `CAMetalLayer nextDrawable`, and `Alloc system memory` grows from 3 GB to 65 GB. See the findings below.
- **Still open.** The intro result on DXMT is not recorded yet. Two Vulkan runs froze WindowServer; the recorder and `collect` now keep the evidence.

## Safety

- The lab root is separate from the app. The default is `~/Library/Application Support/EndfieldLab`.
- Set `ENDFIELD_LAB_ROOT` to use another root.
- The app's runtime is read-only for the lab. The lab never writes to it.
- The lab writes only under its root.
- Use a throwaway Gryphline account. Do not sign in with your main account.
- Use `--dry-run` before every launch. It prints the environment and command without running them.

## Findings

Each finding lists its source. Verify a finding before you rely on it.

- **Engine.** The game uses Unity IL2CPP on x86_64. Unity documents its player command-line flags ([Unity player arguments](https://docs.unity.com/en-us/engine/6000.0/manual/unity-editor/command-line-arguments/player)).
- **Renderer.** Reports say the Vulkan renderer is selectable. Direct3D 12 under Wine fails with "Cannot load DXIL conversion library" ([Endfield_FineWine PR 21](https://github.com/stoicswe/Endfield_FineWine/pull/21)).
- **Runtime graphics.** The app's ARM runtime and the catalog runtime both ship KosmicKrisp: `lib/libvulkan_kosmickrisp.dylib`, the Khronos loader `lib/libvulkan.1.dylib` (1.4.363), and an ICD file in `share/vulkan/icd.d/`. Wine loads `libvulkan.1.dylib`, so `VK_DRIVER_FILES` selects the driver. The `arm-1.0.2` driver is a newer build than the catalog's (different size and hash, 2026-11-26 against 2026-11-17).
- **KosmicKrisp requirements.** The driver needs macOS 26 or later and Apple silicon ([Mesa KosmicKrisp](https://docs.mesa3d.org/drivers/kosmickrisp.html)).
- **Runtime DXMT payload.** The app's ARM runtime ships `DXMT/x64` with `d3d10core.dll`, `d3d11.dll`, and `dxgi.dll`, plus a builtin `winemetal` (`lib/wine/aarch64-windows/winemetal.dll` and `lib/wine/aarch64-unix/winemetal.so`). The catalog `wine-11-22-arm64-v0-7-2-alpha-2` runtime has neither, so `dxmt-d3d11` cannot start there. DXMT has no D3D12. The `vkd3d-kk` backend uses Wine's builtin `d3d12.dll` (vkd3d) on KosmicKrisp instead. Expect the DXIL error there.
- **UnityPlayer 1114.** A native DXMT `d3d11.dll` loaded against a missing or different `winemetal` fails its DLL initialization. Unity reports that as error 1114, "unityplayer.dll fehlt oder ist beschädigt". Use a runtime that bundles `winemetal`, and refresh the prefix DLLs after a runtime change.
- **Freeze evidence.** `collect` on the 23:01 `vulkan-mvk` run found kernel `IOGPUCommandDescriptor::prepare` faults for `Endfield.exe` from 23:01:26 to 23:15:27, with negative `remainingBytes` and `maxWired` 12,713,115,648. WindowServer froze at 23:16. A process RSS guard alone may not catch GPU-side memory.
- **KosmicKrisp frame stall.** The 23:40 `vulkan-kk` run on `arm-1.0.2` rendered the first in-game frame and then stalled. The last log line was `AGX: exceeded compiled variants footprint limit`. A `sample` of the game process shows the render thread in `libvulkan_kosmickrisp` → `-[CAMetalLayer nextDrawable]` → `allocate_drawable_texture` → `-[AGXG16GFamilyDevice newTextureWithDescriptor:iosurface:plane:]`. `Alloc system memory` rose from 3 GB to 65 GB while `In use` stayed near 1 GB. The collected log also has `IOGPUCommandDescriptor::prepare` faults at 23:46:50 to 23:47:28, including an unsigned underflow in `wiring delta`. The sample is saved beside the run record as `<run>-sample.txt`.
- **Platform.** Endfield ships only on the ARM runtime. It needs macOS 27 or later.
- **Anti-cheat.** ACE runs as a kernel-level driver. The community project [Endfield_FineWine](https://github.com/stoicswe/Endfield_FineWine) documents its work in `docs/technical.md`. Most of its fixes target Rosetta.
- **ACE lead.** The relevant patches for us are `ARM/stage1-macos` patches 0010 to 0013. They cover `ntoskrnl` and `wdfldr.sys` for ACE's ARM64 drivers. No report yet confirms ACE under FEX. ACE patches belong in the private ARM Wine repository.
- **Distribution API.** The launcher API is `POST https://launcher.gryphline.com/api/proxy/batch_proxy`. Use kind `get_latest_game` and appcode `YDUTE5gscDZ229CW`. Channel is 6. Sub-channel is 6 or 9999, which is unresolved.
- **Full install.** The full install is 59 split ZIP parts on `beyond.hg-cdn.com`. The download is about 62 GB. The installed size is about 68 GB. The manifest's `total_size` (about 131 GB) is the download plus the installed size. Virtual file system resources come from `get_latest_resources`.
- **Reference code.** [AugustLigh/LLauncher](https://github.com/AugustLigh/LLauncher) is an MIT reference for the API. Do not copy code from GPL or AGPL projects.
- **Parent check.** `Endfield.exe` runs only when the official `Games.exe` is its parent process ([reakjra/stepministrator](https://github.com/reakjra/stepministrator)).
- **Launch chain.** A `+process` trace of a working run shows the chain. GRYPHLINK `Launcher.exe` starts `1.6.0\Games.exe`. `Games.exe` starts `"G:\Endfield.exe" -launcher_lang=en-us -launcher_sub_channel=6` with a plain `CreateProcess`. The game gets no renderer flag; the launcher's **Rendering Mode** setting selects Vulkan. The game then starts `PlatformProcess.exe` and ACE starts `ACE-Service64.exe -autorun`.
- **Next parent test.** Start `Games.exe` alone with `--parent launcher --launcher-exe 'C:\Program Files\GRYPHLINK\1.6.0\Games.exe'`. If the game starts, the client needs no helper. Otherwise build stepministrator in the private ARM runtime pipeline with its llvm-mingw toolchain and ship it in the runtime.
- **Runtime to use.** Run the app's installed ARM runtime with `--runtime "$HOME/Library/Application Support/com.lumisxh.arknights-client/Runtimes/arm-1.0.2"`. It has `bin/wine64`, DXMT, and `winemetal`. The older catalog runtime `wine-11-22-arm64-v0-7-2-alpha-2` remains useful only for comparing Vulkan drivers; a local `bin/wine64 -> wine` symlink was added there.
- **Endfield environment.** Yaagl's Endfield defaults are `FEX_MAXINST=5000`, `FEX_MULTIBLOCK=1`, `WINE_DARWIN_SPARSE_READ=1`, `WINE_NGX_SIGNER=1`, and `GST_PLUGIN_FEATURE_RANK=atdec:MAX,avdec_h264:MAX`. Pass them with `--env`.
- **Sidecar.** Projecting the game to an iPad with Sidecar caused GPU lockups and Mac freezes. It also broke the native fullscreen Space. Test on a physical display only.

## Distribution protocol

Facts verified against the live API on 2026-11-22:

- Request: `POST https://launcher.gryphline.com/api/proxy/batch_proxy` with kind `get_latest_game`, appcode `YDUTE5gscDZ229CW`, channel `6`, and an empty `version`. Send a random `device_id` per run.
- Sub-channels `6` and `9999` return the same manifest.
- The response is `proxy_rsps[0].get_latest_game_rsp`. All numbers are strings.
- Version `1.6.4` lists 59 packs in `pkg.packs[]`. Each pack has `url`, `md5`, and `package_size`.
- The packs are one ZIP cut into byte-exact parts named `.zip.001` to `.zip.059`. Parts are 1 GiB each. The last part is about 101 MB.
- `pkg.total_size` is the installed size in bytes (130924997432). `pkg.package_type` is `ALL_PACKAGE`. `patch` is null.
- `pkg.file_path` points to an encrypted `game_files` manifest. Its MD5 is `pkg.game_files_md5`. The installer ignores its contents.
- The ZIP central directory sits at the end of the last parts. Run `install --plan` to confirm that and to list the entries.

Install flow:

1. Read the manifest. Read the ZIP central directory with HTTP Range requests on the last parts. The limit is 64 MiB of ranged bytes.
2. Download one part at a time, in order, to `<lab>/downloads/<name>.part`. Resume with Range. Verify size and MD5. Rename atomically.
3. Extract every entry whose bytes lie in parts that are on disk. Verify CRC32 and size. Write to `<file>.part`, then rename.
4. Delete a part when no unextracted entry overlaps it.
5. Save progress to `<lab>/state/install-<version>.json`. A killed install resumes without redownloading deleted parts.

Peak disk is the installed size plus about two parts. That is about 133 GB for 1.6.4. Fewer parts stay on disk when no entry spans a part boundary. An entry that spans N parts keeps N parts on disk.

Safety rules:

- The installer connects only to `launcher.gryphline.com` and `beyond.hg-cdn.com` over https. It rejects other hosts, ports, and redirects.
- It rejects absolute paths, drive letters, `..`, empty components, and symlink entries.
- It never follows a symlink under `<lab>/game`. It writes only under the lab root.
- It supports stored and deflate entries only.

## stepministrator

`stepministrator` is our own small Windows helper. We wrote it from scratch under MPL-2.0. Its name refers to reakjra/stepministrator (GPL-3.0). We did not copy code from it.

`Endfield.exe` runs only when its parent process is the official `Games.exe`. `Games.exe` alone idles. On 2026-11-22 a trace showed that it loads Qt and WinHTTP and then waits. GRYPHLINK's `Launcher.exe` drives it to start the game.

How the helper works:

1. It starts the official `Games.exe` suspended. It never runs, so it has no window, no Dock tile and no CPU. This is the approach of LLauncher's MIT `gryphlink-start`.
2. It starts `G:\Endfield.exe` with `Games.exe` as its parent process, through `PROC_THREAD_ATTRIBUTE_PARENT_PROCESS`.
3. It waits for the game to exit. Then it terminates `Games.exe`.

Start lab runs from your own terminal. Runs started from an agent's shell hang: x86_64 processes spin at about 60% CPU and show no window. All stepministrator failures logged before 2026-11-22 came from that shell, not from FEX.

Open work:

- **Shader cache.** The first start on a backend compiles shaders. On Vulkan this can take several minutes, so a slow start is not a hang. The record's `elapsedSeconds` and `gpu` counters show activity. Check that the next start reuses the cache.
- **Intro video.** After you start the game on a fresh account, the screen stays black where the intro video should play. The DXMT run on `arm-1.0.2` reached the game; its intro result is not recorded yet.
  - Media Foundation DLLs (`mf`, `mfplat`, `mfreadwrite`, `winegstreamer`) load, but `GST_DEBUG=2` shows no pipeline activity.
  - `GST_PLUGIN_FEATURE_RANK=atdec:MAX,avdec_h264:MAX` (Yaagl's setting for Endfield) did not help.
  - Next, trace with `--wine-debug "err+all,+mfplat,+loaddll"`.
  - Killing the game during shader compilation may have left a broken cache. A game repair is being tested.
  - Next, run the [Media Foundation test](#media-foundation-test).

Build the helper with ARM64 llvm-mingw. Unpack llvm-mingw into `<lab>/toolchains/` first:

```sh
uv run --locked python experiments/endfield/lab.py build-helpers
```

The output is `<lab>/prefix/drive_c/stepministrator/stepministrator.exe`. Add `--prefix NAME` to build into another prefix. Add `--dry-run` to print the compiler command only.

### Media Foundation test

[mf-install](https://github.com/Ultimator14/mf-install) copies Microsoft's native Media Foundation DLLs and its H.264 and AAC decoders into a prefix. Yaagl uses this approach. The test uses it in a cloned prefix, in place of Wine's `mf` and `winegstreamer` path.

- This is a diagnostic only. Microsoft's binaries are not licensed for this repository. Never commit or ship them.
- The test pins commit `f8d24e9b600bad038911e8618721c8bfb83872e9`. `lab.py` checks the SHA-256 of each file.
- Downloads go to `<lab>/downloads/mf-install-f8d24e9b/`. Only `raw.githubusercontent.com` is allowed.

Do not run `mf-prefix` while the source prefix runs. The clone copies a live prefix.

`mf-prefix` runs these steps:

1. Checks that the source prefix exists and the target does not. Add `--force` to replace the target.
2. Downloads the pinned files and checks their SHA-256. A failed download leaves the target untouched.
3. Clones the source prefix with `cp -c -R`. APFS copy-on-write keeps the clone small until files change.
4. Points `dosdevices/g:` at `<lab>/game`.
5. Copies the 9 DLLs to `C:\windows\system32`, the x64 set Yaagl copies. Copies `mf.reg` and `wmf.reg` to `C:\mf-install`.
6. Sets a `native` DLL override for each of the 9 DLLs.
7. Imports `mf.reg` and `wmf.reg` with `regedit`.
8. Registers `colorcnv.dll`, `msmpeg2adec.dll`, and `msmpeg2vdec.dll` with `regsvr32`.
9. Waits for `wineserver` to exit.

Each step writes its own log to `<lab>/logs/`. The command stops at the first failing step. Its message names the step and the log.

The runtime has no x86_64 `regsvr32`. Step 8 uses the ARM64 `regsvr32`, which may fail on the x64 DLLs. A failure there is only a warning. `wmf.reg` does not register the decoders, so the test is inconclusive after such a failure. Check that step's log.

Run these commands from your own terminal, not from an agent shell:

```sh
uv run --locked python experiments/endfield/lab.py mf-prefix --runtime "$HOME/Library/Application Support/EndfieldLab/runtimes/wine-11-22-arm64-v0-7-2-alpha-2/wine"
uv run --locked python experiments/endfield/lab.py launch --prefix prefix-mf --backend vulkan-kk --parent stepministrator --runtime "$HOME/Library/Application Support/EndfieldLab/runtimes/wine-11-22-arm64-v0-7-2-alpha-2/wine" --wine-debug "err+all,+mfplat,+loaddll" --env FEX_MAXINST=5000 --env FEX_MULTIBLOCK=1 --env WINE_DARWIN_SPARSE_READ=1 --env WINE_NGX_SIGNER=1
```

The clone copies `drive_c/stepministrator` from `prefix`. Run `build-helpers` first if the helper is missing.

Read the result:

- **Intro plays:** the Wine Media Foundation path (`mf` or `winegstreamer`) is the bug.
- **Still black:** the bug is not in that path. Check rendering, or video that does not use Media Foundation.

## Usage

Run every command from the repository root.

Print the help:

```sh
uv run --locked python experiments/endfield/lab.py --help
uv run --locked python experiments/endfield/lab.py launch --help
```

Create the lab prefix. Add `--force` to recreate an existing prefix:

```sh
uv run --locked python experiments/endfield/lab.py prefix --dry-run
uv run --locked python experiments/endfield/lab.py prefix
```

Print the install plan. This reads the manifest and the ZIP central directory only. It downloads no parts:

```sh
uv run --locked python experiments/endfield/lab.py install --plan
```

Install the game into `<lab>/game`. The command stops when free disk is below the estimated peak. Add `--force` to skip that check. Run it again to resume:

```sh
uv run --locked python experiments/endfield/lab.py install
```

Run the lab tests:

```sh
uv run --locked python -m pytest experiments/endfield -q
```

Build the helpers. Add `--dry-run` to print the compiler commands only:

```sh
uv run --locked python experiments/endfield/lab.py build-helpers
```

Clone a prefix with Media Foundation. Add `--dry-run` to print the steps only. See the [Media Foundation test](#media-foundation-test):

```sh
uv run --locked python experiments/endfield/lab.py mf-prefix --dry-run --runtime "$HOME/Library/Application Support/EndfieldLab/runtimes/wine-11-22-arm64-v0-7-2-alpha-2/wine"
```

Print a launch without starting it:

```sh
uv run --locked python experiments/endfield/lab.py launch \
  --backend vulkan-kk --parent direct --dry-run
```

Start the official launcher on the Vulkan backend with the ACE debug channels:

```sh
uv run --locked python experiments/endfield/lab.py launch \
  --backend vulkan-kk --parent launcher --debug ace
```

Start the game on DXMT with the app's ARM runtime. The renderer flag goes after `--`:

```sh
uv run --locked python experiments/endfield/lab.py launch \
  --backend dxmt-d3d11 --parent stepministrator \
  --runtime "$HOME/Library/Application Support/com.lumisxh.arknights-client/Runtimes/arm-1.0.2" \
  -- -force-d3d11
```

Start the game on Vulkan with the newer KosmicKrisp:

```sh
uv run --locked python experiments/endfield/lab.py launch \
  --backend vulkan-kk --parent stepministrator \
  --runtime "$HOME/Library/Application Support/com.lumisxh.arknights-client/Runtimes/arm-1.0.2" \
  -- -force-vulkan
```

Put `--dry-run` before the `--` separator. Everything after `--` goes to the game.

Options:

- `--backend`: `dxmt-d3d11`, `vkd3d-kk`, `vulkan-kk`, or `vulkan-mvk`. `vulkan-mvk` uses a lab-only MoltenVK from `<lab>/toolchains/moltenvk-*/` (KhronosGroup release, `icd.d/MoltenVK_icd.json` with an absolute library path and without `is_portability_driver`). The ARM Wine does not enumerate portability drivers, so the loader skips MoltenVK while that flag is set. On 2026-11-22 `vulkan-kk` hung the M4 GPU ("firmware-detected lockup") when the game loaded its world.
- `--parent`: `direct`, `launcher`, or `stepministrator`. Only `direct` adds the renderer flag for `--backend`. With `stepministrator`, pass `-force-d3d11` or `-force-vulkan` after `--` to select the renderer.
- `--prefix NAME`: prefix directory under the lab root. Default: `prefix`. Use one directory name; separators and `..` are rejected. Used by `prefix`, `launch`, and `build-helpers`.
- `--runtime PATH`: use a patched runtime, for example `<lab>/runtimes/<name>`. For `dxmt-d3d11`, use a runtime that bundles DXMT. The catalog `wine-11-22-arm64-v0-7-2-alpha-2` runtime has no DXMT or `winemetal`, so that backend cannot start there. The app's arm runtime (`Runtimes/arm-1.0.2`) has both.
- `--debug`: `default`, `ace`, or `vulkan`.
- `--wine-debug RAW`: set a raw `WINEDEBUG` value. It overrides `--debug`.
- `--env K=V`: add an environment entry. Repeat it for more entries.
- `--launcher-exe` and `--games-exe`: change the Windows paths of the official tools.
- `--memory-limit-gb GB`: end the lab's Wine processes when their summed resident memory exceeds this limit. Default: 12. Use `0` to disable. A run at about 22.8 GB on a 16 GB Mac hung the GPU and froze the display. The guard decision and any kill also go into the run record.
- `kill`: end the game and every process in the lab prefix. Run it over SSH when the display freezes: `uv run --locked python experiments/endfield/lab.py kill --prefix prefix-mf`. It uses the runtime of the running Wine processes, so it works without `--runtime` and when the pinned runtime is not installed.
- `collect RUN`: copy the host crash reports and the system log for a finished run. See [Collect host reports](#collect-host-reports).
- Extra arguments after `--` go to the game.

Each launch writes four files to `<lab>/logs/`:

- A `.log` file with the game output.
- A `.json` file with the exact environment, argument list, runtime path, runtime version, and prefix name.
- A `-record.jsonl` file with one host sample per second. See [Freeze recorder](#freeze-recorder).
- A timestamp in the file name, in UTC.

The `prefix` command logs `wineboot` output the same way.

### Prefix behavior

The `prefix` command:

1. Runs `wineboot.exe -u` in a new prefix.
2. Copies `DXMT/x64/*.dll` from the runtime into `drive_c/windows/system32`.
3. Links `dosdevices/g:` to `<lab>/game`.

The prefix environment reuses the launch base environment. This keeps `HOME` inside the prefix.

The `mf-prefix` command clones a prefix with `cp -c -R`. It does not run `wineboot`.

### Launch behavior

- The launcher parent starts the game itself. The lab does not pass game arguments or the renderer flag in this mode.
- The lab stops before a real launch when a required file is missing. A dry run only warns.
- A `dxmt-d3d11` launch copies `d3d10core.dll`, `d3d11.dll`, and `dxgi.dll` from the runtime's `DXMT/x64` into the prefix when they differ. A runtime without a DXMT payload fails the launch with a message that names the missing directory. A stale DXMT set fails inside the game as a UnityPlayer load error.

### Freeze recorder

Every launch writes `<lab>/logs/<run>-record.jsonl`. The run name is the log name without its suffix. The recorder samples the host once per second:

- Resident memory of every Wine process from `ps`. Wine names each Unix process after its own binary, so `Endfield.exe` does not reach `ps`. The record and the guard sum the whole prefix instead.
- Free and compressed memory, plus the swap counters, from `vm_stat`.
- Swap usage from `sysctl vm.swapusage`.
- Memory pressure from `memory_pressure -Q`.
- GPU counters from `ioreg -r -c IOAccelerator`: device utilization, in-use memory, allocated memory, and `recoveryCount`.

Each line is one JSON object. It holds a UTC timestamp, the elapsed seconds, the samples, and the guard decision. The first line also holds `processTable`: the five largest processes with their pid, resident bytes, name, and command line. Use it to check how `ps` names the game on a new runtime.

The recorder flushes and fsyncs every line, so a freeze and a hard reboot keep the record up to the last second.

The memory guard reads the same `ps` sample. When the game passes `--memory-limit-gb`, the record gets a `guard-kill` line before the lab ends the game. The warning also prints in the terminal.

`launch` fsyncs the Wine log about once per second. The log keeps its tail through a hard reboot.

### Collect host reports

After a freeze and a reboot, gather the host evidence for the run:

```sh
uv run --locked python experiments/endfield/lab.py collect 20261126T220110Z-vulkan-mvk-stepministrator
```

Use the run stamp or the full run name. `collect` writes `<lab>/logs/<run>-collect/`:

- The WindowServer, GPU, Endfield, and Wine reports from `~/Library/Logs/DiagnosticReports` and `/Library/Logs/DiagnosticReports`. It copies only reports newer than the run start.
- `log-show.txt`: the unified log from the run start to two minutes after the last record. It selects kernel GPU, WindowServer, jetsam, and memorystatus messages. `collect` converts the UTC run times to local time, which `log show` expects.
- `log-show.err`: the `log show` error output, when it writes any.

A report that needs root privileges stays in place. `collect` prints the `sudo cp` line and writes `sudo-copy.sh`. Run the line from your terminal, then copy the file into the same directory.

## Next experiments

In order:

1. **DXMT baseline.** Repeat `dxmt-d3d11` on `arm-1.0.2` and record the intro. DXMT avoids the KosmicKrisp present path.
2. **Lower shader load on Vulkan.** Set the game's lowest graphics quality and start `vulkan-kk` again. If the frame advances, the AGX compiled-variants limit is the trigger.
3. **Add a GPU allocation guard.** The memory guard sums Wine RSS only; this run grew `gpu.Alloc system memory` without moving RSS. Kill above about 10 GB, below the 12.7 GB wired limit.
4. **Retest MoltenVK.** `vulkan-mvk` on `arm-1.0.2` shows whether the stall is KosmicKrisp-specific or shared by both Vulkan drivers.
5. **Source KosmicKrisp build.** Test a Mesa newer than `arm-1.0.2` from the external builder. The target is pipeline variant caching, not only the Metal OOM path (`0db4e290`).

## Test plan

Run the steps in this order:

1. Install the game into `<lab>/game` with the throwaway account.
2. Create the prefix with `prefix`.
3. Get a baseline with the official launcher on `vulkan-kk`.
4. Get a baseline with the official launcher on `dxmt-d3d11`.
5. Record where ACE fails. Use `--debug ace`.
6. Apply the ACE patches in the private ARM Wine repository. Build a patched runtime under `<lab>/runtimes/<name>`.
7. Rerun the baseline with `--runtime`.
8. Test the `stepministrator` parent after running `build-helpers`.
9. Compare the backends on one fixed scene. Record FPS, RAM, visuals, and DLSS.

## Exit criteria

The lab moves into the client only when all of these pass:

- The game gets past ACE.
- The throwaway account signs in.
- A session runs for 30 minutes or more without a crash.
- The backend decision is recorded in the results log.

## Results log

| Date | Runtime | Backend | Parent | Outcome | Notes |
| ---- | ------- | ------- | ------ | ------- | ----- |
| 2026-11-22 | ARM 1.0.1, unpatched | vulkan-kk | launcher | In-game in a native macOS fullscreen Space. | `LMISXH_AKMOCL_FULLSCREEN=1`. After the game quits, `PlatformProcess.exe` keeps running and holds the prefix open. |
| 2026-11-22 | ARM 1.0.1, unpatched | vulkan-kk | `Games.exe` alone | No game. | `Games.exe` loads Qt and WinHTTP, then idles. |
| 2026-11-22 | ARM 1.0.1, unpatched | vulkan-kk | stepministrator (ARM64 llvm-mingw, `Games.exe` not suspended) | No game. | `Games.exe` spins while mapping `hgeventlogsdk.dll`, and `Endfield.exe` spins after `EndfieldBase.dll`, both at about 63% CPU. Invalid: started from an agent shell, which hangs Wine GUI processes. |
| 2026-11-22 | ARM 1.0.1, unpatched | vulkan-kk | stepministrator (ARM64 llvm-mingw, `Games.exe` suspended) | No game. | `Endfield.exe` spins at about 66% CPU with no loader trace. Invalid: started from an agent shell, which hangs Wine GUI processes. |
| 2026-11-22 | ARM 1.0.1, unpatched | vulkan-kk | stepministrator (x86_64 MinGW) | No game. | The helper spins at about 66% CPU and loads no DLL. It hangs before the Wine loader under FEX. Invalid: started from an agent shell, which hangs Wine GUI processes. |
| 2026-11-22 | ARM 1.0.1, unpatched | vulkan-kk | launcher | Login and in-game. ACE passed. | Game 1.6.4, GRYPHLINK 1.6.0. The launcher defaults to **Vulkan (Recommended)**. The launcher accepted the lab install at `G:\`. No macOS fullscreen Space. FPS not measured yet. |
| 2026-11-22 | ARM 1.0.1 | vulkan-kk | stepministrator (ARM64, Games.exe running, windows hidden) | In-game | Games.exe and its QtWebEngineProcess used about 160% CPU while hidden. |
| 2026-11-22 | ARM 1.0.1 | vulkan-mvk (MoltenVK 1.4.2) | stepministrator | Reached the world | Needed the ICD without is_portability_driver; Games.exe crashed in MoltenVK; game footprint about 34 GB on a 16 GB Mac; the Mac froze later (Sidecar active). |
| 2026-11-22 | ARM 1.0.1 | vulkan-kk | stepministrator | Mac froze at the world load | gpuEvent "firmware-detected lockup"; Sidecar was active. |
| 2026-11-22 | wine-11-22-arm64-v0-7-2-alpha-2 | vulkan-kk | stepministrator (Games.exe suspended) | Game starts; intro video stays black | Games.exe 0% CPU, no window, no Dock tile. |
| 2026-11-26 | wine-11-22-arm64-v0-7-2-alpha-2 | vulkan-mvk (MoltenVK 1.4.2) | stepministrator | WindowServer froze after about 15 minutes | No recorder on that run. `collect` found kernel `IOGPUCommandDescriptor::prepare` faults for `Endfield.exe` from 23:01:26 to 23:15:27, then the freeze at 23:16. |
| 2026-11-26 | wine-11-22-arm64-v0-7-2-alpha-2 | dxmt-d3d11 | stepministrator | No game: UnityPlayer 1114 | The catalog runtime has no DXMT or `winemetal`, and the prefix held stale DXMT DLLs. |
| 2026-11-26 | arm-1.0.2 | dxmt-d3d11 | stepministrator | In-game; the run lasted 116 s | The launch refreshed DXMT from the runtime. Device utilization 20–52%, `recoveryCount` 0, guard saw about 4.4 GB of Wine memory. Intro result not recorded. |
| 2026-11-26 | arm-1.0.2 | vulkan-kk | stepministrator | In-game audio; window frozen on the first in-game frame | `AGX: exceeded compiled variants footprint limit` was the last log line. The render thread stuck in `CAMetalLayer nextDrawable`; GPU allocation 3 → 65 GB while in-use stayed near 1 GB. The guard did not fire because Wine RSS stayed near 3 GB. |
