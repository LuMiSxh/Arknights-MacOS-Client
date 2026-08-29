---
title: Legal
description: Licensing, third-party notices, and corresponding-source information
order: 40
---

# Legal

This section records the project's source license, bundled third-party notices, and release-artifact
boundaries. It describes what this repository and its builds contain; it is not a substitute for
legal advice about a particular redistribution.

Arknights Client is community-maintained and is not affiliated with Hypergryph or Yostar. Arknights,
its game files, names, and artwork belong to their respective owners.

## Read by purpose

| If you need to...                                                | Read                                                                                             |
| ---------------------------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| inspect the license for the native launcher and release source   | [Source code](source-code.md)                                                                    |
| identify runtime components, exact source revisions, and notices | [Third-party notices](third-party-notices.md)                                                    |
| read a verbatim license text                                     | [License texts](https://github.com/LuMiSxh/Arknights-MacOS-Client/tree/main/docs/legal/licenses) |

## What a release contains

| Material                                                 | Project boundary                                                                                                                                |
| -------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| Native SwiftUI launcher and small compatibility wrappers | Original project source, marked MPL-2.0; source is available from the matching repository tag                                                   |
| Wine + DXMT compatibility runtime                        | Prebuilt third-party material with its own component licenses and provenance; see [Third-party notices](third-party-notices.md)                 |
| Sparkle update framework                                 | Bundled third-party framework and notices, distributed under its own terms                                                                      |
| Arknights game files                                     | Not included in source archives, DMGs, or update archives; downloaded from official Yostar endpoints by the user-facing installer               |
| Official or user artwork                                 | Official remote artwork is cached at runtime; repository releases do not bundle downloaded wallpapers, and user-selected files remain user data |

> [!WARNING]
> The repository's MPL-2.0 `LICENSE` does not replace the notices or conditions for bundled Wine,
> DXMT, media, browser, update, or other third-party components. Review the component-specific
> texts before redistributing a build, and do not treat the release as permission to redistribute
> Arknights game files or artwork.

License text files for bundled components remain in the repository's [license-text directory](https://github.com/LuMiSxh/Arknights-MacOS-Client/tree/main/docs/legal/licenses) and are reproduced
verbatim where required. The packaging script copies them into the app bundle's
`Contents/Resources/ThirdPartyLicenses/` directory together with `LICENSE`,
`THIRD_PARTY_NOTICES.md`, `SOURCE_CODE.md`, `RUNTIME.json`, and `CHANGELOG.md`.

For a release review, compare the artifact's `RUNTIME.json` with the repository [`runtime.json`](../../runtime.json),
check the matching `vX.Y.Z` source tag described in [Source code](source-code.md), and verify that the notices and license
files are present in the app bundle. If any of those do not match, keep the release draft and report
the discrepancy before publishing.

> [!NOTE]
> The legal pages are also rendered on the documentation website. Website links describe the
> repository and release process; the app bundle contains the release-specific copies used by the
> packaged application.
