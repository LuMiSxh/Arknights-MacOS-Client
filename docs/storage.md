# Storage

The app resolves standard directories through `FileManager`. All app-owned paths use the bundle identifier `com.lumisxh.arknights-client`.

| Data                  | Location                                                                                    | Lifetime                        |
| --------------------- | ------------------------------------------------------------------------------------------- | ------------------------------- |
| Game files            | `~/Library/Application Support/com.lumisxh.arknights-client/Games/Arknights-Global`         | Until **Uninstall Game**        |
| Wine prefix           | `~/Library/Application Support/com.lumisxh.arknights-client/Wine/Prefixes/Arknights-Global` | Persistent runtime state        |
| Custom artwork        | `~/Library/Application Support/com.lumisxh.arknights-client/Artwork/Custom`                 | Until reset or app data removal |
| Official artwork      | `~/Library/Caches/com.lumisxh.arknights-client/Artwork/Downloaded`                          | Recreated when missing          |
| Launcher update cache | `~/Library/Caches/com.lumisxh.arknights-client/Updater`                                     | Temporary                       |
| Runtime log           | `~/Library/Logs/com.lumisxh.arknights-client/wine.log`                                      | Diagnostics                     |
| Preferences           | `UserDefaults`                                                                              | Small settings only             |

Partial game downloads stay beside their final files with a `.part` suffix so downloads can resume. Game files and the Wine prefix are excluded from backups.

## Removal

**Uninstall Game** moves the selected game folder to the Trash without removing the launcher. The launcher follows the macOS convention: reveal it in Finder and move the app to the Trash. A running app does not delete itself.

The project has not shipped yet, so it intentionally contains no migration logic for experimental local paths.

References: [Apple application support directory](https://developer.apple.com/documentation/foundation/url/applicationsupportdirectory), [Apple file-system guidance](https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/FileSystemProgrammingGuide/AccessingFilesandDirectories/AccessingFilesandDirectories.html), and [Apple uninstall guidance](https://support.apple.com/en-us/102610).
