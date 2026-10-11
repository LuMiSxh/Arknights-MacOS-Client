---
title: Third-party notices
description: Licenses, runtime components, and notices for Arknights Client
order: 20
---

# Third-party notices

> [!IMPORTANT]
> Arknights Client packages a prebuilt compatibility runtime. [`runtime.json`](../../runtime.json) pins its exact versions, archive hashes, and build provenance. The app also embeds small MPL-2.0 compatibility wrappers built from `RuntimeSupport/`. It does not distribute the Vuplex SDK or the upstream game files.

The app bundles one compact file with these notices. This website publishes the same content. The [License texts](license-texts.md) page holds the full text of every named license. The [Source code](source-code.md) page describes how to get the source.

`runtime.json` is the source of truth for the runtime artifact. Each source link below points to the provenance commit recorded there. This page is an inventory. It does not relicense a component or decide whether a redistribution is permitted. Read the verbatim texts and the upstream notices for that.

## Runtime components

<!-- runtime:begin components -->

| Component     | Version or revision                                                                                                                                                                                                            | License                                                                                                                                                  | Exact provenance source                                                                                                                      |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| WineCX / Wine | Wine 11.17, `e0aa380780b73e20fabcfe78fd42713b94929a53`                                                                                                                                                                         | LGPL-2.1-or-later and bundled third-party terms                                                                                                          | [dappermint/winecx commit](https://github.com/dappermint/winecx/tree/e0aa380780b73e20fabcfe78fd42713b94929a53)                               |
| DXMT          | 0.80-262-ge94c312, `e94c312f5c054263acf261cfa109edf13e757587`                                                                                                                                                                  | LGPL-2.1-or-later and bundled third-party terms                                                                                                          | [3Shain/dxmt commit](https://github.com/3Shain/dxmt/tree/e94c312f5c054263acf261cfa109edf13e757587)                                           |
| MoltenVK      | 1.4.2, `db66022459ffb663aa2b50f6b018bc2e124f5edf`                                                                                                                                                                              | Apache-2.0 and bundled third-party terms                                                                                                                 | [KhronosGroup/MoltenVK commit](https://github.com/KhronosGroup/MoltenVK/tree/db66022459ffb663aa2b50f6b018bc2e124f5edf)                       |
| Nix libraries | libpng-apng 1.6.46, libunistring 1.3, libffi 39, GMP 6.3.0, Brotli 1.1.0, GnuTLS 3.8.9, zlib 1.3.1, Nettle 3.10.1, libiconv 1.17, bzip2 1.0.8, FreeType 2.13.3, p11-kit 0.25.5, libidn2 2.3.8, gettext 0.22.5, libtasn1 4.20.0 | LGPL-2.1-or-later AND (GPL-2.0-or-later OR LGPL-3.0-or-later) AND (FTL OR GPL-2.0-only) AND BSD-3-Clause AND MIT AND Zlib AND libpng-2.0 AND bzip2-1.0.6 | [Runtime v0.7.0-rc2](https://github.com/LuMiSxh/Arknights-MacOS-Runtime/tree/v0.7.0-rc2), Nixpkgs `ac62194c3917d5f474c1a844b6fd6da2db95077d` |

<!-- runtime:end components -->

The pinned runtime archive has no media stack. It has no Wine Gecko, GStreamer, FFmpeg, or media codec libraries. The `Licenses/` directory and `NOTICE.md` in the archive carry the license texts of every component.

## Runtime build provenance

<!-- runtime:begin build -->

The v0.7.0-rc2 runtime was built from the release tag and exact inputs below. The base archive and Nixpkgs revision are build inputs, not independently selected runtime components. They remain part of the release's corresponding-source record.

| Build input             | Version or revision                                                                        | Exact provenance source                                                                                                                                                             |
| ----------------------- | ------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Runtime build           | Arknights macOS Runtime v0.7.0-rc2                                                         | [Runtime v0.7.0-rc2 tag](https://github.com/LuMiSxh/Arknights-MacOS-Runtime/tree/v0.7.0-rc2), [release](https://github.com/LuMiSxh/Arknights-MacOS-Runtime/releases/tag/v0.7.0-rc2) |
| Whisky base libraries   | v4.7.3, `a4b5d63493f80698cce5cad8e7212d9a51c8292037b00c478f4652636fcfd331` archive SHA-256 | [Whisky v4.7.3 release](https://github.com/dappermint/Whisky/releases/tag/v4.7.3)                                                                                                   |
| winecx-gptk base recipe | `0bf3eabc2f0d95154282eb86b11205cbbaae6c65`                                                 | [winecx-gptk commit](https://github.com/dappermint/winecx-gptk/tree/0bf3eabc2f0d95154282eb86b11205cbbaae6c65)                                                                       |
| Nixpkgs                 | `ac62194c3917d5f474c1a844b6fd6da2db95077d`                                                 | [Nixpkgs commit](https://github.com/NixOS/nixpkgs/tree/ac62194c3917d5f474c1a844b6fd6da2db95077d)                                                                                    |

<!-- runtime:end build -->

> [!IMPORTANT]
> The runtime also contains dynamically linked libraries for text, networking, cryptography, and compression. Their own licenses continue to apply.

## Generated inventory

Scripts generate the lists between the marker pairs. Do not edit them by hand. [License automation](../development/license-automation.md#generated-blocks) describes the markers.

<!-- licenses:begin launcher -->

## Launcher components

These components ship inside the app. `Not yet verified` means that the project has not confirmed the license of the component.

| Component                                                                                                                                          | Version | License   | Status   | Text                                                    |
| -------------------------------------------------------------------------------------------------------------------------------------------------- | ------- | --------- | -------- | ------------------------------------------------------- |
| [Sparkle](https://github.com/sparkle-project/Sparkle/tree/2.9.6) (with bundled bsdiff, sais-lite, ed25519, and signature-verifier notices)         | 2.9.6   | `MIT`     | Verified | [`sparkle.txt`](licenses/sparkle.txt)                   |
| [YouTubePlayerKit](https://github.com/SvenTiigi/YouTubePlayerKit/tree/2.0.5)                                                                       | 2.0.5   | `MIT`     | Verified | [`youtubeplayerkit.txt`](licenses/youtubeplayerkit.txt) |
| [Application icon](https://github.com/LuMiSxh/Arknights-MacOS-Client/tree/main/Resources) (`just icon` generates it from `Resources/AppIcon.icon`) | project | `MPL-2.0` | Verified | None                                                    |
| [Wallpaper tag data](https://github.com/LuMiSxh/Arknights-MacOS-Client/blob/main/Sources/ArknightsCore/Resources/WallpaperTags.json)               | project | `MPL-2.0` | Verified | None                                                    |
| [App icon tint source image](https://github.com/LuMiSxh/Arknights-MacOS-Client/blob/main/Sources/ArknightsCore/Resources/AppIconTintSource.png)    | project | `MPL-2.0` | Verified | None                                                    |
| [Game icon background image](https://github.com/LuMiSxh/Arknights-MacOS-Client/blob/main/Sources/ArknightsCore/Resources/GameIconBackground.png)   | project | `MPL-2.0` | Verified | None                                                    |
| [Operator icon frame graphic](https://github.com/LuMiSxh/Arknights-MacOS-Client/blob/main/Sources/ArknightsCore/Resources/OperatorIconFrame.svg)   | project | `MPL-2.0` | Verified | None                                                    |

<!-- licenses:end launcher -->

<!-- licenses:begin website -->

## Website components

The documentation website embeds these packages. They are not part of the app. The website build also embeds the transitive dependencies of these packages. Each dependency keeps its own license.

| Component                                                                              | Version | License        | Status   | Text                                                              |
| -------------------------------------------------------------------------------------- | ------- | -------------- | -------- | ----------------------------------------------------------------- |
| [marked](https://github.com/markedjs/marked/tree/v18.0.11)                             | 18.0.11 | `MIT`          | Verified | [`marked.txt`](licenses/marked.txt)                               |
| [marked-gfm-heading-id](https://github.com/markedjs/marked-gfm-heading-id/tree/v4.1.4) | 4.1.4   | `MIT`          | Verified | [`marked-gfm-heading-id.txt`](licenses/marked-gfm-heading-id.txt) |
| [mermaid](https://github.com/mermaid-js/mermaid/tree/mermaid@11.17.2)                  | 11.17.2 | `MIT`          | Verified | [`mermaid.txt`](licenses/mermaid.txt)                             |
| [yaml](https://github.com/eemeli/yaml/tree/v2.9.0)                                     | 2.9.0   | `ISC`          | Verified | [`yaml.txt`](licenses/yaml.txt)                                   |
| [svelte](https://github.com/sveltejs/svelte/tree/svelte@5.57.0)                        | 5.57.0  | `MIT`          | Verified | [`svelte.txt`](licenses/svelte.txt)                               |
| [@sveltejs/kit](https://github.com/sveltejs/kit/tree/@sveltejs/kit@2.70.3)             | 2.70.3  | `MIT`          | Verified | [`sveltejs-kit.txt`](licenses/sveltejs-kit.txt)                   |
| [anasthasia](https://github.com/LuMiSxh/Anasthasia/tree/v0.2.4)                        | 0.2.4   | `BSD-3-Clause` | Verified | [`anasthasia.txt`](licenses/anasthasia.txt)                       |

<!-- licenses:end website -->

<!-- licenses:begin runtime -->

## Runtime components

The runtime archive lists its components and their licenses in `Licenses/index.json`. The [license texts](license-texts.md) page merges that list with the launcher components when the maintainer generates it with a prepared runtime.
<!-- licenses:end runtime -->

A runtime dependency can carry an additional notice. The release artifact and upstream source distributions remain authoritative for the complete notice set.

> [!WARNING]
> A component with the status `Not yet verified` has no confirmed license. A public binary release needs a verified license for every shipped component. Do not remove a notice because a component is dynamically linked.

## Included and excluded material

| Material                                   | Packaged?                       | Where its boundary is recorded                                                                                                                                                           |
| ------------------------------------------ | ------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Native launcher                            | Yes                             | Repository source and top-level [`LICENSE`](../../LICENSE)                                                                                                                               |
| Project compatibility wrappers and bridges | Yes                             | `RuntimeSupport/` source at the matching tag; MPL-2.0 SPDX markers                                                                                                                       |
| WineCX + DXMT runtime                      | Yes, as a prebuilt runtime unit | [`runtime.json`](../../runtime.json), `RUNTIME.json`, and this page                                                                                                                      |
| Sparkle framework                          | Yes                             | [License text](license-texts.md#sparkle) and the Sparkle project                                                                                                                         |
| YouTubePlayerKit                           | Yes                             | [License text](license-texts.md#youtubeplayerkit)                                                                                                                                        |
| Arknights game files                       | No                              | Downloaded from first-party publisher endpoints after the user starts installation: Yostar for Global, Japan, and Korea; Gryphline for Taiwan; Hypergryph for China and China (Bilibili) |
| Wine Mono                                  | No                              | Explicitly excluded by packaging                                                                                                                                                         |
| DXVK                                       | No                              | Not copied into the app bundle                                                                                                                                                           |
| Apple Game Porting Toolkit                 | No                              | Not copied into the app bundle                                                                                                                                                           |

> [!WARNING]
> A source link or license text is not evidence that a release bundles a dependency. Before you describe an artifact, confirm the actual app bundle, its `RUNTIME.json`, and its `ThirdPartyNotices.deflate`.

## Release review

See the [release review](../development/releases-and-updates.md#release-review) for the checks before a public release.
