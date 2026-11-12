---
title: Game runtime
description: Supported macOS versions, the x86_64 and ARM64 runtimes, Rosetta 2, and recovery from a failed runtime
order: 41
---

# Game runtime

The runtime is the set of files that runs the Windows game on your Mac. The launcher downloads it. It is separate from the game files. You need no virtual machine or Windows.

Only Apple silicon Macs work: M-series Macs and the MacBook Neo (A18 Pro).

## Runtime architectures

| Architecture              | How it runs               | macOS             |
| ------------------------- | ------------------------- | ----------------- |
| **x86_64**                | Through Rosetta 2         | macOS 15 to 27    |
| **ARM64 (Apple Silicon)** | Natively on Apple silicon | macOS 26 or later |

Use **x86_64** if you are not sure and your Mac runs macOS 15 to 27. On macOS 28 or later, setup selects **ARM64 (Apple Silicon)**.

## macOS support

| macOS          | Runtime you can use                                      |
| -------------- | -------------------------------------------------------- |
| macOS 15 to 26 | **x86_64** only. Setup states that ARM64 needs macOS 26. |
| macOS 26 to 27 | **x86_64** or **ARM64 (Apple Silicon)**                  |
| macOS 28+      | **ARM64 (Apple Silicon)** only                           |

Apple says macOS 27 is the last release with general Rosetta support. From macOS 28, the launcher blocks the x86_64 runtime. The launcher does not rely on Rosetta for ARM64. See Apple's [Rosetta details](https://support.apple.com/en-au/102527) and [developer notice](https://developer.apple.com/news/?id=w5ngl9k2).

On macOS 28 or later, setup selects **ARM64 (Apple Silicon)** by default, and the **Runtime** step does not offer **x86_64**. If you selected x86_64 on an earlier macOS and then upgraded, **System Check** asks you to switch to the ARM64 runtime. Continue setup and choose **ARM64 (Apple Silicon)** in the **Runtime** step. The next game launch uses it.

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

Legacy Game Test Mode exists only in the macOS 27 beta. It disables Rosetta and can crash non-game processes. The launcher detects it through Apple's `game-test-tool` and blocks the launch.

Turn it off in Terminal:

```sh
sudo game-test-tool disable
```

Restart the Mac, then choose **Check Again**. See Apple's [macOS 27 release notes](https://developer.apple.com/documentation/macos-release-notes/macos-27-release-notes?changes=l_2).

## Choose a runtime during setup

1. In the **Runtime** step, choose **x86_64** or **ARM64 (Apple Silicon)**. On macOS 28 or later, only **ARM64 (Apple Silicon)** is offered.
2. Choose **Download and Continue**, **Switch & Continue**, or **Continue Setup**.
3. Wait for the download if one starts.

**Download and Continue** downloads and installs the runtime. **Switch & Continue** selects a runtime that is already installed. **Continue Setup** keeps the current runtime.

While the runtime downloads, the progress line shows the percentage, download size, and speed.

## Switch architectures in Settings

1. Open **Settings → Installation**.
2. In the **Runtime** panel, choose **Switch to x86_64** or **Switch to ARM64**.
3. Read the warning about the separate game environment (Wine prefix).
4. Choose **Switch and Download** or **Switch**.

The warning title names the target, such as **Switch to ARM64?**. **Switch and Download** also downloads the runtime. **Switch** uses an installed runtime. The next game launch uses the new architecture. On macOS 28 or later, the **Runtime** panel does not offer **x86_64**.

## What a switch changes

- The launcher downloads the runtime for the selected architecture. The **Runtime** panel shows its download size.
- The other runtime stays on disk. The panel shows the installed version for each architecture.
- **Remove Other Runtime** deletes the runtime you are not using. Its game environment stays on disk.
- **Remove Runtime…** deletes the runtime you are using. Its game environment stays on disk. Set up the runtime again before you play.
- Each architecture keeps its own game environment.
- A switch keeps both game environments. It does not copy sign-ins, settings, or resources.

The game may treat the new environment as a fresh install. It can ask you to sign in and download resources again. See [Storage](storage.md#where-files-live) for the folders.

## Update the runtime after a launcher update

A launcher update can require a newer runtime. Home then shows **Runtime update required** and **Update Runtime** instead of **Play**.

1. Choose **Update Runtime** on Home or in **Settings → Installation → Runtime**.
2. Wait for the download to finish.
3. Choose **Play** when the button returns.

The **Runtime** panel shows **Update available**, the required version, and the installed version. The launcher removes the old runtime after the update. The launcher never downloads a runtime on its own.

## If a runtime fails

The **Runtime** panel and the **Runtime** setup step show a message and a support code. Match the code to the list below.

If a download fails:

1. Check the connection and free disk space.
2. Choose **Download and Continue** or **Switch and Download** again.
3. Open the page for the code if the failure stays:

- [`RT-MIS`](errors/rt-mis.md): runtime not installed
- [`RT-SET`](errors/rt-set.md): runtime setup failed
- [`RT-VER`](errors/rt-ver.md): runtime verification failed
- [`RT-BND`](errors/rt-bnd.md): runtime information unreadable
- [`RT-ROS`](errors/rt-ros.md): Rosetta missing
- [`RT-BLK`](errors/rt-blk.md): Intel translation blocked

If the Mac cannot run the selected architecture, update macOS for **ARM64 (Apple Silicon)**, or choose another architecture.

A launcher release may not include the ARM64 download. In that case, update the launcher.

If another operation runs, wait for it to finish and try again. [Report a problem](README.md#report-a-problem) if nothing helps. Include the architecture you chose.

## Canary Features

**Settings → Installation → Canary Features** turns on experimental options. There are no Canary features right now. Turning it off restores normal behavior and deletes nothing.

If a Canary option causes a problem, turn it off and mention it in your [report](README.md#report-a-problem).
