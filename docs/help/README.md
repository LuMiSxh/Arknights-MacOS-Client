---
title: Help
description: Support for installation, sign-in, launch, storage, and runtime problems
order: 20
---

# Help

Use this section after [Installation](../installation.md) when the launcher, a regional game installation, sign-in, or the Wine runtime needs attention.

## Find the right guide

| What you are trying to do                                            | Start here                                        |
| -------------------------------------------------------------------- | ------------------------------------------------- |
| Install the launcher or a region                                     | [Installation](../installation.md)                |
| Understand a warning or failed launch                                | [Troubleshooting](troubleshooting.md)             |
| Find game files, logs, or the Wine prefix                            | [Storage](storage.md)                             |
| Understand Rosetta, Wine, and DXMT                                   | [Runtime compatibility](runtime-compatibility.md) |
| Check whether a behavior belongs to the launcher or the game service | [FAQ](faq.md)                                     |
| Look up a word shown with a launcher failure                         | [Error codes](errors/README.md)                   |

> [!TIP]
> Start with the least destructive step that matches the symptom. Reopen the launcher, check the selected region, and use **Settings → Storage → Show Logs** before deleting a prefix or reinstalling game files.

## What this project can support

The launcher owns its download, manifest verification, runtime setup, display integration, settings, and diagnostics. It can resume partial downloads, repair a regional installation, clear recreatable caches, and reset the shared Wine prefix when necessary.

> [!IMPORTANT]
> Yostar owns the account, payment, and game-service endpoints. Contact [Yostar Support](https://account.yo-star.com/contact) for login ownership, purchases, billing, server availability, or in-game account data. Use the launcher's report flow for launcher, installation, runtime, graphics, or embedded-browser failures.

## Before opening a report

Record the selected region, Mac model, macOS version, launcher version, and the step that failed. Then collect the relevant log excerpts from [Troubleshooting](troubleshooting.md#log-locations). Remove account data, private paths, tokens, and unrelated URLs before sharing logs.

The **Report a Problem…** action in the launcher opens a pre-filled public GitHub issue with basic environment metadata. When a failed operation has an error code, the report also includes that code, operation, and selected region. Logs and error messages are never attached automatically; you choose what to review and attach.
