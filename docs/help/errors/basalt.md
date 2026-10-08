---
title: BASALT
description: A local file operation could not finish safely
order: 40
audience: users
code: BASALT
domain: installation
---

# BASALT

The launcher found a symbolic link, unsafe temporary file, permission failure, or other filesystem problem and stopped before it changed data. It can appear when you install, clear game caches, or move an installation to the Trash.

## Try this

1. Quit Arknights and any app that uses the affected folder.
2. Confirm that the folder is on a writable volume and your account owns it.
3. For installation failures, choose a local folder without symbolic links or cloud synchronization.
4. Choose **Retry** once if offered. If it happened at launcher start, fix the folder, then reopen the launcher.

> [!WARNING]
> Do not change ownership or permissions recursively across your home folder. Choose a new install location instead.

Repair cannot fix permissions, open files, or symbolic-link destinations.

## Report this problem

Report the code, operation, region, volume type, and whether a new local folder works.
