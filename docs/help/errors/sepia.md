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

1. Quit other Wine-based tools that may be using the same prefix.
2. Choose **Retry** once.
3. If Retry fails, follow the Wine, prefix, and DXMT recovery steps in [Runtime compatibility](../runtime-compatibility.md).

> [!CAUTION]
> Deleting the Wine prefix signs the embedded browser out for clients that use it and rebuilds Windows-side settings. Do it only through the launcher's confirmed maintenance action after less destructive steps fail.

Repair checks game files and normally does not fix prefix configuration. If the message concerns Vuplex, PlatformProcess, userenv, or restoring an official game helper, use [ANEMONE](anemone.md) instead.

## Report this problem

Report the code and operation, whether another Wine process was open, and which recovery step failed.
