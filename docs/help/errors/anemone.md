---
title: ANEMONE
description: Launcher-owned game compatibility files could not be applied or restored safely
order: 90
audience: users
code: ANEMONE
domain: runtime
---

# ANEMONE

The launcher could not safely apply, update, or restore one of the compatibility files it adds to the game folder. These files make the in-game sign-in and Notices windows work under Wine: the embedded browser for Global, Japan, Korea, and China, and Bilibili's own login window for China — Bilibili. Taiwan signs in through your Mac's default browser and does not use them. The launcher stops instead of overwriting a file it does not recognize.

## Try this

1. Quit Arknights and any official updater that may be changing the game folder.
2. Choose **Repair**, confirm the full check, and let it finish.
3. Choose **Retry**.
4. If Repair itself ends with `ANEMONE`, restart the Mac once and run **Repair** again from **Settings → Installation**.

> [!IMPORTANT]
> Repair restores the official game files and then adds the launcher's compatibility files again. Your Wine prefix, sign-ins, and settings stay.

> [!CAUTION]
> Do not delete or rename the `.original.helper` backups, the `.arknights-client-bilibili` folder, the bridge files, `userenv.dll`, or the launcher's temporary files by hand.

## Report this problem

Report the code, operation, region, and whether the second Repair failed. Do not attach helper binaries.
