---
title: NARWHAL
description: The game process started but no visible window appeared in time
order: 100
audience: users
code: NARWHAL
domain: runtime
---

# NARWHAL

Wine started the game process, but Arknights did not show a visible window within 90 seconds. The launcher stopped the timed-out runtime before presenting this code.

## Try this

1. Wait for other heavy downloads or first-run macOS work to finish.
2. Choose **Retry** once; a warm Wine prefix and populated caches often start faster.
3. Use **Show Logs** and check `wine.log`, `unity.log`, and `chromium.log` for the last launch.
4. If integrity errors appear, run a confirmed **Repair** from Settings before launching again.

> [!NOTE]
> Notices and sign-in pages can take up to a minute on a cold first start. If the game window is already visible and only embedded web content is blank, use the [FAQ](../faq.md#why-is-sign-in-or-the-notices-window-blank-or-slow) instead.

## Logs and reports

Use **Show Logs** and review `wine.log`, `unity.log`, and `chromium.log` around the timed-out launch. Report the code, region, whether this was the first launch after an update, and whether a second attempt behaved differently.
