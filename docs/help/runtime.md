---
title: Game runtime
description: Supported macOS versions, how the launcher picks the x86_64 or ARM64 runtime, Rosetta 2, and recovery from a failed runtime
order: 41
---

# Game runtime

The runtime is the set of files that runs the Windows game on your Mac. The launcher downloads it. It is separate from the game files. You need no virtual machine or Windows.

Only Apple silicon Macs work: M-series Macs and the MacBook Neo (A18 Pro).

## Runtime options

| Runtime                   | How it runs               | macOS             |
| ------------------------- | ------------------------- | ----------------- |
| **x86_64**                | Through Rosetta 2         | macOS 15 to 27    |
| **ARM64 (Apple Silicon)** | Natively on Apple silicon | macOS 27 or later |

The launcher picks the runtime for your Mac. You do not choose one during setup.

## macOS support

| macOS              | Runtime the launcher uses                                              |
| ------------------ | ---------------------------------------------------------------------- |
| macOS 15 to 26     | **x86_64**                                                             |
| macOS 27           | **ARM64 (Apple Silicon)**. You can override it with **x86_64**.        |
| macOS 28 and later | **ARM64 (Apple Silicon)**                                              |

Apple says macOS 27 is the last release with general Rosetta support. From macOS 28, the launcher blocks the x86_64 runtime.

The launcher does not rely on Rosetta for ARM64. See Apple's [Rosetta details](https://support.apple.com/en-au/102527) and [developer notice](https://developer.apple.com/news/?id=w5ngl9k2).

The launcher decides again after every macOS or launcher update. If the runtime it needs is missing, Home shows **Runtime setup required**. Choose **Set Up Runtime** to download it. Your game environment for the other runtime stays on disk.

## Rosetta 2

The x86_64 runtime needs Rosetta 2. macOS may ask you to install it during setup. If the launcher reports Rosetta 2 as missing or unavailable:

1. Choose **Install Rosetta 2…**, or run this in Terminal:

   ```sh
   softwareupdate --install-rosetta --agree-to-license
   ```

2. Restart the Mac and choose **Check Again**.
3. On a macOS 27 beta, turn off Legacy Game Test Mode. See the next section.

The ARM64 runtime does not need Rosetta 2.

## Legacy Game Test Mode on macOS 27 beta

Legacy Game Test Mode exists only in the macOS 27 beta. It disables Rosetta. It can also crash non-game processes.

The launcher detects it through Apple's `game-test-tool`. When it finds the mode, the launcher blocks the launch.

Turn it off in Terminal:

```sh
sudo game-test-tool disable
```

Restart the Mac, then choose **Check Again**. See Apple's [macOS 27 release notes](https://developer.apple.com/documentation/macos-release-notes/macos-27-release-notes?changes=l_2).

## Runtime during setup

The **Install** step shows the runtime the launcher picked. It offers no choice.

1. Choose **Download and Continue** or **Continue**.
2. Finish setup. A runtime download continues in the background if one starts.

- **Download and Continue** downloads and installs the runtime.
- **Continue** uses the runtime that is already installed.

While the runtime downloads, the progress line shows the percentage, download size, and speed. Choose **Pause** to stop the download in setup or in the **Active runtime** panel. Choose **Resume** to continue from the partial file. Pause works only while the runtime downloads, not while it installs.

If the game is installed but the runtime is missing, Home shows **Runtime setup required**. Choose **Set Up Runtime** on Home to download it.

## Override the runtime in Settings

Override the runtime only to work around a problem. The **Active runtime** panel in **Settings → Runtime** shows the runtime in use. It has no picker.

1. Open **Settings → Runtime**.
2. In the **Danger zone**, open **Runtime choice**.
3. Choose **Automatic** or a runtime. The menu lists only the runtimes your macOS allows.
4. Read the warning about the separate game environment (Wine prefix).
5. Choose **Switch and Download** or **Switch**.

The warning title names the target, such as **Switch to x86_64?**.

- **Switch and Download** selects the runtime at once and downloads it. Home shows the runtime setup state, not **Play**, until the download finishes.
- **Switch** uses an installed runtime.
- **Automatic** returns to the runtime the launcher picks.

The next game launch uses the new runtime. If a macOS update no longer allows your override, the launcher ignores it. While the game or a download is running, the menu is disabled. The panel shows the reason.

## What a switch changes

- The launcher downloads the new runtime. The **Active runtime** panel shows its download size while the runtime is not installed.
- The other runtime stays on disk.
- **Remove Other Runtime…** in the **Danger zone** deletes the runtime you are not using. Its game environment stays on disk.
- **Remove Runtime…** in the **Danger zone** deletes the runtime you are using. Its game environment stays on disk. Set up the runtime again before you play.
- Each runtime keeps its own game environment.
- A switch keeps both game environments. It does not copy sign-ins, settings, or resources.

The game may treat the new game environment as a fresh install. It can ask you to sign in and download resources again. See [Storage](storage.md#where-files-live) for the folders.

## Update the runtime after a launcher update

A launcher update can require a newer runtime. Home then shows **Runtime update required** and **Update Runtime** instead of **Play**.

1. Choose **Update Runtime** on Home or in **Settings → Runtime → Maintenance**.
2. Wait for the download to finish.
3. Choose **Play** when the button returns.

The **Active runtime** panel shows **Update available**, the required version, and the installed version under the runtime. The launcher removes the old runtime after the update. The launcher never downloads a runtime on its own.

### Game environment update

After a runtime update, the launcher updates the game environment of each installed server in the background. This frees the disk space that the old runtime files held. The update starts when the launcher is idle, one server at a time. **Play** stops it, and it continues after the game closes. Other actions wait until it finishes.

## If a runtime fails

The **Active runtime** panel and the **Install** setup step show a message and a support code. Home shows **Needs attention**. The details open in a dialog. Match the code to the list below.

If a download fails:

1. Check the connection and free disk space.
2. Choose **Download and Continue** again.
3. If the failure stays, open the page for the code:

- [`RT-MIS`](errors/rt-mis.md): runtime not installed
- [`RT-SET`](errors/rt-set.md): runtime setup failed
- [`RT-VER`](errors/rt-ver.md): runtime verification failed
- [`RT-BND`](errors/rt-bnd.md): runtime information unreadable
- [`RT-ROS`](errors/rt-ros.md): Rosetta missing
- [`RT-BLK`](errors/rt-blk.md): Intel translation blocked

If the Mac cannot run the runtime, set **Runtime choice** to **Automatic** in the **Danger zone**, or update macOS.

A launcher release may not include the ARM64 download. In that case, update the launcher.

If another operation runs, wait for it to finish. Then try again. If nothing helps, [report a problem](README.md#report-a-problem). Include the runtime in use.
