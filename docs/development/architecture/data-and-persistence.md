---
title: Data and persistence
description: App-owned paths, preferences, caches, and runtime state boundaries
order: 50
---

# Data and persistence

`AppPaths` is the single resolver for locations the launcher writes on macOS. Controllers receive
an `AppPaths` value from [`LauncherViewModel`](../../../Sources/ArknightsClient/Features/Launcher/State/LauncherViewModel.swift)
instead of constructing paths from the current working directory or from a hard-coded repository
path. Tests and the isolated preview can inject temporary roots through the same initializer.

## Location contract

The default paths below use the bundle identifier
`com.lumisxh.arknights-client`. The selected region can override its game directory in Settings;
the other locations remain app-owned.

| Data                        | Default location                                                                                  | Owner                                      | Removal or update behavior                                                                 |
| --------------------------- | ------------------------------------------------------------------------------------------------- | ------------------------------------------ | ------------------------------------------------------------------------------------------ |
| Regional game files         | `~/Library/Application Support/com.lumisxh.arknights-client/{Yostar/{Global,Japan,Korea},Hypergryph/{China,China-Bilibili}}` | `InstallationController` / `GameInstaller` | Updated by the manifest; **Uninstall Game** moves only the selected directory to the Trash |
| Installed manifest state    | `.arknights-client-state.json` inside that regional directory                                     | `GameInstaller`                            | Written atomically after all files pass validation and checksum verification               |
| Wine prefixes               | `~/Library/Application Support/com.lumisxh.arknights-client/{Yostar,Hypergryph}/Prefix` | `GameSessionController` / `WineRuntime`    | Shared within the publisher family; deleting one reruns its migration plan                   |
| Runtime migration state     | `.arknights-runtime-migrations.json` inside the Wine prefix                                       | `RuntimeMigrationStore`                    | Records runtime revision and completed setup steps; it is not game-save data               |
| Bundled runtime             | `Contents/Resources/Runtime` inside the app bundle                                                | Packaging and `WineRuntime`                | Read-only at runtime; replaced with a launcher update                                      |
| Downloaded official artwork | `~/Library/Caches/com.lumisxh.arknights-client/Artwork/Downloaded`                                | `CustomizationController` / `ArtworkCache` | Recreated when missing; never required for game files                                      |
| Preset gallery cache        | `~/Library/Caches/com.lumisxh.arknights-client/PresetGallery`                                     | `PresetCatalogService`                     | Targeted cleanup from Settings; recreated on demand                                        |
| Playtime statistics         | `~/Library/Application Support/com.lumisxh.arknights-client/playtime-v1.json`                     | `PlaytimeStatisticsController`             | Versioned local totals plus 31 daily buckets; removed only by its confirmed reset          |
| DXMT and browser caches     | `<prefix>/home/.cache/dxmt` and `<prefix>/drive_c/users/<profile>/AppData/Local/cache`            | `StorageMaintenanceController`             | Targeted cleanup across real Wine profiles; symlinks are not followed                      |
| Launcher and runtime logs   | `~/Library/Logs/com.lumisxh.arknights-client`                                                     | `LauncherLog` and runtime process output   | `launcher.log`, `wine.log`, `unity.log`, and `chromium.log`; **Show Logs** prepares them   |
| Preferences                 | `UserDefaults`                                                                                    | `LauncherPreferencesStore`                 | Small settings and selected paths only; no game files or downloaded payloads               |

The path table mirrors [`AppPaths.swift`](../../../Sources/ArknightsClient/Shared/Persistence/AppPaths.swift)
and [`StorageOverviewResolver`](../../../Sources/ArknightsClient/Features/Game/Storage/StorageOverview.swift).
If the implementation changes, update the user-facing [Storage](../../help/storage.md) guide in the
same change.

## Application Support layout migration

The publisher-based layout is a persisted path contract. On the first start after the launcher
version that introduces it, a startup migration runs before normal readiness and blocks installation,
maintenance, and game launch until the check completes. It considers only these exact old defaults:

```text
Games/Arknights-Global          → Yostar/Global
Games/Arknights-Japan           → Yostar/Japan
Games/Arknights-Korea           → Yostar/Korea
Games/Arknights-China           → Hypergryph/China
Games/Arknights-China-Bilibili  → Hypergryph/China-Bilibili
Wine/Prefixes/Arknights-Global  → Yostar/Prefix
Wine/Prefixes/Arknights-China   → Hypergryph/Prefix
```

The migrator also rewrites a persisted regional install path only when its value exactly equals one
of the old default game paths. Custom paths are outside this migration contract and remain untouched.
No contents are merged and no destination is overwritten. A source is moved only when it is the
expected directory, and a destination is accepted only when it is absent or already represents the
completed move. A collision, symbolic link, or other unexpected node is a blocking error requiring
the user to resolve or report it.

Each move is a same-volume metadata rename rather than a file copy. The migration is idempotent:
completed entries are skipped, and a process interruption leaves partial progress to resume on the
next start. The migrator must finish before the app publishes normal readiness, so no installer or
Wine operation can observe a half-migrated standard path set.

> [!IMPORTANT]
> Keep path construction centralized. A new feature must receive `AppPaths` or a narrower URL
> dependency from the composition root; it must not invent another Application Support, Caches, or
> Logs location. This is what keeps cleanup, storage measurement, previews, and tests aligned.

## Preferences

`LauncherPreferencesStore` owns every `UserDefaults` read and write. The controller layer exposes
typed values and applies side effects when a setting changes. The current persisted groups are:

| Group                    | Examples                                                                        | Notes                                                                                             |
| ------------------------ | ------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| Region and locations     | selected region, one install path per region                                    | A region switch changes the active game path but does not move files                              |
| Update and communication | automatic launcher/game checks, announcements enabled, seen announcement IDs    | Update checks never download game data without an explicit install/update action                  |
| Launch and display       | launch options, high-resolution override, dynamic theme                         | Launch options are encoded as data; paths and runtime state are not stored in the options blob    |
| Personalization          | dynamic-theme accent snapshots, language, music URL/volume, playback visibility | A chosen image is copied into `Artwork/Custom`; the user's original remains outside app ownership |

Only the store knows the serialized key names and defaults. A new preference should be added there,
covered by its owning feature's tests, and reset by `resetToDefaults` when appropriate. Do not use a
preference as a substitute for a file marker or migration state: those have different recovery and
atomicity requirements.

## Runtime state and atomicity

The installer and runtime use small files to make long-running work restartable:

1. A manifest file is downloaded to a sibling path with the `.part` suffix.
2. The installer verifies its size and CRC64, then moves it into the final destination.
3. After every manifest entry is complete, `.arknights-client-state.json` records the version,
   source, install time, and manifest files with an atomic write.
4. Prefix setup records each completed migration in
   `.arknights-runtime-migrations.json` with an atomic write. A runtime archive checksum or
   `prefixRevision` change invalidates the relevant plan and is reconciled on the next launch.

Playtime uses a separate versioned JSON document. All-time regional totals remain exact while daily aggregates are capped at 31 entries. An active-session marker is written when a game window first becomes visible; the completed duration uses monotonic uptime rather than wall-clock subtraction. After an unclean launcher exit, that marker is discarded without adding guessed time. Every normal terminal path writes the completed session atomically before returning the launcher to idle.

> [!CAUTION]
> Do not treat a `.part` file, an old migration marker, or an executable's presence as proof that
> an installation is usable. The launcher requires the final manifest state and executable, and it
> validates the prefix migration state before starting Wine. Recovery must go through the owning
> controller so partial work remains resumable.

## Ownership and removal

The app separates user data, game data, runtime state, and recreatable caches so maintenance can be
targeted:

- **Uninstall Game** recycles the selected region's game directory. It does not delete the shared
  Wine prefix, other regional installations, preferences, artwork, or logs.
- **Clear Caches** removes only DXMT and embedded-browser cache directories that resolve inside
  the prefix. It does not remove saves, installed game files, or the prefix itself.
- **Clear gallery cache** removes preset catalog/image cache data. It does not remove app-owned
  copies of selected artwork/icon sources, generated icons, or the user's original files.
- **Delete Wine prefix** removes shared Windows runtime state for the selected publisher family. The
  next launch recreates it and reruns Wine initialization, DXMT installation, and registry configuration.
- **Reset Statistics** removes local playtime totals, the latest session, and recent daily
  aggregates. It does not change game files, preferences, logs, or network behavior.
- Removing the app from Finder does not automatically remove Application Support, Caches, Logs, or
  UserDefaults. Users can remove those separately after the app is no longer running.

The user-facing deletion behavior is documented in [Storage](../../help/storage.md). Keep that page
explicit whenever a new cleanup action is introduced.

## Safety rules for new persisted data

When adding a path or a persisted value:

1. Decide whether it is user data, runtime state, a cache, or a preference. That classification
   determines ownership and removal behavior.
2. Add the path to `AppPaths` or the preference to `LauncherPreferencesStore`.
3. Keep writes cancellable where they are part of a long-running operation and use atomic writes for
   state that controls recovery.
4. Do not follow symlinks while validating game destinations or measuring app-owned caches.
5. Document the location and lifetime in [Storage](../../help/storage.md), and add a focused test for
   path derivation, migration, or cleanup behavior when the change affects recovery or safety.
