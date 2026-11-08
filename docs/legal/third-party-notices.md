---
title: Third-party notices
description: Licenses, runtime components, and notices for Arknights Client
order: 20
---

# Third-party notices

> [!IMPORTANT]
> Arknights Client downloads a prebuilt compatibility runtime for the architecture that you choose. [`runtime.json`](../../runtime.json) pins one archive per runtime lane, with its exact version, archive hash, size, and build provenance. The app bundle does not contain a runtime. The app embeds small MPL-2.0 compatibility wrappers built from `RuntimeSupport/`. It does not distribute the Vuplex SDK or the upstream game files.

The app bundles one compact file with the notices of its own components. This website publishes the same content. The [License texts](license-texts.md) page holds the full text of every named license. The [Source code](source-code.md) page describes how to get the source.

`runtime.json` is the source of truth for each runtime archive. Each source link below points to the provenance commit recorded there. This page is an inventory. It does not relicense a component or decide whether a redistribution is permitted. Read the verbatim texts and the upstream notices for that.

## Runtime components

<!-- runtime:begin components -->
| Runtime | Component | Version or revision | License | Exact provenance source |
| --- | --- | --- | --- | --- |
| x86 | WineCX / Wine | 11.17, `a54b8240683e92bf4c15cb1ba6bf92a9539bd768` | LGPL-2.1-or-later | [dappermint/winecx commit](https://github.com/dappermint/winecx/tree/a54b8240683e92bf4c15cb1ba6bf92a9539bd768) |
| x86 | DXMT | 0.80-361-g9839e55, `9839e55f98d4aca103957ee4132d6395a325a9ed` | LGPL-2.1-or-later | [3Shain/dxmt commit](https://github.com/3Shain/dxmt/tree/9839e55f98d4aca103957ee4132d6395a325a9ed) |
| x86 | MoltenVK | 1.4.2, `db66022459ffb663aa2b50f6b018bc2e124f5edf` | Apache-2.0 | [KhronosGroup/MoltenVK commit](https://github.com/KhronosGroup/MoltenVK/tree/db66022459ffb663aa2b50f6b018bc2e124f5edf) |
<!-- runtime:end components -->

The x86_64 runtime contains WineCX, DXMT, and MoltenVK. The ARM64 runtime contains Wine, FEX, Mesa, and DXMT. Each runtime archive carries its own license index, license texts, and `NOTICE.md`. The launcher shows those notices for the installed runtime under **Settings → About**.

The client does not generate a runtime closure inventory. The runtime archive is the authoritative record of its own components, build inputs, and notices.

## Runtime build provenance

<!-- runtime:begin build -->
The client pins one runtime archive per architecture. The launcher downloads the archive for the architecture that you choose; the app bundle does not contain a runtime. Each archive carries its own build provenance, license texts, and notices. The client does not generate a runtime closure inventory.

| Runtime | Release | Archive SHA-256 | Archive size |
| --- | --- | --- | --- |
| x86 | [v0.8.0-rc7+x86](https://github.com/LuMiSxh/Arknights-MacOS-Runtime/releases/tag/v0.8.0-rc7+x86) | `428f69821dac948a13cef65ab89b92b5bca8f95d922f14476e42e2cb373d4b5e` | 119320594 bytes |
| arm | Not pinned yet | | |
<!-- runtime:end build -->

> [!IMPORTANT]
> Each runtime archive contains dynamically linked libraries for text, networking, cryptography, and compression. Their own licenses continue to apply.

## Generated inventory

Scripts generate the lists between the marker pairs. Do not edit them by hand. [License automation](../development/license-automation.md#generated-blocks) describes the markers.

<!-- licenses:begin launcher -->
## Launcher components

These components ship inside the app. `Not yet verified` means that the project has not confirmed the license of the component.

| Component | Version | License | Status | Text |
| --- | --- | --- | --- | --- |
| [Sparkle](https://github.com/sparkle-project/Sparkle/tree/2.9.6) (with bundled bsdiff, sais-lite, ed25519, and signature-verifier notices) | 2.9.6 | `MIT` | Verified | [`sparkle.txt`](licenses/sparkle.txt) |
| [YouTubePlayerKit](https://github.com/SvenTiigi/YouTubePlayerKit/tree/2.0.5) | 2.0.5 | `MIT` | Verified | [`youtubeplayerkit.txt`](licenses/youtubeplayerkit.txt) |
| [Application icon](https://github.com/LuMiSxh/Arknights-MacOS-Client/tree/main/Resources) (`just icon` generates it from `Resources/AppIcon.icon`) | project | `MPL-2.0` | Verified | None |
| [Wallpaper tag data](https://github.com/LuMiSxh/Arknights-MacOS-Client/blob/main/Sources/ArknightsCore/Resources/WallpaperTags.json) | project | `MPL-2.0` | Verified | None |
| [App icon tint source image](https://github.com/LuMiSxh/Arknights-MacOS-Client/blob/main/Sources/ArknightsCore/Resources/AppIconTintSource.png) | project | `MPL-2.0` | Verified | None |
| [Game icon background image](https://github.com/LuMiSxh/Arknights-MacOS-Client/blob/main/Sources/ArknightsCore/Resources/GameIconBackground.png) | project | `MPL-2.0` | Verified | None |
| [Operator icon frame graphic](https://github.com/LuMiSxh/Arknights-MacOS-Client/blob/main/Sources/ArknightsCore/Resources/OperatorIconFrame.svg) | project | `MPL-2.0` | Verified | None |
<!-- licenses:end launcher -->

<!-- licenses:begin website -->
## Website components

The documentation website embeds these packages. They are not part of the app. The website build also embeds the transitive dependencies of these packages. Each dependency keeps its own license.

| Component | Version | License | Status | Text |
| --- | --- | --- | --- | --- |
| [marked](https://github.com/markedjs/marked/tree/v18.0.11) | 18.0.11 | `MIT` | Verified | [`marked.txt`](licenses/marked.txt) |
| [marked-gfm-heading-id](https://github.com/markedjs/marked-gfm-heading-id/tree/v4.1.4) | 4.1.4 | `MIT` | Verified | [`marked-gfm-heading-id.txt`](licenses/marked-gfm-heading-id.txt) |
| [mermaid](https://github.com/mermaid-js/mermaid/tree/mermaid@11.17.2) | 11.17.2 | `MIT` | Verified | [`mermaid.txt`](licenses/mermaid.txt) |
| [yaml](https://github.com/eemeli/yaml/tree/v2.9.0) | 2.9.0 | `ISC` | Verified | [`yaml.txt`](licenses/yaml.txt) |
| [svelte](https://github.com/sveltejs/svelte/tree/svelte@5.57.0) | 5.57.0 | `MIT` | Verified | [`svelte.txt`](licenses/svelte.txt) |
| [@sveltejs/kit](https://github.com/sveltejs/kit/tree/@sveltejs/kit@2.70.3) | 2.70.3 | `MIT` | Verified | [`sveltejs-kit.txt`](licenses/sveltejs-kit.txt) |
| [anasthasia](https://github.com/LuMiSxh/Anasthasia/tree/v0.2.4) | 0.2.4 | `BSD-3-Clause` | Verified | [`anasthasia.txt`](licenses/anasthasia.txt) |
| [uPlot](https://github.com/leeoniya/uPlot/tree/1.6.32) | 1.6.32 | `MIT` | Verified | [`uplot.txt`](licenses/uplot.txt) |
<!-- licenses:end website -->

<!-- licenses:begin runtime -->
## Runtime components

The launcher downloads one runtime archive for the architecture that you choose. The app bundle does not contain a runtime. Each archive lists its components and licenses in `Licenses/index.json` and carries its own `NOTICE.md`. The launcher shows those notices for the installed runtime under **Settings → About**. The client does not generate a runtime closure inventory.
<!-- licenses:end runtime -->

A runtime dependency can carry an additional notice. The release artifact and upstream source distributions remain authoritative for the complete notice set.

> [!WARNING]
> A component with the status `Not yet verified` has no confirmed license. A public binary release needs a verified license for every shipped component. Do not remove a notice because a component is dynamically linked.

## Included and excluded material

| Material                                   | Packaged?                   | Where its boundary is recorded                                                                                                                                                           |
| ------------------------------------------ | --------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Native launcher                            | Yes                         | Repository source and top-level [`LICENSE`](../../LICENSE)                                                                                                                               |
| Project compatibility wrappers and bridges | Yes                         | `RuntimeSupport/` source at the matching tag; MPL-2.0 SPDX markers                                                                                                                       |
| x86_64 runtime                             | No. Downloaded on first use | [`runtime.json`](../../runtime.json) lane `x86` and the runtime archive notices                                                                                                          |
| ARM64 runtime                              | No. Downloaded on first use | [`runtime.json`](../../runtime.json) lane `arm` and the runtime archive notices                                                                                                          |
| Sparkle framework                          | Yes                         | [License text](license-texts.md#sparkle) and the Sparkle project                                                                                                                         |
| YouTubePlayerKit                           | Yes                         | [License text](license-texts.md#youtubeplayerkit)                                                                                                                                        |
| Arknights game files                       | No                          | Downloaded from first-party publisher endpoints after the user starts installation: Yostar for Global, Japan, and Korea; Gryphline for Taiwan; Hypergryph for China and China (Bilibili) |
| Wine Mono                                  | No                          | Explicitly excluded by packaging                                                                                                                                                         |
| DXVK                                       | No                          | Not part of the client or its runtimes                                                                                                                                                   |
| Apple Game Porting Toolkit                 | No                          | Not part of the client or its runtimes                                                                                                                                                   |

> [!WARNING]
> A source link or license text is not evidence that a release bundles a dependency. Before you describe an artifact, confirm the actual app bundle and its `RUNTIME.json`, and check the notices inside the installed runtime.

## Release review

See the [release review](../development/releases-and-updates.md#release-review) for the checks before a public release.
