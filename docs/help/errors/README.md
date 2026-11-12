---
title: Error codes
description: What launcher error codes mean and what to do
order: 10
audience: users
---

# Error codes

The launcher shows a short code when a failed operation has a specific fix. The code stays the same across versions.

## Start with the code you see

1. Find the code in [Codes by area](#codes-by-area). Open its page.
2. Do the steps in order. Stop when it works.

> [!CAUTION]
> Do not delete the shared game environment (Wine prefix), game files, or partly downloaded files unless the page says so.

If the launcher shows no code, use [Troubleshooting](../troubleshooting.md).

## Codes by area

Each code has its own page. The page title starts with the code.

<!-- support-codes:begin codes -->
### Service

| Code | Problem | What to do |
| --- | --- | --- |
| [SV-CNT](sv-cnt.md) | Remote content not usable | Update the launcher, or wait and check again later. |
| [SV-ERR](sv-err.md) | Game service error | Check the network. If the service is in maintenance, wait. |

### Network

| Code | Problem | What to do |
| --- | --- | --- |
| [NW-OFF](nw-off.md) | No network connection | Check that the Mac can open ordinary websites. |

### Installation

| Code | Problem | What to do |
| --- | --- | --- |
| [IN-BSY](in-bsy.md) | Installation in use | Wait for the other launcher to finish, or restart the Mac. |
| [IN-DIR](in-dir.md) | Install folder cannot be used | Choose a local folder that your account owns. |
| [IN-DLD](in-dld.md) | Download incomplete or damaged | Check the connection and any proxy. Then select **Retry** or **Repair**. |
| [IN-DSK](in-dsk.md) | Not enough free disk space | Free disk space, then empty the Trash. |
| [IN-MAN](in-man.md) | Unsafe game file list | Update the launcher, or wait for a corrected file list. |
| [IN-MIS](in-mis.md) | Game files missing | Quit apps that change the game folder. Then restart the Mac. |

### Files

| Code | Problem | What to do |
| --- | --- | --- |
| [FS-MIG](fs-mig.md) | Launcher data migration failed | Quit apps that use the data folder. Then choose **Retry**. |
| [FS-WRT](fs-wrt.md) | Local file action failed | Quit apps that use the affected files. Check folder permissions. |

### Runtime

| Code | Problem | What to do |
| --- | --- | --- |
| [RT-BIL](rt-bil.md) | Bilibili login unavailable | Quit other Wine apps, then restart the Mac. |
| [RT-BLK](rt-blk.md) | Intel translation blocked | Use the ARM64 runtime on macOS 28 or later. On a macOS 27 beta, turn off Legacy Game Test Mode. |
| [RT-BND](rt-bnd.md) | Runtime information missing or damaged | Replace the launcher with a complete copy from the release DMG. |
| [RT-CMP](rt-cmp.md) | Game compatibility setup failed | Quit the official updater. Then choose **Repair**. |
| [RT-MIS](rt-mis.md) | Runtime not installed | Choose **Set Up Runtime** on Home, then start the game. |
| [RT-ROS](rt-ros.md) | Rosetta unavailable | Install Rosetta if the launcher offers it. |
| [RT-SET](rt-set.md) | Runtime setup failed | Choose **Settings → Help → Troubleshooting → Rebuild…**, then start the game. |
| [RT-VER](rt-ver.md) | Runtime failed verification | Download the runtime again. If it fails again, report the problem. |

### Game

| Code | Problem | What to do |
| --- | --- | --- |
| [GM-CRS](gm-crs.md) | Game closed unexpectedly | Close overlays and tools that change game processes. |
| [GM-SCP](gm-scp.md) | Screen Recording is off | Allow Screen Recording for Arknights Client in System Settings. |
| [GM-SCW](gm-scw.md) | No game window to capture | Show the game window, then try again. |
| [GM-WIN](gm-win.md) | No game window | Wait for other downloads to finish. Then start the game again. |

### Update

| Code | Problem | What to do |
| --- | --- | --- |
| [UP-ERR](up-err.md) | Launcher update failed | Check the connection, then check for an update again. |

### Customization

| Code | Problem | What to do |
| --- | --- | --- |
| [UI-ICN](ui-icn.md) | App icon not updated | Choose another image, then try again. |
| [UI-IMG](ui-img.md) | Artwork image not usable | Choose an image that meets the size limits, then select it again. |
<!-- support-codes:end codes -->

## Codes before 0.8.0

Launcher 0.8.0 replaced these codes. Open the page for the new code.

<!-- support-codes:begin retired -->
| Old code | New code |
| --- | --- |
| ANEMONE | [RT-CMP](rt-cmp.md) |
| BASALT | [IN-BSY](in-bsy.md), [IN-DIR](in-dir.md), [FS-MIG](fs-mig.md), [FS-WRT](fs-wrt.md) |
| CRUX | [GM-CRS](gm-crs.md) |
| GABBRO | [IN-MAN](in-man.md) |
| LIMPET | [RT-BLK](rt-blk.md), [RT-ROS](rt-ros.md) |
| NARWHAL | [GM-WIN](gm-win.md) |
| PEBBLE | [SV-CNT](sv-cnt.md), [IN-DLD](in-dld.md), [IN-MIS](in-mis.md) |
| SCREE | [IN-DSK](in-dsk.md) |
| SEPIA | [RT-SET](rt-set.md) |
| VIRGA | [SV-ERR](sv-err.md) |
| WHELK | [RT-BND](rt-bnd.md) |
<!-- support-codes:end retired -->

## Publisher support

The publisher and payment provider handle account, payment, and billing problems. They also handle server and in-game service problems.

Use the [publisher support routing table](../README.md#publisher-support-routing) to find the right contact.
