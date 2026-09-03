---
title: Wine prefix architecture
description: Prefix topology, isolation, migrations, persistent state, and maintenance boundaries
order: 35
audience: developers
toc: true
---

# Wine prefix architecture

A Wine prefix is the mutable Windows environment used by the bundled runtime. It contains Wine's
registry, Windows user profiles, embedded-browser sessions, installed DXMT libraries, caches, and
launcher migration state. It is not the runtime itself: the runtime is read-only inside the app
bundle, while prefixes persist below Application Support across launcher updates.

[`GameSessionController`](../../../Sources/ArknightsClient/Features/Game/Runtime/GameSessionController.swift)
owns prefix preparation and process lifetime. [`WineRuntime`](../../../Sources/ArknightsClient/Features/Game/Runtime/WineRuntime.swift)
implements setup and process operations, and [`AppPaths`](../../../Sources/ArknightsClient/Shared/Persistence/AppPaths.swift)
is the only source of prefix locations.

## Prefix topology

The stable Yostar regions share one historical prefix. The China and China — Bilibili clients share
a separate Hypergryph prefix so their Windows-side state, login sessions, registry, and runtime
processes cannot mix with the Yostar regions.

| Region family              | Default prefix                                                                              |
| -------------------------- | ------------------------------------------------------------------------------------------- |
| Global, Japan, and Korea   | `~/Library/Application Support/com.lumisxh.arknights-client/Yostar/Prefix`     |
| China and China — Bilibili | `~/Library/Application Support/com.lumisxh.arknights-client/Hypergryph/Prefix` |

Code must resolve the active path through `AppPaths.winePrefix(for:)` instead of selecting a directory
name itself. Tests and the isolated preview inject temporary `AppPaths` roots and must use the same
resolver.

The launcher permits only one install, maintenance operation, or Wine-backed session at a time.
Changing the selected region cannot transfer an active session to another prefix. The session keeps
the region and prefix captured at launch until prefix-wide shutdown finishes.

## Directory and drive contract

Wine creates most of the prefix contents. The launcher owns the following additional structure and
mappings:

```text
{Yostar,Hypergryph}/Prefix/
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
reconciles drive mappings before every launch. It preserves `C:`, points `G:` at only the selected
region's game directory, points `L:` at the central log directory, and removes every other mapping,
including Wine's default `Z:` mapping to the macOS filesystem root. A region switch therefore changes
`G:` without moving or merging game files.

Wine may seed profiles for both the current macOS username and `crossover`. For both profiles, the
launcher replaces Wine's default Desktop, Documents, Downloads, Music, Pictures, and Videos links
with real directories inside the prefix. These paths must never be redirected back into the user's
macOS home directory.

> [!WARNING]
> The private home and reduced drive map limit normal Windows-path access, but they are not a macOS
> sandbox. Wine and native runtime libraries still execute with the launcher's user permissions.

## Environment isolation

[`WineRuntime+Environment.swift`](../../../Sources/ArknightsClient/Features/Game/Runtime/WineRuntime+Environment.swift)
constructs the environment from an empty dictionary. It inherits only `LANG`, `LC_ALL`, `LC_CTYPE`,
and `__CF_USER_TEXT_ENCODING` when present. It does not forward arbitrary variables from the launcher.

The constructed environment:

- assigns `HOME`, `WINEHOMEDIR`, and `CFFIXED_USER_HOME` to `<prefix>/home`;
- assigns `WINEPREFIX` to the selected prefix;
- keeps XDG cache, configuration, data, state, and runtime paths below the private home;
- keeps `TMPDIR`, `TMP`, and `TEMP` below `<prefix>/home/tmp`;
- keeps GStreamer and DXMT caches below the private home;
- restricts `PATH` to the bundled runtime, `/usr/bin`, and `/bin`;
- points the dynamic-library fallback path at the bundled runtime libraries; and
- adds only launcher-owned synchronization, diagnostics, icon, audio, and frame-latency overrides
  for the current launch.

Launch-scoped options are not prefix migrations. For example, selecting MSYNC or ESYNC, changing
frame latency, or following the default audio output changes the next process environment without
rewriting migration history.

## Preparation and migrations

Before starting the game, `WineRuntime.preparePrefixIfNeeded` performs two kinds of work:

1. Ordered, recorded migrations initialize Wine, install DXMT, and configure stable registry
   overrides.
2. Reconciliation updates volatile drive mappings and private shell folders on every launch.

Migration state lives in `.arknights-runtime-migrations.json`. Its effective runtime revision is:

```text
<runtime archive SHA-256>-prefix-<prefixRevision>
```

The current ordered migration identifiers are:

1. `initialize-wine-prefix` runs `wineboot.exe -u`.
2. `install-dxmt` copies the bundled x64 and x32 DXMT libraries into `system32` and `syswow64`.
3. `configure-registry` installs stable DLL overrides, disables Wine's crash dialog, and maps the
   Command keys to Control.

Each successful step is written atomically. An interruption resumes at the first incomplete step.
A different runtime archive checksum or `prefixRevision` starts a complete plan for that runtime;
missing or stale DXMT files invalidate `install-dxmt` and every later step. Legacy single-file
markers are imported once and then removed.

`prefixRevision` is a prefix-contract revision, not the runtime's version number. Do not increment
it merely because Wine or DXMT changed: the archive checksum already changes the effective runtime
revision. Increment it only when unchanged runtime bytes must replay the entire prefix plan because
the launcher's prefix contract changed.

Display settings are reconciled separately. Retina mode, `LogPixels`, and precise scrolling are
written only when their current registry values differ from the selected launch configuration.

## Persistent and recreatable state

| State                         | Location                                                               | Lifetime                                          |
| ----------------------------- | ---------------------------------------------------------------------- | ------------------------------------------------- |
| Wine registry                 | `<prefix>/*.reg`                                                       | Persistent; removed only with the prefix          |
| Browser profiles and sessions | `<prefix>/drive_c/users/<profile>`                                     | Persistent; deleting the prefix signs users out   |
| DXMT libraries                | `<prefix>/drive_c/windows/{system32,syswow64}`                         | Reconciled from the bundled runtime               |
| DXMT shader cache             | `<prefix>/home/.cache/dxmt`                                            | Recreatable through targeted cache cleanup        |
| Browser caches                | `<prefix>/drive_c/users/<profile>/AppData/Local/cache`                 | Recreatable through targeted cache cleanup        |
| Migration state               | `<prefix>/.arknights-runtime-migrations.json`                          | Reset by **Force Migration**; recreated on launch |
| Regional game files           | Outside the prefix under the publisher folder or a selected custom path | Owned by installation, not prefix maintenance     |
| Runtime binaries              | Outside the prefix in the app bundle                                   | Replaced only with the launcher application       |
| Runtime and game logs         | Outside the prefix under `~/Library/Logs/com.lumisxh.arknights-client` | Shared diagnostic destination mapped as `L:`      |

Cache discovery accepts only real directories contained by the resolved prefix and does not follow
symbolic links. Prefix maintenance must preserve the same containment rule.

## Process ownership and shutdown

The direct Wine process and the prefix-wide `wineserver` answer different questions. The direct
process reports whether game startup failed or `Arknights.exe` exited. `wineserver -w` observes the
entire prefix, including browser and notice helpers. The launcher does not return to Idle merely
because the direct process ended.

Every callback is scoped to the session UUID that captured the region and prefix. A stale callback
cannot clear a newer session's state. **Stop**, launch cancellation, visible-window timeout, normal
game exit, and app termination all converge on prefix-scoped cleanup. The controller retains prefix
ownership until `wineserver` confirms shutdown or the bounded termination escalation finishes.

See [Launch and process lifecycle](launch-and-process-lifecycle.md) for the complete session state
machine and failure behavior.

## Compatibility reconciliation

Game-directory compatibility components are intentionally separate from prefix migrations. The
official updater may replace Vuplex or PlatformProcess at any time, so
`GameCompatibilityManager` reconciles active components before every launch and restores active or
retired components before install, update, or repair. Ownership markers allow the launcher to touch
only its own wrappers, DLLs, and bridges; unknown files remain untouched.

DXMT is prefix-owned and follows the migration path because its Windows DLLs live in `drive_c`.
Runtime-level Wine and DXMT patches remain in the bundled runtime and are never copied into game
files.

## Maintenance operations

**Force Migration** removes only current and legacy migration bookkeeping. The next launch reruns
Wine initialization, DXMT installation, and registry configuration while preserving profiles,
sessions, registry data unrelated to those settings, and game files.

**Delete Wine Prefix** removes the selected region family's complete prefix on a background task.
For Global, Japan, or Korea, that means the shared Yostar prefix and all browser sessions stored in
it. For either China client, it means the shared Hypergryph prefix. Game installations,
launcher preferences, artwork, and central logs remain outside either prefix.

Both operations require an idle lifecycle. Do not add a direct filesystem deletion path in UI code;
route maintenance through `GameSessionController` so lifecycle ownership and error presentation
remain intact.

## Change checklist

When changing the prefix contract:

1. Keep locations in `AppPaths`; when a path contract changes, define and test an explicit migration.
2. Decide whether the change is a recorded migration, per-launch reconciliation, or a launch-scoped
   environment option. Do not use migration state for volatile configuration.
3. Preserve the migration order and atomic state write. Add a new migration identifier when only
   new work must run; change `prefixRevision` only when the whole plan must replay without a runtime
   checksum change.
4. Keep the selected prefix and session UUID captured across every suspension and callback.
5. Preserve private home directories, the `G:` and `L:` mappings, removal of `Z:`, and the rule that
   unknown files are not overwritten.
6. Keep prefix-wide shutdown as the terminal ownership boundary.
7. Update [Runtime compatibility](../../help/runtime-compatibility.md),
   [Storage](../../help/storage.md), and [Data and persistence](data-and-persistence.md) when a
   user-visible path, reset consequence, or persistence rule changes.

Focused coverage lives in `RuntimeMigrationTests`, `WinePrefixConfiguratorTests`,
`WineRuntimeTests`, `GameSessionRecoveryTests`, `GameSessionTerminationTests`, `GameCacheCleanerTests`,
and `AppPathsTests`. Run `just check` for deterministic native and script checks. Changes to the
runtime archive or live Wine behavior additionally require the manual compatibility matrix in
[Testing architecture](../testing.md); unit tests do not launch Wine.
