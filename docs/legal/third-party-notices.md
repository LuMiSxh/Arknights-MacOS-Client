---
title: Third-party notices
description: Licenses, runtime components, and notices for Arknights Client
order: 20
---

# Third-party notices

> [!IMPORTANT]
> Arknights Client packages a prebuilt compatibility runtime. [`runtime.json`](../../runtime.json) pins its exact versions, archive hashes, and build provenance. The app also embeds small MPL-2.0 compatibility wrappers built from `RuntimeSupport/`. It does not distribute the Vuplex SDK or the upstream game files.

The app bundles one compact file with these notices. This website publishes the same content. The [License texts](license-texts.md) page holds the full text of every license that the lists below name. The [Source code](source-code.md) page describes how to get the source.

## How to read this page

`runtime.json` is the source of truth for the runtime artifact and its interface. The component versions below are the human-readable labels from that file. Each source link points to the exact provenance commit recorded there. Packaging copies the release's `RUNTIME.json` from the same input, so you can check it without trusting the checkout that built the app.

This page is an inventory and release-review aid. It does not relicense a component. It does not summarize every condition of a license. It does not determine whether a particular redistribution is permitted. To decide that, read the verbatim text on the [License texts](license-texts.md) page and the upstream project notices.

## Runtime components

| Component     | Version or revision                                                                      | License                                                                                             | Exact provenance source                                                                                                |
| ------------- | ---------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| WineCX / Wine | Wine 11.17, `e0aa380780b73e20fabcfe78fd42713b94929a53`                                   | LGPL-2.1-or-later and bundled third-party terms                                                     | [dappermint/winecx commit](https://github.com/dappermint/winecx/tree/e0aa380780b73e20fabcfe78fd42713b94929a53)         |
| DXMT          | 0.80-244-g7c8dee1, `7c8dee1c2d73415301ceb7d1fa810861cef4cd67`                            | LGPL-2.1-or-later and bundled third-party terms                                                     | [3Shain/dxmt commit](https://github.com/3Shain/dxmt/tree/7c8dee1c2d73415301ceb7d1fa810861cef4cd67)                     |
| MoltenVK      | 1.4.2, `db66022459ffb663aa2b50f6b018bc2e124f5edf`                                        | Apache-2.0 and bundled third-party terms                                                            | [KhronosGroup/MoltenVK commit](https://github.com/KhronosGroup/MoltenVK/tree/db66022459ffb663aa2b50f6b018bc2e124f5edf) |
| Wine Gecko    | 2.47.4, `557ea0c2e9f9ebd621323b3dbfbdd18c2528759c`                                       | MPL/GPL/LGPL terms and Mozilla notices                                                              | [Wine Gecko commit](https://gitlab.winehq.org/wine/wine-gecko/-/tree/557ea0c2e9f9ebd621323b3dbfbdd18c2528759c)         |
| GStreamer     | 1.26.3 (no longer bundled from runtime 0.7.0)                                            | Mostly LGPL-2.1-or-later; selected plugins and dependencies are GPL-2.0-or-later or use other terms | [GStreamer commit](https://github.com/GStreamer/gstreamer/tree/87bc0c6e949e3dcc440658f78ef52aa8088cb62f)               |
| FFmpeg        | 7.1.1 (no longer bundled from runtime 0.7.0), `db69d06eeeab4f46da15030a80d539efb4503ca8` | GPL-3.0-or-later for the bundled configuration                                                      | [FFmpeg commit](https://github.com/FFmpeg/FFmpeg/tree/db69d06eeeab4f46da15030a80d539efb4503ca8)                        |

## Runtime build provenance

The v0.6.1 runtime was built from the release commit and exact inputs below. The base archive and Nixpkgs revision are build inputs, not independently selected runtime components. They remain part of the release's corresponding-source record.

| Build input             | Version or revision                                                                        | Exact provenance source                                                                                                                                                                                      |
| ----------------------- | ------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Runtime build           | Arknights macOS Runtime v0.6.1, `e53f807f6567209482fa0be134b8fee85d01e60c`                 | [Runtime v0.6.1 commit](https://github.com/LuMiSxh/Arknights-MacOS-Runtime/tree/e53f807f6567209482fa0be134b8fee85d01e60c), [release](https://github.com/LuMiSxh/Arknights-MacOS-Runtime/releases/tag/v0.6.1) |
| Whisky base libraries   | v4.6.8, `19b9d7942b8cfd4871eee2a8f81abc7c849307c7858873f9b504c24c1bb6b25d` archive SHA-256 | [Whisky v4.6.8 release](https://github.com/dappermint/Whisky/releases/tag/v4.6.8)                                                                                                                            |
| WineCX GPTK base recipe | `f374f5bae40631a466c03c59180ca34605091efd`                                                 | [winecx-gptk commit](https://github.com/dappermint/winecx-gptk/tree/f374f5bae40631a466c03c59180ca34605091efd)                                                                                                |
| Nixpkgs                 | `ac62194c3917d5f474c1a844b6fd6da2db95077d`                                                 | [Nixpkgs commit](https://github.com/NixOS/nixpkgs/tree/ac62194c3917d5f474c1a844b6fd6da2db95077d)                                                                                                             |

> [!IMPORTANT]
> The runtime also contains dynamically linked libraries for media, text, networking, compression, and X11 compatibility. Notable media dependencies include x264, x265, FDK-AAC, FAAD2, libdvdcss, libdvdnav, libdvdread, OpenH264, libde265, libaom, dav1d, SVT-AV1, libvpx, LAME, OpenMPT, FLAC, Vorbis, Opus, Theora, Speex, and libsndfile. Their own licenses and patent terms continue to apply.

## Generated inventory

A script generates the component lists in this page. The script reads `docs/legal/licenses/index.json`, `Package.resolved`, `web/package.json`, and `runtime.json`. Do not edit the lists between the `licenses:begin` and `licenses:end` markers by hand. The developer guide `docs/development/license-automation.md` describes the process.

<!-- licenses:begin launcher -->

## Launcher components

These components ship inside the app. `Not yet verified` means that the project has not confirmed the license of the component.

| Component                                                                                                                                          | Version | License   | Status   | Text                                                    |
| -------------------------------------------------------------------------------------------------------------------------------------------------- | ------- | --------- | -------- | ------------------------------------------------------- |
| [Sparkle](https://github.com/sparkle-project/Sparkle/tree/2.9.6) (with bundled bsdiff, sais-lite, ed25519, and signature-verifier notices)         | 2.9.6   | `MIT`     | Verified | [`sparkle.txt`](licenses/sparkle.txt)                   |
| [YouTubePlayerKit](https://github.com/SvenTiigi/YouTubePlayerKit/tree/2.0.5)                                                                       | 2.0.5   | `MIT`     | Verified | [`youtubeplayerkit.txt`](licenses/youtubeplayerkit.txt) |
| [Application icon](https://github.com/LuMiSxh/Arknights-MacOS-Client/tree/main/Resources) (`just icon` generates it from `Resources/AppIcon.icon`) | project | `MPL-2.0` | Verified | None                                                    |
| [Wallpaper tag data](https://github.com/LuMiSxh/Arknights-MacOS-Client/blob/main/Sources/ArknightsClient/Resources/WallpaperTags.json)             | project | `MPL-2.0` | Verified | None                                                    |
| [App icon tint source image](https://github.com/LuMiSxh/Arknights-MacOS-Client/blob/main/Sources/ArknightsClient/Resources/AppIconTintSource.png)  | project | `MPL-2.0` | Verified | None                                                    |
| [Game icon background image](https://github.com/LuMiSxh/Arknights-MacOS-Client/blob/main/Sources/ArknightsClient/Resources/GameIconBackground.png) | project | `MPL-2.0` | Verified | None                                                    |
| [Operator icon frame graphic](https://github.com/LuMiSxh/Arknights-MacOS-Client/blob/main/Sources/ArknightsClient/Resources/OperatorIconFrame.svg) | project | `MPL-2.0` | Verified | None                                                    |

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

The runtime lists above can include notices that need more than a short label. A runtime dependency can carry an additional notice. The release artifact and upstream source distributions remain authoritative for the complete notice set.

> [!WARNING]
> A component with the status `Not yet verified` has no confirmed license. A public binary release needs a verified license for every component that ships. Keep the GitHub release in draft until the review of each such component is complete.

> [!CAUTION]
> Media codecs and related libraries can carry obligations or patent considerations that a short license label does not capture. Do not remove a notice because a component is dynamically linked. Do not assume that this inventory answers patent or distribution questions.

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

## Release review checklist

For each binary release, compare these items:

1. The runtime archive SHA-256 and build-recipe SHA-256 in the repository and in the packaged `RUNTIME.json`.
2. The component commits in `runtime.json` with the source links above.
3. The runtime's actual files against the declared interface: `bin/wine64`, `bin/wineserver`, `winemetal.dll`, the macOS driver, and the DXMT x64 library set. Runtimes before 0.7.0 also ship x32.
4. The license texts on the [License texts](license-texts.md) page against the generated lists in this page. Run `scripts/licenses.py --check --strict --runtime .build/runtime`. Compare the list with the notices file in the app: **Settings → About → Third-Party Notices**.
5. The source and notice package supplied for every bundled runtime component.

The runtime repository validates its source pins and release inventory. The client release still requires a review of the exact packaged archive. Keep a release in draft while a notice or corresponding-source review is incomplete. See [Source code](source-code.md) and [Releases and updates](../development/releases-and-updates.md).
