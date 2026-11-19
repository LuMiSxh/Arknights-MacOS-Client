---
title: Legal
description: Licensing, third-party notices, and corresponding-source information
order: 40
---

# Legal

Arknights Client is a community project. It is not affiliated with Yostar, Gryphline, Hypergryph, or Bilibili. Arknights, its game files, names, and artwork belong to their respective owners.

## Read by purpose

| If you need to                                            | Read                                                       |
| --------------------------------------------------------- | ---------------------------------------------------------- |
| Check the license of the launcher and get its source code | [Source code](source-code.md)                              |
| See which third-party components ship, and why            | [Third-party notices](third-party-notices.md)              |
| Learn how the notices are generated                       | [License automation](../development/license-automation.md) |
| Read a full license text                                  | [License texts](license-texts.md)                          |

## What a release contains

| Part                         | License                                                                                                  |
| ---------------------------- | -------------------------------------------------------------------------------------------------------- |
| The launcher                 | MPL-2.0. Source is available from the matching repository tag                                            |
| x86_64 runtime               | Downloaded on first use. Each component's own license. See [Third-party notices](third-party-notices.md) |
| ARM64 runtime                | Downloaded on first use. Each component's own license. See [Third-party notices](third-party-notices.md) |
| Sparkle and YouTubePlayerKit | Their own licenses. See [License texts](license-texts.md)                                                |
| Arknights game files         | Not included. Downloaded from the publisher after you choose a region                                    |
| Artwork                      | Not included. Official wallpapers are downloaded and cached at runtime                                   |

> [!WARNING]
> The launcher's MPL-2.0 license does not cover the downloaded runtime components, the game, or its artwork. Check each component's license before you redistribute a build.

The app bundles one compact file with the notices of its own components. Each runtime archive carries its own license texts and notices; the launcher shows them for the installed runtime under **Settings → About**. This website publishes the launcher notices.
