---
title: ANEMONE
description: Launcher-owned game compatibility files could not be applied or restored safely
order: 90
audience: users
code: ANEMONE
domain: runtime
---

# ANEMONE

The launcher could not safely apply, update, or restore one of its game-file compatibility helpers. These helpers make the embedded sign-in browser and Notices window work correctly through Wine. The launcher stops instead of overwriting an unknown file or leaving an official helper without a recoverable backup.

## Try this

1. Quit Arknights and any official updater that may be changing the same game folder.
2. In the launcher, choose **Repair**, confirm the full verification, and let it finish.
3. Choose **Retry** after Repair completes.
4. If the code returns, choose **Report Problem** and say whether Repair completed.

> [!IMPORTANT]
> Repair restores official game files from the publisher and then reapplies only launcher-owned compatibility files. It preserves the Wine prefix, saved sign-ins, and launcher settings.

> [!CAUTION]
> Do not delete or rename `.original.helper`, bridge, DLL, or launcher temporary files by hand. A rollback failure means the launcher could not prove that another manual change would preserve the official helper.

If Repair itself ends with `ANEMONE`, restart the Mac once to release any open helper files, then start Repair again from **Settings → Installation**.

## Report this problem

Report the code, operation, region, and whether the second Repair failed. Do not attach helper binaries.
