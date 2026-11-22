# Arknights: Endfield lab

## Purpose and status

This lab tests Arknights: Endfield on the app's ARM Wine runtime.

- Status: experiment. The lab is not part of the app, SwiftPM, or CI.
- The lab moves into the client only if the exit criteria pass.
- Files: `lab.py` (CLI), `installer.py` and `zipstream.py` (streaming installer), `test_installer.py`, `fixtures/`, and this README.

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
- **Runtime graphics.** The ARM runtime 1.0.1 ships KosmicKrisp. It has `lib/libvulkan_kosmickrisp.dylib`, the Khronos loader `lib/libvulkan.1.dylib` (1.4.363), and the ICD file in `share/vulkan/icd.d/`. Wine loads `libvulkan.1.dylib`, so `VK_DRIVER_FILES` selects the driver.
- **KosmicKrisp requirements.** The driver needs macOS 26 or later and Apple silicon ([Mesa KosmicKrisp](https://docs.mesa3d.org/drivers/kosmickrisp.html)).
- **Runtime DXMT payload.** The ARM runtime 1.0.1 ships `DXMT/x64` with `d3d10core.dll`, `d3d11.dll`, and `dxgi.dll` only. DXMT has no D3D12. The `vkd3d-kk` backend uses Wine's builtin `d3d12.dll` (vkd3d) on KosmicKrisp instead. Expect the DXIL error there.
- **Platform.** Endfield ships only on the ARM runtime. It needs macOS 27 or later.
- **Anti-cheat.** ACE runs as a kernel-level driver. The community project [Endfield_FineWine](https://github.com/stoicswe/Endfield_FineWine) documents its work in `docs/technical.md`. Most of its fixes target Rosetta.
- **ACE lead.** The relevant patches for us are `ARM/stage1-macos` patches 0010 to 0013. They cover `ntoskrnl` and `wdfldr.sys` for ACE's ARM64 drivers. No report yet confirms ACE under FEX. ACE patches belong in the private ARM Wine repository.
- **Distribution API.** The launcher API is `POST https://launcher.gryphline.com/api/proxy/batch_proxy`. Use kind `get_latest_game` and appcode `YDUTE5gscDZ229CW`. Channel is 6. Sub-channel is 6 or 9999, which is unresolved.
- **Full install.** The full install is 59 split ZIP parts on `beyond.hg-cdn.com`. The download is about 62 GB. The installed size is about 68 GB. The manifest's `total_size` (about 131 GB) is the download plus the installed size. Virtual file system resources come from `get_latest_resources`.
- **Reference code.** [AugustLigh/LLauncher](https://github.com/AugustLigh/LLauncher) is an MIT reference for the API. Do not copy code from GPL or AGPL projects.
- **Parent check.** `Endfield.exe` runs only when the official `Games.exe` is its parent process ([reakjra/stepministrator](https://github.com/reakjra/stepministrator)).
- **Launch chain.** A `+process` trace of a working run shows the chain. GRYPHLINK `Launcher.exe` starts `1.6.0\Games.exe`. `Games.exe` starts `"G:\Endfield.exe" -launcher_lang=en-us -launcher_sub_channel=6` with a plain `CreateProcess`. The game gets no renderer flag; the launcher's **Rendering Mode** setting selects Vulkan. The game then starts `PlatformProcess.exe` and ACE starts `ACE-Service64.exe -autorun`.
- **Next parent test.** Start `Games.exe` alone with `--parent launcher --launcher-exe 'C:\Program Files\GRYPHLINK\1.6.0\Games.exe'`. If the game starts, the client needs no helper. Otherwise build stepministrator in the private ARM runtime pipeline with its llvm-mingw toolchain and ship it in the runtime.

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

1. It starts the official `Games.exe` suspended.
2. It starts `G:\Endfield.exe` with `Games.exe` as its parent process, through `PROC_THREAD_ATTRIBUTE_PARENT_PROCESS`.
3. It waits for the game to exit. Then it terminates the suspended `Games.exe`.

Build the helper with MinGW. Install the toolchain first with `brew install mingw-w64`:

```sh
uv run --locked python experiments/endfield/lab.py build-stepministrator
```

The output is `<lab>/bin/stepministrator.exe`. Add `--dry-run` to print the compiler command only.

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

Run the installer tests:

```sh
uv run --locked python -m pytest experiments/endfield -q
```

Build the helper into `<lab>/bin`. Add `--dry-run` to print the compiler command only:

```sh
uv run --locked python experiments/endfield/lab.py build-stepministrator
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

Options:

- `--backend`: `dxmt-d3d11`, `vkd3d-kk`, or `vulkan-kk`.
- `--parent`: `direct`, `launcher`, or `stepministrator`. Only `direct` adds the renderer flag for `--backend`. The `stepministrator` parent passes no renderer flag. The game takes its renderer from the launcher setting.
- `--runtime PATH`: use a patched runtime, for example `<lab>/runtimes/<name>`.
- `--debug`: `default`, `ace`, or `vulkan`.
- `--wine-debug RAW`: set a raw `WINEDEBUG` value. It overrides `--debug`.
- `--env K=V`: add an environment entry. Repeat it for more entries.
- `--launcher-exe` and `--games-exe`: change the Windows paths of the official tools.
- Extra arguments after `--` go to the game.

Each launch writes three files to `<lab>/logs/`:

- A `.log` file with the game output.
- A `.json` file with the exact environment, argument list, runtime path, and runtime version.
- A timestamp in the file name, in UTC.

The `prefix` command logs `wineboot` output the same way.

### Prefix behavior

The `prefix` command:

1. Runs `wineboot.exe -u` in a new prefix.
2. Copies `DXMT/x64/*.dll` from the runtime into `drive_c/windows/system32`.
3. Links `dosdevices/g:` to `<lab>/game`.

The prefix environment reuses the launch base environment. This keeps `HOME` inside the prefix.

### Launch behavior

- The launcher parent starts the game itself. The lab does not pass game arguments or the renderer flag in this mode.
- The lab stops before a real launch when a required file is missing. A dry run only warns.

## Test plan

Run the steps in this order:

1. Install the game into `<lab>/game` with the throwaway account.
2. Create the prefix with `prefix`.
3. Get a baseline with the official launcher on `vulkan-kk`.
4. Get a baseline with the official launcher on `dxmt-d3d11`.
5. Record where ACE fails. Use `--debug ace`.
6. Apply the ACE patches in the private ARM Wine repository. Build a patched runtime under `<lab>/runtimes/<name>`.
7. Rerun the baseline with `--runtime`.
8. Test the `stepministrator` parent after running `build-stepministrator`.
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
| 2026-11-22 | ARM 1.0.1, unpatched | vulkan-kk | stepministrator (ARM64 llvm-mingw, `Games.exe` not suspended) | No game. | `Games.exe` spins while mapping `hgeventlogsdk.dll`, and `Endfield.exe` spins after `EndfieldBase.dll`, both at about 63% CPU. |
| 2026-11-22 | ARM 1.0.1, unpatched | vulkan-kk | stepministrator (ARM64 llvm-mingw, `Games.exe` suspended) | No game. | `Endfield.exe` spins at about 66% CPU with no loader trace. |
| 2026-11-22 | ARM 1.0.1, unpatched | vulkan-kk | stepministrator (x86_64 MinGW) | No game. | The helper spins at about 66% CPU and loads no DLL. It hangs before the Wine loader under FEX. |
| 2026-11-22 | ARM 1.0.1, unpatched | vulkan-kk | launcher | Login and in-game. ACE passed. | Game 1.6.4, GRYPHLINK 1.6.0. The launcher defaults to **Vulkan (Recommended)**. The launcher accepted the lab install at `G:\`. No macOS fullscreen Space. FPS not measured yet. |
