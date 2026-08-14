# Architecture

The app has one native SwiftUI process. It downloads and verifies the Global PC files, then starts `Arknights.exe` through the bundled Wine + DXMT runtime. Wine is not involved in the launcher UI or download flow.

## Source layout

| Folder        | Contents                                                   |
| ------------- | ---------------------------------------------------------- |
| `Application` | App entry point and scene setup                            |
| `UI`          | Launcher and Settings views                                |
| `ViewModels`  | UI state and user actions                                  |
| `Models`      | API payloads, install state, launch options, and errors    |
| `Services`    | Yostar API, artwork, installer, and launcher update checks |
| `Storage`     | Standard macOS paths and preferences                       |
| `Runtime`     | Wine discovery, prefix setup, DXMT, and process launch     |
| `Utilities`   | CRC64 implementation                                       |

## Main flows

Game installation starts with `LauncherAPI`, which returns the current version, manifest location, and CDN. `GameInstaller` validates every manifest path, resumes partial files, checks sizes and CRC64, then records the installed manifest.

An update compares the previous and current manifests, so unchanged files are reused even in a large release. Repair mode ignores that shortcut and checks every existing file.

`LauncherViewModel` keeps the UI state but delegates network, storage, and runtime work to the components above. Preferences contain only small user choices; downloaded files and state are stored on disk.

## Boundaries

- Only the Global distribution is supported.
- Game downloads use first-party HTTPS endpoints.
- Manifest paths cannot escape the selected game folder.
- The game and Wine prefix are excluded from backup because they can be recreated.
- The app never embeds official game artwork in a release.
