---
title: Source code
description: Launcher source and corresponding-source information for releases
order: 10
---

# Source code

MPL-2.0 licenses the original native launcher and the project compatibility wrappers. Project source files use SPDX markers. The complete native source of a launcher release is at the matching tag, `vX.Y.Z`, in the [Arknights Client repository](https://github.com/LuMiSxh/Arknights-MacOS-Client).

The tag contains the source for the launcher executable, compatibility wrappers, packaging scripts, documentation, and release configuration. It is not the complete corresponding source for every third-party binary in a downloaded runtime.

## What corresponds to which binary

| Release material             | Corresponding source or record                                                                                                                                                                      |
| ---------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Native launcher              | Swift sources under `Sources/` at the matching tag                                                                                                                                                  |
| Native compatibility helpers | C/Objective-C sources under `RuntimeSupport/` at the matching tag                                                                                                                                   |
| Downloaded runtime archive   | The archive URL, checksum, size, component revisions, and interface in [`runtime.json`](../../runtime.json), plus the upstream source repositories in [Third-party notices](third-party-notices.md) |
| Packaging                    | `scripts/build_app.py` and `scripts/build_compatibility.py`                                                                                                                                         |
| Third-party notices          | [Third-party notices](third-party-notices.md) and the verbatim [License texts](license-texts.md)                                                                                                    |

The app bundle does not contain a runtime. Each runtime archive carries its own build provenance, license texts, and `NOTICE.md`. The release workflow does not attach a client-side runtime source archive.

<!-- licenses:begin offer -->
## Written offer for LGPL and GPL components

The runtimes contain software under the GNU LGPL and GNU GPL licenses. Wine is one example. You can ask for the corresponding source of any such component in a release that you received. To ask, fill in the [Source code request](https://github.com/LuMiSxh/Arknights-MacOS-Client/issues/new?template=source-request.yml) issue form. Name the version of the app, the architecture, and the component. The maintainer then sends the source or the exact public location of the source.

### What this offer covers today

- The x86 runtime release page: [https://github.com/LuMiSxh/Arknights-MacOS-Runtime/releases/tag/v0.8.0-rc7+x86](https://github.com/LuMiSxh/Arknights-MacOS-Runtime/releases/tag/v0.8.0-rc7+x86).
- The arm runtime release page: [https://github.com/LuMiSxh/Arknights-MacOS-Runtime/releases/tag/v0.8.0-rc8+arm](https://github.com/LuMiSxh/Arknights-MacOS-Runtime/releases/tag/v0.8.0-rc8+arm).
- The pinned source trees of the runtime components, as `runtime.json` records them. [Third-party notices](third-party-notices.md) links each tree.
- The license texts and notices inside each runtime archive. The launcher shows them for the installed runtime under **Settings → About**.

### What this offer does not cover today

- The app bundle does not contain a runtime. Each runtime archive is the authoritative record of its own build inputs, notices, and corresponding source.
- The client does not publish a generated runtime closure inventory.
- This text does not fix a period of validity for the offer. The maintainer must set that period before a public binary release.
<!-- licenses:end offer -->

> [!IMPORTANT]
> `runtime.json` identifies the runtime bytes that the launcher downloads. It is not the runtime source. A public binary release waits until the maintainer has reviewed the exact sources and notices of each pinned runtime archive. The [release review](../development/releases-and-updates.md#release-review) lists the checks. If a published asset is wrong, do not replace it. Open a repository issue with the version and asset. A corrected build uses a higher version.
