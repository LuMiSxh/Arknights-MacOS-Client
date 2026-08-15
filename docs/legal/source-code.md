# Source code

Arknights Client is licensed under MPL-2.0. Source for a launcher release is available from the matching `vX.Y.Z` tag at:

https://github.com/LuMiSxh/Arknights-MacOS-Client

The release workflow also attaches `Runtime-Build-Recipe.tar.gz`. That archive contains the pinned runtime build recipe and is useful for provenance, but it does not contain complete corresponding source for every binary in the runtime.

Runtime versions and upstream revisions are recorded in [`runtime.json`](../../runtime.json) and [`third-party-notices.md`](third-party-notices.md). A public binary release must additionally provide the exact corresponding sources and notices required by those components. Until that bundle exists, development DMGs must not be published.
