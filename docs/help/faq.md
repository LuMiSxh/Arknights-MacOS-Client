---
title: Frequently asked questions
description: Answers about the project, game files, regions, updates, and privacy
order: 10
---

# Frequently asked questions

## Is this an official launcher?

No. Arknights Client is a community project and is not affiliated with Yostar, Gryphline, Hypergryph, or Bilibili. It downloads the official game from your region's publisher, but it cannot promise how a publisher treats third-party launchers.

## Does the download include the game?

No. The DMG contains only the launcher and the Wine environment it needs. The game is downloaded from the publisher after you choose a region.

## Which regions can I play?

Global, Japan, and Korea by default. Taiwan, China, and China — Bilibili are available as [Canary regions](../installation.md#canary-regions). You can install several regions side by side; each keeps its own files and version.

## Do I need an internet connection?

Yes, for installing, updating, signing in, and playing. The game has no offline mode.

## Does the launcher update the game on its own?

No. It checks for updates and shows **Update**, but only downloads when you choose it. Launcher updates work the same way and never touch game files.

## What is the difference between update, resume, and repair?

- **Update** downloads only files that changed in the new version.
- **Resume** continues an interrupted download.
- **Repair** checks every file and downloads missing or damaged ones again.

## Does the launcher change the game files?

It adds a few compatibility files so the game runs under Wine, and restores the originals before every update or repair. Do not replace these files by hand.

## Why does macOS ask for Local Network access?

The game needs it to connect while it runs through Wine. The launcher does not upload anything.

## Can I quit the launcher while playing?

No. Quitting Arknights Client also quits the game. Closing the launcher window is fine.

## Why do notices still appear with announcements turned off?

That setting only covers project announcements. Notices from the publisher come from the game service and still appear.

## Does “Report a Problem…” upload my logs?

No. It opens a public GitHub issue with basic details about the error and your Mac, which you can review before sending. See [Report a problem](README.md#report-a-problem).

## Is Game Mode required?

No. It is an optional experiment, off by default, and needs the full Xcode app to work.

## Who helps with accounts and payments?

Your region's publisher. See [Publisher support routing](README.md#publisher-support-routing).
