---
title: Storage
description: File locations, logs, and what cleanup removes
order: 30
---

# Storage

Each region keeps its own game files. Regions of one publisher share one **Wine prefix**: the Windows environment with sign-ins, settings, and caches.

## Where files live

Paths start with `~/Library/Application Support/com.lumisxh.arknights-client/` unless noted.

| What                        | Location                                                             |
| --------------------------- | -------------------------------------------------------------------- |
| Yostar games and prefix     | `Yostar/Global`, `Yostar/Japan`, `Yostar/Korea`, `Yostar/Prefix`     |
| Gryphline game and prefix   | `Gryphline/Taiwan`, `Gryphline/Prefix`                               |
| Hypergryph games and prefix | `Hypergryph/China`, `Hypergryph/China-Bilibili`, `Hypergryph/Prefix` |
| Custom icons                | `Artwork/Custom`                                                     |
| Playtime statistics         | `playtime-v1.json` (local only, never uploaded)                      |
| Caches                      | `~/Library/Caches/com.lumisxh.arknights-client/`                     |
| Logs                        | `~/Library/Logs/com.lumisxh.arknights-client/`                       |

A custom installation location replaces only the game folder of that region. **Settings → Storage** shows the space each part uses. macOS backups exclude game folders and prefixes.

> [!WARNING]
> The game can see everything in its installation folder. For a custom location, use a folder with only the game.

## Logs

**Settings → Storage → Show Logs** opens the log folder.

| File                                                                          | Contains                               |
| ----------------------------------------------------------------------------- | -------------------------------------- |
| `launcher.log`, `launcher.previous.log`                                       | Setup, downloads, updates, and errors  |
| `arknights-yostar.log`, `arknights-gryphline.log`, `arknights-hypergryph.log` | Game start and Wine for that publisher |
| `unity.log`                                                                   | Messages from the game itself          |
| `chromium.log`                                                                | The sign-in window                     |

Logs can contain private paths or URLs. Attach only the requested file.

## What cleanup removes

| Action                  | Removes                                                         | Keeps                                      |
| ----------------------- | --------------------------------------------------------------- | ------------------------------------------ |
| **Clear Caches**        | Graphics and sign-in window caches (the next start is slower)   | Games, sign-ins, settings                  |
| **Rebuild…**            | Nothing; reruns the Windows environment setup on the next start | Everything                                 |
| **Delete Environment…** | The publisher's prefix, including sign-ins and Windows settings | All game files and launcher settings       |
| **Reset All Settings…** | Launcher preferences and launch options                         | Region, installation locations, game files |
| **Reset Statistics…**   | Playtime totals                                                 | Everything else                            |
| **Uninstall Game…**     | The game folder of the selected region (moved to the Trash)     | Other regions, the prefix, the launcher    |

Try **Clear Caches** and **Rebuild…** before **Delete Environment…**.

## Uninstall completely

1. Choose **Uninstall Game…** for each installed region.
2. Choose **Delete Environment…** for each publisher you used.
3. Quit the launcher and move **Arknights Client.app** to the Trash.
4. Optional: Delete the folders in [Where files live](#where-files-live).

Removing only the app keeps game files, prefixes, caches, and logs.

## After a launcher update

Some updates rename the standard game folders to a new layout on the first start. Nothing downloads again. Custom locations are never touched.

If the launcher reports a conflict, do not delete or merge either folder. [Report the problem](README.md#report-a-problem) with the launcher message.
