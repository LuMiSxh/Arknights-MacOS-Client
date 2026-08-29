---
title: Storage
description: Locations and removal behavior for game files, runtime data, caches, preferences, and logs
order: 30
---

# Storage

Arknights Client keeps regional game files separate from one shared Wine environment. The launcher computes its standard locations below from the bundle identifier `com.lumisxh.arknights-client`; a custom game location replaces only that region's default game path.

## Locations at a glance

| Data                           | Default location                                                                            | Lifetime                                                                      |
| ------------------------------ | ------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------- |
| Global game files              | `~/Library/Application Support/com.lumisxh.arknights-client/Games/Arknights-Global`         | Until **Uninstall Game** or manual removal                                    |
| Japan game files               | `~/Library/Application Support/com.lumisxh.arknights-client/Games/Arknights-Japan`          | Until **Uninstall Game** or manual removal                                    |
| Korea game files               | `~/Library/Application Support/com.lumisxh.arknights-client/Games/Arknights-Korea`          | Until **Uninstall Game** or manual removal                                    |
| Shared Wine prefix             | `~/Library/Application Support/com.lumisxh.arknights-client/Wine/Prefixes/Arknights-Global` | Persistent runtime state shared by all regions                                |
| Custom launcher and game icons | `~/Library/Application Support/com.lumisxh.arknights-client/Artwork/Custom`                 | Until reset or app-data removal                                               |
| Bundled compatibility runtime  | Inside the app at `Contents/Resources/Runtime`                                              | Read-only; replaced by a launcher release                                     |
| Downloaded official artwork    | `~/Library/Caches/com.lumisxh.arknights-client/Artwork/Downloaded`                          | Recreated when missing                                                        |
| Preset gallery cache           | `~/Library/Caches/com.lumisxh.arknights-client/PresetGallery`                               | Recreated automatically; cleared by **Clear Gallery Cache**                   |
| Launcher and Wine logs         | `~/Library/Logs/com.lumisxh.arknights-client/`                                              | Rotating diagnostics; see [Troubleshooting](troubleshooting.md#log-locations) |
| Preferences                    | macOS `UserDefaults` for the bundle identifier                                              | Small launcher settings; locations are kept when settings are reset           |

The Wine prefix directory keeps its historical `Arknights-Global` name for storage compatibility. It is shared even when Japan or Korea is selected. The launcher repoints Wine's `G:` drive to the selected region immediately before launch.

> [!NOTE]
> If you selected a custom location, the game files are not under the default `Games/` path. Use **Settings → Installation → Show** to reveal the active folder instead of guessing from the default path.

## What Settings → Storage measures

The Storage screen measures these buckets independently:

- **Game Installations**: one row for Global, Japan, and Korea
- **Shared by All Regions**: the Wine prefix and bundled compatibility runtime
- **Recreatable Caches**: DXMT shader data, embedded-browser data, and the preset gallery cache
- **Logs**: the central launcher, Wine, Unity, and Chromium diagnostic files

Missing locations appear as **Not present**. A refresh measures the current directories again; it does not download or delete anything.

> [!TIP]
> You do not need logs for an initial report. If a maintainer asks for a specific file, **Settings → Storage → Show Logs** prepares the log directory and selects the available files in Finder.

## Caches and partial downloads

DXMT shader data lives under `<WinePrefix>/home/.cache/dxmt`. Embedded-browser cache directories live below `<WinePrefix>/drive_c/users/<profile>/AppData/Local/cache`; there can be more than one Wine profile. The launcher discovers only real directories inside the prefix and skips symbolic links.

**Clear Caches** removes the DXMT and embedded-browser caches. **Clear Gallery Cache** removes cached preset metadata and downloaded gallery assets. Both are recreatable and neither removes game files, the Wine prefix's login state, or launcher preferences.

> [!IMPORTANT]
> An interrupted game download keeps its data beside the destination with a `.part` suffix. Those files are used by **Resume Download**. Do not rename or edit them manually; if their size or checksum is invalid, the installer discards and downloads that file again.

The completed game directory contains `.arknights-client-state.json`, which records the verified manifest and version. The launcher uses it together with `Arknights.exe` to decide whether a region is installed. Do not recreate the file by hand; use the install or repair flow to produce a verified state.

## Prefix isolation and custom locations

Before Wine initializes, the launcher gives it a private Unix home, XDG directories, temporary directory, and Wine prefix. It replaces Wine's default shell-folder links with directories inside the prefix. The selected game folder is exposed as `G:` and the central log directory as `L:`. Wine's default `Z:` mapping to the macOS file-system root is removed before each start.

> [!WARNING]
> This is application-level isolation, not a macOS security sandbox. A custom game folder is intentionally visible to the Windows client through `G:`. Choose a dedicated folder rather than a directory that contains personal documents.

The shared prefix stores embedded-browser data, saved provider sessions, Wine registry state, DXMT cache data, and runtime migration state. The launcher applies compatibility settings there when the runtime revision changes; it does not use the prefix to merge the game files of different regions.

## Backups

The installer marks each game directory as excluded from macOS backups, and the runtime launch path marks the shared Wine prefix the same way. This avoids copying large, reproducible game and runtime data into a backup. Your backup tool may expose its own override for excluded locations; verify the result if you need a custom backup policy.

> [!CAUTION]
> A backup of the launcher application alone does not preserve the game installation, Wine prefix, cached sign-ins, or custom artwork. Keep the original folders if you need to preserve that state, and remember that a deleted Wine prefix cannot restore its embedded-browser sessions.

## Remove or reset data

### Remove one regional installation

1. Select the region in **Settings → Installation**.
2. Confirm that no game, update, repair, or download is running.
3. Choose **Uninstall Game…** and confirm **Move Game to Trash**.

The launcher moves only the selected game directory to the macOS Trash. It does not remove the launcher, another region, the shared Wine prefix, or custom artwork. Empty the Trash separately if you want the space back.

### Reset the shared Wine environment

Choose **Settings → Installation → Wine Prefix → Delete Wine Prefix…** only when troubleshooting specifically points to persistent Wine state. This removes the shared prefix, including saved Yostar, Google, Apple, and Facebook browser sessions, registry settings, DXMT cache, and migration state. All regional game files remain untouched. The prefix is initialized again on the next launch.

Windows-side settings or other local state stored only inside that prefix are removed with it. The launcher preferences, custom artwork, central logs, gallery cache, and every regional game directory live outside the prefix and remain in place.

> [!WARNING]
> Deleting the prefix signs you out of every provider in every region. Try [Force Migration](troubleshooting.md#no-game-window-appears) or targeted cache cleanup first when those actions match the symptom.

### Reset launcher settings

**Settings → Installation → Launcher Settings → Reset All Settings…** returns toggles and launch options to their defaults. It deliberately keeps the selected region and all installation locations, so it does not move or remove game files.

### Remove the launcher

Quit the app, reveal it in Finder from **Settings → About → Show in Finder**, and move **Arknights Client.app** to the Trash. Removing the app does not automatically remove the game directories, Wine prefix, caches, logs, or custom artwork. Use the targeted actions above before removing the app if you want a clean uninstall.

For Apple's general application and file-system guidance, see [Application Support directory](https://developer.apple.com/documentation/foundation/url/applicationsupportdirectory), [File System Programming Guide](https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/FileSystemProgrammingGuide/AccessingFilesAndDirectories/AccessingFilesAndDirectories.html), and [Apple Support's uninstall guidance](https://support.apple.com/en-us/102610).
