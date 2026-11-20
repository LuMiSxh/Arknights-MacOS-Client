---
title: Storage
description: File locations, logs, and what cleanup removes
order: 30
---

# Storage

Each server keeps its own game files in a folder named after the server. Servers from the same publisher share one **game environment** (Wine prefix) for the selected runtime. Each runtime keeps its own game environment.

Game environments are named after their publisher and architecture. The x86_64 runtime uses `Environments/<publisher>-x86`. The ARM64 runtime uses `Environments/<publisher>-arm`. A switch keeps both game environments.

The launcher downloads one runtime for the selected architecture. To override or remove a runtime, see [Game runtime](runtime.md).

## Where files live

Paths start with `~/Library/Application Support/com.lumisxh.arknights-client/` unless noted.

| What                 | Location                                                                                       |
| -------------------- | ---------------------------------------------------------------------------------------------- |
| Games                | `Games/global`, `Games/japan`, `Games/korea`, `Games/taiwan`, `Games/china`, `Games/china-bilibili` |
| Game environments    | `Environments/yostar-x86`, `Environments/yostar-arm`, `Environments/gryphline-x86`, `Environments/gryphline-arm`, `Environments/hypergryph-x86`, `Environments/hypergryph-arm` |
| Custom icons and artwork | `Artwork/`                                                                                 |
| Playtime statistics  | `playtime.json` (local only, never uploaded)                                                   |
| Runtimes             | `Runtimes/<lane>-<version>`, for example `Runtimes/x86-1.0.0`                                  |
| Runtime downloads    | `Downloads/<lane>`                                                                             |
| Folder layout record | `layout.json` (do not edit)                                                                    |
| Caches               | `~/Library/Caches/com.lumisxh.arknights-client/`                                               |
| Logs                 | `~/Library/Logs/com.lumisxh.arknights-client/`                                                 |

A custom installation location replaces only the game folder of that server. **Settings → Storage** shows the space each part uses. macOS backups exclude game folders and game environments.

To open the app data folder, go to **Settings → Storage → Logs and data**. Choose **Show in Finder** in the **App Data Folder** row.

> [!WARNING]
> The game can see everything in its installation folder. For a custom location, use a folder with only the game. **Uninstall Game…** in a custom folder removes only the files the launcher installed. Your other files stay. Files the game created later also stay.

## Logs

**Settings → Storage → Show Logs** opens the log folder.

| File                                                                          | Contains                               |
| ----------------------------------------------------------------------------- | -------------------------------------- |
| `launcher.log`, `launcher.previous.log`                                       | Setup, downloads, updates, and errors  |
| `arknights-yostar.log`, `arknights-gryphline.log`, `arknights-hypergryph.log` | Game start messages for that publisher |
| `unity.log`                                                                   | Messages from the game itself          |
| `unity.previous.log`, `arknights-<publisher>.previous.log`                    | The same logs from the session before  |
| `chromium.log`                                                                | The sign-in window                     |
| `sdklogs/<publisher>/`                                                        | Publisher SDK logs (see below)         |

Logs can contain private paths, URLs, account IDs, or access keys. Do not attach them directly. If a maintainer asks for logs, choose **Help → Save Diagnostics…**. The launcher saves the file to Downloads. The file includes:

- Launcher and game logs, including the session before.
- `environment.json` with app, system, runtime, game, and settings details.
- The SDK logs for China, China (Bilibili), and Taiwan.
- The game crash reporter logs from the last 7 days, and the China (Bilibili) platform logs.
- macOS crash reports from the last 7 days for the launcher, Wine, and the game.
- The pinned runtime version.

The file never holds save data, the game's event logs, or settings databases.

The launcher redacts your home folder, user name, and URL queries. It does not remove account IDs or access keys. Review the file before you attach it.

## What cleanup removes

Try **Clear Caches** and **Rebuild…** before **Delete Environment…**.

| Action                  | Where                             | Removes                                                         | Keeps                                      |
| ----------------------- | --------------------------------- | --------------------------------------------------------------- | ------------------------------------------ |
| **Clear Caches**        | Settings → Storage                | Graphics and sign-in window caches (the next start is slower)   | Games, sign-ins, settings                  |
| **Rebuild…**            | Settings → Help → Troubleshooting | Nothing; reruns the Windows environment setup on the next start | Everything                                 |
| **Delete Environment…** | Settings → Help → Danger zone     | The publisher's game environment: sign-ins and Windows settings | All game files and launcher settings       |
| **Reset All Settings…** | Settings → Help → Danger zone     | Launcher preferences and launch options                         | Server, installation locations, game files |
| **Reset Statistics…**   | Settings → Playtime               | Playtime totals                                                 | Everything else                            |
| **Uninstall Game…**     | Settings → Installation           | The game files of the selected server (moved to the Trash)      | Other servers, game environment, launcher  |
| **Remove Runtime…**     | Settings → Runtime                | The runtime you use (set it up again before you play)           | Game files, game environments, launcher    |

## Uninstall completely

1. Choose **Uninstall Game…** for each installed server.
2. Choose **Delete Environment…** in **Settings → Help → Danger zone** for each publisher you used.
3. Choose **Remove Runtime…** and **Remove Other Runtime…** in **Settings → Runtime → Danger zone**.
4. Quit the launcher and move **Arknights Client.app** to the Trash.
5. Optional: Delete the folders in [Where files live](#where-files-live). Open the app data folder with **Settings → Storage → Logs and data**.

Removing only the app keeps game files, game environments, caches, and logs.

## After a launcher update

This version moves data from launcher versions 0.6 and 0.7 to the new folder layout on the first start. Nothing downloads again. Custom locations are never touched.

If the launcher shows **Quit the game first**, quit the game and choose **Try Again**.

If the launcher reports a conflict, do not delete or merge either folder. [Report the problem](README.md#report-a-problem) with the launcher message.

If the data folder comes from a launcher older than 0.6, the launcher shows **Data from an old launcher version**. Choose **Delete Data Folder**, then confirm **Delete**. The launcher removes its old data and starts a fresh setup. You do not need to relaunch it. Games installed in a custom folder are not deleted.
