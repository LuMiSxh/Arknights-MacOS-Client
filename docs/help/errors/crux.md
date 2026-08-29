---
title: CRUX
description: The game runtime ended unexpectedly
order: 110
audience: users
code: CRUX
domain: process
---

# CRUX

The Wine or game process ended before launch completed, or exited abnormally after the game had been running.

## Try this

1. Choose **Retry** once after closing overlays or tools that modify game processes.
2. Check `wine.log` and `unity.log` through **Show Logs**.
3. If a game file is missing or corrupt, run a confirmed **Repair** from Settings.
4. If the log points to Wine, DXMT, or prefix setup, follow [Runtime compatibility](../runtime-compatibility.md).

> [!IMPORTANT]
> A normal exit after closing the game does not produce CRUX. The code is reserved for an abnormal or premature process exit.

## Logs and reports

Include the code, operation, region, whether a window appeared, and the last safe log lines before the exit. Remove local paths, account information, tokens, and private URLs. Account, payment, and in-game service failures belong to [Yostar Support](https://account.yo-star.com/contact).
