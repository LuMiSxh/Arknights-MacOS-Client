<div align="center">

<img src="Resources/AppIcon.png" width="112" height="112" alt="Arknights Client app icon" />

# Arknights Client

**Unofficial macOS launcher for the PC version of Arknights**

Runs the official Windows client on Apple Silicon Macs via a bundled Wine and DXMT runtime.

[![License](https://img.shields.io/badge/license-MPL--2.0-blue.svg)](LICENSE)
[![Version](https://img.shields.io/github/v/release/LuMiSxh/Arknights-MacOS-Client)](https://github.com/LuMiSxh/Arknights-MacOS-Client/releases)

[Overview](#overview) • [Features](#features) • [Installation](#installation) • [Quick Start](#quick-start) • [Development](#development)

</div>

---

## Overview

Arknights Client is a native SwiftUI launcher for the official Global PC client. It downloads game files from Yostar and runs the Windows game through a bundled Wine and DXMT runtime.

The project is in beta and supports only Apple Silicon Macs running macOS 26 or newer.

> [!WARNING]
> Credit card and PayPal payments have been observed to work. These flows can still be unstable in this unofficial Wine environment, so transactions should be treated as high-risk. Verify every purchase directly with the provider and with Yostar, and monitor statements carefully. The launcher is community-maintained and includes patched compatibility layers; users accept all payment and billing risks themselves.

## Features

- Install, resume, update, repair, and remove the Global, Japan, or Korea PC client
- Windowed, borderless, or fullscreen mode at a chosen resolution
- HiDPI rendering for the game and its login browser
- Yostar, Apple, Google, and Facebook login flows through Wine compatibility helpers
- Independent version checks for launcher and game; automatic checks can be disabled
- One-time project announcements from this repository; can also be disabled
- Wine prefix and Windows user folders stored under Application Support
- Separate launcher and Wine logs, viewable from Settings

## Installation

The app requires:

- Apple Silicon
- macOS 26 or newer
- Rosetta 2

Download `Arknights Client.dmg` from [GitHub Releases](https://github.com/LuMiSxh/Arknights-MacOS-Client/releases/latest), open it, and drag the app to **Applications**.

> [!WARNING]
> Builds are ad-hoc signed and not notarized. On first launch, right-click the app in Finder and select **Open**.

The bundled Wine runtime is an Intel binary and currently runs through Rosetta 2. macOS may show a one-time notice when **Play** is selected for the first time because Apple has announced that Intel-app support will end in a future macOS release.

Game files are stored separately from the app. Removing the launcher does not remove the game; use **Uninstall Game** in Settings.

## Quick Start

1. Open Arknights Client.
2. Open **Settings** (⚙) → **Installation** and choose your region: **Global**, **Japan**, or **Korea**.
3. Select **Install** and wait for the download to finish.
4. Choose a display mode in Settings if needed.
5. Select **Play**.

Each region has its own install folder (for example `Arknights-Global`, `Arknights-Japan`, or `Arknights-Korea`) under
`~/Library/Application Support/com.lumisxh.arknights-client/Games/`.

> [!NOTE]
> The first Google, Apple, or Facebook sign-in can take 5–15 seconds to open while the embedded Windows browser starts through Wine. A blank login view during that interval does not usually indicate a failed click.

## Development

Development requires Swift 6.2, the matching Xcode command-line tools, [`just`](https://github.com/casey/just), and [`uv`](https://docs.astral.sh/uv/).

```sh
git clone https://github.com/LuMiSxh/Arknights-MacOS-Client.git
cd Arknights-MacOS-Client
just check
```

| Command                    | Purpose                                                       |
| -------------------------- | -------------------------------------------------------------- |
| `just preview`             | Run the isolated debug-state simulator; every state is available from Settings → Developer |
| `just runtime`             | Download and verify the tested Wine and DXMT runtime          |
| `just dev [target] [run]`  | Build the app or dmg with the runtime, optionally opening it  |
| `just ci`                  | Run all checks and build the release configuration            |

Run `just --groups` for the complete command list.
Tested runtime versions, download locations, checksums, and source provenance are pinned in [`runtime.json`](runtime.json).
Repository automation lives in `scripts/` as Python scripts. uv reads their inline metadata and installs tool-specific dependencies automatically.

## Documentation

- [Architecture](docs/architecture.md)
- [Design](docs/design.md)
- [Storage](docs/storage.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Releases and updates](docs/releases-and-updates.md)
- [Announcements](docs/announcements.md)
- [Changelog](CHANGELOG.md)
- [Third-party notices](docs/legal/third-party-notices.md)
- [Source code](docs/legal/source-code.md)

## License

Arknights Client is licensed under the [Mozilla Public License 2.0](LICENSE).

Copyright © 2026 LuMiSxh. This project is not affiliated with Hypergryph or Yostar. Arknights and its artwork belong to their respective owners.
