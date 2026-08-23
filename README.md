<div align="center">

<img src="Resources/AppIcon.png" width="112" height="112" alt="Arknights Client app icon" />

# Arknights Client

**Run the official Global, Japan, and Korea Arknights PC clients on Apple Silicon Macs through a native SwiftUI launcher.**

[![Version](https://img.shields.io/github/v/release/LuMiSxh/Arknights-MacOS-Client)](https://github.com/LuMiSxh/Arknights-MacOS-Client/releases)
[![macOS](https://img.shields.io/badge/macOS-15%2B-black.svg)](https://github.com/LuMiSxh/Arknights-MacOS-Client/releases/latest)
[![Platform](https://img.shields.io/badge/platform-Apple%20Silicon-black.svg)](#requirements)
[![License](https://img.shields.io/badge/license-MPL--2.0-blue.svg)](LICENSE)

<img src="Resources/github/landing-page.png" width="1200" alt="Arknights Client ready to launch the official PC client on macOS" />

[Download](https://github.com/LuMiSxh/Arknights-MacOS-Client/releases/latest) · [Features](#features) · [Installation](#installation) · [Development](#development)

</div>

## Overview

Arknights Client downloads the official PC game directly from Yostar and runs it through a bundled, tested Wine and DXMT environment. The native launcher manages game installation, updates, display options, artwork, icons, compatibility fixes, and diagnostics.

The project is community-maintained, currently in beta, and is not affiliated with Hypergryph or Yostar. Game files and downloaded artwork are not included in release builds.

## Features

### Install and play

- Install, resume, update, repair, and remove the Global, Japan, or Korea PC client
- Keep each region in its own game directory and switch between installed regions
- Run in windowed, borderless, or fullscreen mode at a selected resolution
- Enable HiDPI rendering for the game and its embedded login browser
- Use Yostar, Apple, Google, and Facebook login flows through Wine compatibility helpers

### Native macOS experience

- Follow a resumable setup assistant while the game downloads in the background
- Personalize the launcher with custom artwork, a preset gallery, and dynamic theme colors
- Customize launcher and game icons with normalized macOS Dock sizing
- Show optional game-version, server-time, and daily-reset indicators
- Play optional YouTube background music with playlist and volume controls
- Use native Settings, update notices, diagnostics, and support actions

### Compatibility and maintenance

- Launch through a pinned Wine and DXMT runtime tested as one compatibility unit
- Apply game-specific browser, window, input, and Command-Q integrations automatically
- Check launcher and game versions independently; automatic checks can be disabled
- Clear DXMT shader, browser, and downloaded gallery caches from Settings
- Keep launcher, Wine, game, and embedded-browser logs available for troubleshooting

## Requirements

|                | Minimum to run                       | Recommended for smoother play                        |
| -------------- | ------------------------------------ | ---------------------------------------------------- |
| Mac chip       | Apple M1 with 7- or 8-core GPU       | M1 Pro or Max, 10-core GPU M2, or any newer chip     |
| Unified memory | 8 GB                                 | 16 GB or more                                        |
| macOS          | 15 Sequoia                           | macOS 15 or newer, fully updated                     |
| Free storage   | 50 GB during installation            | 60 GB or more for updates, repairs, and caches       |
| Translation    | Rosetta 2                            | Rosetta 2                                            |

macOS 26 receives the Liquid Glass interface. macOS 15–25 use native Material and bordered-control fallbacks.

These Mac requirements are project guidance, not official Yostar specifications. Yostar's Windows client requires an Intel Core i3-6100, GTX 750 Ti, and 8 GB of RAM at minimum; it recommends an Intel Core i5-8400 and GTX 1060. The official client also requires 30 GB of storage plus 20 GB of temporary installation space. See the [official PC FAQ](https://www.arknights.global/news/4335).

The Windows game runs through Rosetta 2, Wine, and DXMT on macOS, while Apple silicon shares unified memory between the CPU and GPU. That additional overhead means the Windows requirements do not translate directly. An M1 Mac with 8 GB can run the client, but should be treated as the functional floor: reduced resolution and settings may still show stutter or memory pressure. For a consistently better experience, use at least 16 GB of unified memory and the recommended chip tier above.

## Installation

1. Download `Arknights Client.dmg` from [GitHub Releases](https://github.com/LuMiSxh/Arknights-MacOS-Client/releases/latest).
2. Open the DMG and drag **Arknights Client** to **Applications**.
3. On first launch, right-click the app in Finder and select **Open**.
4. Follow the setup assistant to check the launcher and Rosetta 2, choose a region, and install the game.

> [!NOTE]
> Builds are ad-hoc signed and not notarized. The setup assistant detects whether Rosetta 2 is available and provides the installation command when it is missing.

## Quick Start

1. Open Arknights Client.
2. Let the setup assistant check for a newer launcher version and Rosetta 2.
3. Choose **Global**, **Japan**, or **Korea** and begin the official PC-client download.
4. Configure display, artwork, theme, icons, update checks, and audio while the download continues.
5. Finish setup and select **Play** from the main window.

Each region has its own folder under:

```text
~/Library/Application Support/com.lumisxh.arknights-client/Games/
```

Removing the launcher does not remove these game files. Use **Uninstall Game** in Settings when you want to remove an installed region.

## Important Notes

> [!CAUTION]
> Payment flows run inside a Wine compatibility environment. Credit card and PayPal payments have worked in testing, but users should verify every transaction with Yostar and their payment provider. The launcher cannot assume responsibility for payment or billing problems.

- The bundled Wine runtime is an Intel binary and currently runs through Rosetta 2. Apple has announced that Intel-app support will end in a future macOS release.
- The first Google, Apple, or Facebook sign-in can take 5–15 seconds to appear while the embedded Windows browser starts through Wine.
- The launcher modifies only its own compatibility files and restores official helpers before game installation, updates, or repairs.
- For launcher, Wine, or embedded-browser problems, use the pre-filled GitHub report available in Settings. Contact [Yostar Support](https://account.yo-star.com/contact) for account, payment, or game-service issues.

## Development

Development requires Swift 6.2, the matching Xcode command-line tools, [`just`](https://github.com/casey/just), and [`uv`](https://docs.astral.sh/uv/).

```sh
git clone https://github.com/LuMiSxh/Arknights-MacOS-Client.git
cd Arknights-MacOS-Client
just check
```

| Command            | Purpose                                              |
| ------------------ | ---------------------------------------------------- |
| `just check`       | Run source checks and tests                          |
| `just preview`     | Open the isolated UI-state simulator                 |
| `just runtime`     | Download and verify the tested Wine and DXMT runtime |
| `just dev app run` | Build the app with its runtime and open it           |
| `just ci`          | Run all checks and build the release configuration   |

Run `just --groups` for the complete command list. Tested runtime versions, download locations, checksums, and source provenance are pinned in [`runtime.json`](runtime.json). Repository automation lives in `scripts/` as uv-managed Python entry points.

## Documentation

### Users

- [Troubleshooting](docs/troubleshooting.md)
- [Storage and removal behavior](docs/storage.md)
- [Runtime compatibility](docs/runtime-compatibility.md)
- [Changelog](CHANGELOG.md)

### Contributors and maintainers

- [Architecture](docs/architecture.md)
- [Design](docs/design.md)
- [Localization](docs/localization.md)
- [Releases and updates](docs/releases-and-updates.md)
- [Announcements](docs/announcements.md)
- [Third-party notices](docs/legal/third-party-notices.md)
- [Corresponding source](docs/legal/source-code.md)

## License

Arknights Client is licensed under the [Mozilla Public License 2.0](LICENSE).

Copyright © 2026 LuMiSxh. Arknights and its artwork belong to their respective owners.
