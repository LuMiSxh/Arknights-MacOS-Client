---
title: Frequently asked questions
description: Answers about the project, servers, updates, and privacy
order: 10
---

# Frequently asked questions

## Is this an official launcher?

No. It is a community project. It is not affiliated with Yostar, Gryphline, Hypergryph, or Bilibili. It downloads the official game from your publisher. Publishers can treat third-party launchers as they choose.

## Does the download include the game?

No. The DMG contains only the launcher and Wine. The launcher downloads the game after you choose a server.

## Which servers can I play?

You can play these servers: Global, Japan, Korea, Taiwan, China, and China (Bilibili). Each server has separate files and versions. Servers install side by side.

## Do I need an internet connection?

Yes. The game has no offline mode.

## Does the launcher update the game on its own?

No. It downloads only when you choose **Update**. Launcher updates work the same way. They never change game files.

## What is the difference between update, resume, and repair?

- **Update** downloads only changed files.
- **Resume** continues an interrupted download.
- **Repair** checks every file and downloads missing or damaged files again.

## Does the launcher change the game files?

Yes. It adds compatibility files for Wine. It restores the originals before every update or repair. Do not replace the compatibility files.

## Why does macOS ask for Local Network access?

The game needs it to connect through Wine.

## Can I quit the launcher while playing?

No. Quitting the launcher quits the game. Closing its window does not.

## Why do notices still appear with announcements turned off?

The setting covers only project announcements. Publisher notices come from the game.

## Does “Report a Problem…” upload my logs?

No. It opens a public GitHub issue with basic error and Mac details. Logs are not included. You can review the details before sending.

See [Report a problem](README.md#report-a-problem).

## Is Game Mode required?

No. It is optional and off by default. It needs the full Xcode app. Without Xcode, the setting is greyed out.

## Who helps with accounts and payments?

Contact your publisher.

See [Publisher support routing](README.md#publisher-support-routing).

## How do I change the game volume in a per-app volume tool?

It depends on the runtime. With **ARM64**, tools such as FineTune and SoundSource list the game as its own **Arknights** entry. Change the game volume there.

With **x86_64**, these tools list the game under **Arknights Client**, not **Arknights**. That runtime gives the game no app bundle of its own, so the tools assign its audio to the launcher. Use the **Arknights Client** entry for the game volume. That entry also contains the launcher music.

To change launcher music settings, use **Settings → Integration**.
