---
title: Source code
description: Launcher source and corresponding-source information for releases
order: 10
---

# Source code

MPL-2.0 licenses the original native launcher and the project compatibility wrappers. Project source files use SPDX markers. The complete native source of a launcher release is at the matching tag, `vX.Y.Z`, in the [Arknights Client repository](https://github.com/LuMiSxh/Arknights-MacOS-Client).

The tag contains the source for the launcher executable, compatibility wrappers, packaging scripts, documentation, and release configuration. It is not the complete corresponding source for every third-party binary in the prebuilt runtime.

## What corresponds to which binary

| Release material               | Corresponding source or record                                                                                                                                                           |
| ------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Native launcher                | Swift sources under `Sources/` at the matching tag                                                                                                                                       |
| Native compatibility helpers   | C/Objective-C sources under `RuntimeSupport/` at the matching tag                                                                                                                        |
| Bundled Wine + DXMT runtime    | The archive checksum, component revisions, and interface in [`runtime.json`](../../runtime.json), plus the upstream source repositories in [Third-party notices](third-party-notices.md) |
| Packaging and runtime patching | `scripts/build_app.py`, `scripts/build_compatibility.py`, and the pinned build recipe                                                                                                    |
| Third-party notices            | [Third-party notices](third-party-notices.md) and the verbatim [License texts](license-texts.md)                                                                                         |

The release attaches `Runtime-Build-Recipe.tar.gz`. It is a provenance record. It does not replace the upstream source and notice obligations of the runtime components.

<!-- licenses:begin offer -->

## Written offer for LGPL and GPL components

The runtime contains software under the GNU LGPL and GNU GPL licenses. Wine is one example. You can ask for the corresponding source of any such component in a release that you received. To ask, open an issue in the [Arknights Client repository](https://github.com/LuMiSxh/Arknights-MacOS-Client/issues). Name the version of the app and the component. The maintainer then sends the source or the exact public location of the source.

### What this offer covers today

- The runtime release page: [https://github.com/LuMiSxh/Arknights-MacOS-Runtime/releases/tag/v0.7.0-rc2](https://github.com/LuMiSxh/Arknights-MacOS-Runtime/releases/tag/v0.7.0-rc2).
- The pinned build recipe archive: [https://github.com/LuMiSxh/Arknights-MacOS-Runtime/releases/download/v0.7.0-rc2/Arknights-MacOS-Runtime-v0.7.0-rc2-source.tar.gz](https://github.com/LuMiSxh/Arknights-MacOS-Runtime/releases/download/v0.7.0-rc2/Arknights-MacOS-Runtime-v0.7.0-rc2-source.tar.gz). Its SHA-256 is `d666c767a77dfad97404fa381cbd095b83201477c4b4af3285ae52b200007215`.
- The pinned source trees of the runtime components, as `runtime.json` records them. [Third-party notices](third-party-notices.md) links each tree.
- The pinned [Nixpkgs revision](https://github.com/NixOS/nixpkgs/tree/ac62194c3917d5f474c1a844b6fd6da2db95077d). It names the exact source of each library that the runtime copies from Nixpkgs.

### What this offer does not cover today

- The build recipe archive is a provenance record. It is not a complete corresponding-source archive.
- The project has not yet published one source archive for the libraries that the runtime copies from Nixpkgs. The runtime repository still has this work open. Until the project publishes that archive, the written offer for these libraries uses the issue process above.
- This text does not fix a period of validity for the offer. The maintainer must set that period before a public binary release.

<!-- licenses:end offer -->

> [!IMPORTANT]
> `runtime.json` identifies the runtime bytes in a DMG. It is not the runtime source. A public binary release waits until the maintainer has reviewed the exact sources and notices of its bundled components. The [release review](../development/releases-and-updates.md#release-review) lists the checks. If a published asset is wrong, do not replace it. Open a repository issue with the version and asset. A corrected build uses a higher version.
