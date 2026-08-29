---
title: Installation
description: Requirements, installation, and first launch on Apple Silicon Macs
order: 10
---

# Installation

Arknights Client installs the official Global, Japan, or Korea PC client and starts it through a bundled Wine + DXMT runtime. The launcher and the game download are separate: the DMG does not contain Arknights game files.

> [!NOTE]
> This is an unofficial community launcher. It supports Yostar's official Global, Japan, and Korea PC clients only. The CN client is not supported.

## Before you download

You need:

- an Apple silicon Mac (M1 or newer)
- macOS 15 through macOS 27; macOS 27 additionally requires Legacy Game Test Mode to be disabled
- Rosetta 2, because the bundled Wine runtime currently contains x86-64 macOS binaries
- an account and sign-in provider accepted by the region you plan to play
- a stable internet connection and enough free space for the selected client, its updates, and temporary files

The launcher reads the current install size from Yostar before a download starts and checks the available capacity at the destination. Leave additional headroom for updates, repair files, and caches; the server-reported size can change independently of a launcher release.

> [!WARNING]
> The current runtime cannot use macOS 28's restricted Intel translation mode. macOS 27 also blocks Wine when **Legacy Game Test Mode** disables general Rosetta translation. The setup assistant checks the mode it can detect and keeps **Play** disabled until the host can run the runtime. See [Runtime compatibility](help/runtime-compatibility.md#macos-support) if you are deciding whether to upgrade macOS.

On supported systems, macOS 26 and 27 can use the launcher's Liquid Glass presentation. macOS 15–25 use the launcher's native material and bordered-control fallbacks. This UI distinction does not extend the runtime support range described above.

## Download and open the launcher

1. Download the latest `Arknights Client.dmg` from [GitHub Releases](https://github.com/LuMiSxh/Arknights-MacOS-Client/releases/latest).
2. Open the DMG and drag **Arknights Client** to **Applications**.
3. Eject the DMG. Keep the application in **Applications** so later launcher updates can replace the expected bundle.
4. In Finder, right-click the app and choose **Open** the first time.

> [!WARNING]
> Release builds are ad-hoc signed and not notarized. macOS may show a Gatekeeper warning even when the file is the release you intended to download. Use Finder's **Open** action for the first launch; do not remove quarantine attributes unless you understand the security trade-off.

The setup assistant opens on the first run. It checks for a launcher update and then checks whether macOS can execute an Intel process. An update check failure does not prevent setup from continuing, but a newer launcher release should be installed before you proceed so the instructions and runtime contract match the app you are using.

## Complete the setup assistant

The assistant saves each choice immediately. You can skip optional steps and change them later in **Settings**.

### 1. Preflight and Rosetta 2

The first screen checks the launcher update source and Intel compatibility. If Rosetta 2 is missing, choose **Install Rosetta 2…** and approve Apple's installer. If that action cannot start, install it manually in Terminal:

```sh
softwareupdate --install-rosetta --agree-to-license
```

Return to the assistant and choose **Check Again**. The launcher runs a small x86-64 test process; an installed Rosetta marker alone is not enough to pass the check.

If Apple's installer or the manual command fails, keep the exact error text, restart the Mac, install pending macOS updates, and try once more. A persistent operating-system installation error belongs with Apple Support; include the resulting `launcher.log` in a project report only when Rosetta installs but the launcher's functional check still fails.

> [!CAUTION]
> On macOS 27, a **Legacy Game Test Mode** status can make Rosetta appear installed while still preventing Wine from starting. Disable it with the command shown in [Runtime compatibility](help/runtime-compatibility.md#macos-27-legacy-game-test-mode), restart the Mac, and check again.

### 2. Select a region

Choose the region that matches the service and Yostar account you intend to use:

| Region     | Use it for                                      |
| ---------- | ----------------------------------------------- |
| **Global** | The English Global PC client and Global service |
| **Japan**  | The Japanese PC client and Japan service        |
| **Korea**  | The Korean PC client and Korea service          |

Each region has its own game files, version, and installed state. All supported regions share one Wine prefix for the runtime and embedded browser. You can install another region later from **Settings → Installation**.

> [!IMPORTANT]
> Selecting a different region does not move or convert an existing installation. It changes which regional installation the launcher refreshes and starts.

### 3. Start the official client download

The assistant shows the current region and the install size returned by Yostar. Choose **Install & Continue** to start. The launcher downloads the official files directly from Yostar, verifies each file against the manifest, and writes the completed file only after its size and CRC64 checksum match.

The download can continue while you finish the remaining assistant pages. Closing the launcher pauses the operation safely. A later **Resume Download** continues existing `.part` files and verifies them when each file is complete; it does not restart the whole client.

> [!TIP]
> If you are short on time, start the download, finish setup, and let the main launcher continue it. Avoid moving or renaming the selected game folder while the download is active.

### 4. Choose game display settings

The default is **Use In-Game Display Settings**, which leaves window mode and resolution to Arknights after its first successful launch. Turn it off only when you want the launcher to supply these values on every start.

Available launcher-controlled modes are **Windowed**, **Borderless**, and **Fullscreen**, with resolutions from `640 × 480` through `3840 × 2160`. Higher resolutions increase the work done by Wine and DXMT. **High-Resolution Mode** makes text sharper on Retina displays but can increase memory and rendering cost.

> [!TIP]
> Start with the default display settings on a base-model Mac. If the window is uneven or frame pacing is poor, turn off High-Resolution Mode first, then lower the selected resolution. See [Graphics and window problems](help/troubleshooting.md#graphics-window-and-performance-problems).

### 5. Personalize the launcher

The optional launcher page controls artwork, Dynamic Theme, the displayed game version, and the server reset countdown. Artwork is cached locally; Dynamic Theme samples the selected artwork for the launcher accent, glass tint, and compatible icon styles.

The icon page can generate matching Launcher and Game Dock icons from one operator selection. You can also choose separate local images or restore the defaults. These choices affect the launcher and icons, not the official game files.

### 6. Choose updates, notices, and audio

The final optional page contains:

- **Check for Launcher Updates**: checks for a newer launcher when the app opens; you still choose when to install it
- **Check for Game Updates**: compares the selected installed region with Yostar's current manifest; it does not download until you choose an update
- **Show Project Announcements**: shows occasional launcher notices once per announcement
- **Play Background Music** and **Show Currently Playing**: controls the optional YouTube player while the launcher is open and the game is not running

### 7. Finish

Finish setup when the game is installed or when you want to continue later. If the download is still running, finishing does not stop it. The main launcher shows progress and enables **Play** after verification completes.

## Install another region or use an existing installation

To add another region after setup, select it in **Settings → Installation**, choose its location, and start the download. Regional installations remain independent.

To use files already on disk, choose **Settings → Installation → Installation Location → Locate Existing Installation…** and select the actual game folder. The launcher recognizes an installation only when it can find both the configured game executable (`Arknights.exe`) and its `.arknights-client-state.json` manifest state. Files copied manually from another launcher may therefore appear as **Not installed**; use the launcher's install or repair flow to create a verified state.

To place a new installation elsewhere, choose **Choose New Location…** while no install, repair, or update is running. The location is stored separately for each region.

> [!WARNING]
> A custom game location is deliberately exposed to the Windows client as its `G:` drive. Choose a folder dedicated to the game rather than a directory containing personal documents. See [Storage and file access](help/storage.md#prefix-isolation-and-custom-locations).

## First launch

After the selected region is installed:

1. Let the launcher finish any pending Wine or DXMT setup shown before **Play**.
2. Select **Play**.
3. Sign in through the official game client. The Yostar, Google, Apple, and Facebook flows use the embedded browser inside the Wine environment.
4. If the game opens correctly, configure any remaining display options from the game or from **Settings → General**.

The first embedded-browser sign-in can take longer than a normal web page while Wine and its browser helper start. If it stays blank, see [Sign-in, Notices, and embedded browser problems](help/troubleshooting.md#sign-in-notices-and-embedded-browser-problems).

> [!IMPORTANT]
> The launcher applies its game compatibility files before a launch and restores the official files before an update or repair. Do not replace those files manually while the launcher is running.

## Manage the installation later

| Task                    | Where to do it                                                                  | What happens                                                                          |
| ----------------------- | ------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------- |
| Check for a game update | **Settings → Updates → Arknights → Check**                                      | Fetches the current region configuration and marks an update when the version differs |
| Install an update       | Main **Update** action or **Settings → Installation → Repair** when appropriate | Reuses matching files and downloads only missing or changed files                     |
| Verify every file       | **Settings → Installation → Repair…**                                           | Checks every manifest file and downloads missing or damaged files again               |
| Pause or resume         | Close the launcher while downloading, then choose **Resume Download**           | Keeps safe partial files beside their final destinations                              |
| Show game files         | **Settings → Installation → Location → Show**                                   | Opens the selected region folder in Finder                                            |
| Remove one region       | **Settings → Installation → Uninstall Game…**                                   | Moves only the selected game folder to the Trash                                      |

Automatic checks only look for changes. They do not silently download game data. For paths, caches, and the shared Wine prefix, see [Storage](help/storage.md). For runtime-level behavior, see [Runtime compatibility](help/runtime-compatibility.md).

## Support boundary

Use the launcher's **Report a Problem…** action for launcher, installation, Wine, graphics, embedded-browser, or runtime failures. It opens a pre-filled GitHub issue with the app version, macOS version, chip name, and memory size; it does not attach logs automatically.

> [!WARNING]
> GitHub issues are public. Review the pre-filled metadata and remove private paths, URLs, account details, tokens, and unrelated log content before submitting the report.

Contact [Yostar Support](https://account.yo-star.com/contact) for account access, payment, billing, or game-service issues. Payment pages run inside the compatibility environment, so verify every charge directly with Yostar and your payment provider.

If installation or launch fails, start with [Troubleshooting](help/troubleshooting.md). [FAQ](help/faq.md) answers common support-boundary and compatibility questions.
