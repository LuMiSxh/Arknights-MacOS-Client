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
| Regional game files         | `InstallationController` / `GameInstaller` | Manifest-updated. **Uninstall Game** trashes only the selected directory    |
| Installed manifest state    | `GameInstaller`                            | Written atomically after all files pass validation and checksums            |
| Wine prefixes               | `GameSessionController` / `WineRuntime`    | One per publisher family. Deleting a prefix reruns its migration plan       |
| Runtime migration state     | `RuntimeMigrationStore`                    | Runtime revision and completed setup steps. It is not game-save data        |
| Bundled runtime             | Packaging and `WineRuntime`                | Read-only. A launcher update replaces it                                    |
| Downloaded official artwork | `CustomizationController` / `ArtworkCache` | Recreated when missing                                                      |
| Preset gallery cache        | `PresetCatalogService`                     | Targeted cleanup in Settings. Recreated on demand                           |
| Playtime statistics         | `PlaytimeStatisticsController`             | Versioned totals plus 31 daily buckets. Only a confirmed reset removes them |
| DXMT and browser caches     | `StorageMaintenanceController`             | Targeted cleanup across real Wine profiles. No symlink is followed          |
| Launcher and runtime logs   | `LauncherLog` and runtime process output   | **Show Logs** prepares them                                                 |
| Preferences                 | `LauncherPreferencesStore`                 | Small settings and selected paths only, in `UserDefaults`                   |

## Application Support layout migration

The publisher-based layout is a persisted path contract. On the first start after the launcher version
that introduces it, a startup migration runs before normal readiness. It blocks installation,
maintenance, and game launch until it finishes. It considers only these exact old defaults:

```text
Games/Arknights-Global          → Yostar/Global
Games/Arknights-Japan           → Yostar/Japan
Games/Arknights-Korea           → Yostar/Korea
Games/Arknights-China           → Hypergryph/China
Games/Arknights-China-Bilibili  → Hypergryph/China-Bilibili
Wine/Prefixes/Arknights-Global  → Yostar/Prefix
Wine/Prefixes/Arknights-China   → Hypergryph/Prefix
```

Rules:

- The migrator rewrites a persisted regional install path only when it exactly equals an old default
  game path. Custom paths stay untouched.
- It merges no contents and overwrites no destination.
- It moves a source only when the source is the expected directory. It accepts a destination only when
  the destination is absent or already shows the completed move.
- A collision, symbolic link, or other unexpected node is a blocking error.
- Each move is a same-volume rename, not a copy.
- The migration is idempotent. It skips completed entries and resumes partial progress on the next
  start.
- A failed move does not undo earlier moves. The migrator returns `AppStorageMigrationResult` with the
  completed moves and the first failure. The model saves the preferences of the completed moves only
  and skips the moves that follow the failure.
- A failure releases the startup activity. The launcher shows an `FS-MIG` failure with **Retry**,
  **Troubleshooting**, and **Report a problem**, and blocks game launch. **Retry** runs the migration
  again for the current failure ID only, then continues the normal startup work.

## Preferences

`LauncherPreferencesStore` owns every `UserDefaults` read and write. Only the store knows the
serialized key names and defaults. Controllers expose typed values. The store holds the selected region,
one install path per region, update and announcement switches, seen announcement IDs, launch options,
display settings, and personalization values. A region switch moves no files. Update checks never
download game data. A chosen image is copied into `Artwork/Custom`.

To add a preference, add it to the store, test it in its owning feature, and reset it in
`resetToDefaults` when appropriate. Never use a preference as a file marker or as filesystem migration state.

### Add a preferences migration

`PreferencesMigrator` runs once at launch, before the launcher reads any preference. It stores the last
applied version in one `UserDefaults` key and runs each newer step in order. Use it for a cache wipe, a
key rename, or a key removal. Filesystem moves stay in `AppStorageMigrator`. Wine prefix changes stay
in `RuntimeMigration`.

1. Open `PreferencesMigrator.swift`.
2. Append a `Step` with the next version to `steps`. Never edit a released step.
3. Call `removeKeys(withPrefix:keeping:)`, `remove(_:)`, or `rename(_:to:)` in the step body.

```swift
Step(version: 2) { $0.remove("lastAppliedDynamicIconHue") },
```

Keep the step idempotent. A fresh install runs every step on empty defaults. Every key name stays in
`LauncherPreferencesStore.Key`. Name a retired key as a literal in its step.

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
