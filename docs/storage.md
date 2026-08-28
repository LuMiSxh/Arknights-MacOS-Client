# Storage

The app resolves standard directories through `FileManager`. All app-owned paths use the bundle identifier `com.lumisxh.arknights-client`.

| Data             | Location                                                                                    | Lifetime                        |
| ---------------- | ------------------------------------------------------------------------------------------- | ------------------------------- |
| Game files       | `~/Library/Application Support/com.lumisxh.arknights-client/Games/Arknights-Global`         | Until **Uninstall Game**        |
| Wine prefix      | `~/Library/Application Support/com.lumisxh.arknights-client/Wine/Prefixes/Arknights-Global` | Persistent runtime state        |
| Bundled runtime  | Inside the app bundle under `Contents/Resources/Runtime`                                    | Read-only, replaced with launcher updates |
| DXMT cache       | `<WinePrefix>/home/.cache/dxmt`                                                            | Recreated automatically; targeted cleanup |
| Browser caches   | `<WinePrefix>/drive_c/users/<user>/AppData/Local/cache`                                   | Recreated automatically; targeted cleanup |
| Gallery cache    | `~/Library/Caches/com.lumisxh.arknights-client/PresetGallery`                              | Recreated automatically; targeted cleanup |
| Custom artwork and icons | `~/Library/Application Support/com.lumisxh.arknights-client/Artwork/Custom`          | Until individually reset or app data removal |
| Official artwork | `~/Library/Caches/com.lumisxh.arknights-client/Artwork/Downloaded`                          | Recreated when missing; includes a small per-region pointer so the last active image appears before the branding refresh |
| Launcher log     | `~/Library/Logs/com.lumisxh.arknights-client/launcher.log`                                  | Rotating diagnostics            |
| Runtime log      | `~/Library/Logs/com.lumisxh.arknights-client/wine.log`                                      | Game and Wine diagnostics       |
| Preferences      | `UserDefaults`                                                                              | Small settings only             |

## Settings storage overview

**Settings → Storage** measures the three regional game installations independently, then shows
the shared Wine prefix and bundled compatibility runtime. **Recreatable Caches** groups DXMT,
embedded-browser, and gallery data; its targeted actions clear only those caches. **Logs** is
read-only and offers **Show Logs**, which creates the log directory when needed and opens it in
Finder. Game files, the Wine prefix, and the bundled runtime have no deletion action in this view.

Partial game downloads stay beside their final files with a `.part` suffix so downloads can resume. Game files and the Wine prefix are excluded from backups.

The setup assistant stores only its schema version and current step in `UserDefaults`. Completing or explicitly skipping the assistant clears the step and records the current schema; **Run Again** removes that completion marker. All choices made inside setup remain owned by the normal launcher preference and asset stores.

The Wine prefix is intentionally isolated. Before the first `wineboot`, Wine receives a private Unix home and XDG user-folder configuration. The prebuilt runtime initializes Windows data under a `crossover` profile, while some processes use the current macOS account name; both profiles therefore remain inside the prefix instead of linking to macOS folders. Only the private `C:` drive and the selected game directory as `G:` are visible through normal Windows paths. The launcher removes Wine's default `Z:` mapping to the macOS file-system root before every start.

`.arknights-runtime-migrations.json` belongs to the Wine prefix. It records the effective `<archive SHA-256>-prefix-<prefixRevision>` runtime revision and completed migration IDs so prefix changes are resumable and idempotent. A new runtime archive therefore replays its migrations without deleting the prefix. Deleting the prefix also deletes this state and causes the complete migration plan to run during the next launch.

This limits accidental file access but is not a macOS security sandbox. Choosing a custom game location explicitly exposes that directory to the Windows client.

Launcher and Game operator presets keep separate source avatars beside their rendered icons. This lets Dynamic Theme regenerate the Launcher treatment without another download while leaving the Game icon untouched. Choosing a local image or using **Use Default** clears only that destination's source; for the game, **Use Default** restores Wine's normalized original Arknights icon.

## Removal

**Uninstall Game** moves the selected game folder to the Trash without removing the launcher. The launcher follows the macOS convention: reveal it in Finder and move the app to the Trash. A running app does not delete itself.

References: [Apple application support directory](https://developer.apple.com/documentation/foundation/url/applicationsupportdirectory), [Apple file-system guidance](https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/FileSystemProgrammingGuide/AccessingFilesandDirectories/AccessingFilesandDirectories.html), and [Apple uninstall guidance](https://support.apple.com/en-us/102610).
