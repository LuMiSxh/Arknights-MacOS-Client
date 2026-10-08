---
title: SEPIA
description: Wine, DXMT, or the shared prefix could not be configured
order: 80
audience: users
code: SEPIA
domain: runtime
---

# SEPIA

The launcher found the runtime, but a setup step failed: Wine prefix migration, registry setup, DXMT installation, or another runtime step.

## Try this

1. Quit other Wine apps.
2. Choose **Retry** once.
3. Choose **Settings → Installation → Rebuild…**, then start the game. This sets up the game environment again and deletes nothing.
4. As a last resort, choose **Delete Environment…**. It keeps your game files but signs you out. See [What cleanup removes](../storage.md#what-cleanup-removes).

Repair cannot fix this code. For a Rosetta or macOS problem, see [macOS compatibility](../runtime-compatibility.md). If the message mentions Vuplex, PlatformProcess, the Bilibili login window, userenv, or restoring an official game helper, use [ANEMONE](anemone.md).

## Report this problem

Report the code, operation, whether another Wine process was open, and which recovery step failed.
