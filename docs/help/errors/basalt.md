---
title: BASALT
description: A required local file operation could not be completed safely
order: 40
audience: users
code: BASALT
domain: installation
---

# BASALT

The launcher found a symbolic link, unsafe temporary file, permission failure, or another local filesystem problem and stopped before changing data. This code can appear while installing, clearing game caches, or moving a regional installation to the Trash.

## Try this

1. Quit Arknights and any app that may be using the affected folder.
2. Confirm the folder is on a writable volume and owned by your macOS account.
3. For installation failures, choose a normal local folder without symbolic links or cloud synchronization.
4. Choose **Retry** once.

> [!WARNING]
> Do not change ownership or permissions recursively across your home folder. Choose a fresh install location instead.

Repair is useful only after an installation location itself is safe. It cannot fix filesystem permissions, clear a file held open by another process, or replace a symbolic-link destination.

## Logs and reports

Use **Show Logs** to find the operation that was refused. Remove your account name and private path components before sharing an excerpt. Report the code, operation, region, volume type, and whether a fresh local folder works.
