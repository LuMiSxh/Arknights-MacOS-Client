---
title: Source code
description: Launcher source and corresponding-source information for releases
order: 10
---

# Source code

MPL-2.0 licenses the original native launcher and the project compatibility wrappers. Project source files use SPDX markers to identify that license. The complete native project source for a launcher release is available from the matching version tag, named `vX.Y.Z`, at the [Arknights Client repository](https://github.com/LuMiSxh/Arknights-MacOS-Client).

The tag contains the source for the launcher executable, project compatibility wrappers, packaging scripts, documentation, and release configuration. It does not by itself claim to be the complete corresponding source for every third-party binary in the prebuilt runtime. Build metadata comes from the checked-in [`Package.swift`](../../Package.swift), [`Resources/Info.plist`](../../Resources/Info.plist), and [`runtime.json`](../../runtime.json) files, not from an untracked build directory.

## What corresponds to which binary

| Release material               | Corresponding source or record                                                                                                                                                                        |
| ------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Native launcher                | Swift sources under `Sources/ArknightsClient/` at the matching tag                                                                                                                                    |
| Native compatibility helpers   | C/Objective-C sources under `RuntimeSupport/` at the matching tag                                                                                                                                     |
| Bundled Wine + DXMT runtime    | The exact archive checksum, component revisions, and interface in [`runtime.json`](../../runtime.json), plus the upstream source repositories listed in [Third-party notices](third-party-notices.md) |
| Packaging and runtime patching | `scripts/build_app.py`, `scripts/build_compatibility.py`, and the pinned build recipe record                                                                                                          |
| Third-party notices            | [`docs/legal/third-party-notices.md`](third-party-notices.md) and the verbatim [License texts](license-texts.md)                                                                                      |

The release workflow attaches `Runtime-Build-Recipe.tar.gz`. It contains the pinned runtime build recipe and is useful for provenance. It is not a complete corresponding-source archive for every binary in the prebuilt runtime. Do not describe its presence as a replacement for the upstream source and notice obligations of those components.

<!-- licenses:begin offer -->

## Written offer for LGPL and GPL components

The runtime contains software under the GNU LGPL and GNU GPL licenses. Wine is one example. You can ask for the corresponding source of any such component in a release that you received. To ask, open an issue in the [Arknights Client repository](https://github.com/LuMiSxh/Arknights-MacOS-Client/issues). Name the version of the app and the component. The maintainer then sends the source or the exact public location of the source.

### What this offer covers today

- The runtime release page: [https://github.com/LuMiSxh/Arknights-MacOS-Runtime/releases/tag/v0.6.1](https://github.com/LuMiSxh/Arknights-MacOS-Runtime/releases/tag/v0.6.1).
- The pinned build recipe archive: [https://github.com/LuMiSxh/Arknights-MacOS-Runtime/releases/download/v0.6.1/Arknights-MacOS-Runtime-v0.6.1-source.tar.gz](https://github.com/LuMiSxh/Arknights-MacOS-Runtime/releases/download/v0.6.1/Arknights-MacOS-Runtime-v0.6.1-source.tar.gz). Its SHA-256 is `55889cdbda123751ab5b7e9ea0dc34c8afd8ee95e548f84d6a390fdc5c5e70d2`.
- The pinned source trees of the runtime components, as `runtime.json` records them. [Third-party notices](third-party-notices.md) links each tree.
- The pinned [Nixpkgs revision](https://github.com/NixOS/nixpkgs/tree/ac62194c3917d5f474c1a844b6fd6da2db95077d). It names the exact source of each library that the runtime copies from Nixpkgs.

### What this offer does not cover today

- The build recipe archive is a provenance record. It is not a complete corresponding-source archive.
- The project has not yet published one source archive for the libraries that the runtime copies from Nixpkgs. The runtime repository still has this work open. Until the project publishes that archive, the written offer for these libraries uses the issue process above.
- This text does not fix a period of validity for the offer. The maintainer must set that period before a public binary release.

<!-- licenses:end offer -->

> [!IMPORTANT]
> `runtime.json` is the release's identity record, not the runtime source itself. When a runtime changes, review the archive checksum, build-recipe checksum, component commits, required layout, license set, and prefix revision together. A version label or a download URL alone is not enough to identify the bytes packaged in a DMG.

## Release review

Before you publish a binary release, the maintainer must be able to answer these questions:

1. Does the source tag match `CFBundleShortVersionString` and the release notes?
2. Does the app's `Contents/Resources/RUNTIME.json` match the repository `runtime.json` that the build used?
3. Are the exact runtime archive and build recipe available at the pinned HTTPS URLs? Do the recorded SHA-256 values verify them?
4. Does the app bundle contain `LICENSE`, `RUNTIME.json`, and `ThirdPartyNotices.deflate`? Does the website publish the current [Third-party notices](third-party-notices.md) and [License texts](license-texts.md)?
5. Has the release-specific corresponding-source and notice package been reviewed for every bundled runtime component before the draft is published?

The packaging checks enforce the input files, runtime interface, resource files, and required license text files in the repository. They cannot determine whether a third-party component's full corresponding source has been published. That final review remains a release decision.

For every release, maintain a component-level redistribution record outside the generated binaries. It maps each bundled library to its exact version or revision, applicable notices, preferred-form source, build scripts, and any relinkable material or written or network offer that the component's terms require. The canonical license files in this repository are inputs to that review, not a substitute for it. Attach or publish the resulting source and notice material through a stable release-linked location before you make the draft public.

> [!WARNING]
> Runtime versions and upstream revisions are recorded in [`runtime.json`](../../runtime.json) and [`third-party-notices.md`](third-party-notices.md). Under the project's release policy, a public binary release waits until the team has assembled and reviewed the exact corresponding sources and notices that its bundled components require. A development DMG is not a substitute for that release bundle.

If a release artifact is missing a notice, has a different runtime checksum, or points to the wrong source tag, keep it in draft state. Open a repository issue with the affected version and asset. Do not silently replace an already-published asset. Releases are immutable. A corrected build uses a higher version.
