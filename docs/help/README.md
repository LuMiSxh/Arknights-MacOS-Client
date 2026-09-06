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
> Start with the least destructive step that matches the symptom. Reopen the launcher and check the selected region before deleting a prefix or reinstalling game files.

## What this project can support

The launcher owns its download, manifest verification, runtime setup, display integration, settings, and diagnostics. It can resume partial downloads, repair a regional installation, clear recreatable caches, and reset the shared Wine prefix when necessary.

## Publisher support routing

Account access, payments, billing, server availability, and in-game data belong to the official
publisher and payment provider, even when a page appears inside the game's embedded browser.
Route publisher questions by the selected region:

| Region or client        | Publisher  | Official support                                                       |
| ----------------------- | ---------- | --------------------------------------------------------------------- |
| Global, Japan, or Korea | Yostar     | [Yostar Support](https://account.yo-star.com/contact)                |
| China                   | Hypergryph | [Hypergryph Support](https://user.hypergryph.com/support)             |
| China — Bilibili        | Hypergryph | [Hypergryph Support](https://user.hypergryph.com/support)             |

Verify charges with the payment provider shown by the transaction, then contact the publisher
listed above for account, entitlement, billing, or game-service review. The launcher project
handles installation, runtime, graphics, window, and launcher-owned embedded-browser failures.

> [!NOTE]
> Global, Japan, Korea, and China clients can use the embedded login-window path described in this
> Help section. China — Bilibili uses its own client login flow; the embedded login-window guidance
> does not apply to that client.

## Before opening a report

Record the selected region, Mac model, macOS version, launcher version, and the step that failed.

The **Report a Problem…** action in the launcher opens a pre-filled public GitHub issue with basic environment metadata. When a failed operation has an error code, the report also includes that code, operation, and selected region. Log files are not needed for the initial report. If a maintainer later asks for a specific file, open **Settings → Storage** and choose **Show Logs**.
