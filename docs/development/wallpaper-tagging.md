---
title: Wallpaper tagging and search
description: Curating searchable metadata for official wallpaper presets
order: 70
audience: developers
---

# Wallpaper tagging and search

The Artwork gallery searches Yostar's official wallpaper titles and the curated operator, faction,
event, and collaboration tags in
[`WallpaperTags.json`](../../Sources/ArknightsClient/Resources/WallpaperTags.json). Search terms are
case- and diacritic-insensitive; every term must match the title or a tag. Once a query exactly names
a known tag, it matches that tag rather than longer tags with the same prefix.

The gallery also groups wallpapers as Story, Commemorative, Celebration, or Holiday based on their
official titles. This classification needs no manifest entry and therefore works for new wallpapers.

## Finding untagged wallpapers

The `wallpaper-tag-scan` workflow runs daily and can be dispatched manually. It compares the Global
Fankit gallery with the bundled manifest and open `wallpaper-tagging` issues, then files one issue for
each newly discovered wallpaper. It never guesses tags or modifies the manifest.

Run the same scan locally without creating issues:

```sh
uv run --locked scripts/scan_untagged_wallpapers.py --dry-run
```

Add lowercase tags to the matching `global-<id>` entry in `WallpaperTags.json`, then reference the
tagging issue from the pull request. The updated tags ship with the next launcher build.

```json
{
	"schemaVersion": 1,
	"tags": {
		"global-4431": ["amiya", "closer", "anniversary"]
	}
}
```

Changing the manifest shape requires a schema-version bump and matching decoder change.
