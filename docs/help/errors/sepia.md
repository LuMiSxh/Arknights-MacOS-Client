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
3. Open **Show Logs** and identify whether the failure mentions migration, registry, or DXMT.
4. Follow the matching step in [Runtime compatibility](../runtime-compatibility.md).

> [!CAUTION]
> Deleting the Wine prefix signs the embedded browser out and rebuilds Windows-side settings. Do it only through the launcher's confirmed maintenance action after less destructive steps fail.

Repair checks game files and normally does not fix prefix configuration. If the message concerns Vuplex, PlatformProcess, userenv, or restoring an official game helper, use [ANEMONE](anemone.md) instead.

## Logs and reports

Use **Show Logs** to identify whether launch, Force Migration, or Delete Wine Prefix failed. Report the code and operation, whether another Wine process was open, and the last migration or registry stage. Review paths before sharing excerpts.
