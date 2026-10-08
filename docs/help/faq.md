---
title: Frequently asked questions
description: Answers about the project, regions, updates, and privacy
order: 10
---

# Frequently asked questions

## Is this an official launcher?

No. It is a community project, not affiliated with Yostar, Gryphline, Hypergryph, or Bilibili. It downloads the official game from your publisher. Publishers can treat third-party launchers as they choose.

## Does the download include the game?

No. The DMG contains only the launcher and Wine. The launcher downloads the game after you choose a region.

## Which regions can I play?

Global, Japan, Korea, China, and China (Bilibili). Taiwan is a [Canary region](../installation.md#canary-regions). Regions install side by side with separate files and versions.

## Do I need an internet connection?

Yes. The game has no offline mode.

## Does the launcher update the game on its own?

No. It downloads only when you choose **Update**. Launcher updates work the same way and never change game files.

## What is the difference between update, resume, and repair?

- **Update** downloads only changed files.
- **Resume** continues an interrupted download.
- **Repair** checks every file and downloads missing or damaged files again.

## Does the launcher change the game files?

It adds compatibility files for Wine. It restores the originals before every update or repair. Do not replace them.

## Why does macOS ask for Local Network access?

The game needs it to connect through Wine.

## Can I quit the launcher while playing?

No. Quitting the launcher quits the game. Closing its window does not.

## Why do notices still appear with announcements turned off?

The setting covers only project announcements. Publisher notices come from the game.

## Does “Report a Problem…” upload my logs?

No. It opens a public GitHub issue with basic error and Mac details. You can review them before sending. See [Report a problem](README.md#report-a-problem).

## Is Game Mode required?

No. It is optional, off by default, and needs the full Xcode app. Without Xcode, the setting is greyed out.

## Who helps with accounts and payments?

Your publisher. See [Publisher support routing](README.md#publisher-support-routing).
