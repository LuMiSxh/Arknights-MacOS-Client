---
title: Storage
description: File locations, logs, and what cleanup removes
order: 30
---

# Storage

Each server keeps its own game files. Servers of one publisher share one **game environment** (Wine prefix) for the selected runtime architecture.

The x86_64 runtime uses `Prefix`. The ARM64 runtime uses `Prefix-ARM64` in the same publisher folder. Each architecture keeps its own game environment. Switching between them keeps both. The environments do not share sign-ins, settings, or caches, so a switch can look like a fresh install.

The launcher downloads one runtime for the selected architecture. Both runtimes can stay on disk. **Settings → Installation → Runtime** shows the installed version of each and offers **Remove Other Runtime**.

## Where files live

Paths start with `~/Library/Application Support/com.lumisxh.arknights-client/` unless noted.

| What                                  | Location                                                                                        |
| ------------------------------------- | ----------------------------------------------------------------------------------------------- |
| Yostar games and game environment     | `Yostar/Global`, `Yostar/Japan`, `Yostar/Korea`, `Yostar/Prefix`, `Yostar/Prefix-ARM64`         |
| Gryphline game and game environment   | `Gryphline/Taiwan`, `Gryphline/Prefix`, `Gryphline/Prefix-ARM64`                                |
| Hypergryph games and game environment | `Hypergryph/China`, `Hypergryph/China-Bilibili`, `Hypergryph/Prefix`, `Hypergryph/Prefix-ARM64` |
| Custom icons and artwork              | `Artwork/Custom`                                                                                |
| Playtime statistics                   | `playtime-v1.json` (local only, never uploaded)                                                 |
| Storage measurements                  | `storage-overview-cache.json` (local only; safe to delete)                                      |
| Caches                                | `~/Library/Caches/com.lumisxh.arknights-client/`                                                |
| Runtimes                              | `Runtimes/x86`, `Runtimes/arm`                                                                  |
| Logs                                  | `~/Library/Logs/com.lumisxh.arknights-client/`                                                  |

A custom installation location replaces only the game folder of that server. **Settings → Storage** shows the space each part uses. macOS backups exclude game folders and game environments.

> [!WARNING]
> The game can see everything in its installation folder. For a custom location, use a folder with only the game.

## Logs

**Settings → Storage → Show Logs** opens the log folder.

| File                                                                          | Contains                               |
| ----------------------------------------------------------------------------- | -------------------------------------- |
| `launcher.log`, `launcher.previous.log`                                       | Setup, downloads, updates, and errors  |
| `arknights-yostar.log`, `arknights-gryphline.log`, `arknights-hypergryph.log` | Game start messages for that publisher |
| `unity.log`                                                                   | Messages from the game itself          |
| `chromium.log`                                                                | The sign-in window                     |
| `sdklogs/<publisher>/`                                                        | Publisher SDK logs (see below)         |

Logs can contain private paths, URLs, account IDs, or access keys. Do not attach them directly. If a maintainer asks for logs, choose **Help → Save Diagnostics…**. It saves launcher and game logs, and the SDK logs for China, China (Bilibili), and Taiwan, to Downloads. The launcher redacts your home folder, user name, and URL queries. It does not remove account IDs or access keys. Review the file before you attach it.

## What cleanup removes

| Action                  | Where                             | Removes                                                         | Keeps                                      |
| ----------------------- | --------------------------------- | --------------------------------------------------------------- | ------------------------------------------ |
| **Clear Caches**        | Settings → Storage                | Graphics and sign-in window caches (the next start is slower)   | Games, sign-ins, settings                  |
| **Rebuild…**            | Settings → Help → Troubleshooting | Nothing; reruns the Windows environment setup on the next start | Everything                                 |
| **Delete Environment…** | Settings → Help → Troubleshooting | The publisher's game environment: sign-ins and Windows settings | All game files and launcher settings       |
| **Reset All Settings…** | Settings → Help → Troubleshooting | Launcher preferences and launch options                         | Server, installation locations, game files |
| **Reset Statistics…**   | Settings → Playtime               | Playtime totals                                                 | Everything else                            |
| **Uninstall Game…**     | Settings → Installation           | The game folder of the selected server (moved to the Trash)     | Other servers, game environment, launcher  |

Try **Clear Caches** and **Rebuild…** before **Delete Environment…**.

## Uninstall completely

1. Choose **Uninstall Game…** for each installed server.
2. Choose **Delete Environment…** for each publisher you used.
3. Quit the launcher and move **Arknights Client.app** to the Trash.
4. Optional: Delete the folders in [Where files live](#where-files-live).

Removing only the app keeps game files, game environments, caches, and logs.

## After a launcher update

Some updates rename the standard game folders to a new layout on the first start. Nothing downloads again. Custom locations are never touched.

If the launcher reports a conflict, do not delete or merge either folder. [Report the problem](README.md#report-a-problem) with the launcher message.
