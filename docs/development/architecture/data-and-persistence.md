---
title: Data and persistence
description: App-owned paths, preferences, caches, and runtime state boundaries
order: 50
---

# Data and persistence

`AppPaths` is the single resolver for locations the launcher writes on macOS. Controllers receive an
`AppPaths` value from `LauncherViewModel`. They never build paths from the working directory or a
hard-coded repository path. Tests and the isolated preview inject temporary roots through the same
initializer.

## Location contract

Default paths use the bundle identifier `com.lumisxh.arknights-client`. Settings can override the
selected region's game directory. All other locations stay app-owned. The [Storage](../../help/storage.md)
guide lists the paths. Update it in the same change as `AppPaths`.

| Data                        | Owner                                      | Lifetime                                                                    |
| --------------------------- | ------------------------------------------ | --------------------------------------------------------------------------- |
| Regional game files         | `InstallationController` / `GameInstaller` | Manifest-updated. **Uninstall Game** trashes the default folder, or only the installed files elsewhere |
| Installed manifest state    | `GameInstaller`                            | Written atomically after all files pass validation and checksums            |
| Wine prefixes               | `GameSessionController` / `WineRuntime`    | One per publisher family and lane under `Environments/`. Deleting a prefix reruns its migration plan |
| Runtime migration state     | `RuntimeMigrationStore`                    | Runtime revision and completed setup steps. It is not game-save data        |
| Downloaded runtime          | `RuntimeSelectionController`               | One version directory per lane under `Runtimes/<lane>-<version>/` and archives under `Downloads/<lane>/`. `runtime-selection.json` records the user's lane override (absent means the launcher chooses) and each installed version. The launcher ignores the legacy `selected` key as a choice and rewrites it as the effective lane. **Remove Runtime…** deletes only that lane's version directories under a per-lane lease. The game environment and selection stay |
| Application Support folder  | `StorageMaintenanceController`             | **Show in Finder** under Settings → Storage → Logs and data opens `applicationSupportRoot` |
| Downloaded official artwork | `CustomizationController` / `ArtworkCache` | Recreated when missing                                                      |
| Preset gallery cache        | `PresetCatalogService`                     | Targeted cleanup in Settings. Recreated on demand                           |
| Playtime statistics         | `PlaytimeStatisticsController`             | Versioned totals plus 31 daily buckets. Only a confirmed reset removes them |
| DXMT and browser caches     | `StorageMaintenanceController`             | Targeted cleanup across real Wine profiles. No symlink is followed          |
| Launcher and runtime logs   | `LauncherLog` and runtime process output   | **Show Logs** prepares them                                                 |
| Preferences                 | `LauncherPreferencesStore`                 | Small settings and selected paths only, in `UserDefaults`                   |

## Application Support layout migration

`layout.json` records the Application Support layout with `schemaVersion`. When the file is missing,
`LayoutMigrator` runs once before normal readiness. It blocks installation, maintenance, and game
launch until it finishes. It moves the released 0.6/0.7 layout to the flat by-type layout:

```text
Yostar/Global          → Games/global
Yostar/Japan           → Games/japan
Yostar/Korea           → Games/korea
Gryphline/Taiwan       → Games/taiwan
Hypergryph/China       → Games/china
Hypergryph/China-Bilibili → Games/china-bilibili
Yostar/Prefix          → Environments/yostar-x86
Yostar/Prefix-ARM64    → Environments/yostar-arm
Artwork/Custom/<file>  → Artwork/<file>
playtime-v1.json       → playtime.json
```

Rules:

- The migrator rewrites a persisted regional install path only when it exactly equals an old default
  game path. Custom paths stay untouched.
- It merges no contents and overwrites no destination.
- It moves a source only when the source exists and the destination does not. A destination that
  already exists while its source exists is a blocking error.
- A collision, symbolic link, or other unexpected node is a blocking error.
- Each move is a same-volume rename, not a copy.
- Inside each moved prefix, it rewrites an absolute `dosdevices` link whose target points into a moved
  game directory. The log drive and relative links stay unchanged.
- The migration is idempotent. It skips completed entries and resumes partial progress on the next
  start. It writes `layout.json` last.
- A failed step does not undo earlier moves. The migrator returns `LayoutMigrationResult` with the
  completed moves and the first failure. The model saves the preferences of the completed moves only
  and skips the steps that follow the failure.
- It also deletes pre-release 0.8 leftovers that never shipped: `storage-overview-cache.json`,
  old-shape `Runtimes/<lane>/` directories, `Runtimes/.downloads`,
  `Runtimes/.staging`, `Caches/<bundle>/Artwork/Downloaded`, and `Caches/<bundle>/PresetGallery`. It
  clears recorded runtime versions, so a runtime downloads again.
- The pre-0.5 layout (`Games/Arknights-*` or `Wine/Prefixes/*` directories) is not migrated. Startup
  shows a blocking **Data from an old launcher version** notice with **Delete Data Folder** and
  **Quit**, and nothing else starts. **Delete Data Folder** asks for confirmation, then
  `LegacyDataEraser` removes the contents of the Application Support and Caches roots without
  following symlinks. Startup writes `layout.json` and continues as a fresh install; a failure shows
  **Try Again** and **Quit**.
- Leftover legacy `Games/` and `Wine/` trees that hold only `.DS_Store` files and empty directories
  are metadata, not old data. The migration removes them before it creates the new `Games/`.
- A failure releases the startup activity. The launcher shows an `FS-MIG` failure with **Retry**,
  **Troubleshooting**, and **Report a problem**, and blocks game launch. **Retry** runs the migration
  again for the current failure ID only, then continues the normal startup work.

## Preferences

`LauncherPreferencesStore` owns every `UserDefaults` read and write. Only the store knows the
serialized key names and defaults. Controllers expose typed values. The store holds the selected region,
one install path per region, update and announcement switches, seen announcement IDs, launch options,
display settings, and personalization values. A region switch moves no files. Update checks never
download game data. A chosen image is copied into `Artwork/`.

To add a preference, add it to the store, test it in its owning feature, and reset it in
`resetToDefaults` when appropriate. Never use a preference as a file marker or as filesystem migration state.

### Add a preferences migration

`PreferencesMigrator` runs once at launch, before the launcher reads any preference. It stores the last
applied version in one `UserDefaults` key and runs each newer step in order. Use it for a cache wipe, a
key rename, or a key removal. Filesystem moves stay in `LayoutMigrator`. Wine prefix changes stay
in `RuntimeMigration`.

1. Open `PreferencesMigrator.swift`.
2. Append a `Step` with the next version to `steps`. Never edit a released step.
3. Call `removeKeys(withPrefix:keeping:)`, `remove(_:)`, or `rename(_:to:)` in the step body.

```swift
Step(version: 2) { $0.remove("lastAppliedDynamicIconHue") },
```

Keep the step idempotent. A fresh install runs every step on empty defaults. Every key name stays in
`LauncherPreferencesStore.Key.Name`. Name a retired key as a literal in its step.

## Runtime state and atomicity

The installer and runtime use small files to make long-running work restartable:

1. The installer downloads a game file to a sibling path with the `.part` suffix.
2. It verifies the size and provider checksum (CRC64 or MD5), then moves the file to its destination.
3. After all manifest entries pass verification, it writes the version, source, install time, and
   manifest files to `.arknights-client-state.json` atomically.
4. Prefix setup records each completed migration in `.arknights-runtime-migrations.json` atomically. See
   [Preparation and migrations](wine-prefix.md#preparation-and-migrations).

Playtime uses a separate versioned JSON document:

- All-time regional totals stay exact. Daily aggregates have at most 31 entries.
- The controller writes an active-session marker when a game window first becomes visible. The duration
  uses monotonic uptime, not wall-clock subtraction.
- After an unclean launcher exit, the marker is discarded and no time is guessed.
- Every normal terminal path writes the completed session atomically before the launcher returns to
  idle.

Never treat a `.part` file, an old migration marker, or an executable's presence as proof of a usable
installation. The launcher requires the final manifest state and the executable.

## Rules for new persisted data

1. Classify the data as user data, runtime state, a cache, or a preference. The class sets ownership and
   removal behavior.
2. Add the path to `AppPaths`, or the preference to `LauncherPreferencesStore`. Never build another
   Application Support, Caches, or Logs location.
3. Use atomic writes for state that controls recovery.
4. Never follow symlinks when you validate game destinations or measure caches.
5. Document the location in [Storage](../../help/storage.md). Add a focused test when the change affects
   recovery or safety.
