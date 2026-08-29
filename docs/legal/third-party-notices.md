---
title: Third-party notices
description: Licenses, runtime components, and notices bundled with Arknights Client
order: 20
---

# Third-party notices

> [!IMPORTANT]
> Arknights Client packages a prebuilt compatibility runtime. Exact versions, archive hashes, and
> build provenance are pinned in [`runtime.json`](../../runtime.json). The app also embeds small
> MPL-2.0 compatibility wrappers built from `RuntimeSupport/`; it does not distribute the Vuplex
> SDK or the upstream game files.

The launcher embeds [Sparkle 2.9.6](https://github.com/sparkle-project/Sparkle), an MIT-licensed
update framework. Its MIT license and notices for bundled bsdiff, sais-lite, Ed25519, and
signature-verifier code are included in [`ThirdPartyLicenses/sparkle.txt`](licenses/sparkle.txt) in
the app bundle.

## How to read this page

`runtime.json` is the source of truth for the runtime artifact and its interface. The component
versions below are the human-readable labels from that file; each source link points to the exact
provenance commit recorded there. The release's `RUNTIME.json` is copied from the same input during
packaging, so it can be checked without trusting the repository checkout used to build the app.

This page is an inventory and release-review aid. It does not relicense a component, summarize every
condition of a license, or determine whether a particular redistribution is permitted. Read the
verbatim license text shipped with the artifact and the upstream project notices when making that
decision.

## Runtime components

| Component     | Version or revision                                    | License                                                                                             | Exact provenance source                                                                                                |
| ------------- | ------------------------------------------------------ | --------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| WineCX / Wine | Wine 11.15, `51e3854751e51ed25af4cd3af367f92f421ed0c8` | LGPL-2.1-or-later and bundled third-party terms                                                     | [dappermint/winecx commit](https://github.com/dappermint/winecx/tree/51e3854751e51ed25af4cd3af367f92f421ed0c8)         |
| DXMT          | 0.80, `589adb780354b461645b29999cefaf533594ee99`       | MIT and bundled third-party terms                                                                   | [3Shain/dxmt commit](https://github.com/3Shain/dxmt/tree/589adb780354b461645b29999cefaf533594ee99)                     |
| MoltenVK      | 1.4.2, `db66022459ffb663aa2b50f6b018bc2e124f5edf`      | Apache-2.0 and bundled third-party terms                                                            | [KhronosGroup/MoltenVK commit](https://github.com/KhronosGroup/MoltenVK/tree/db66022459ffb663aa2b50f6b018bc2e124f5edf) |
| Wine Gecko    | 2.47.4, `557ea0c2e9f9ebd621323b3dbfbdd18c2528759c`     | MPL/GPL/LGPL terms and Mozilla notices                                                              | [Wine Gecko commit](https://gitlab.winehq.org/wine/wine-gecko/-/tree/557ea0c2e9f9ebd621323b3dbfbdd18c2528759c)         |
| GStreamer     | 1.26.3, including base, good, bad, and libav plugins   | Mostly LGPL-2.1-or-later; selected plugins and dependencies are GPL-2.0-or-later or use other terms | [GStreamer commit](https://github.com/GStreamer/gstreamer/tree/87bc0c6e949e3dcc440658f78ef52aa8088cb62f)               |
| FFmpeg        | 7.1.1, `db69d06eeeab4f46da15030a80d539efb4503ca8`      | GPL-3.0-or-later for the bundled configuration                                                      | [FFmpeg commit](https://github.com/FFmpeg/FFmpeg/tree/db69d06eeeab4f46da15030a80d539efb4503ca8)                        |

> [!IMPORTANT]
> The runtime also contains dynamically linked libraries for media, text, networking, compression, and X11 compatibility. Notable media dependencies include x264, x265, FDK-AAC, FAAD2, libdvdcss, libdvdnav, libdvdread, OpenH264, libde265, libaom, dav1d, SVT-AV1, libvpx, LAME, OpenMPT, FLAC, Vorbis, Opus, Theora, Speex, and libsndfile. Their own licenses and patent terms continue to apply.

## Notice inventory

The packaging script copies the following canonical text files from `docs/legal/licenses/` into
`Contents/Resources/ThirdPartyLicenses/`:

| File                                        | Primary inventory entry                                             |
| ------------------------------------------- | ------------------------------------------------------------------- |
| [`apache-2.0.txt`](licenses/apache-2.0.txt) | Apache-2.0 runtime terms, including MoltenVK's license family       |
| [`gpl-2.0.txt`](licenses/gpl-2.0.txt)       | GPL-2.0 runtime terms where the bundled configuration requires them |
| [`gpl-3.0.txt`](licenses/gpl-3.0.txt)       | FFmpeg's GPL-3.0-or-later configuration terms                       |
| [`lgpl-2.1.txt`](licenses/lgpl-2.1.txt)     | Wine and LGPL-2.1-or-later runtime terms                            |
| [`lgpl-3.0.txt`](licenses/lgpl-3.0.txt)     | LGPL-3.0 runtime terms present in the runtime inventory             |
| [`mit-dxmt.txt`](licenses/mit-dxmt.txt)     | DXMT 0.80 MIT license                                               |
| [`fdk-aac.txt`](licenses/fdk-aac.txt)       | Fraunhofer FDK-AAC notice                                           |
| [`sparkle.txt`](licenses/sparkle.txt)       | Sparkle and its listed bundled notices                              |

The inventory is intentionally conservative: a canonical text file may cover more than the short
label in this table, and a runtime dependency may carry an additional notice. The release artifact
and upstream source distributions remain authoritative for the complete notice set.

> [!WARNING]
> This eight-file inventory is not a complete component-by-component SBOM or corresponding-source package. A public binary release requires a reviewed release-specific mapping for every bundled library, including its exact revision, license and notice files, preferred-form source, build instructions, and any relinkable material or source offer its terms require. Keep the GitHub release in draft until that package has a stable release-linked location.

> [!CAUTION]
> Media codecs and related libraries can carry obligations or patent considerations that are not
> captured by a short license label. Do not remove a notice because a component is dynamically linked,
> and do not assume that this inventory answers patent or distribution questions.

## Included and excluded material

| Material                                   | Packaged?                       | Where its boundary is recorded                                               |
| ------------------------------------------ | ------------------------------- | ---------------------------------------------------------------------------- |
| Native launcher                            | Yes                             | Repository source and top-level [`LICENSE`](../../LICENSE)                   |
| Project compatibility wrappers and bridges | Yes                             | `RuntimeSupport/` source at the matching tag; MPL-2.0 SPDX markers           |
| WineCX + DXMT runtime                      | Yes, as a prebuilt runtime unit | [`runtime.json`](../../runtime.json), `RUNTIME.json`, and this page          |
| Sparkle framework                          | Yes                             | `ThirdPartyLicenses/sparkle.txt` and the Sparkle project                     |
| Arknights game files                       | No                              | Downloaded from official Yostar endpoints after the user starts installation |
| Wine Mono                                  | No                              | Explicitly excluded by packaging                                             |
| DXVK                                       | No                              | Not copied into the app bundle                                               |
| Apple Game Porting Toolkit                 | No                              | Not copied into the app bundle                                               |

> [!WARNING]
> Do not use the presence of a source link or license text as evidence that a dependency is bundled
> in a particular release. Confirm the actual app bundle, its `RUNTIME.json`, and its
> `ThirdPartyLicenses/` directory before describing an artifact.

## Release review checklist

For each binary release, compare:

1. The runtime archive SHA-256 and build-recipe SHA-256 in the repository and packaged
   `RUNTIME.json`.
2. The component commits in `runtime.json` with the source links above.
3. The runtime's actual files against the declared interface (`bin/wine64`, `bin/wineserver`,
   `winemetal.dll`, the macOS driver, and both DXMT library sets).
4. The license and notice files in the app bundle against the repository's `licenses/` directory.
5. The source and notice package supplied for every bundled runtime component.

The runtime monitor can report unavailable pinned artifacts and provenance mismatches, but it does
not decide whether a component is ready for public redistribution. Keep a release in draft while a
notice or corresponding-source review is incomplete; see [Source code](source-code.md) and [Releases
and updates](../development/releases-and-updates.md).
