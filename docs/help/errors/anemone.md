---
title: ANEMONE
description: Compatibility files in the game folder could not be applied or restored
order: 90
audience: users
code: ANEMONE
domain: runtime
---

# ANEMONE

The launcher could not safely apply, update, or restore a compatibility file in the game folder. These files enable the sign-in and Notices windows under Wine:

- Global, Japan, Korea, and China use the embedded browser.
- China (Bilibili) uses the login window of Bilibili.
- Taiwan signs in through your default browser and does not use these files.

The launcher does not overwrite unknown files.

## Try this

1. Quit Arknights and any official updater.
2. Choose **Repair**, confirm the full check, then choose **Retry**.
3. If Repair ends with `ANEMONE`, restart the Mac and run **Repair** again from **Settings → Installation**.

> [!IMPORTANT]
> Repair restores the official game files, then adds the compatibility files. Your Wine prefix, sign-ins, and settings stay.

> [!CAUTION]
> Do not delete or rename the `.original.helper` backups, the `.arknights-client-bilibili` folder, the bridge files, `userenv.dll`, or the temporary files of the launcher.

## Report this problem

Report the code, operation, region, and whether the second Repair failed. Attach no helper binaries.
