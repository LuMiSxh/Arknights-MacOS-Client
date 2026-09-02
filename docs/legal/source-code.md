---
title: Source code
description: Launcher source and corresponding-source information for releases
order: 10
---

# Source code

The original native launcher and project compatibility wrappers are licensed under MPL-2.0. Project
source files use SPDX markers to identify that license, and the complete native project source for a launcher
release is available from the matching version tag, named `vX.Y.Z`, at the
[Arknights Client repository](https://github.com/LuMiSxh/Arknights-MacOS-Client).

The tag contains the source used for the launcher executable, project compatibility wrappers, packaging scripts, documentation, and release configuration. It does not by itself claim to be the complete corresponding source for every third-party binary in the prebuilt runtime. Build metadata is derived from the checked-in
[`Package.swift`](../../Package.swift), [`Resources/Info.plist`](../../Resources/Info.plist), and
[`runtime.json`](../../runtime.json) files rather than from an untracked build directory.

## What corresponds to which binary

| Release material               | Corresponding source or record                                                                                                                                                                                    |
| ------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Native launcher                | Swift sources under `Sources/ArknightsClient/` at the matching tag                                                                                                                                                |
| Native compatibility helpers   | C/Objective-C sources under `RuntimeSupport/` at the matching tag                                                                                                                                                 |
| Bundled Wine + DXMT runtime    | The exact archive checksum, component revisions, and interface in [`runtime.json`](../../runtime.json), plus the upstream source repositories listed in [Third-party notices](third-party-notices.md)             |
| Packaging and runtime patching | `scripts/build_app.py`, `scripts/build_compatibility.py`, and the pinned build recipe record                                                                                                                      |
| Third-party notices            | [`docs/legal/third-party-notices.md`](third-party-notices.md) and verbatim files under the repository's [license-text directory](https://github.com/LuMiSxh/Arknights-MacOS-Client/tree/main/docs/legal/licenses) |

The release workflow attaches `Runtime-Build-Recipe.tar.gz`. That archive contains the pinned
runtime build recipe and is useful for provenance. It is not a complete corresponding-source
archive for every binary in the prebuilt runtime; its presence must not be described as replacing
the upstream source and notice obligations of those components.

> [!IMPORTANT]
> `runtime.json` is the release's identity record, not the runtime source itself. When a runtime
> changes, review the archive checksum, build-recipe checksum, component commits, required layout,
> license set, and prefix revision together. A version label or a download URL alone is not enough
> to identify the bytes packaged in a DMG.

## Release review

Before publishing a binary release, the maintainer should be able to answer all of these questions:

1. Does the source tag match `CFBundleShortVersionString` and the release notes?
2. Does the app's `Contents/Resources/RUNTIME.json` match the repository `runtime.json` used by the
   build?
3. Is the exact runtime archive and build recipe available at the pinned HTTPS URLs and verified by
   the recorded SHA-256 values?
4. Are `LICENSE`, `SOURCE_CODE.md`, `THIRD_PARTY_NOTICES.md`, `RUNTIME.json`, and every file under
   `ThirdPartyLicenses/` present in the app bundle?
5. Has the release-specific corresponding-source and notice package been reviewed for every bundled
   runtime component before the draft is published?

The packaging checks enforce the input files, runtime interface, localization resources, and
required license text files. They cannot by themselves determine whether a third-party component's
full corresponding source has been published, so that final review remains a release decision.

For every release, maintain a component-level redistribution record outside the generated binaries that maps each bundled library to its exact version or revision, applicable notices, preferred-form source, build scripts, and any relinkable material or written/network offer required by that component's terms. The canonical license files in this repository are inputs to that review, not a substitute for it. Attach or publish the resulting source/notice material through a stable release-linked location before turning the draft public.

> [!WARNING]
> Runtime versions and upstream revisions are recorded in [`runtime.json`](../../runtime.json) and
> [`third-party-notices.md`](third-party-notices.md). Under the project's release policy, a public
> binary release waits until the exact corresponding sources and notices required by its bundled
> components have been assembled and reviewed. A development DMG is not a substitute for that
> release bundle.

If a release artifact is missing a notice, has a different runtime checksum, or points to the wrong
source tag, keep it in draft state and open a repository issue with the affected version and asset.
Do not silently replace an already-published asset; releases are immutable and a corrected build
uses a higher version.
