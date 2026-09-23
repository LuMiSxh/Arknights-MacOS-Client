---
title: SEPIA
description: Wine, DXMT, or the shared prefix could not be configured
order: 80
audience: users
code: SEPIA
domain: runtime
---

# SEPIA

The runtime was found, but Wine prefix migration, registry setup, DXMT installation, or another runtime setup step did not complete.

## Try this

1. Quit other Wine-based apps that may be using the same files.
2. Choose **Retry** once.
3. Choose **Settings → Installation → Force Migration…**, then start the game again. This reruns the setup without deleting anything.
4. As a last resort, choose **Delete Wine Prefix…**. It keeps your game files but signs you out; see [What cleanup removes](../storage.md#what-cleanup-removes).

If the launcher also reports a Rosetta or macOS problem, see [macOS compatibility](../runtime-compatibility.md). Repair checks game files and does not fix this code. If the message mentions Vuplex, PlatformProcess, the Bilibili login window, userenv, or restoring an official game helper, use [ANEMONE](anemone.md) instead.

## Report this problem

Report the code and operation, whether another Wine process was open, and which recovery step failed.
