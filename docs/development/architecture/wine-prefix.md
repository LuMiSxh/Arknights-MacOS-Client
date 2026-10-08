---
title: Wine prefix architecture
description: Prefix topology, isolation, migrations, persistent state, and maintenance boundaries
order: 35
audience: developers
toc: true
---

# Wine prefix architecture

A Wine prefix is the mutable Windows environment of the bundled runtime. It holds the Wine registry,
Windows profiles, embedded-browser sessions, DXMT libraries, caches, and launcher migration state. The
runtime is read-only in the app bundle. Prefixes persist below Application Support across launcher
updates.

- [`GameSessionController`](../../../Sources/ArknightsClient/Features/Game/Runtime/GameSessionController.swift)
  owns preparation and process lifetime.
- [`WineRuntime`](../../../Sources/ArknightsClient/Features/Game/Runtime/WineRuntime.swift) implements
  setup and process operations.
- [`AppPaths`](../../../Sources/ArknightsClient/Shared/Persistence/AppPaths.swift) is the only source
  of prefix locations.

## Prefix topology

Each publisher family has its own prefix. Windows-side state, logins, registry, and processes never mix
across families.

| Region family              | Default prefix                                                                 |
| -------------------------- | ------------------------------------------------------------------------------ |
| Global, Japan, and Korea   | `~/Library/Application Support/com.lumisxh.arknights-client/Yostar/Prefix`     |
| Taiwan                     | `~/Library/Application Support/com.lumisxh.arknights-client/Gryphline/Prefix`  |
| China and China (Bilibili) | `~/Library/Application Support/com.lumisxh.arknights-client/Hypergryph/Prefix` |

- Resolve the active path with `AppPaths.winePrefix(for:)`. Never select a directory name in other code.
- Tests and the isolated preview inject temporary `AppPaths` roots.
- The launcher permits one install, maintenance operation, or Wine-backed session at a time. A session
  keeps its launch-time region and prefix until prefix-wide shutdown finishes.

## Directory and drive contract

The launcher owns this structure inside Wine's prefix:

```text
{Yostar,Gryphline,Hypergryph}/Prefix/
├── .arknights-runtime-migrations.json
├── dosdevices/
│   ├── c: -> ../drive_c
│   ├── g: -> selected regional game directory
│   └── l: -> ~/Library/Logs/com.lumisxh.arknights-client
├── drive_c/
│   ├── users/<profile>/
│   └── windows/{system32,syswow64}/
└── home/
    ├── .cache/dxmt/
    ├── .config/user-dirs.dirs
    ├── .local/{share,state}/
    ├── runtime/
    └── tmp/
```

[`WinePrefixConfigurator`](../../../Sources/ArknightsClient/Features/Game/Runtime/WinePrefixConfigurator.swift)
reconciles drive mappings before every launch:

- It keeps `C:` inside the prefix, points `G:` at only the selected region's game directory, and points
  `L:` at the central log directory.
- It removes every other mapping, including Wine's default `Z:` mapping to the macOS root.

A region switch changes `G:` and moves no game files.

For the current macOS username and for `crossover`, the launcher replaces Wine's default Desktop,
Documents, Downloads, Music, Pictures, and Videos links with real directories inside the prefix. Never
redirect them into the user's macOS home.

> [!WARNING]
> The private home and reduced drive map limit Windows-path access. They are not a macOS sandbox. Wine
> and native runtime libraries run with the launcher user's permissions.

## Environment isolation

[`WineRuntime+Environment.swift`](../../../Sources/ArknightsClient/Features/Game/Runtime/WineRuntime+Environment.swift)
builds the environment from an empty dictionary. It inherits only `LANG`, `LC_ALL`, `LC_CTYPE`, and
`__CF_USER_TEXT_ENCODING`, when present. It forwards no other launcher variable. It:

- assigns `HOME`, `WINEHOMEDIR`, and `CFFIXED_USER_HOME` to `<prefix>/home`, and `WINEPREFIX` to the
  selected prefix;
- keeps XDG, GStreamer, and DXMT cache, configuration, data, state, and runtime paths below the private
  home, and `TMPDIR`, `TMP`, and `TEMP` below `<prefix>/home/tmp`;
- restricts `PATH` to the bundled runtime, `/usr/bin`, and `/bin`;
- points the dynamic-library fallback path at the bundled runtime libraries;
- adds only launcher-owned synchronization, diagnostics, icon, audio, and cursor overrides for the
  current launch.

Launch-scoped options (MSYNC or ESYNC, Mac pointer) change only the next process environment, not
migrations. The environment always enables the default macOS audio output follow.

## Preparation and migrations

`WineRuntime.preparePrefixIfNeeded` runs ordered, recorded migrations (below). It also reconciles
volatile drive mappings and private shell folders on every launch.

Migration state lives in `.arknights-runtime-migrations.json`. The effective runtime revision is:

```text
<runtime archive SHA-256>-prefix-<prefixRevision>
```

The plan comes from the bundled runtime, not the game version. The ordered migrations are:

1. `initialize-wine-prefix` runs `wineboot.exe -u`.
2. `install-dxmt` copies the bundled x64 DXMT libraries into `system32`. The launcher no longer
   installs or needs the x32 set. Step 5 removes copies from earlier builds.
3. `configure-registry` installs stable DLL overrides, disables Wine's crash dialog, and maps the
   Command keys to Control.
4. `share-runtime-libraries` (`WinePrefixLibraryDeduplicator`) replaces `system32` and `syswow64` files
   that are byte-identical to the runtime's `lib/wine/x86_64-windows` and `i386-windows` builtins with
   APFS clones. It is appended last, so prefixes from earlier builds replay only this step. It skips
   DXMT files. If the volume cannot clone, the copies stay and launch continues.
5. `remove-legacy-32-bit-libraries` (`WinePrefixLegacyLibraryCleaner`) runs only when the runtime has
   no `lib/wine/i386-windows` (runtime 0.7.0 and later). It removes from `syswow64` only top-level regular
   files with Wine's builtin marker (`Wine builtin DLL` at offset 0x40 of a PE file) and the
   DXMT library names the launcher installed there. It keeps everything else. It is best effort:
   failures are logged and launch continues. Cancellation leaves the step pending.

Registry work runs as one generated `.reg` script through one `regedit.exe`. The script lives in the
prefix's Windows temp directory, because `regedit.exe` accepts only Windows paths, and is removed after use.

Replay rules:

- Each step is written atomically. An interruption resumes at the first incomplete step.
- A different runtime archive checksum or `prefixRevision` starts the complete plan.
- Missing or stale DXMT files invalidate `install-dxmt` and every later step.
- A new migration ID runs only that step.
- Legacy single-file markers (version 0.1) are imported once and removed.

`prefixRevision` is a revision of the prefix contract, not the runtime version. Do not increment it when
Wine or DXMT changes, because the archive checksum already changes the effective revision. Increment it
only to replay the whole plan for unchanged runtime bytes.

The launcher writes display settings (Retina mode, `LogPixels`, precise scrolling) separately, through
the same script path, only when the registry value differs.

## Persistent and recreatable state

| State                         | Location                                                          | Lifetime                             |
| ----------------------------- | ----------------------------------------------------------------- | ------------------------------------ |
| Wine registry                 | `<prefix>/*.reg`                                                  | Persistent; removed with the prefix  |
| Browser profiles and sessions | `<prefix>/drive_c/users/<profile>`                                | Persistent; deleting signs users out |
| DXMT libraries                | `<prefix>/drive_c/windows/{system32,syswow64}`                    | Reconciled from the runtime          |
| DXMT shader cache             | `<prefix>/home/.cache/dxmt`                                       | Recreatable by cache cleanup         |
| Browser caches                | `<prefix>/drive_c/users/<profile>/AppData/Local/cache`            | Recreatable by cache cleanup         |
| Migration state               | `<prefix>/.arknights-runtime-migrations.json`                     | Reset by **Rebuild…**; recreated     |
| Regional game files           | Publisher folder or custom path, outside the prefix               | Owned by installation                |
| Runtime binaries              | App bundle, outside the prefix                                    | Replaced with the launcher           |
| Runtime and game logs         | `~/Library/Logs/com.lumisxh.arknights-client`, outside the prefix | Mapped as `L:`                       |

Cache discovery accepts only real directories inside the resolved prefix and never follows symbolic
links. Prefix maintenance keeps this rule.

## Process ownership and shutdown

The direct Wine process and the prefix-wide `wineserver` answer different questions:

- The direct process reports if startup failed or `Arknights.exe` exited.
- `wineserver -k` requests prefix shutdown. Its exit means the request was issued, not completed.
- A bounded `wineserver -w` wait completes after wineserver releases the server lock.

The launcher does not return to Idle when only the direct process or `-k` exits. Every callback is
scoped to the session UUID that captured the region and prefix. **Stop**, launch cancellation,
visible-window timeout, normal game exit, and app termination all request prefix-scoped shutdown. See
[Failure and shutdown behavior](launch-and-process-lifecycle.md#failure-and-shutdown-behavior) for the
stop sequence, deadline, and retry rules.

## Compatibility reconciliation

Game-directory compatibility components are separate from prefix migrations. `GameCompatibilityManager`
reconciles them before every launch, because the official updater can replace Vuplex or PlatformProcess
at any time. See [Launch and process lifecycle](launch-and-process-lifecycle.md).

DXMT is prefix-owned and follows the migration path, because its Windows DLLs live in `drive_c`. Runtime
Wine and DXMT patches stay in the bundled runtime. The launcher never copies them into game files.

## Maintenance operations

- **Rebuild…** removes only current and legacy migration bookkeeping. The next launch reruns Wine
  initialization, DXMT installation, and registry configuration. Profiles, sessions, unrelated registry
  data, and game files stay.
- **Delete Environment…** removes the whole prefix of the selected region family on a background task:
  the shared Yostar prefix (with all its browser sessions) for Global, Japan, or Korea; the Gryphline
  prefix for Taiwan; the shared Hypergryph prefix for either China client. Game installations,
  preferences, artwork, and central logs stay outside every prefix.

Both operations require an idle lifecycle. Never delete files directly from UI code. Route maintenance
through `GameSessionController` to keep lifecycle ownership and error presentation.

## Change checklist

When you change the prefix contract:

1. Keep locations in `AppPaths`. For a path contract change, define and test an explicit migration.
2. Choose one: recorded migration, per-launch reconciliation, or launch-scoped environment option. Never
   use migration state for volatile configuration.
3. Preserve the migration order and atomic state write. Add a migration identifier when only new work
   must run. Change `prefixRevision` only to replay the whole plan without a checksum change.
4. Keep the selected prefix and session UUID captured across every suspension and callback.
5. Preserve the private homes, the `G:` and `L:` mappings, the removal of `Z:`, and the rule that
   unknown files are never overwritten.
6. Keep prefix-wide shutdown as the terminal ownership boundary.
7. Update [Runtime compatibility](../../help/runtime-compatibility.md), [Storage](../../help/storage.md),
   and [Data and persistence](data-and-persistence.md) when a user-visible path, reset consequence, or
   persistence rule changes.

Tests: `RuntimeMigrationTests`, `WinePrefixConfiguratorTests`, `WineRuntimeTests`,
`GameSessionRecoveryTests`, `GameSessionTerminationTests`, `GameCacheCleanerTests`, and `AppPathsTests`.
Run `just check`. Runtime archive or live Wine changes also need the manual matrix in
[Testing architecture](../testing.md). Unit tests do not launch Wine.
