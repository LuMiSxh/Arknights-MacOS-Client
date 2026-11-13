---
title: Game runtime
description: Supported macOS versions, the x86_64 and ARM64 runtimes, Rosetta 2, and recovery from a failed runtime
order: 41
---

# Game runtime

The runtime is the set of files that runs the Windows game on your Mac. The launcher downloads it. It is separate from the game files. You need no virtual machine or Windows.

Only Apple silicon Macs work: M-series Macs and the MacBook Neo (A18 Pro).

## Runtime options

| Runtime                   | How it runs               | macOS             |
| ------------------------- | ------------------------- | ----------------- |
| **x86_64**                | Through Rosetta 2         | macOS 15 to 27    |
| **ARM64 (Apple Silicon)** | Natively on Apple silicon | macOS 26 or later |

Use **ARM64 (Apple Silicon)** if your Mac runs macOS 26 or later.

## macOS support

| macOS          | Runtime you can use                                      |
| -------------- | -------------------------------------------------------- |
| macOS 15           | **x86_64** only.                                                    |
| macOS 26 and 27    | **ARM64 (Apple Silicon)** is recommended. **x86_64** is a fallback. |
| macOS 28 and later | **ARM64 (Apple Silicon)** only.                                     |

Apple says macOS 27 is the last release with general Rosetta support. From macOS 28, the launcher blocks the x86_64 runtime.

The launcher does not rely on Rosetta for ARM64. See Apple's [Rosetta details](https://support.apple.com/en-au/102527) and [developer notice](https://developer.apple.com/news/?id=w5ngl9k2).

On macOS 28 or later, setup selects **ARM64 (Apple Silicon)** by default. The **Runtime** step does not offer **x86_64**.

If you selected x86_64 on an earlier macOS and then upgraded, **System Check** asks you to switch to the ARM64 runtime. To switch:

1. Continue setup.
2. Choose **ARM64 (Apple Silicon)** in the **Runtime** step.

The next game launch uses the ARM64 runtime.

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

## Choose a runtime during setup

1. In the **Runtime** step, choose **ARM64 (Apple Silicon)** or **x86_64**. **ARM64 (Apple Silicon)** is recommended. On macOS 28 or later, only **ARM64 (Apple Silicon)** is offered.
2. Choose **Download and Continue** or **Continue**.
3. Wait for the download if one starts.

- **Download and Continue** downloads and installs the runtime.
- **Continue** uses the installed runtime you chose. It keeps the current runtime if you did not switch.

The launcher shows a note when the game may ask you to sign in again.

While the runtime downloads, the progress line shows the percentage, download size, and speed.

## Switch runtimes in Settings

1. Open **Settings → Runtime**.
2. In the **Active runtime** panel, choose **Switch to x86_64** or **Switch to ARM64**.
3. Read the warning about the separate game environment (Wine prefix).
4. Choose **Switch and Download** or **Switch**.

The warning title names the target, such as **Switch to ARM64?**.

- **Switch and Download** also downloads the runtime.
- **Switch** uses an installed runtime.

The next game launch uses the new runtime. On macOS 28 or later, the **Active runtime** panel does not offer **x86_64**. While the game or a download is running, the panel cannot switch runtimes. It shows the reason.

## What a switch changes

- The launcher downloads the selected runtime. The **Active runtime** panel shows its download size.
- The other runtime stays on disk. The panel shows the installed version for each runtime.
- **Remove Other Runtime** in the **Maintenance** panel deletes the runtime you are not using. Its game environment stays on disk.
- **Remove Runtime…** in the **Danger zone** deletes the runtime you are using. Its game environment stays on disk. Set up the runtime again before you play.
- Each runtime keeps its own game environment.
- A switch keeps both game environments. It does not copy sign-ins, settings, or resources.

The game may treat the new game environment as a fresh install. It can ask you to sign in and download resources again. See [Storage](storage.md#where-files-live) for the folders.

## Update the runtime after a launcher update

A launcher update can require a newer runtime. Home then shows **Runtime update required** and **Update Runtime** instead of **Play**.

1. Choose **Update Runtime** on Home or in **Settings → Runtime → Maintenance**.
2. Wait for the download to finish.
3. Choose **Play** when the button returns.

The **Runtime** panel shows **Update available**, the required version, and the installed version. The launcher removes the old runtime after the update. The launcher never downloads a runtime on its own.

## If a runtime fails

The **Runtime** panel and the **Runtime** setup step show a message and a support code. Match the code to the list below.

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

If the Mac cannot run the selected runtime, update macOS for **ARM64 (Apple Silicon)**, or choose another runtime.

A launcher release may not include the ARM64 download. In that case, update the launcher.

If another operation runs, wait for it to finish. Then try again. If nothing helps, [report a problem](README.md#report-a-problem). Include the runtime you chose.

## Canary Features

**Settings → Installation → Canary Features** turns on experimental options. There are no Canary features right now.

Turning it off restores normal behavior. It deletes nothing. If a Canary option causes a problem, turn it off and mention it in your [report](README.md#report-a-problem).
