---
title: Storage
description: Locations and removal behavior for game files, runtime data, caches, preferences, and logs
order: 30
---

# Storage

Each region keeps its own game files. Regions from the same publisher share one **Wine prefix**: the Windows environment that holds sign-ins, settings, and caches.

## Where files live

All paths start with `~/Library/Application Support/com.lumisxh.arknights-client/` unless noted.

| What                        | Location                                                             |
| --------------------------- | -------------------------------------------------------------------- |
| Yostar games and prefix     | `Yostar/Global`, `Yostar/Japan`, `Yostar/Korea`, `Yostar/Prefix`     |
| Gryphline game and prefix   | `Gryphline/Taiwan`, `Gryphline/Prefix`                               |
| Hypergryph games and prefix | `Hypergryph/China`, `Hypergryph/China-Bilibili`, `Hypergryph/Prefix` |
| Custom icons                | `Artwork/Custom`                                                     |
| Playtime statistics         | `playtime-v1.json` (local only, never uploaded)                      |
| Caches                      | `~/Library/Caches/com.lumisxh.arknights-client/`                     |
| Logs                        | `~/Library/Logs/com.lumisxh.arknights-client/`                       |

A custom installation location replaces only that region's game folder. **Settings → Storage** shows how much space each part uses.

> [!WARNING]
> The game can see everything inside its installation folder. If you choose a custom location, use a folder that contains only the game.

Game folders and prefixes are excluded from macOS backups such as Time Machine because they can be downloaded or rebuilt.

## Logs

You do not need logs for a first report. **Settings → Storage → Show Logs** opens the folder:

| File                                                                          | Contains                               |
| ----------------------------------------------------------------------------- | -------------------------------------- |
| `launcher.log`, `launcher.previous.log`                                       | Setup, downloads, updates, and errors  |
| `arknights-yostar.log`, `arknights-gryphline.log`, `arknights-hypergryph.log` | Game start and Wine for that publisher |
| `unity.log`                                                                   | Messages from the game itself          |
| `chromium.log`                                                                | The sign-in window                     |

Logs can contain private paths or URLs. Attach only the file a maintainer asks for.

## What cleanup removes

| Action                  | Removes                                                         | Keeps                                      |
| ----------------------- | --------------------------------------------------------------- | ------------------------------------------ |
| **Clear Caches**        | Graphics and sign-in window caches (the next start is slower)   | Games, sign-ins, settings                  |
| **Force Migration…**    | Nothing; reruns the Windows environment setup on the next start | Everything                                 |
| **Delete Wine Prefix…** | The publisher's prefix, including sign-ins and Windows settings | All game files and launcher settings       |
| **Reset All Settings…** | Launcher preferences and launch options                         | Region, installation locations, game files |
| **Reset Statistics…**   | Playtime totals                                                 | Everything else                            |
| **Uninstall Game…**     | The selected region's game folder (moved to the Trash)          | Other regions, the prefix, the launcher    |

Try **Clear Caches** and **Force Migration…** before **Delete Wine Prefix…**. The prefix is rebuilt automatically on the next start.

## Uninstall completely

1. Choose **Uninstall Game…** for each installed region.
2. Choose **Delete Wine Prefix…** for each publisher you used.
3. Quit the launcher and move **Arknights Client.app** to the Trash.
4. Optionally delete the folders listed under [Where files live](#where-files-live).

Removing only the app keeps all game files, prefixes, caches, and logs.

## After a launcher update

Some updates move the standard game folders to a new layout on the first start. This is a quick rename on the same drive; nothing is downloaded again, and custom locations are never touched.

If the launcher reports a conflict, do not delete or merge either folder. [Report the problem](README.md#report-a-problem) with the message the launcher shows.
