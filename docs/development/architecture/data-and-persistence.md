---
title: Data and persistence
description: App-owned paths, preferences, caches, and runtime state boundaries
order: 50
---

# Data and persistence

`AppPaths` is the single resolver for locations the launcher writes on macOS. Controllers receive an
`AppPaths` value from [`LauncherViewModel`](../../../Sources/ArknightsClient/Features/Launcher/State/LauncherViewModel.swift).
They never build paths from the working directory or a hard-coded repository path. Tests and the
isolated preview inject temporary roots through the same initializer.

## Location contract

Default paths use the bundle identifier `com.lumisxh.arknights-client`. Settings can override the
selected region's game directory. All other locations stay app-owned.

| Data                        | Default location                                                                                                                              | Owner                                      | Removal or update behavior                                                                                                   |
| --------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------- |
| Regional game files         | `~/Library/Application Support/com.lumisxh.arknights-client/{Yostar/{Global,Japan,Korea},Gryphline/Taiwan,Hypergryph/{China,China-Bilibili}}` | `InstallationController` / `GameInstaller` | Manifest-updated; **Uninstall Game** trashes only the selected directory                                                     |
| Installed manifest state    | `.arknights-client-state.json` inside that regional directory                                                                                 | `GameInstaller`                            | Written atomically after all files pass validation and checksums                                                             |
| Wine prefixes               | `~/Library/Application Support/com.lumisxh.arknights-client/{Yostar,Gryphline,Hypergryph}/Prefix`                                             | `GameSessionController` / `WineRuntime`    | Shared per publisher family; deleting reruns its migration plan                                                              |
| Runtime migration state     | `.arknights-runtime-migrations.json` inside the Wine prefix                                                                                   | `RuntimeMigrationStore`                    | Runtime revision and completed setup steps; not game-save data                                                               |
| Bundled runtime             | `Contents/Resources/Runtime` inside the app bundle                                                                                            | Packaging and `WineRuntime`                | Read-only; replaced by launcher update                                                                                       |
| Downloaded official artwork | `~/Library/Caches/com.lumisxh.arknights-client/Artwork/Downloaded`                                                                            | `CustomizationController` / `ArtworkCache` | Recreated when missing; not needed for game files                                                                            |
| Preset gallery cache        | `~/Library/Caches/com.lumisxh.arknights-client/PresetGallery`                                                                                 | `PresetCatalogService`                     | Targeted cleanup in Settings; recreated on demand                                                                            |
| Playtime statistics         | `~/Library/Application Support/com.lumisxh.arknights-client/playtime-v1.json`                                                                 | `PlaytimeStatisticsController`             | Versioned totals plus 31 daily buckets; removed only by confirmed reset                                                      |
| DXMT and browser caches     | `<prefix>/home/.cache/dxmt` and `<prefix>/drive_c/users/<profile>/AppData/Local/cache`                                                        | `StorageMaintenanceController`             | Targeted cleanup across real Wine profiles; no symlinks followed                                                             |
| Launcher and runtime logs   | `~/Library/Logs/com.lumisxh.arknights-client`                                                                                                 | `LauncherLog` and runtime process output   | `launcher.log`, publisher logs including `arknights-gryphline.log`, `unity.log`, `chromium.log`; **Show Logs** prepares them |
| Preferences                 | `UserDefaults`                                                                                                                                | `LauncherPreferencesStore`                 | Small settings and selected paths only                                                                                       |

The table mirrors [`AppPaths.swift`](../../../Sources/ArknightsClient/Shared/Persistence/AppPaths.swift)
and [`StorageOverviewResolver`](../../../Sources/ArknightsClient/Features/Game/Storage/StorageOverview.swift).
When the implementation changes, update the [Storage](../../help/storage.md) guide in the same change.

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
- A collision, symbolic link, or other unexpected node is a blocking error. The user must resolve or
  report it.
- Each move is a same-volume metadata rename, not a copy.
- The migration is idempotent. It skips completed entries and resumes partial progress on the next
  start.
- It finishes before the app publishes normal readiness, so no installer or Wine operation sees a
  half-migrated path set.

> [!IMPORTANT]
> Keep path construction centralized. A new feature receives `AppPaths` or a narrower URL dependency
> from the composition root. It never invents another Application Support, Caches, or Logs location.
> This keeps cleanup, storage measurement, previews, and tests aligned.

## Preferences

`LauncherPreferencesStore` owns every `UserDefaults` read and write. Controllers expose typed values and
apply side effects when a setting changes. Persisted groups:

| Group                    | Examples                                                                     | Notes                                                                         |
| ------------------------ | ---------------------------------------------------------------------------- | ----------------------------------------------------------------------------- |
| Region and locations     | selected region, one install path per region                                 | A region switch changes the active game path and moves no files               |
| Update and communication | automatic launcher/game checks, announcements enabled, seen announcement IDs | Update checks never download game data without an install/update action       |
| Launch and display       | launch options, rendering mode, display note, dynamic theme                  | Launch options are encoded as data; no paths or runtime state inside          |
| Personalization          | dynamic-theme accent snapshots, music URL/volume, playback visibility        | A chosen image is copied into `Artwork/Custom`; the original stays user-owned |

Only the store knows the serialized key names and defaults. To add a preference, add it to the store,
cover it in its owning feature's tests, and reset it in `resetToDefaults` when appropriate. Never use a
preference as a file marker or migration state: those need different recovery and atomicity.

## Runtime state and atomicity

The installer and runtime use small files to make long-running work restartable:

1. The installer downloads a manifest file to a sibling path with the `.part` suffix.
2. It verifies the size and provider checksum (CRC64 or MD5), then moves the file to its destination.
3. After every manifest entry completes, it writes the version, source, install time, and manifest files
   to `.arknights-client-state.json` atomically.
4. Prefix setup records each completed migration in `.arknights-runtime-migrations.json` atomically. A
   runtime archive checksum or `prefixRevision` change invalidates the plan. The next launch reconciles
   it.

Playtime uses a separate versioned JSON document:

- All-time regional totals stay exact. Daily aggregates have at most 31 entries.
- The controller writes an active-session marker when a game window first becomes visible. The duration
  uses monotonic uptime, not wall-clock subtraction.
- After an unclean launcher exit, the marker is discarded and no time is guessed.
- Every normal terminal path writes the completed session atomically before the launcher returns to idle.

> [!CAUTION]
> Never treat a `.part` file, an old migration marker, or an executable's presence as proof of a usable
> installation. The launcher requires the final manifest state and the executable, and validates the
> prefix migration state before it starts Wine. Recover through the owning controller, so partial work
> stays resumable.

## Ownership and removal

User data, game data, runtime state, and recreatable caches stay separate for targeted maintenance:

- **Uninstall Game** recycles the game directory of the selected region. It does not delete the
  shared Wine prefix, other regional installations, preferences, artwork, or logs.
- **Clear Caches** removes only DXMT and embedded-browser cache directories that resolve inside the
  prefix. It does not remove saves, installed game files, or the prefix.
- **Clear gallery cache** removes preset catalog and image cache data. It does not remove app-owned
  copies of selected artwork or icon sources, generated icons, or the user's original files.
- **Delete Wine prefix** removes the shared Windows runtime state of the selected publisher family.
  The next launch recreates it and reruns Wine initialization, DXMT installation, and registry
  configuration.
- **Reset Statistics** removes local playtime totals, the latest session, and recent daily
  aggregates. It does not change game files, preferences, logs, or network behavior.
- Removing the app in Finder does not remove Application Support, Caches, Logs, or UserDefaults. Users
  remove these separately after the app stops.

[Storage](../../help/storage.md) documents deletion behavior. Update it when you add a cleanup action.

## Safety rules for new persisted data

When you add a path or a persisted value:

1. Classify it as user data, runtime state, a cache, or a preference. The class sets ownership and
   removal behavior.
2. Add the path to `AppPaths`, or the preference to `LauncherPreferencesStore`.
3. Keep writes cancellable in long-running operations. Use atomic writes for state that controls
   recovery.
4. Never follow symlinks when you validate game destinations or measure app-owned caches.
5. Document the location and lifetime in [Storage](../../help/storage.md). When the change affects
   recovery or safety, add a focused test for path derivation, migration, or cleanup.
